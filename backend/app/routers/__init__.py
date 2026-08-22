from app.routers.health import router as health_router
from app.routers.transit import router as transit_router
from app.routers.ai_planner import router as ai_router
from app.routers.trips import router as trips_router

__all__ = ["health_router", "transit_router", "ai_router", "trips_router"]
