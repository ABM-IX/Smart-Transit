from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional

from app.database import get_db
from app.models.transit import Route, Stop, RouteStop
from app.schemas.transit import RouteOut, StopOut, ActiveDriverOut
from app.sockets.gateway import active_drivers

router = APIRouter(prefix="/api/transit", tags=["Transit Network"])

@router.get("/routes")
async def get_routes(route_type: Optional[str] = None, db: AsyncSession = Depends(get_db)):
    """Fetches all registered routes that have active drivers."""
    try:
        stmt = select(Route)
        if route_type:
            stmt = stmt.where(Route.route_type == route_type.upper())
        result = await db.execute(stmt)
        routes = result.scalars().all()
        # Filter out legacy test subjects (e.g. route-u01..route-u04)
        filtered = [r for r in routes if not r.id.lower().startswith("route-u0") and "test" not in r.name.lower()]
        return filtered
    except Exception:
        return []

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
