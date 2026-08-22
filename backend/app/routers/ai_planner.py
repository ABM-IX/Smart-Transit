from fastapi import APIRouter, HTTPException
from app.schemas.ai_planner import PlanJourneyRequest, PlannedItinerary
from app.services.ai_orchestrator import ai_orchestrator

router = APIRouter(prefix="/api/ai", tags=["AI Multi-Modal Journey Planner"])

@router.post("/plan-journey", response_model=PlannedItinerary)
async def plan_journey(request: PlanJourneyRequest):
    """
    AI Autonomous Transit Facilitator:
    Plans and coordinates an end-to-end multi-modal journey (Doorstep Taxi -> Arterial Combi -> Intercity Bus).
    Calculates departure schedules, transfers, fares, and auto-hail readiness.
    """
    try:
        itinerary = ai_orchestrator.plan_multi_modal_journey(request)
        return itinerary
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI journey orchestration failed: {str(e)}")
