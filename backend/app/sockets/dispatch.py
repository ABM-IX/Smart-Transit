import time
import uuid
from app.sockets.gateway import (
    sio, active_drivers, active_passengers, active_hails,
    active_taxi_requests, taxi_assignments, active_boardings,
    driver_ratings, active_trips
)
from app.services.fare import get_fare, estimate_special_taxi_fare
from app.services.geo import haversine_distance, find_nearest_stop


def _clear_taxi_requests_for_passenger(passenger_id, request_id=None):
    if request_id:
        active_taxi_requests.pop(request_id, None)
    if not passenger_id:
        return
    for active_request_id, request in list(active_taxi_requests.items()):
        request_passenger_id = request.get("passengerId") or request.get("passenger_id")
        if request_passenger_id == passenger_id:
            active_taxi_requests.pop(active_request_id, None)


def _clear_active_trips_for_passenger(passenger_id, request_id=None):
    if request_id:
        active_trips.pop(request_id, None)
    if not passenger_id:
        return
    for active_trip_id, trip in list(active_trips.items()):
        trip_passenger_id = trip.get("passengerId") or trip.get("passenger_id")
        if trip_passenger_id == passenger_id:
            active_trips.pop(active_trip_id, None)

@sio.event
async def passenger_request_taxi(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    pickup = data.get("pickup") or data.get("pickupLoc")
    dropoff = data.get("dropoff") or data.get("destination") or data.get("destinationLoc")
    service_type = str(data.get("serviceType") or data.get("type") or "STANDARD").upper()

    if not passenger_id or not pickup:
        return

    request_id = f"req-{uuid.uuid4().hex[:8]}"
    recommended_fare = get_fare(service_type, pickup, dropoff)
    offered_fare = data.get("offeredFare") or data.get("offered_fare")
    fare_estimate = max(12.0, float(offered_fare)) if service_type == "SPECIAL" and offered_fare is not None else recommended_fare

    request = {
        "requestId": request_id,
        "passengerId": passenger_id,
        "passenger_id": passenger_id,
        "routeId": "taxi-service",
        "pickupLoc": pickup,
        "pickupName": data.get("pickupName") or data.get("pickup_name"),
        "destinationLoc": dropoff,
        "destinationName": data.get("destinationName") or data.get("dropoffName") or data.get("dropoff_name"),
        "serviceType": service_type,
        "fareEstimate": fare_estimate,
        "recommendedFare": recommended_fare,
        "requestedAt": time.time()
    }
    active_taxi_requests[request_id] = request
    active_hails[passenger_id] = request

    # Update active passenger in memory & notify dashboard
    active_passengers[passenger_id] = {
        "passengerId": passenger_id,
        "passenger_id": passenger_id,
        "routeId": "taxi-service",
        "route_id": "taxi-service",
        "serviceType": "TAXI",
        "service_type": "TAXI",
        "coords": pickup,
        "socket_id": sid,
        "status": "WAITING",
        "last_update": time.time()
    }
    await sio.emit('fleet-update', {
        'type': 'passenger',
        'passengerId': passenger_id,
        'passenger_id': passenger_id,
        'routeId': 'taxi-service',
        'serviceType': 'TAXI',
        'service_type': 'TAXI',
        'coords': pickup,
        'status': 'WAITING'
    }, room='dashboard')
    await sio.emit('new-hail', request, room='dashboard')
    await sio.emit('new-taxi-request', request, room='drivers-taxi-service')

    # Find nearest online taxi drivers
    online_taxis = [
        d for d in active_drivers.values()
        if (d.get("service_type") == "TAXI" or d.get("serviceType") == "TAXI")
        and d.get("status") == "ONLINE" and d.get("coords")
    ]
    online_taxis.sort(key=lambda d: haversine_distance(pickup, d["coords"]))
    closest_taxis = online_taxis[:5]

    for d in closest_taxis:
        target_sid = d.get("socket_id")
        if target_sid:
            await sio.emit('new-taxi-request', request, to=target_sid)
            await sio.emit('new-hail', request, to=target_sid)

    await sio.emit('taxi-dispatched', {
        "status": "finding_driver",
        "requestId": request_id,
        "fareEstimate": fare_estimate
    }, to=sid)

sio.on('passenger-request-taxi', passenger_request_taxi)

@sio.event
async def taxi_accept(sid, data):
    await accept_hail(sid, data)

sio.on('taxi-accept', taxi_accept)

@sio.event
async def hail(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    route_id = data.get("routeId", "taxi-service")
    pickup_loc = data.get("pickupLoc") or data.get("pickup_coords")
    destination_loc = data.get("destinationLoc") or data.get("dropoff_coords")

    if not passenger_id or not route_id or not pickup_loc:
        return

    service_type = str(data.get("serviceType") or data.get("type") or "").upper()
    if not service_type or service_type == "STANDARD":
        if route_id.startswith("bus-"):
            service_type = "BUS"
        elif route_id == "taxi-service":
            service_type = "TAXI"
        else:
            service_type = "COMBI"

    request_id = f"req-{uuid.uuid4().hex[:8]}"
    fare_estimate = float(data.get("fareEstimate") or get_fare(service_type, pickup_loc, destination_loc))
    pickup_name = data.get("pickupName") or data.get("pickup_name") or data.get("stopName") or data.get("stop_name")
    destination_name = data.get("destinationName") or data.get("dropoffName") or data.get("dropoff_name")

    hail_payload = {
        "requestId": request_id,
        "passengerId": passenger_id,
        "passenger_id": passenger_id,
        "routeId": route_id,
        "route_id": route_id,
        "pickupLoc": pickup_loc,
        "pickupName": pickup_name,
        "stopName": pickup_name,
        "destinationLoc": destination_loc,
        "destinationName": destination_name,
        "serviceType": service_type,
        "service_type": service_type,
        "fareEstimate": fare_estimate,
        "requestedAt": time.time()
    }

    active_hails[passenger_id] = hail_payload
    if route_id == "taxi-service" or service_type == "TAXI":
        active_taxi_requests[request_id] = hail_payload

    # Register passenger & update dashboard
    active_passengers[passenger_id] = {
        "passengerId": passenger_id,
        "passenger_id": passenger_id,
        "routeId": route_id,
        "route_id": route_id,
        "serviceType": service_type,
        "service_type": service_type,
        "coords": pickup_loc,
        "socket_id": sid,
        "status": "WAITING",
        "last_update": time.time()
    }
    await sio.emit('fleet-update', {
        'type': 'passenger',
        'passengerId': passenger_id,
        'passenger_id': passenger_id,
        'routeId': route_id,
        'serviceType': service_type,
        'service_type': service_type,
        'coords': pickup_loc,
        'status': 'WAITING'
    }, room='dashboard')

    # Emit to drivers on route & general drivers room & dashboard
    await sio.emit('new-hail', hail_payload, room=f"drivers-{route_id}")
    await sio.emit('new-hail', hail_payload, room='drivers')
    await sio.emit('new-hail', hail_payload, room='dashboard')
    await sio.emit('hail-queued', {
        'requestId': request_id,
        'routeId': route_id,
        'serviceType': service_type,
        'fareEstimate': fare_estimate,
    }, to=sid)

    # Also emit directly to individual sockets of matching online drivers
    for d in active_drivers.values():
        if (d.get("routeId") == route_id or d.get("route_id") == route_id or d.get("serviceType") == "TAXI") and d.get("socket_id"):
            await sio.emit('new-hail', hail_payload, to=d["socket_id"])

sio.on('hail', hail)

@sio.event
async def cancel_hail(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    route_id = data.get("routeId", "taxi-service")
    if not passenger_id:
        return

    active_hails.pop(passenger_id, None)
    active_passengers.pop(passenger_id, None)
    taxi_assignments.pop(passenger_id, None)
    _clear_taxi_requests_for_passenger(passenger_id)
    await sio.emit('hail-cancelled', {"passengerId": passenger_id, "routeId": route_id}, room=f"drivers-{route_id}")
    await sio.emit('hail-cancelled', {"passengerId": passenger_id, "routeId": route_id}, room='dashboard')
    await sio.emit('fleet-remove', {'type': 'passenger', 'id': passenger_id, 'passengerId': passenger_id}, room='dashboard')

sio.on('cancel-hail', cancel_hail)

@sio.event
async def accept_hail(sid, data):
    from app.services.geo import calculate_eta

    passenger_id = data.get("passengerId") or data.get("passenger_id")
    driver_id = data.get("driverId") or data.get("driver_id")
    route_id = data.get("routeId", "taxi-service")
    request_id = data.get("requestId")

    if not passenger_id or not driver_id:
        return

    active_hails.pop(passenger_id, None)
    passenger = active_passengers.get(passenger_id)
    req = active_taxi_requests.get(request_id) if request_id else None
    driver = active_drivers.get(driver_id, {})

    incoming_coords = data.get("coords")
    if incoming_coords and driver_id in active_drivers:
        active_drivers[driver_id]["coords"] = incoming_coords
        driver = active_drivers[driver_id]

    driver_coords = incoming_coords or driver.get("coords")
    driver_plate = (
        data.get("driverPlate")
        or data.get("vehiclePlate")
        or data.get("vehicleId")
        or driver.get("vehiclePlate")
        or driver.get("vehicleId")
        or "B-BW"
    )
    service_type = req.get("serviceType") if req else ("TAXI" if route_id == "taxi-service" else "COMBI")
    default_fare = get_fare(service_type)
    fare_est = (req.get("fareEstimate") if req else None) or default_fare

    # Compute initial distance and ETA right on acceptance
    dist_meters = None
    eta_sec = None
    p_coords = (passenger.get("coords") if passenger else None) or (req.get("pickupLoc") if req else None)
    if driver_coords and p_coords:
        try:
            d_lat = float(driver_coords.get("lat") or driver_coords.get("latitude") or 0.0)
            d_lng = float(driver_coords.get("lng") or driver_coords.get("longitude") or 0.0)
            p_lat = float(p_coords.get("lat") or p_coords.get("latitude") or 0.0)
            p_lng = float(p_coords.get("lng") or p_coords.get("longitude") or 0.0)
            if d_lat != 0.0 and d_lng != 0.0 and p_lat != 0.0 and p_lng != 0.0:
                dist_meters = round(
                    haversine_distance({"lat": d_lat, "lng": d_lng}, {"lat": p_lat, "lng": p_lng}),
                    1,
                )
                eff_speed = float(driver.get("speed") or 0.0)
                if eff_speed <= 10.0:
                    eff_speed = 35.0
                eta_sec = max(60, calculate_eta(dist_meters, eff_speed))
        except Exception:
            pass

    taxi_assignments[passenger_id] = {
        "driver_id": driver_id,
        "driverId": driver_id,
        "started_at": time.time(),
        "request_id": request_id,
        "route_id": route_id,
        "routeId": route_id,
        "fareEstimate": fare_est,
        "serviceType": service_type,
        "arrived": False,
    }

    payload = {
        "passengerId": passenger_id,
        "driverId": driver_id,
        "routeId": route_id,
        "requestId": request_id,
        "driverPlate": driver_plate,
        "fareEstimate": fare_est,
        "serviceType": service_type,
        "coords": driver_coords,
        "distanceMeters": dist_meters,
        "etaSeconds": eta_sec,
    }

    # Share contact details only with the two sockets in this accepted match.
    contacts = {}
    try:
        from app.database import AsyncSessionLocal
        from app.models.user import User
        from sqlalchemy import select

        async with AsyncSessionLocal() as session:
            result = await session.execute(select(User).where(User.id.in_([passenger_id, driver_id])))
            for user in result.scalars():
                contacts[user.id] = {
                    "name": user.full_name or "",
                    "phone": user.phone_number or ""
                }
    except Exception:
        pass

    driver_name = data.get("driverName") or driver.get("driverName") or contacts.get(driver_id, {}).get("name", "")
    driver_phone = data.get("driverPhone") or driver.get("driverPhone") or contacts.get(driver_id, {}).get("phone", "")

    if passenger and passenger.get("socket_id"):
        p_sid = passenger["socket_id"]
        await sio.emit('hail-accepted', {
            **payload,
            "driverName": driver_name,
            "driverPhone": driver_phone,
        }, to=p_sid)
        await sio.emit('taxi-arrived', {
            **payload,
            "driverName": driver_name,
            "driverPhone": driver_phone,
            "status": "DRIVER_ACCEPTED",
        }, to=p_sid)
        if driver_coords:
            await sio.emit('driver-location', {
                "driverId": driver_id,
                "routeId": route_id,
                "serviceType": service_type,
                "vehicleId": driver_plate,
                "vehiclePlate": driver_plate,
                "coords": driver_coords,
                "speed": float(driver.get("speed") or 0.0),
                "heading": float(driver.get("heading") or 0.0),
                "occupancy": driver.get("occupancy", 0),
                "status": "ONLINE",
            }, to=p_sid)
        if eta_sec is not None and dist_meters is not None:
            await sio.emit('eta-update', {
                "driverId": driver_id,
                "etaSeconds": eta_sec,
                "distanceMeters": dist_meters,
                "speed": float(driver.get("speed") or 0.0),
                "occupancy": driver.get("occupancy", 0),
                "routeId": route_id,
            }, to=p_sid)

    if driver.get("socket_id"):
        await sio.emit('hail-accepted', {
            **payload,
            "passengerName": contacts.get(passenger_id, {}).get("name", ""),
            "passengerPhone": contacts.get(passenger_id, {}).get("phone", "")
        }, to=driver["socket_id"])

    await sio.emit('hail-accepted', payload, room=f"drivers-{route_id}")
    await sio.emit('hail-accepted', payload, room='dashboard')

sio.on('accept-hail', accept_hail)

@sio.event
async def driver_arrived(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    driver_id = data.get("driverId") or data.get("driver_id")
    if not passenger_id:
        for p_id, assign in taxi_assignments.items():
            if assign.get("driver_id") == driver_id or assign.get("driverId") == driver_id:
                passenger_id = p_id
                break

    if passenger_id:
        assignment = taxi_assignments.get(passenger_id)
        if assignment and driver_id and driver_id not in (
            assignment.get("driver_id"), assignment.get("driverId")
        ):
            return
        if assignment:
            assignment["arrived"] = True
        passenger = active_passengers.get(passenger_id)
        if passenger:
            passenger["status"] = "ARRIVED"
        if passenger and passenger.get("socket_id"):
            await sio.emit('driver-arrived-pickup', {
                "driverId": driver_id,
                "passengerId": passenger_id,
                "status": "ARRIVED_AT_PICKUP"
            }, to=passenger["socket_id"])
            await sio.emit('taxi-arrived', {
                "driverId": driver_id,
                "passengerId": passenger_id,
                "status": "ARRIVED_AT_PICKUP"
            }, to=passenger["socket_id"])

    await sio.emit('route-status', {
        "type": "driver-arrived",
        "driverId": driver_id,
        "passengerId": passenger_id
    }, room='dashboard')

sio.on('driver-arrived', driver_arrived)

@sio.event
async def boarding(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    assignment = taxi_assignments.get(passenger_id, {}) if passenger_id else {}
    driver_id = data.get("driverId") or data.get("driver_id") or assignment.get("driver_id") or assignment.get("driverId")
    route_id = data.get("routeId") or data.get("route_id") or assignment.get("route_id") or assignment.get("routeId")
    request_id = data.get("requestId") or assignment.get("request_id")
    driver = active_drivers.get(driver_id, {})

    # Deactivate and clear hail from active hails
    if passenger_id:
        active_hails.pop(passenger_id, None)
        if passenger_id in active_passengers:
            active_passengers[passenger_id]["status"] = "ON_BOARD"

    board_payload = {
        "driverId": driver_id,
        "passengerId": passenger_id,
        "routeId": route_id,
        "requestId": request_id,
        "timestamp": time.time()
    }

    active_boarding = active_boardings.get(passenger_id) if passenger_id else None
    if passenger_id and not active_boarding:
        active_boardings[passenger_id] = {
            "driver_id": driver_id,
            "route_id": route_id or (driver or {}).get("route_id"),
            "request_id": request_id,
            "since": time.time(),
        }
    if assignment:
        assignment["boarded"] = True
        assignment["arrived"] = True
    if request_id and request_id not in active_trips:
        active_trips[request_id] = {
            "trip_id": request_id,
            "tripId": request_id,
            "request_id": request_id,
            "driver_id": driver_id,
            "driverId": driver_id,
            "passenger_id": passenger_id,
            "passengerId": passenger_id,
            "route_id": route_id or "taxi-service",
            "service_type": assignment.get("serviceType", "TAXI"),
            "start_time": time.time(),
            "start_coords": driver.get("coords"),
        }

    # Broadcast to route & drivers to remove waiting hail badge
    if route_id:
        await sio.emit('hail-cancelled', {"passengerId": passenger_id, "routeId": route_id}, room=f"drivers-{route_id}")
        await sio.emit('passenger-boarded', board_payload, room=f"drivers-{route_id}")
    await sio.emit('hail-cancelled', {"passengerId": passenger_id, "routeId": route_id}, room="drivers")
    await sio.emit('passenger-boarded', board_payload, room="drivers")
    await sio.emit('boarding', board_payload, room='dashboard')

    if driver and driver.get("socket_id"):
        await sio.emit('passenger-boarded', board_payload, to=driver["socket_id"])

    passenger = active_passengers.get(passenger_id)
    if passenger and passenger.get("socket_id"):
        await sio.emit('boarding-confirmed', board_payload, to=passenger["socket_id"])
        await sio.emit('trip-started', board_payload, to=passenger["socket_id"])
    if driver and driver.get("socket_id"):
        await sio.emit('trip-started', board_payload, to=driver["socket_id"])

sio.on('boarding', boarding)

@sio.event
async def trip_start(sid, data):
    trip_id = data.get("tripId") or f"trip-{uuid.uuid4().hex[:8]}"
    driver_id = data.get("driverId") or data.get("driver_id")
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    if not passenger_id:
        for p_id, assign in taxi_assignments.items():
            if assign.get("driver_id") == driver_id or assign.get("driverId") == driver_id:
                passenger_id = p_id
                break

    driver = active_drivers.get(driver_id, {})
    trip = {
        "trip_id": trip_id,
        "tripId": trip_id,
        "driver_id": driver_id,
        "driverId": driver_id,
        "passenger_id": passenger_id,
        "passengerId": passenger_id,
        "route_id": data.get("routeId", "taxi-service"),
        "service_type": data.get("type", "TAXI"),
        "passenger_count": data.get("passengerCount", 1),
        "revenue": data.get("revenue", 25.0),
        "start_time": time.time(),
        "start_coords": driver.get("coords")
    }
    active_trips[trip_id] = trip

    if passenger_id:
        passenger = active_passengers.get(passenger_id)
        if passenger and passenger.get("socket_id"):
            await sio.emit('boarding-confirmed', trip, to=passenger["socket_id"])
            await sio.emit('trip-started', trip, to=passenger["socket_id"])

    await sio.emit('trip-started', trip, room='dashboard')

sio.on('trip-start', trip_start)

@sio.event
async def trip_end(sid, data):
    trip_id = data.get("tripId") or data.get("requestId") or f"trip-{uuid.uuid4().hex[:8]}"
    request_id = data.get("requestId") or trip_id
    driver_id = data.get("driverId") or data.get("driver_id")
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    revenue = float(data.get("revenue") or data.get("fare") or get_fare("TAXI"))

    if not passenger_id:
        for p_id, assign in list(taxi_assignments.items()):
            if assign.get("driver_id") == driver_id or assign.get("driverId") == driver_id:
                passenger_id = p_id
                request_id = assign.get("request_id") or assign.get("requestId") or request_id
                break

    trip = active_trips.pop(trip_id, {})
    trip["end_time"] = time.time()
    trip["revenue"] = revenue
    _clear_active_trips_for_passenger(passenger_id, trip_id)

    if passenger_id:
        passenger = active_passengers.get(passenger_id)
        if passenger and passenger.get("socket_id"):
            end_payload = {
                "tripId": trip_id,
                "driverId": driver_id,
                "fare": revenue,
                "passengerId": passenger_id
            }
            await sio.emit('taxi-trip-ended', end_payload, to=passenger["socket_id"])
            await sio.emit('trip-completed', end_payload, to=passenger["socket_id"])
        taxi_assignments.pop(passenger_id, None)
        active_boardings.pop(passenger_id, None)
        active_passengers.pop(passenger_id, None)
        active_hails.pop(passenger_id, None)
        _clear_taxi_requests_for_passenger(passenger_id, request_id)
    if request_id:
        active_taxi_requests.pop(request_id, None)

    await sio.emit('trip-completed', {"tripId": trip_id, "driverId": driver_id, "fare": revenue}, room='dashboard')

sio.on('trip-end', trip_end)

@sio.event
async def passenger_end_trip(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    assignment = taxi_assignments.get(passenger_id, {}) if passenger_id else {}
    driver_id = data.get("driverId") or data.get("driver_id") or assignment.get("driverId") or assignment.get("driver_id")
    request_id = data.get("requestId") or data.get("request_id") or assignment.get("requestId") or assignment.get("request_id")
    route_id = data.get("routeId", "taxi-service")
    fare = float(data.get("fare") or data.get("fareEstimate") or get_fare("TAXI"))

    if not passenger_id:
        return

    active_passengers.pop(passenger_id, None)
    active_hails.pop(passenger_id, None)
    active_boardings.pop(passenger_id, None)
    taxi_assignments.pop(passenger_id, None)
    _clear_taxi_requests_for_passenger(passenger_id, request_id)
    _clear_active_trips_for_passenger(passenger_id, request_id)

    end_payload = {
        "passengerId": passenger_id,
        "driverId": driver_id,
        "requestId": request_id,
        "tripId": request_id,
        "routeId": route_id,
        "fare": fare,
        "status": "COMPLETED",
        "timestamp": time.time()
    }

    # Emit to passenger socket
    await sio.emit('trip-completed', end_payload, to=sid)
    await sio.emit('taxi-trip-ended', end_payload, to=sid)

    # Notify driver socket if driver ID is online
    if driver_id and driver_id in active_drivers:
        driver = active_drivers[driver_id]
        if driver.get("socket_id"):
            await sio.emit('passenger-alighted', end_payload, to=driver["socket_id"])
            await sio.emit('passenger-trip-ended', end_payload, to=driver["socket_id"])

    # Broadcast to dashboard
    await sio.emit('passenger-alighted', end_payload, room='dashboard')
    await sio.emit('trip-completed', end_payload, room='dashboard')

sio.on('passenger-end-trip', passenger_end_trip)
sio.on('passenger_end_trip', passenger_end_trip)

@sio.event
async def driver_rating(sid, data):
    driver_id = data.get("driverId") or data.get("driver_id")
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    rating_val = int(data.get("rating") or 5)
    comment = data.get("comment", "")
    trip_id = data.get("tripId") or data.get("trip_id")

    if not driver_id:
        return

    # Update in-memory driver rating
    driver_stats = driver_ratings.get(driver_id, {"count": 0, "total": 0.0, "avg": 5.0})
    driver_stats["count"] += 1
    driver_stats["total"] += rating_val
    driver_stats["avg"] = round(driver_stats["total"] / driver_stats["count"], 1)
    driver_ratings[driver_id] = driver_stats

    if driver_id in active_drivers:
        active_drivers[driver_id]["rating"] = driver_stats["avg"]
        active_drivers[driver_id]["ratingCount"] = driver_stats["count"]
        await sio.emit('fleet-update', {'type': 'driver', **active_drivers[driver_id]}, room='dashboard')

    # Persist review & driver rating to database
    try:
        from app.database import AsyncSessionLocal
        from app.models.trip import Review
        from app.models.user import DriverProfile
        from sqlalchemy import select

        async with AsyncSessionLocal() as session:
            review = Review(
                driver_id=driver_id,
                passenger_id=passenger_id or "anonymous",
                trip_id=trip_id,
                rating=rating_val,
                comment=comment
            )
            session.add(review)

            stmt = select(DriverProfile).where(DriverProfile.driver_id == driver_id)
            res = await session.execute(stmt)
            profile = res.scalar_one_or_none()
            if profile:
                profile.rating_avg = driver_stats["avg"]
                profile.rating_count = driver_stats["count"]
            await session.commit()
    except Exception:
        pass

    # Notify driver
    driver = active_drivers.get(driver_id)
    if driver and driver.get("socket_id"):
        await sio.emit('driver-rated', {
            "driverId": driver_id,
            "rating": rating_val,
            "avgRating": driver_stats["avg"],
            "comment": comment
        }, to=driver["socket_id"])

    # Broadcast to dashboard
    await sio.emit('driver-feedback', {
        "driverId": driver_id,
        "rating": rating_val,
        "avgRating": driver_stats["avg"],
        "comment": comment
    }, room='dashboard')

sio.on('driver-rating', driver_rating)

@sio.event
async def request_stop(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    route_id = data.get("routeId") or data.get("route_id")
    driver_id = data.get("driverId")

    payload = {
        "passengerId": passenger_id,
        "routeId": route_id,
        "message": "Passenger signaling stop ahead",
        "driverId": driver_id,
        "timestamp": time.time()
    }

    if route_id:
        await sio.emit('stop-requested', payload, room=f"drivers-{route_id}")
    await sio.emit('stop-requested', payload, room="drivers")
    if driver_id:
        driver = active_drivers.get(driver_id)
        if driver and driver.get("socket_id"):
            await sio.emit('stop-requested', payload, to=driver["socket_id"])
    await sio.emit('stop-requested', payload, room='dashboard')

sio.on('request-stop', request_stop)
