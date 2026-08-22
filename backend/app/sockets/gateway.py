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

@sio.event
async def connect(sid, environ, auth=None):
    print(f"[SOCKET CONNECT] Client SID: {sid}")

@sio.event
async def disconnect(sid):
    # Clean up disconnected drivers or passengers
    driver_to_remove = None
    for d_id, driver in list(active_drivers.items()):
        if driver.get("socket_id") == sid:
            driver_to_remove = d_id
            break
    if driver_to_remove:
        active_drivers.pop(driver_to_remove, None)
        await sio.emit('fleet-remove', {
            'type': 'driver',
            'id': driver_to_remove,
            'driverId': driver_to_remove,
            'driver_id': driver_to_remove
        }, room='dashboard')

    passenger_to_remove = None
    for p_id, passenger in list(active_passengers.items()):
        if passenger.get("socket_id") == sid:
            passenger_to_remove = p_id
            break
    if passenger_to_remove:
        active_passengers.pop(passenger_to_remove, None)
        active_hails.pop(passenger_to_remove, None)
        await sio.emit('fleet-remove', {
            'type': 'passenger',
            'id': passenger_to_remove,
            'passengerId': passenger_to_remove,
            'passenger_id': passenger_to_remove
        }, room='dashboard')

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
            if p_id:
                active_passengers[p_id] = {
                    "passenger_id": p_id,
                    "passengerId": p_id,
                    "route_id": route_id,
                    "routeId": route_id,
                    "coords": coords,
                    "socket_id": sid,
                    "last_update": time.time()
                }
                if coords:
                    await sio.emit('fleet-update', {
                        'type': 'passenger',
                        'passengerId': p_id,
                        'passenger_id': p_id,
                        'routeId': route_id,
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
