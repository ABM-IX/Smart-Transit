import pytest
from httpx import AsyncClient, ASGITransport
from main import fastapi_app

@pytest.mark.asyncio
async def test_health_endpoint():
    async with AsyncClient(transport=ASGITransport(app=fastapi_app), base_url="http://test") as ac:
        response = await ac.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "FastAPI" in data["engine"]

@pytest.mark.asyncio
async def test_get_routes_endpoint():
    async with AsyncClient(transport=ASGITransport(app=fastapi_app), base_url="http://test") as ac:
        response = await ac.get("/api/transit/routes")
    assert response.status_code == 200
    routes = response.json()
    assert len(routes) > 0

@pytest.mark.asyncio
async def test_ai_planner_endpoint():
    async with AsyncClient(transport=ASGITransport(app=fastapi_app), base_url="http://test") as ac:
        payload = {
            "passenger_id": "test-user-1",
            "origin": {
                "name": "Block 8 Gaborone",
                "coords": {"lat": -24.6150, "lng": 25.9050}
            },
            "destination": {
                "name": "Francistown Central",
                "coords": {"lat": -21.1661, "lng": 27.5144}
            },
            "desired_arrival_time": "15:30"
        }
        response = await ac.post("/api/ai/plan-journey", json=payload)
    assert response.status_code == 200
    itinerary = response.json()
    assert itinerary["origin_name"] == "Block 8 Gaborone"
    assert len(itinerary["legs"]) == 3
