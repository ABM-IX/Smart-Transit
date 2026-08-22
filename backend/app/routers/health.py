from fastapi import APIRouter
from app.sockets.gateway import (
    active_drivers, active_passengers, active_trips,
    taxi_assignments, active_hails, system_active
)

router = APIRouter(tags=["System & Telemetry"])

@router.get("/health")
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
