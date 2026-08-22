import time
import uuid
from app.sockets.gateway import (
    sio, active_drivers, active_passengers, active_hails,
    active_taxi_requests, taxi_assignments, active_boardings,
    driver_ratings, active_trips
)
from app.services.fare import get_fare, estimate_special_taxi_fare
from app.services.geo import haversine_distance, find_nearest_stop

@sio.event
async def passenger_request_taxi(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    pickup = data.get("pickup") or data.get("pickupLoc")
    dropoff = data.get("dropoff") or data.get("destination") or data.get("destinationLoc")
    service_type = str(data.get("serviceType") or data.get("type") or "STANDARD").upper()

    if not passenger_id or not pickup:
        return

    request_id = f"req-{uuid.uuid4().hex[:8]}"
    fare_estimate = get_fare(service_type, pickup, dropoff)

    request = {
        "requestId": request_id,
        "passengerId": passenger_id,
        "passenger_id": passenger_id,
        "routeId": "taxi-service",
        "pickupLoc": pickup,
        "destinationLoc": dropoff,
        "serviceType": service_type,
        "fareEstimate": fare_estimate,
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
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    driver_id = data.get("driverId") or data.get("driver_id")
    request_id = data.get("requestId")
    route_id = data.get("routeId", "taxi-service")

    if not passenger_id or not driver_id:
        return

    if passenger_id in taxi_assignments:
        await sio.emit('taxi-error', {"reason": "Ride already assigned"}, to=sid)
        return

    req = active_taxi_requests.get(request_id) if request_id else None
    taxi_assignments[passenger_id] = {
        "driver_id": driver_id,
        "started_at": time.time(),
        "request_id": request_id
    }
    active_hails.pop(passenger_id, None)

    passenger = active_passengers.get(passenger_id)
    if passenger and passenger.get("socket_id"):
        await sio.emit('taxi-arrived', {
            "driverId": driver_id,
            "routeId": route_id,
            "requestId": request_id,
            "fareEstimate": req.get("fareEstimate") if req else 8.0
        }, to=passenger["socket_id"])

    await sio.emit('hail-accepted', {
        "type": "taxi-assign",
        "passengerId": passenger_id,
        "driverId": driver_id,
        "requestId": request_id,
        "routeId": route_id
    }, room='dashboard')

sio.on('taxi-accept', taxi_accept)

@sio.event
async def hail(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    route_id = data.get("routeId", "taxi-service")
    pickup_loc = data.get("pickupLoc") or data.get("pickup_coords")
    destination_loc = data.get("destinationLoc") or data.get("dropoff_coords")

    if not passenger_id or not route_id or not pickup_loc:
        return

    service_type = str(data.get("serviceType") or "STANDARD").upper()
    request_id = f"req-{uuid.uuid4().hex[:8]}"
    fare_estimate = get_fare(service_type, pickup_loc, destination_loc)

    hail_payload = {
        "requestId": request_id,
        "passengerId": passenger_id,
        "passenger_id": passenger_id,
        "routeId": route_id,
        "route_id": route_id,
        "pickupLoc": pickup_loc,
        "destinationLoc": destination_loc,
        "serviceType": service_type,
        "fareEstimate": fare_estimate,
        "requestedAt": time.time()
    }

    active_hails[passenger_id] = hail_payload
    if route_id == "taxi-service":
        active_taxi_requests[request_id] = hail_payload

    # Register passenger & update dashboard
    active_passengers[passenger_id] = {
        "passengerId": passenger_id,
        "passenger_id": passenger_id,
        "routeId": route_id,
        "route_id": route_id,
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
        'coords': pickup_loc,
        'status': 'WAITING'
    }, room='dashboard')

    # Emit to drivers on route & general drivers room & dashboard
    await sio.emit('new-hail', hail_payload, room=f"drivers-{route_id}")
    await sio.emit('new-hail', hail_payload, room='drivers')
    await sio.emit('new-hail', hail_payload, room='dashboard')

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
    await sio.emit('hail-cancelled', {"passengerId": passenger_id, "routeId": route_id}, room=f"drivers-{route_id}")
    await sio.emit('hail-cancelled', {"passengerId": passenger_id, "routeId": route_id}, room='dashboard')
    await sio.emit('fleet-remove', {'type': 'passenger', 'id': passenger_id, 'passengerId': passenger_id}, room='dashboard')

sio.on('cancel-hail', cancel_hail)

@sio.event
async def accept_hail(sid, data):
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
    fare_est = (req.get("fareEstimate") if req else None) or 25.0

    taxi_assignments[passenger_id] = {
        "driver_id": driver_id,
        "driverId": driver_id,
        "started_at": time.time(),
        "request_id": request_id,
        "fareEstimate": fare_est,
        "serviceType": req.get("serviceType") if req else "STANDARD"
    }

    payload = {
        "passengerId": passenger_id,
        "driverId": driver_id,
        "routeId": route_id,
        "requestId": request_id,
        "driverPlate": driver.get("vehiclePlate") or "B-BW",
        "fareEstimate": fare_est,
        "serviceType": req.get("serviceType") if req else "STANDARD",
        "coords": driver.get("coords")
    }

    if passenger and passenger.get("socket_id"):
        await sio.emit('hail-accepted', payload, to=passenger["socket_id"])
        await sio.emit('taxi-arrived', payload, to=passenger["socket_id"])

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
        passenger = active_passengers.get(passenger_id)
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
    driver_id = data.get("driverId") or data.get("driver_id")
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    route_id = data.get("routeId") or data.get("route_id")

    # Deactivate and clear hail from active hails
    if passenger_id:
        active_hails.pop(passenger_id, None)
        if passenger_id in active_passengers:
            active_passengers[passenger_id]["status"] = "ON_BOARD"

    board_payload = {
        "driverId": driver_id,
        "passengerId": passenger_id,
        "routeId": route_id,
        "timestamp": time.time()
    }

    # Broadcast to route & drivers to remove waiting hail badge
    if route_id:
        await sio.emit('hail-cancelled', {"passengerId": passenger_id, "routeId": route_id}, room=f"drivers-{route_id}")
        await sio.emit('passenger-boarded', board_payload, room=f"drivers-{route_id}")
    await sio.emit('hail-cancelled', {"passengerId": passenger_id, "routeId": route_id}, room="drivers")
    await sio.emit('passenger-boarded', board_payload, room="drivers")
    await sio.emit('boarding', board_payload, room='dashboard')

    driver = active_drivers.get(driver_id)
    if driver and driver.get("socket_id"):
        await sio.emit('passenger-boarded', board_payload, to=driver["socket_id"])

    passenger = active_passengers.get(passenger_id)
    if passenger and passenger.get("socket_id"):
        await sio.emit('boarding-confirmed', board_payload, to=passenger["socket_id"])
        await sio.emit('trip-started', board_payload, to=passenger["socket_id"])

    if driver and passenger:
        active_boardings[passenger_id] = {
            "driver_id": driver_id,
            "route_id": route_id or driver.get("route_id"),
            "since": time.time()
        }

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
    trip_id = data.get("tripId") or f"trip-{uuid.uuid4().hex[:8]}"
    driver_id = data.get("driverId") or data.get("driver_id")
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    revenue = float(data.get("revenue") or data.get("fare") or 25.0)

    if not passenger_id:
        for p_id, assign in list(taxi_assignments.items()):
            if assign.get("driver_id") == driver_id or assign.get("driverId") == driver_id:
                passenger_id = p_id
                break

    trip = active_trips.get(trip_id, {})
    trip["end_time"] = time.time()
    trip["revenue"] = revenue
    if trip_id not in active_trips:
        active_trips[trip_id] = trip

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
        active_passengers.pop(passenger_id, None)

    await sio.emit('trip-completed', {"tripId": trip_id, "driverId": driver_id, "fare": revenue}, room='dashboard')

sio.on('trip-end', trip_end)

@sio.event
async def passenger_end_trip(sid, data):
    passenger_id = data.get("passengerId") or data.get("passenger_id")
    driver_id = data.get("driverId") or data.get("driver_id")
    route_id = data.get("routeId", "taxi-service")
    fare = float(data.get("fare") or data.get("fareEstimate") or 8.0)

    if not passenger_id:
        return

    active_passengers.pop(passenger_id, None)
    active_hails.pop(passenger_id, None)
    active_boardings.pop(passenger_id, None)
    taxi_assignments.pop(passenger_id, None)

    end_payload = {
        "passengerId": passenger_id,
        "driverId": driver_id,
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
