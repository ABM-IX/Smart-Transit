import math
from typing import Dict, Optional
from app.config import settings

def estimate_special_taxi_fare(pickup: Dict[str, float], dropoff: Optional[Dict[str, float]]) -> float:
    """
    Calculates dynamic special taxi fare based on base price, distance, and duration.
    """
    if not pickup or not dropoff:
        return settings.TAXI_SPECIAL_BASE
    
    from app.services.geo import haversine_distance
    distance_meters = haversine_distance(pickup, dropoff)
    distance_km = distance_meters / 1000.0
    duration_min = (distance_km / 30.0) * 60.0 # Assuming ~30km/h avg speed
    
    calculated_fare = (
        settings.TAXI_SPECIAL_BASE +
        (distance_km * settings.TAXI_SPECIAL_PER_KM) +
        (duration_min * settings.TAXI_SPECIAL_PER_MIN)
    )
    return max(settings.TAXI_SPECIAL_BASE, round(calculated_fare, 2))

def get_fare(service_type: str, pickup: Optional[Dict[str, float]] = None, dropoff: Optional[Dict[str, float]] = None) -> float:
    """
    Unified fare resolver for all transit modes (COMBI, BUS, TAXI STANDARD, TAXI SPECIAL).
    """
    st = service_type.upper()
    if st == "SPECIAL":
        return estimate_special_taxi_fare(pickup or {}, dropoff or {})
    elif st == "TAXI" or st == "STANDARD":
        return settings.TAXI_STANDARD_FARE
    else:
        return settings.BUS_COMBI_FARE
