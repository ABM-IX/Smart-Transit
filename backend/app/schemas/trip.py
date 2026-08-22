from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class Coordinates(BaseModel):
    lat: float
    lng: float

class TaxiRequestIn(BaseModel):
    passenger_id: str
    pickup: Coordinates
    dropoff: Optional[Coordinates] = None
    service_type: str = "STANDARD" # STANDARD or SPECIAL

class TaxiRequestOut(BaseModel):
    request_id: str
    passenger_id: str
    pickup: Coordinates
    dropoff: Optional[Coordinates] = None
    service_type: str
    fare_estimate: float
    status: str
    requested_at: float

class HailIn(BaseModel):
    passenger_id: str
    route_id: str
    pickup_coords: Coordinates
    dropoff_coords: Optional[Coordinates] = None
    service_type: str = "STANDARD"

class HailOut(BaseModel):
    request_id: str
    passenger_id: str
    route_id: str
    pickup_coords: Coordinates
    dropoff_coords: Optional[Coordinates] = None
    service_type: str
    fare_estimate: float
    stop_id: Optional[str] = None
    stop_name: Optional[str] = None
    stop_distance_meters: Optional[float] = None
    near_stop: bool
    requested_at: float

class BoardingConfirmIn(BaseModel):
    driver_id: str
    passenger_id: str
    route_id: str

class DriverRatingIn(BaseModel):
    driver_id: str
    passenger_id: str
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = None
