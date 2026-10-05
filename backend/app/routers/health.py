import os
from fastapi import APIRouter
from fastapi.responses import FileResponse, Response
from app.sockets.gateway import (
    active_drivers, active_passengers, active_trips,
    taxi_assignments, active_hails, system_active
)

router = APIRouter(tags=["System & Telemetry"])

STATIC_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "static")
STATIC_INDEX = os.path.join(STATIC_DIR, "index.html")

@router.get("/")
async def root_status():
    """Serves the Admin Dispatch Dashboard UI if available, or system info."""
    if os.path.exists(STATIC_INDEX):
        return FileResponse(STATIC_INDEX, media_type="text/html")
    return {
        "status": "online",
        "project": "SmartTransit AI Platform",
        "version": "2.0.0",
        "endpoints": {
            "health": "/health",
            "routes": "/api/transit/routes",
            "stops": "/api/transit/stops",
            "ai_planner": "/api/ai/plan-journey",
            "docs": "/docs"
        }
    }

@router.head("/")
async def root_head():
    """Health check for cloud load balancers / Render pinger."""
    return Response(status_code=200)


from app.database import check_db_health

@router.get("/health")
@router.head("/health")
async def health_check():
    """Returns the operational health of the SmartTransit engine and database."""
    db_health = await check_db_health()
    is_healthy = system_active and db_health.get("status") == "connected"
    return {
        "status": "ok" if is_healthy else "degraded",
        "system_active": system_active,
        "database": db_health,
        "engine": "FastAPI + Socket.IO + AI Orchestrator",
        "active_drivers_count": len(active_drivers),
        "active_passengers_count": len(active_passengers),
        "active_trips_count": len(active_trips),
        "taxi_assignments_count": len(taxi_assignments)
    }

@router.get("/api/health/db")
async def db_health_endpoint():
    """Explicit database health diagnostic endpoint."""
    return await check_db_health()


@router.get("/api/analytics")
async def get_analytics():
    """Provides high-level system analytics for the admin dashboard."""
    return {
        "activeDrivers": len(active_drivers),
        "activePassengers": len(active_passengers),
        "activeTrips": len(active_trips),
        "taxiAssignments": len(taxi_assignments),
        "activeHails": len(active_hails)
    }
