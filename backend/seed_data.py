import asyncio
from app.database import AsyncSessionLocal, init_db
from app.models.transit import Route, Stop, RouteStop, RouteType

SAMPLE_ROUTES = [
    # Intercity Buses & Regional Corridors
    {"id": "bus-molepolole", "name": "Gaborone → Molepolole Coach", "origin_name": "Gaborone Bus Rank", "destination_name": "Molepolole Bus Rank", "route_type": "BUS", "base_fare": 35.0},
    {"id": "bus-francistown", "name": "Gaborone → Francistown Express", "origin_name": "Gaborone Bus Rank", "destination_name": "Francistown Central", "route_type": "BUS", "base_fare": 150.0},
    {"id": "bus-lobatse", "name": "Gaborone → Lobatse Intercity", "origin_name": "Gaborone Bus Rank", "destination_name": "Lobatse Rank", "route_type": "BUS", "base_fare": 35.0},
    {"id": "bus-kanye", "name": "Gaborone → Kanye Express", "origin_name": "Gaborone Bus Rank", "destination_name": "Kanye Bus Rank", "route_type": "BUS", "base_fare": 45.0},
    {"id": "bus-mahalapye", "name": "Gaborone → Mahalapye Express", "origin_name": "Gaborone Bus Rank", "destination_name": "Mahalapye", "route_type": "BUS", "base_fare": 90.0},
    {"id": "bus-palapye", "name": "Gaborone → Palapye Junction", "origin_name": "Gaborone Bus Rank", "destination_name": "Palapye", "route_type": "BUS", "base_fare": 110.0},
    {"id": "bus-maun", "name": "Gaborone → Maun Safari Line", "origin_name": "Gaborone Bus Rank", "destination_name": "Maun Terminal", "route_type": "BUS", "base_fare": 280.0},

    # Local Urban & Regional Combis
    {"id": "route-m01", "name": "Route M1 – Molepolole Central to Mafitlhakgosi", "origin_name": "Molepolole Rank", "destination_name": "Mafitlhakgosi", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-m02", "name": "Route M2 – Molepolole to Borakalalo", "origin_name": "Molepolole Rank", "destination_name": "Borakalalo", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u01", "name": "Route U1 – BAC to Bus Rank", "origin_name": "BAC Stop", "destination_name": "Gaborone Bus Rank", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u02", "name": "Route U2 – UB to Main Mall", "origin_name": "UB Gate", "destination_name": "Main Mall CBD", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u03", "name": "Route U3 – Botho to Bus Rank", "origin_name": "Botho University", "destination_name": "Gaborone Bus Rank", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u04", "name": "Route U4 – Game City to Bus Rank", "origin_name": "Game City", "destination_name": "Gaborone Bus Rank", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u05", "name": "Route U5 – Mogoditshane to Bus Rank", "origin_name": "Mogoditshane Rank", "destination_name": "Gaborone Bus Rank", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u06", "name": "Route U6 – Tlokweng to Main Mall", "origin_name": "Tlokweng Border", "destination_name": "Main Mall", "route_type": "COMBI", "base_fare": 8.0},
]

SAMPLE_STOPS = [
    # Molepolole Stops
    {"id": "stop-mol-1", "name": "Molepolole Central Bus Rank", "latitude": -24.4069, "longitude": 25.4951, "description": "Main transport interchange in Molepolole"},
    {"id": "stop-mol-2", "name": "Mafitlhakgosi Stop", "latitude": -24.4150, "longitude": 25.5100, "description": "Mafitlhakgosi ward combi stop"},
    {"id": "stop-mol-3", "name": "Borakalalo Station", "latitude": -24.3980, "longitude": 25.4850, "description": "Borakalalo junction"},
    {"id": "stop-mol-4", "name": "Kweneng Rural Development", "latitude": -24.4020, "longitude": 25.5010, "description": "KRDA area stop"},

    # Gaborone & Regional Stops
    {"id": "stop-u01-1", "name": "BAC Stop", "latitude": -24.6549, "longitude": 25.9082, "description": "Botswana Accountancy College entrance"},
    {"id": "stop-u01-2", "name": "Gaborone Bus Rank", "latitude": -24.6546, "longitude": 25.9145, "description": "Central transport hub"},
    {"id": "stop-u02-1", "name": "UB Gate Stop", "latitude": -24.6590, "longitude": 25.9325, "description": "University of Botswana main gate"},
    {"id": "stop-u02-2", "name": "Main Mall Station", "latitude": -24.6543, "longitude": 25.9189, "description": "Central Business Area"},
    {"id": "stop-u03-1", "name": "Botho University Stop", "latitude": -24.6407, "longitude": 25.9295, "description": "Botho Park entrance"},
    {"id": "stop-u04-1", "name": "Game City Mall Stop", "latitude": -24.6832, "longitude": 25.8952, "description": "Game City Mall rank"},
    {"id": "stop-mogo-1", "name": "Mogoditshane Junction Stop", "latitude": -24.6300, "longitude": 25.8600, "description": "Mogoditshane main road"},
    {"id": "stop-tlok-1", "name": "Tlokweng Main Stop", "latitude": -24.6738, "longitude": 26.0354, "description": "Tlokweng border corridor"},
    {"id": "stop-francistown", "name": "Francistown Central Terminal", "latitude": -21.1661, "longitude": 27.5144, "description": "Francistown main terminal"},
    {"id": "stop-lobatse", "name": "Lobatse Bus Rank", "latitude": -25.2167, "longitude": 25.6667, "description": "Lobatse town rank"},
]

async def seed():
    print("[SEED] Initializing DB & Seeding data...")
    await init_db()
    async with AsyncSessionLocal() as session:
        for r_data in SAMPLE_ROUTES:
            route = Route(
                id=r_data["id"],
                name=r_data["name"],
                origin_name=r_data["origin_name"],
                destination_name=r_data["destination_name"],
                route_type=r_data["route_type"],
                base_fare=r_data["base_fare"]
            )
            await session.merge(route)
            
        for s_data in SAMPLE_STOPS:
            stop = Stop(
                id=s_data["id"],
                name=s_data["name"],
                latitude=s_data["latitude"],
                longitude=s_data["longitude"],
                description=s_data.get("description")
            )
            await session.merge(stop)
            
        await session.commit()
    print("[SEED] Seeding completed successfully with Molepolole, Gaborone & Intercity routes!")

if __name__ == "__main__":
    asyncio.run(seed())
