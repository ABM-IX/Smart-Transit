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


@router.get("/health")
@router.head("/health")
async def health_check():
    """Returns the operational health of the SmartTransit engine."""
    return {
        "status": "ok",
        "system_active": system_active,
        "engine": "FastAPI + Socket.IO + AI Orchestrator",
        "active_drivers_count": len(active_drivers),
        "active_passengers_count": len(active_passengers),
        "active_trips_count": len(active_trips),
        "taxi_assignments_count": len(taxi_assignments)
    }


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
