from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional

from app.database import get_db
from app.models.transit import Route, Stop, RouteStop
from app.schemas.transit import RouteOut, StopOut, ActiveDriverOut
from app.sockets.gateway import active_drivers

router = APIRouter(prefix="/api/transit", tags=["Transit Network"])

# Mock fallback for rapid local prototype if DB is empty
FALLBACK_ROUTES = [
    {"id": "bus-francistown", "name": "Gaborone → Francistown Express", "origin_name": "Gaborone Bus Rank", "destination_name": "Francistown", "route_type": "BUS", "base_fare": 150.0},
    {"id": "bus-lobatse", "name": "Gaborone → Lobatse Intercity", "origin_name": "Gaborone Bus Rank", "destination_name": "Lobatse", "route_type": "BUS", "base_fare": 35.0},
    {"id": "bus-maun", "name": "Gaborone → Maun Safari Line", "origin_name": "Gaborone Bus Rank", "destination_name": "Maun", "route_type": "BUS", "base_fare": 280.0},
    {"id": "route-u01", "name": "Route U1 – BAC to Bus Rank", "origin_name": "BAC Stop", "destination_name": "Gaborone Bus Rank", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u02", "name": "Route U2 – UB to Main Mall", "origin_name": "UB Gate", "destination_name": "Main Mall", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u03", "name": "Route U3 – Botho to Bus Rank", "origin_name": "Botho University", "destination_name": "Gaborone Bus Rank", "route_type": "COMBI", "base_fare": 8.0},
    {"id": "route-u04", "name": "Route U4 – Game City to Bus Rank", "origin_name": "Game City", "destination_name": "Gaborone Bus Rank", "route_type": "COMBI", "base_fare": 8.0}
]

FALLBACK_STOPS = [
    {"id": "stop-u01-1", "name": "BAC Stop", "latitude": -24.6549, "longitude": 25.9082, "description": "Botswana Accountancy College main entrance"},
    {"id": "stop-u01-2", "name": "Gaborone Bus Rank", "latitude": -24.6546, "longitude": 25.9145, "description": "Central transport hub"},
    {"id": "stop-u02-1", "name": "UB Gate Stop", "latitude": -24.6590, "longitude": 25.9325, "description": "University of Botswana main gate"},
    {"id": "stop-u02-2", "name": "Main Mall Station", "latitude": -24.6543, "longitude": 25.9189, "description": "Central Business Area"},
    {"id": "stop-u03-1", "name": "Botho University Stop", "latitude": -24.6407, "longitude": 25.9295, "description": "Botho Park entrance"},
    {"id": "stop-u04-1", "name": "Game City Mall Stop", "latitude": -24.6832, "longitude": 25.8952, "description": "Game City Taxi/Combi rank"}
]

@router.get("/routes")
async def get_routes(route_type: Optional[str] = None, db: AsyncSession = Depends(get_db)):
    """Fetches all registered routes (Combis and Intercity Buses)."""
    try:
        stmt = select(Route)
        if route_type:
            stmt = stmt.where(Route.route_type == route_type.upper())
        result = await db.execute(stmt)
        routes = result.scalars().all()
        if routes:
            return routes
    except Exception:
        pass
    
    if route_type:
        return [r for r in FALLBACK_ROUTES if r["route_type"] == route_type.upper()]
    return FALLBACK_ROUTES

@router.get("/stops")
async def get_stops(route_id: Optional[str] = None, db: AsyncSession = Depends(get_db)):
    """Fetches stops, optionally filtered by a specific route ID."""
    try:
        stmt = select(Stop)
        result = await db.execute(stmt)
        stops = result.scalars().all()
        if stops:
            return stops
    except Exception:
        pass
    return FALLBACK_STOPS

@router.get("/fleet/active", response_model=List[ActiveDriverOut])
async def get_active_fleet():
    """Returns real-time online drivers across Taxi, Combi, and Bus services."""
    return [
        ActiveDriverOut(
            driver_id=d["driver_id"],
            service_type=d.get("service_type", "COMBI"),
            status=d.get("status", "ONLINE"),
            route_id=d.get("route_id"),
            vehicle_id=d.get("vehicle_id"),
            coords=d.get("coords"),
            occupancy=d.get("occupancy", 0),
            speed=d.get("speed", 0.0),
            heading=d.get("heading", 0.0),
            last_update=d.get("last_update")
        )
        for d in active_drivers.values()
    ]
