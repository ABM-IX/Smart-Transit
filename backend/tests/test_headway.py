import pytest
from app.services.headway import calculate_spacing_advisories

def test_headway_under_two_drivers():
    drivers = [{"driver_id": "d1", "coords": {"lat": -24.65, "lng": 25.90}, "service_type": "COMBI"}]
    advisories = calculate_spacing_advisories(drivers)
    assert advisories == []

def test_headway_slow_down_and_speed_up():
    # Sorted by latitude:
    # d3 (-24.6650) -> next is d2 (-24.6508), distance ~1.5km (>800m) -> SPEED UP
    # d2 (-24.6508) -> next is d1 (-24.6500), distance ~88m (<200m) -> SLOW DOWN
    # d1 (-24.6500) -> leader (no vehicle ahead) -> MAINTAIN CURRENT SPEED
    drivers = [
        {"driver_id": "d1", "coords": {"lat": -24.6500, "lng": 25.9000}, "service_type": "COMBI", "socket_id": "s1"},
        {"driver_id": "d2", "coords": {"lat": -24.6508, "lng": 25.9000}, "service_type": "COMBI", "socket_id": "s2"},
        {"driver_id": "d3", "coords": {"lat": -24.6650, "lng": 25.9000}, "service_type": "COMBI", "socket_id": "s3"}
    ]
    advisories = calculate_spacing_advisories(drivers)
    assert len(advisories) == 3
    
    # Map by driver_id for deterministic checks
    adv_by_driver = {a["driver_id"]: a for a in advisories}
    assert adv_by_driver["d3"]["status"] == "SPEED UP"
    assert adv_by_driver["d2"]["status"] == "SLOW DOWN"
    assert adv_by_driver["d1"]["status"] == "MAINTAIN CURRENT SPEED"
