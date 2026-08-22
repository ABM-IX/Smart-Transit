import pytest
from app.services.ai_orchestrator import ai_orchestrator
from app.schemas.ai_planner import PlanJourneyRequest, LocationPoint, Coordinates

def test_local_urban_journey_planning():
    req = PlanJourneyRequest(
        passenger_id="p-123",
        origin=LocationPoint(name="BAC College", coords=Coordinates(lat=-24.6549, lng=25.9082)),
        destination=LocationPoint(name="Main Mall", coords=Coordinates(lat=-24.6543, lng=25.9189))
    )
    plan = ai_orchestrator.plan_multi_modal_journey(req)
    assert plan is not None
    assert plan.plan_id.startswith("plan-")
    assert len(plan.legs) >= 2
    assert plan.total_duration_minutes > 0
    assert plan.total_fare_bwp >= 8.0

def test_intercity_multi_modal_orchestration():
    # From Home in Gaborone (Block 8) to Francistown Central Terminal (> 400km)
    req = PlanJourneyRequest(
        passenger_id="p-456",
        origin=LocationPoint(name="Block 8 Home", coords=Coordinates(lat=-24.6150, lng=25.9050)),
        destination=LocationPoint(name="Francistown Terminal", coords=Coordinates(lat=-21.1661, lng=27.5144)),
        desired_arrival_time="14:00"
    )
    plan = ai_orchestrator.plan_multi_modal_journey(req)
    assert plan is not None
    assert len(plan.legs) == 3 # 1: Taxi to Combi -> 2: Combi to Bus Rank -> 3: Intercity Bus
    modes = [leg.mode for leg in plan.legs]
    assert modes == ["TAXI", "COMBI", "BUS"]
    assert plan.legs[0].auto_hail_ready is True
    assert plan.legs[1].auto_hail_ready is True
    assert plan.total_fare_bwp > 50.0
