import asyncio
import socketio

async def main():
    sio = socketio.AsyncClient()
    connected = asyncio.Event()

    @sio.event
    async def connect():
        print("[CLIENT] Connected to SmartTransit Socket Gateway!")
        connected.set()

    @sio.on('fleet-update')
    async def on_fleet_update(data):
        print(f"[CLIENT] Received fleet-update: {data.get('type')} - Driver {data.get('driver_id')}")

    @sio.on('spacing-advisory')
    async def on_spacing(data):
        print(f"[CLIENT] Spacing Advisory Received: {data}")

    try:
        await sio.connect("http://127.0.0.1:8000", socketio_path="socket.io", transports=['websocket', 'polling'])
        await connected.wait()
        
        # Join as dashboard to monitor
        await sio.emit('join', {'role': 'dashboard'})
        
        # Emit a driver online
        await sio.emit('driver-online', {
            'driverId': 'drv-live-01',
            'routeId': 'route-u01',
            'serviceType': 'COMBI',
            'vehicleId': 'B-123-ABC'
        })
        
        # Emit driver location
        await sio.emit('driver-location', {
            'driverId': 'drv-live-01',
            'routeId': 'route-u01',
            'coords': {'lat': -24.6549, 'lng': 25.9082},
            'speed': 35.0,
            'heading': 90.0,
            'occupancy': 8
        })

        await asyncio.sleep(1)
        await sio.disconnect()
        print("[CLIENT] Test completed successfully.")
    except Exception as e:
        print(f"[CLIENT] Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
