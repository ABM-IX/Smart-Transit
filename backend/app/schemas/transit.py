from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List

class StopBase(BaseModel):
    id: str
    name: str
    latitude: float
    longitude: float
    description: Optional[str] = None

class StopOut(StopBase):
    model_config = ConfigDict(from_attributes=True)

class RouteStopOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    stop_sequence: int
    distance_from_start_meters: float
    stop: StopOut

class RouteBase(BaseModel):
    id: str
    name: str
    origin_name: str
    destination_name: str
    route_type: str = "COMBI"
    base_fare: float = 8.0

class RouteOut(RouteBase):
    model_config = ConfigDict(from_attributes=True)
    stops: List[RouteStopOut] = []

class ActiveDriverOut(BaseModel):
    driver_id: str
    service_type: str
    status: str
    route_id: Optional[str] = None
    vehicle_id: Optional[str] = None
    coords: Optional[dict] = None
    occupancy: Optional[int] = 0
    speed: Optional[float] = 0.0
    heading: Optional[float] = 0.0
    last_update: Optional[float] = None
