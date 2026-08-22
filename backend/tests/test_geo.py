import pytest
from app.services.geo import haversine_distance, find_nearest_stop, calculate_eta

def test_haversine_distance_same_point():
    p = {"lat": -24.6549, "lng": 25.9082}
    assert haversine_distance(p, p) == 0.0

def test_haversine_distance_known_distance():
    # Distance between BAC Stop and Gaborone Bus Rank is approx ~640 meters
    bac = {"lat": -24.6549, "lng": 25.9082}
    bus_rank = {"lat": -24.6546, "lng": 25.9145}
    dist = haversine_distance(bac, bus_rank)
    assert 600.0 <= dist <= 700.0

def test_find_nearest_stop():
    stops = [
        {"id": "s1", "name": "Stop 1", "latitude": -24.6549, "longitude": 25.9082},
        {"id": "s2", "name": "Stop 2", "latitude": -24.6832, "longitude": 25.8952}
    ]
    query_loc = {"lat": -24.6550, "lng": 25.9085} # Right next to Stop 1
    nearest = find_nearest_stop(stops, query_loc)
    assert nearest is not None
    assert nearest["id"] == "s1"
    assert nearest["distance_meters"] < 50.0

def test_calculate_eta():
    eta = calculate_eta(distance_meters=1000.0, speed_kmh=30.0)
    assert eta > 0
    assert eta == int(1000.0 / (30.0 * 1000.0 / 3600.0))
