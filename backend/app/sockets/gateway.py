import socketio
import time
from typing import Dict, Any, List

# Create async Socket.IO server with CORS enabled
sio = socketio.AsyncServer(
    async_mode='asgi',
    cors_allowed_origins='*',
    ping_timeout=60,
    ping_interval=25
)

# In-Memory State Cache (Shared across modules)
active_drivers: Dict[str, Dict[str, Any]] = {}
active_passengers: Dict[str, Dict[str, Any]] = {}
active_trips: Dict[str, Dict[str, Any]] = {}
taxi_assignments: Dict[str, Dict[str, Any]] = {}
active_hails: Dict[str, Dict[str, Any]] = {}
active_taxi_requests: Dict[str, Dict[str, Any]] = {}
driver_ratings: Dict[str, Dict[str, Any]] = {}
active_boardings: Dict[str, Dict[str, Any]] = {}
system_active: bool = True

def driver_can_accept_taxi(driver_id: str, requested_service_type: str) -> bool:
    """Standard rides may be queued together; a special ride is exclusive."""
    active_types = {
        str(assignment.get("serviceType") or "STANDARD").upper()
        for assignment in taxi_assignments.values()
        if (assignment.get("driver_id") or assignment.get("driverId")) == driver_id
        and str(assignment.get("serviceType") or "STANDARD").upper()
        in ("STANDARD", "SPECIAL", "TAXI")
    }
    if "SPECIAL" in active_types:
        return False
    requested = str(requested_service_type or "STANDARD").upper()
    if requested == "SPECIAL" and active_types:
        return False
    return requested in ("STANDARD", "SPECIAL")

@sio.event
async def connect(sid, environ, auth=None):
    print(f"[SOCKET CONNECT] Client SID: {sid}")

@sio.event
async def disconnect(sid):
    # Keep shift and trip records across short mobile background disconnects.
    for d_id, driver in list(active_drivers.items()):
        if driver.get("socket_id") == sid:
            driver["socket_id"] = None
            driver["last_disconnect"] = time.time()

    for p_id, passenger in list(active_passengers.items()):
        if passenger.get("socket_id") == sid:
            passenger["socket_id"] = None
            passenger["last_disconnect"] = time.time()

@sio.event
async def join(sid, data):
    payload = {"role": data} if isinstance(data, str) else (data or {})
    role = payload.get("role")
    route_id = payload.get("routeId", "default")

    if role:
        await sio.enter_room(sid, role)
        await sio.enter_room(sid, f"{role}-{route_id}")
        
        if role == 'dashboard':
            await sio.emit('system-status', {'active': system_active}, to=sid)
            # Send current full snapshot to dashboard
            await sio.emit('dashboard-snapshot', {
                'drivers': list(active_drivers.values()),
                'passengers': list(active_passengers.values()),
                'hails': list(active_hails.values()),
                'trips': list(active_trips.values())
            }, to=sid)

        if role == 'passengers':
            p_id = payload.get("passengerId") or payload.get("id")
            coords = payload.get("coords")
            service_type = str(payload.get("serviceType") or payload.get("type") or "").upper()
            if not service_type:
                service_type = "BUS" if route_id.startswith("bus-") else ("TAXI" if route_id == "taxi-service" else "COMBI")
            if p_id:
                previous = active_passengers.get(p_id, {})
                active_passengers[p_id] = {
                    "passenger_id": p_id,
                    "passengerId": p_id,
                    "route_id": route_id,
                    "routeId": route_id,
                    "serviceType": service_type,
                    "service_type": service_type,
                    "coords": coords or previous.get("coords"),
                    "status": previous.get("status", "WAITING"),
                    "socket_id": sid,
                    "last_update": time.time()
                }
                if coords:
                    await sio.emit('fleet-update', {
                        'type': 'passenger',
                        'passengerId': p_id,
                        'passenger_id': p_id,
                        'routeId': route_id,
                        'serviceType': service_type,
                        'service_type': service_type,
                        'coords': coords,
                        'status': 'WAITING'
                    }, room='dashboard')

            # Send snapshot of currently active drivers to passenger
            active_list = [d for d in active_drivers.values() if d.get("status") == "ONLINE"]
            await sio.emit('active-drivers-snapshot', active_list, to=sid)

@sio.event
async def subscribe_route(sid, data):
    payload = data if isinstance(data, dict) else {}
    role = payload.get("role", "passengers")
    route_id = payload.get("routeId") or payload.get("route_id")
    if route_id:
        await sio.enter_room(sid, f"{role}-{route_id}")
        drivers_on_route = [
            d for d in active_drivers.values()
            if d.get("status") == "ONLINE" and (d.get("routeId") == route_id or d.get("route_id") == route_id or d.get("serviceType") == "TAXI")
        ]
        await sio.emit('active-drivers-snapshot', drivers_on_route, to=sid)

sio.on('subscribe-route', subscribe_route)

@sio.on('resume-session')
async def resume_session(sid, data):
    payload = data if isinstance(data, dict) else {}
    if payload.get("role") != "passengers":
        return
    passenger_id = payload.get("userId")
    if not passenger_id:
        return
    request = active_hails.get(passenger_id)
    assignment = taxi_assignments.get(passenger_id)
    boarding = active_boardings.get(passenger_id)
    passenger = active_passengers.get(passenger_id)
    if passenger:
        passenger["socket_id"] = sid
        passenger["last_update"] = time.time()
    await sio.emit('session-restored', {
        "request": request,
        "assignment": assignment,
        "boarded": bool(boarding),
    }, to=sid)
