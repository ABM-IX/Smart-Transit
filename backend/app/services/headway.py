from typing import List, Dict, Any, Optional
from app.services.geo import haversine_distance

def calculate_spacing_advisories(drivers_on_route: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Computes inter-vehicle headways (distances ahead and behind) along a corridor
    to prevent vehicle bunching.
    
    Returns a list of advisory payloads containing:
    - driver_id
    - status: 'SLOW DOWN' | 'SPEED UP' | 'MAINTAIN CURRENT SPEED'
    - ahead_dist_meters
    - behind_dist_meters
    """
    valid_drivers = [
        d for d in drivers_on_route
        if d.get("coords") and d.get("service_type") != "TAXI"
    ]
    
    if len(valid_drivers) < 2:
        return []

    # Sort drivers spatially along the latitude progression of the route
    sorted_drivers = sorted(valid_drivers, key=lambda d: d["coords"]["lat"])
    advisories = []

    for i in range(len(sorted_drivers)):
        curr = sorted_drivers[i]
        ahead = sorted_drivers[i + 1] if i + 1 < len(sorted_drivers) else None
        behind = sorted_drivers[i - 1] if i - 1 >= 0 else None

        ahead_dist = haversine_distance(curr["coords"], ahead["coords"]) if ahead else None
        behind_dist = haversine_distance(curr["coords"], behind["coords"]) if behind else None

        status = "MAINTAIN CURRENT SPEED"
        if ahead_dist is not None:
            if ahead_dist < 200.0:
                status = "SLOW DOWN" # Too close to vehicle ahead (anti-bunching)
            elif ahead_dist > 800.0:
                status = "SPEED UP"  # Lagging too far behind (gap prevention)

        advisories.append({
            "driver_id": curr["driver_id"],
            "socket_id": curr.get("socket_id"),
            "status": status,
            "ahead_dist_meters": round(ahead_dist) if ahead_dist is not None else None,
            "behind_dist_meters": round(behind_dist) if behind_dist is not None else None,
            "ahead_display": f"{round(ahead_dist)}m" if ahead_dist is not None else "N/A",
            "behind_display": f"{round(behind_dist)}m" if behind_dist is not None else "N/A"
        })

    return advisories
