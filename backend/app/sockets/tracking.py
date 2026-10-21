import time
from datetime import datetime
from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.user import DriverProfile
from app.sockets.gateway import (
    sio, active_drivers, active_passengers, active_hails, active_taxi_requests,
    taxi_assignments, active_boardings, active_trips, route_board_candidates,
    system_active, driver_can_accept_taxi
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
    active_request_id = data.get("activeRequestId")
    if active_request_id:
        assignment = next(
            (
                assigned
                for assigned in taxi_assignments.values()
                if (assigned.get("driver_id") or assigned.get("driverId")) == driver_id
                and (assigned.get("request_id") or assigned.get("requestId")) == active_request_id
            ),
            None,
        )
        if assignment is None:
            await sio.emit('passenger-trip-cancelled', {
                "driverId": driver_id,
                "passengerId": data.get("activePassengerId"),
                "requestId": active_request_id,
                "tripId": active_request_id,
                "status": "NO_LONGER_ACTIVE",
            }, to=sid)
    await sio.emit('fleet-update', {'type': 'driver', **driver_data}, room='dashboard')
    await sio.emit('vehicle-update', {'type': 'driver', **driver_data}, room=f"passengers-{route_id}")
    await sio.emit('driver-location', {**driver_data}, room=f"passengers-{route_id}")
    for request in active_taxi_requests.values():
        passenger_id = request.get("passengerId") or request.get("passenger_id")
        if (
            passenger_id
            and passenger_id not in taxi_assignments
            and driver_can_accept_taxi(driver_id, request.get("serviceType"))
        ):
            await sio.emit('new-taxi-request', request, to=sid)

    # Restore the pickup marker privately after an assigned driver reconnects.
    for passenger_id, assignment in taxi_assignments.items():
        assigned_driver_id = assignment.get("driver_id") or assignment.get("driverId")
        passenger = active_passengers.get(passenger_id)
        if (
            assigned_driver_id == driver_id
            and not assignment.get("boarded")
            and passenger
            and passenger.get("coords")
        ):
            await sio.emit('passenger-location', {
                **{key: value for key, value in passenger.items() if key != 'socket_id'},
            }, to=sid)

    # Bring an on-route driver up to date when they come online after a
    # passenger has already raised a hail on this route.
    for request in active_hails.values():
        request_route = request.get("routeId") or request.get("route_id")
        request_type = str(request.get("serviceType") or "").upper()
        request_passenger_id = request.get("passengerId") or request.get(
            "passenger_id"
        )
        if (
            request_route == route_id
            and request_type in ("COMBI", "BUS")
            and request_passenger_id not in taxi_assignments
        ):
            await sio.emit('new-hail', request, to=sid)

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
        "occupancyText": data.get("occupancyText", existing.get("occupancyText", "Empty")),
        "accuracy": float(data.get("accuracy") or 999.0),
        "speed": float(data.get("speed") or 0.0),
        "heading": float(data.get("heading") or 0.0),
        "status": "ONLINE",
        "last_update": time.time(),
        "socket_id": sid
    }
    active_drivers[driver_id] = driver_data

    # Reconcile accepted taxi rides on each location heartbeat. Mobile sockets
    # can briefly disconnect and miss the original cancellation event.
    active_request_id = data.get("activeRequestId") or data.get("active_request_id")
    if service_type == "TAXI" and active_request_id:
        active_assignment = next(
            (
                (passenger_id, assignment)
                for passenger_id, assignment in taxi_assignments.items()
                if (assignment.get("driver_id") or assignment.get("driverId")) == driver_id
                and (assignment.get("request_id") or assignment.get("requestId")) == active_request_id
            ),
            None,
        )
        if active_assignment is None:
            await sio.emit('passenger-trip-cancelled', {
                "driverId": driver_id,
                "passengerId": data.get("activePassengerId") or data.get("active_passenger_id"),
                "requestId": active_request_id,
                "tripId": active_request_id,
                "status": "NO_LONGER_ACTIVE",
            }, to=sid)

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

    # Compute ETA for route hails and apply guarded route boarding/alighting.
    for p_id, p in list(active_passengers.items()):
        assignment = taxi_assignments.get(p_id, {})
        assigned_taxi = (
            service_type == "TAXI"
            and (assignment.get("driver_id") == driver_id or assignment.get("driverId") == driver_id)
        )
        same_transit_route = (
            service_type != "TAXI"
            and (p.get("routeId") == route_id or p.get("route_id") == route_id)
        )
        if assigned_taxi or same_transit_route:
            p_coords = p.get("coords")
            if p_coords:
                p_lat = float(p_coords.get("lat") or p_coords.get("latitude") or 0.0)
                p_lng = float(p_coords.get("lng") or p_coords.get("longitude") or 0.0)
                if p_lat != 0.0 and p_lng != 0.0:
                    dist_meters = round(
                        haversine_distance(
                            {"lat": lat, "lng": lng},
                            {"lat": p_lat, "lng": p_lng},
                        ),
                        1,
                    )
                    curr_speed = float(data.get("speed") or 0.0)
                    eff_speed = curr_speed if curr_speed > 10.0 else 35.0
                    eta_sec = calculate_eta(dist_meters, eff_speed)

                    # Automatic Arrival at Pickup Detection:
                    # Trigger when an assigned driver reaches within 35m of the passenger's pickup location
                    if (
                        assignment
                        and (assignment.get("driver_id") == driver_id or assignment.get("driverId") == driver_id)
                        and not assignment.get("arrived")
                        and p.get("status") == "WAITING"
                        and dist_meters <= 35.0
                        and (time.time() - float(assignment.get("started_at") or 0.0)) >= 3.5
                    ):
                        assignment["arrived"] = True
                        p["status"] = "ARRIVED"
                        await sio.emit('driver-arrived-pickup', {
                            "driverId": driver_id,
                            "passengerId": p_id,
                            "status": "ARRIVED_AT_PICKUP",
                            "distanceMeters": dist_meters,
                        }, to=p["socket_id"])
                        await sio.emit('taxi-arrived', {
                            "driverId": driver_id,
                            "passengerId": p_id,
                            "status": "ARRIVED_AT_PICKUP",
                            "distanceMeters": dist_meters,
                        }, to=p["socket_id"])

                    route_service = str(p.get("serviceType") or "").upper() in ("COMBI", "BUS")
                    same_route_driver = (p.get("routeId") or p.get("route_id")) == route_id
                    fresh_passenger = time.time() - float(p.get("gps_updated_at") or 0) < 15
                    accurate = float(driver_data.get("accuracy") or 999) <= 35 and float(p.get("accuracy") or 999) <= 35
                    occupancy_full = str(driver_data.get("occupancyText") or "").strip().upper() == "FULL"
                    candidate_key = f"{p_id}:{driver_id}"

                    if (route_service and same_route_driver
                            and p.get("status") in ("WAITING", "ARRIVED")
                            and driver_data.get("status") == "ONLINE"):
                        if dist_meters >= 25 or not fresh_passenger or not accurate or occupancy_full:
                            route_board_candidates.pop(candidate_key, None)
                        else:
                            candidate = route_board_candidates.get(candidate_key)
                            if candidate and time.time() - float(candidate.get("last_at") or 0) > 7:
                                route_board_candidates.pop(candidate_key, None)
                                candidate = None
                            if candidate is None:
                                candidate = {"first_at": time.time(), "samples": 0}
                                route_board_candidates[candidate_key] = candidate
                            candidate["samples"] += 1
                            candidate["last_at"] = time.time()
                            passenger_speed = float(p.get("speed") or 0.0)
                            heading_delta = abs((float(driver_data.get("heading") or 0) - float(p.get("heading") or 0) + 180) % 360 - 180)
                            co_moving = (
                                curr_speed > 10
                                and passenger_speed > 10
                                and abs(curr_speed - passenger_speed) <= 12
                                and heading_delta <= 30
                            )
                            sustained = candidate["samples"] >= 2 and time.time() - candidate["first_at"] >= 6
                            if co_moving or sustained:
                                hail = active_hails.get(p_id, {})
                                request_id = hail.get("requestId") or p.get("requestId")
                                p["status"] = "ON_BOARD"
                                p["boarded_at"] = time.time()
                                active_hails.pop(p_id, None)
                                active_boardings[p_id] = {
                                    "driver_id": driver_id, "route_id": route_id,
                                    "service_type": service_type,
                                    "request_id": request_id, "since": p["boarded_at"],
                                    "boarded_at": p["boarded_at"], "last_separation_samples": [],
                                }
                                if request_id:
                                    active_trips[request_id] = {
                                        "trip_id": request_id, "tripId": request_id,
                                        "request_id": request_id, "driver_id": driver_id,
                                        "driverId": driver_id, "passenger_id": p_id,
                                        "passengerId": p_id, "route_id": route_id,
                                        "service_type": service_type,
                                        "start_time": p["boarded_at"], "start_coords": coords,
                                    }
                                route_board_candidates.pop(candidate_key, None)
                                board_payload = {
                                    "driverId": driver_id, "passengerId": p_id,
                                    "routeId": route_id, "requestId": request_id,
                                    "status": "BOARDED", "boardedAt": p["boarded_at"],
                                    "autoBoarded": True,
                                }
                                if p.get("socket_id"):
                                    await sio.emit('boarding-confirmed', board_payload, to=p["socket_id"])
                                    await sio.emit('trip-started', board_payload, to=p["socket_id"])
                                await sio.emit('passenger-boarded', board_payload, room=f"drivers-{route_id}")
                                await sio.emit('passenger-boarded', board_payload, to=sid)
                                await sio.emit('fleet-remove', {'type': 'passenger', 'id': p_id, 'passengerId': p_id}, room='dashboard')
                                await sio.emit('boarding', board_payload, room='dashboard')

                    boarding = active_boardings.get(p_id)
                    if (route_service and boarding and boarding.get("driver_id") == driver_id
                            and p.get("status") == "ON_BOARD"):
                        boarded_at = float(boarding.get("boarded_at") or boarding.get("since") or time.time())
                        samples = boarding.setdefault("last_separation_samples", [])
                        if time.time() - boarded_at < 45 or not fresh_passenger or not accurate:
                            samples.clear()
                        elif dist_meters > 50 and curr_speed > 1:
                            if samples and time.time() - samples[-1]["at"] > 7:
                                samples.clear()
                            if not samples or dist_meters > samples[-1]["distance"]:
                                samples.append({"at": time.time(), "distance": dist_meters})
                            else:
                                samples.clear()
                                samples.append({"at": time.time(), "distance": dist_meters})
                            samples[:] = samples[-4:]
                            if (len(samples) >= 4
                                    and samples[-1]["at"] - samples[0]["at"] >= 10
                                    and samples[-1]["at"] - samples[0]["at"] <= 15):
                                request_id = boarding.get("request_id")
                                completion_payload = {
                                    "driverId": driver_id, "passengerId": p_id,
                                    "routeId": route_id, "requestId": request_id,
                                    "tripId": request_id, "status": "COMPLETED",
                                    "autoCompleted": True, "distanceMeters": dist_meters,
                                }
                                p["status"] = "COMPLETED"
                                if p.get("socket_id"):
                                    await sio.emit('trip-completed', completion_payload, to=p["socket_id"])
                                if driver_data.get("socket_id"):
                                    await sio.emit('passenger-alighted', completion_payload, to=driver_data["socket_id"])
                                await sio.emit('passenger-alighted', completion_payload, room=f"drivers-{route_id}")
                                await sio.emit('fleet-remove', {'type': 'passenger', 'id': p_id, 'passengerId': p_id}, room='dashboard')
                                await sio.emit('trip-completed', completion_payload, room='dashboard')
                                active_boardings.pop(p_id, None)
                                active_passengers.pop(p_id, None)
                                if request_id:
                                    active_trips.pop(request_id, None)
                        else:
                            samples.clear()

                    if p.get("socket_id"):
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
    hail = active_hails.get(passenger_id)
    assignment = taxi_assignments.get(passenger_id)
    passenger = active_passengers.get(passenger_id)

    # Do not accept unsolicited GPS reports. The active hail creates the
    # passenger record, and only that passenger's socket may update it.
    if not passenger or passenger.get("socket_id") != sid:
        return
    boarding = active_boardings.get(passenger_id)
    if not hail and not assignment and not boarding:
        return

    passenger_route = (
        (hail or {}).get("routeId")
        or (hail or {}).get("route_id")
        or (assignment or {}).get("routeId")
        or (assignment or {}).get("route_id")
        or (boarding or {}).get("route_id")
    )
    if passenger_route and passenger_route != route_id:
        return
    passenger["coords"] = coords
    passenger["last_update"] = time.time()
    updated_at = data.get("updatedAt") or data.get("updated_at")
    try:
        passenger["gps_updated_at"] = datetime.fromisoformat(str(updated_at).replace("Z", "+00:00")).timestamp() if updated_at else time.time()
    except (TypeError, ValueError):
        passenger["gps_updated_at"] = 0.0
    passenger["accuracy"] = float(data.get("accuracy") or 999.0)
    passenger["speed"] = float(data.get("speed") or 0.0)
    passenger["heading"] = float(data.get("heading") or 0.0)
    passenger["routeId"] = passenger_route or route_id
    passenger["route_id"] = passenger_route or route_id

    if hail:
        hail["pickupLoc"] = coords
        hail["pickup_loc"] = coords
        passenger["requestId"] = hail.get("requestId")
        passenger["serviceType"] = hail.get("serviceType")
    elif assignment:
        passenger["requestId"] = assignment.get("request_id") or assignment.get("requestId")
        passenger["serviceType"] = assignment.get("serviceType")
    elif boarding:
        passenger["requestId"] = boarding.get("request_id")
        passenger["serviceType"] = boarding.get("service_type") or passenger.get("serviceType")

    # An accepted ride is private to its assigned driver. While a hail is
    # waiting, it is visible to its route drivers (or eligible taxi drivers)
    # and to the admin dashboard.
    if assignment:
        driver_id = assignment.get("driver_id") or assignment.get("driverId")
        driver = active_drivers.get(driver_id, {})
        if driver.get("socket_id"):
            await sio.emit('passenger-location', {
                **{key: value for key, value in passenger.items() if key != 'socket_id'},
                'coords': coords,
                'status': passenger.get('status'),
            }, to=driver['socket_id'])
        return

    if boarding:
        driver_id = boarding.get("driver_id")
        driver = active_drivers.get(driver_id, {})
        if driver.get("socket_id"):
            await sio.emit('passenger-location', {
                **{key: value for key, value in passenger.items() if key != 'socket_id'},
                'coords': coords,
                'updatedAt': time.time(),
                'status': 'ON_BOARD',
            }, to=driver['socket_id'])
        return

    passenger_data = {
        **{key: value for key, value in passenger.items() if key != 'socket_id'},
        'coords': coords,
        'last_update': passenger['last_update'],
        'accuracy': passenger['accuracy'],
        'speed': passenger['speed'],
        'heading': passenger['heading'],
    }
    service_type = str(hail.get("serviceType") or "").upper()
    if service_type in ("TAXI", "STANDARD", "SPECIAL"):
        for driver in active_drivers.values():
            driver_id = str(driver.get("driver_id") or driver.get("driverId") or "")
            driver_type = str(driver.get("service_type") or driver.get("serviceType") or "").upper()
            if (
                driver_type == "TAXI"
                and driver.get("status") == "ONLINE"
                and driver.get("socket_id")
                and driver_can_accept_taxi(driver_id, service_type)
            ):
                await sio.emit('passenger-location', passenger_data, to=driver['socket_id'])
    else:
        await sio.emit('passenger-location', passenger_data, room=f"drivers-{route_id}")
    await sio.emit('fleet-update', {'type': 'passenger', **passenger_data}, room='dashboard')

sio.on('passenger-location', passenger_location)
