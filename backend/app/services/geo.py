import math
from typing import Dict, Any, Optional, List, Tuple

def haversine_distance(c1: Dict[str, float], c2: Dict[str, float]) -> float:
    """
    Calculates great-circle distance between two GPS coordinates in meters.
    c1, c2 format: {"lat": float, "lng": float} or {"latitude": float, "longitude": float}
    """
    lat1 = c1.get("lat", c1.get("latitude", 0.0))
    lng1 = c1.get("lng", c1.get("longitude", 0.0))
    lat2 = c2.get("lat", c2.get("latitude", 0.0))
    lng2 = c2.get("lng", c2.get("longitude", 0.0))

    R = 6371000.0  # Earth's radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lng2 - lng1)

    a = (math.sin(delta_phi / 2.0) ** 2 +
         math.cos(phi1) * math.cos(phi2) * (math.sin(delta_lambda / 2.0) ** 2))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

def find_nearest_stop(stops: List[Dict[str, Any]], coords: Dict[str, float]) -> Optional[Dict[str, Any]]:
    """
    Finds the nearest stop from a list of stop records.
    Returns stop dictionary augmented with `distance_meters`.
    """
    if not stops or not coords:
        return None
    
    nearest = None
    min_dist = float("inf")

    for stop in stops:
        s_coords = {"lat": stop.get("latitude", 0.0), "lng": stop.get("longitude", 0.0)}
        dist = haversine_distance(coords, s_coords)
        if dist < min_dist:
            min_dist = dist
            nearest = {**stop, "distance_meters": dist}
            
    return nearest

def calculate_eta(distance_meters: float, speed_kmh: float = 30.0) -> int:
    """
    Calculates ETA in seconds given distance in meters and speed in km/h.
    Applies a minimum floor speed of 18 km/h (5 m/s) to account for traffic crawl.
    """
    effective_speed_kmh = max(18.0, speed_kmh)
    speed_ms = effective_speed_kmh * (1000.0 / 3600.0)
    return max(10, int(distance_meters / speed_ms))
