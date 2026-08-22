from pydantic import BaseModel, Field
from typing import List, Optional
from app.schemas.trip import Coordinates

class LocationPoint(BaseModel):
    name: str
    coords: Coordinates

class JourneyPreference(BaseModel):
    optimize_for: str = "FASTEST" # FASTEST, CHEAPEST, BALANCED
    max_walking_meters: float = 800.0
    allow_taxi_first_mile: bool = True
    allow_intercity_bus: bool = True

class PlanJourneyRequest(BaseModel):
    passenger_id: str
    origin: LocationPoint
    destination: LocationPoint
    desired_arrival_time: Optional[str] = None # e.g. "14:00" or ISO format
    desired_departure_time: Optional[str] = None
    preferences: Optional[JourneyPreference] = Field(default_factory=JourneyPreference)

class JourneyLeg(BaseModel):
    leg_number: int
    mode: str # WALK, TAXI, COMBI, BUS
    from_name: str
    to_name: str
    from_coords: Coordinates
    to_coords: Coordinates
    route_id: Optional[str] = None
    route_name: Optional[str] = None
    departure_time: str
    arrival_time: str
    duration_minutes: int
    distance_meters: float
    fare_bwp: float
    instruction: str
    auto_hail_ready: bool = False

class PlannedItinerary(BaseModel):
    plan_id: str
    passenger_id: str
    origin_name: str
    destination_name: str
    summary: str
    total_duration_minutes: int
    total_fare_bwp: float
    total_distance_km: float
    departure_time: str
    estimated_arrival_time: str
    legs: List[JourneyLeg]
    orchestration_confidence: float = 0.95
