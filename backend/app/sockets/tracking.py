import time
from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.user import DriverProfile
from app.sockets.gateway import (
    sio, active_drivers, active_passengers, taxi_assignments, system_active
)
from app.services.geo import haversine_distance, calculate_eta
from app.services.headway import calculate_spacing_advisories

async def persist_driver_to_db(driver_id: str, service_type: str, route_id: str, lat: float, lng: float, is_online: bool = True):
    """Persists driver state and live GPS coordinates to SQLite/PostgreSQL asynchronously."""
    try:
        async with AsyncSessionLocal() as session:
            stmt = select(DriverProfile).where(DriverProfile.driver_id == driver_id)
            result = await session.execute(stmt)
            profile = result.scalar_one_or_none()
            
            if not profile:
                profile = DriverProfile(
                    driver_id=driver_id,
                    service_type=service_type,
                    assigned_route_id=route_id,
                    is_online=is_online,
                    current_lat=lat,
                    current_lng=lng
                )
                session.add(profile)
            else:
                profile.service_type = service_type
                profile.assigned_route_id = route_id
                profile.is_online = is_online
                profile.current_lat = lat
                profile.current_lng = lng
                
            await session.commit()
    except Exception as e:
        pass

@sio.event
async def driver_online(sid, data):
    driver_id = data.get("driverId") or data.get("driver_id")
    if not driver_id:
        return
    
    route_id = data.get("routeId") or data.get("route_id") or "default-route"
    vehicle_id = data.get("vehicleId") or data.get("vehiclePlate") or data.get("vehicle_id") or "B-BW"
    raw_type = str(data.get("serviceType") or data.get("driverType") or "").upper()
    service_type = "TAXI" if "TAXI" in raw_type else ("BUS" if "BUS" in raw_type else "COMBI")

    # Enter driver rooms so incoming hails are received immediately
    await sio.enter_room(sid, "drivers")
    await sio.enter_room(sid, f"drivers-{route_id}")

    driver_data = {
        "driverId": driver_id,
        "driver_id": driver_id,
        "routeId": route_id,
        "route_id": route_id,
        "vehicleId": vehicle_id,
        "vehicle_id": vehicle_id,
        "vehiclePlate": vehicle_id,
        "serviceType": service_type,
        "service_type": service_type,
        "status": "ONLINE",
        "coords": data.get("coords") or active_drivers.get(driver_id, {}).get("coords"),
        "socket_id": sid,
        "last_update": time.time()
    }
    active_drivers[driver_id] = driver_data
    await sio.emit('fleet-update', {'type': 'driver', **driver_data}, room='dashboard')
    await sio.emit('vehicle-update', {'type': 'driver', **driver_data}, room=f"passengers-{route_id}")
    await sio.emit('driver-location', {**driver_data}, room=f"passengers-{route_id}")

sio.on('driver-online', driver_online)

@sio.event
async def driver_offline(sid, data):
    driver_id = data.get("driverId") or data.get("driver_id")
    if not driver_id:
        return
    
    # Remove from memory so it no longer shows on the dashboard
    active_drivers.pop(driver_id, None)
    
    await sio.emit('fleet-remove', {
        'type': 'driver',
        'id': driver_id,
        'driverId': driver_id,
        'driver_id': driver_id
    }, room='dashboard')
        
    await persist_driver_to_db(driver_id, "COMBI", "", 0.0, 0.0, is_online=False)

sio.on('driver-offline', driver_offline)

@sio.event
async def driver_location(sid, data):
    if not system_active:
        return
    
    driver_id = data.get("driverId") or data.get("driver_id")
    incoming_route_id = data.get("routeId") or data.get("route_id") or "default-route"
    coords = data.get("coords")
    if not driver_id or not coords:
        return
    
    existing = active_drivers.get(driver_id, {})
    route_id = incoming_route_id if (incoming_route_id and incoming_route_id != "default-route") else existing.get("route_id", "default-route")
    raw_type = str(data.get("serviceType") or existing.get("service_type") or "COMBI").upper()
    service_type = "TAXI" if "TAXI" in raw_type else ("BUS" if "BUS" in raw_type else "COMBI")
    vehicle_id = data.get("vehicleId") or data.get("vehiclePlate") or existing.get("vehicle_id") or "B-BW"

    driver_data = {
        "driverId": driver_id,
        "driver_id": driver_id,
        "routeId": route_id,
        "route_id": route_id,
        "serviceType": service_type,
        "service_type": service_type,
        "vehicleId": vehicle_id,
        "vehiclePlate": vehicle_id,
        "coords": coords,
        "occupancy": data.get("occupancy", existing.get("occupancy", 0)),
        "speed": float(data.get("speed") or 0.0),
        "heading": float(data.get("heading") or 0.0),
        "status": "ONLINE",
        "last_update": time.time(),
        "socket_id": sid
    }
    active_drivers[driver_id] = driver_data

    # Persist live GPS position to database
    lat = float(coords.get("lat") or coords.get("latitude") or 0.0)
    lng = float(coords.get("lng") or coords.get("longitude") or 0.0)
    await persist_driver_to_db(driver_id, service_type, route_id, lat, lng, is_online=True)

    # Handle Taxi vs Combi/Bus broadcast
    if service_type == "TAXI":
        for p_id, assignment in taxi_assignments.items():
            if assignment.get("driver_id") == driver_id:
                passenger = active_passengers.get(p_id)
                if passenger and passenger.get("socket_id"):
                    await sio.emit('driver-location', {**driver_data, 'routeId': 'taxi-service'}, to=passenger["socket_id"])
    else:
        await sio.emit('vehicle-update', {'type': 'driver', **driver_data, 'routeId': route_id}, room=f"passengers-{route_id}")
        
        drivers_on_route = [d for d in active_drivers.values() if d.get("route_id") == route_id or d.get("routeId") == route_id]
        advisories = calculate_spacing_advisories(drivers_on_route)
        for adv in advisories:
            target_sid = adv.get("socket_id")
            if target_sid:
                await sio.emit('spacing-advisory', {
                    "status": adv["status"],
                    "ahead": adv["ahead_display"],
                    "behind": adv["behind_display"]
                }, to=target_sid)

    # Compute and broadcast ETA & live speed to all waiting passengers on this route
    for p_id, p in active_passengers.items():
        if p.get("routeId") == route_id or p.get("route_id") == route_id or service_type == "TAXI":
            p_coords = p.get("coords")
            if p_coords and p.get("socket_id"):
                p_lat = float(p_coords.get("lat") or p_coords.get("latitude") or 0.0)
                p_lng = float(p_coords.get("lng") or p_coords.get("longitude") or 0.0)
                if p_lat != 0.0 and p_lng != 0.0:
                    dist_km = haversine_distance(lat, lng, p_lat, p_lng)
                    dist_meters = round(dist_km * 1000, 1)
                    curr_speed = float(data.get("speed") or 0.0)
                    eff_speed = curr_speed if curr_speed > 10.0 else 35.0
                    eta_sec = calculate_eta(dist_km, eff_speed)

                    # Automatic Boarding: Trigger when vehicle is in 20m proximity and co-moving
                    if p.get("status") == "WAITING" and dist_meters <= 20.0 and curr_speed > 2.0:
                        p["status"] = "ON_BOARD"
                        await sio.emit('boarding-confirmed', {
                            "driverId": driver_id,
                            "passengerId": p_id,
                            "routeId": route_id,
                            "autoBoarded": True
                        }, to=p["socket_id"])
                        await sio.emit('boarding', {
                            "driverId": driver_id,
                            "passengerId": p_id,
                            "routeId": route_id,
                            "autoBoarded": True
                        }, room='dashboard')

                    # Automatic Trip Completion / Alighting Detection:
                    # When passenger was ON_BOARD and distance now exceeds 60m with vehicle moving away
                    elif p.get("status") == "ON_BOARD" and dist_meters > 60.0 and curr_speed > 3.0:
                        p["status"] = "COMPLETED"
                        completion_payload = {
                            "driverId": driver_id,
                            "passengerId": p_id,
                            "routeId": route_id,
                            "autoCompleted": True,
                            "distanceMeters": dist_meters
                        }
                        await sio.emit('trip-completed', completion_payload, to=p["socket_id"])
                        await sio.emit('trip-completed', completion_payload, room='dashboard')

                    await sio.emit('eta-update', {
                        "driverId": driver_id,
                        "etaSeconds": eta_sec,
                        "distanceMeters": dist_meters,
                        "speed": curr_speed,
                        "occupancy": data.get("occupancy", 0),
                        "routeId": route_id
                    }, to=p["socket_id"])

    await sio.emit('driver-location', {**driver_data, 'routeId': route_id}, room=f"passengers-{route_id}")
    await sio.emit('driver-location', {**driver_data, 'routeId': route_id}, room=f"drivers-{route_id}")
    await sio.emit('fleet-update', {'type': 'driver', **driver_data, 'routeId': route_id}, room='dashboard')

sio.on('driver-location', driver_location)

@sio.event
async def passenger_location(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    route_id = data.get("routeId") or data.get("route_id") or "default-route"
    coords = data.get("coords")
    if not passenger_id or not coords:
        return
    
    passenger_data = {
        "passengerId": passenger_id,
        "passenger_id": passenger_id,
        "routeId": route_id,
        "route_id": route_id,
        "coords": coords,
        "socket_id": sid,
        "status": "WAITING",
        "last_update": time.time()
    }
    active_passengers[passenger_id] = passenger_data
    
    await sio.emit('passenger-location', passenger_data, room=f"drivers-{route_id}")
    await sio.emit('fleet-update', {'type': 'passenger', **passenger_data}, room='dashboard')

sio.on('passenger-location', passenger_location)
