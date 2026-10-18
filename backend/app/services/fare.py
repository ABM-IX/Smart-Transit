import math
from typing import Dict, Optional
from app.config import settings

def estimate_special_taxi_fare(pickup: Dict[str, float], dropoff: Optional[Dict[str, float]]) -> float:
    """Recommend a metered fare using the passenger pricing specification."""
    if not pickup or not dropoff:
        return 12.0
    
    from app.services.geo import haversine_distance
    distance_meters = haversine_distance(pickup, dropoff)
    distance_km = distance_meters / 1000.0
    duration_min = (distance_km / 30.0) * 60.0
    calculated_fare = 10.0 + max(0.0, distance_km - 1.0) * 2.5 + max(0.0, duration_min - 3.0) * 0.3
    return round(max(12.0, calculated_fare), 2)

def get_fare(service_type: str, pickup: Optional[Dict[str, float]] = None, dropoff: Optional[Dict[str, float]] = None) -> float:
    """
    Unified fare resolver for all transit modes (COMBI, BUS, TAXI STANDARD, TAXI SPECIAL).
    """
    st = service_type.upper()
    if st == "SPECIAL":
        return estimate_special_taxi_fare(pickup or {}, dropoff or {})
    elif st == "TAXI" or st == "STANDARD":
        return settings.TAXI_STANDARD_FARE
    elif st == "BUS":
        return 0.0
    else:
        return settings.BUS_COMBI_FARE
