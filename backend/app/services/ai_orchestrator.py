import uuid
import math
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import networkx as nx

from app.schemas.ai_planner import PlanJourneyRequest, PlannedItinerary, JourneyLeg, Coordinates, LocationPoint
from app.services.geo import haversine_distance, calculate_eta
from app.services.fare import get_fare, estimate_special_taxi_fare

# Default mock stop network in Botswana (Gaborone region + Intercity hubs)
DEFAULT_STOPS = [
    {"id": "stop-u01-1", "name": "BAC Stop", "lat": -24.6549, "lng": 25.9082, "type": "COMBI", "route_id": "route-u01"},
    {"id": "stop-u01-2", "name": "Gaborone Bus Rank (Local)", "lat": -24.6546, "lng": 25.9145, "type": "COMBI", "route_id": "route-u01"},
    {"id": "stop-u02-1", "name": "UB Gate Stop", "lat": -24.6590, "lng": 25.9325, "type": "COMBI", "route_id": "route-u02"},
    {"id": "stop-u02-2", "name": "Main Mall Station", "lat": -24.6543, "lng": 25.9189, "type": "COMBI", "route_id": "route-u02"},
    {"id": "stop-u03-1", "name": "Botho University Stop", "lat": -24.6407, "lng": 25.9295, "type": "COMBI", "route_id": "route-u03"},
    {"id": "stop-u04-1", "name": "Game City Mall Stop", "lat": -24.6832, "lng": 25.8952, "type": "COMBI", "route_id": "route-u04"},
    {"id": "stop-bus-rank", "name": "Gaborone Central Bus Rank", "lat": -24.6546, "lng": 25.9145, "type": "BUS_TERMINAL", "route_id": "intercity"},
    {"id": "stop-francistown", "name": "Francistown Central Terminal", "lat": -21.1661, "lng": 27.5144, "type": "BUS_TERMINAL", "route_id": "bus-francistown"},
    {"id": "stop-lobatse", "name": "Lobatse Bus Rank", "lat": -25.2167, "lng": 25.6667, "type": "BUS_TERMINAL", "route_id": "bus-lobatse"},
    {"id": "stop-palapye", "name": "Palapye Main Junction", "lat": -22.5500, "lng": 27.1333, "type": "BUS_TERMINAL", "route_id": "bus-palapye"},
    {"id": "stop-maun", "name": "Maun Bus Rank", "lat": -19.9833, "lng": 23.4167, "type": "BUS_TERMINAL", "route_id": "bus-maun"}
]

class AITransitOrchestrator:
    """
    Intelligent Multi-Modal Journey Planner & Autonomous Dispatch Facilitator.
    Solves time-budgeted multi-leg routes combining Taxi, Combi, and Intercity Buses.
    """

    def __init__(self, stops_data: Optional[List[Dict[str, Any]]] = None):
        self.stops = stops_data or DEFAULT_STOPS
        self._build_transit_graph()

    def _build_transit_graph(self):
        """Constructs a directed graph representing transit nodes and available routes."""
        self.graph = nx.DiGraph()
        for stop in self.stops:
            self.graph.add_node(
                stop["id"],
                name=stop["name"],
                lat=stop["lat"],
                lng=stop["lng"],
                type=stop["type"],
                route_id=stop.get("route_id")
            )

    def plan_multi_modal_journey(self, req: PlanJourneyRequest) -> PlannedItinerary:
        """
        Orchestrates an optimal multi-leg itinerary.
        Case 1: Direct Local (Walk or Taxi to Combi -> Destination)
        Case 2: Intercity Multi-Modal (Doorstep Taxi -> Arterial Combi -> Central Bus Rank -> Intercity Express Bus)
        """
        origin = req.origin
        destination = req.destination
        
        # Calculate straight-line distance
        orig_dict = {"lat": origin.coords.lat, "lng": origin.coords.lng}
        dest_dict = {"lat": destination.coords.lat, "lng": destination.coords.lng}
        total_dist_meters = haversine_distance(orig_dict, dest_dict)
        is_intercity = total_dist_meters > 35000.0  # More than 35km implies intercity trip

        # Determine target arrival time (or now + ETA)
        now = datetime.now()
        target_arrival = now + timedelta(hours=4) if is_intercity else now + timedelta(minutes=45)
        
        if req.desired_arrival_time:
            try:
                # Handle HH:MM string
                parts = req.desired_arrival_time.split(":")
                target_arrival = target_arrival.replace(hour=int(parts[0]), minute=int(parts[1]), second=0)
            except Exception:
                pass

        legs: List[JourneyLeg] = []
        plan_id = f"plan-{uuid.uuid4().hex[:8]}"

        if is_intercity:
            # Multi-Modal Coordinated Flow:
            # Leg 1: Special Taxi from Doorstep to nearest Local Combi Stop
            # Leg 2: Combi from Local Stop to Central Bus Rank
            # Leg 3: Intercity Bus from Central Bus Rank to Destination Terminal
            
            nearest_combi_stop = self._find_nearest_stop_by_type(orig_dict, "COMBI") or self.stops[0]
            bus_rank = self._find_stop_by_id("stop-bus-rank") or self.stops[1]
            dest_terminal = self._find_nearest_stop_by_type(dest_dict, "BUS_TERMINAL") or self.stops[7]

            # Timing calculations (Backwards scheduling from target arrival)
            intercity_duration_mins = int((haversine_distance(
                {"lat": bus_rank["lat"], "lng": bus_rank["lng"]},
                {"lat": dest_terminal["lat"], "lng": dest_terminal["lng"]}
            ) / 1000.0 / 80.0) * 60.0) # 80 km/h coach speed
            
            combi_duration_mins = 20
            taxi_duration_mins = 12
            buffer_mins = 15

            # Calculate leg schedule times
            bus_arrival_time = target_arrival
            bus_departure_time = bus_arrival_time - timedelta(minutes=intercity_duration_mins)
            
            combi_arrival_time = bus_departure_time - timedelta(minutes=buffer_mins)
            combi_departure_time = combi_arrival_time - timedelta(minutes=combi_duration_mins)
            
            taxi_arrival_time = combi_departure_time - timedelta(minutes=5) # 5 min transfer buffer
            taxi_departure_time = taxi_arrival_time - timedelta(minutes=taxi_duration_mins)

            # Leg 1: Taxi First-Mile Pickup
            taxi_dist = haversine_distance(orig_dict, {"lat": nearest_combi_stop["lat"], "lng": nearest_combi_stop["lng"]})
            taxi_fare = estimate_special_taxi_fare(orig_dict, {"lat": nearest_combi_stop["lat"], "lng": nearest_combi_stop["lng"]})
            legs.append(JourneyLeg(
                leg_number=1,
                mode="TAXI",
                from_name=origin.name,
                to_name=nearest_combi_stop["name"],
                from_coords=origin.coords,
                to_coords=Coordinates(lat=nearest_combi_stop["lat"], lng=nearest_combi_stop["lng"]),
                departure_time=taxi_departure_time.strftime("%H:%M"),
                arrival_time=taxi_arrival_time.strftime("%H:%M"),
                duration_minutes=taxi_duration_mins,
                distance_meters=round(taxi_dist),
                fare_bwp=taxi_fare,
                instruction=f"AI Auto-Hail: Taxi arrives at {origin.name} at {taxi_departure_time.strftime('%H:%M')} to drop you at {nearest_combi_stop['name']}.",
                auto_hail_ready=True
            ))

            # Leg 2: Combi Urban Trunk
            combi_dist = haversine_distance({"lat": nearest_combi_stop["lat"], "lng": nearest_combi_stop["lng"]}, {"lat": bus_rank["lat"], "lng": bus_rank["lng"]})
            legs.append(JourneyLeg(
                leg_number=2,
                mode="COMBI",
                from_name=nearest_combi_stop["name"],
                to_name=bus_rank["name"],
                from_coords=Coordinates(lat=nearest_combi_stop["lat"], lng=nearest_combi_stop["lng"]),
                to_coords=Coordinates(lat=bus_rank["lat"], lng=bus_rank["lng"]),
                route_id=nearest_combi_stop.get("route_id", "route-u01"),
                route_name="Route U1 – Urban Feeder",
                departure_time=combi_departure_time.strftime("%H:%M"),
                arrival_time=combi_arrival_time.strftime("%H:%M"),
                duration_minutes=combi_duration_mins,
                distance_meters=round(combi_dist),
                fare_bwp=8.0,
                instruction=f"Board approaching Combi (Route U1) at {nearest_combi_stop['name']} towards {bus_rank['name']}.",
                auto_hail_ready=True
            ))

            # Leg 3: Intercity Bus Long-Haul
            bus_dist = haversine_distance({"lat": bus_rank["lat"], "lng": bus_rank["lng"]}, {"lat": dest_terminal["lat"], "lng": dest_terminal["lng"]})
            bus_fare = round(max(50.0, (bus_dist / 1000.0) * 0.35), 2) # e.g. ~150 BWP for Gaborone-Francistown
            legs.append(JourneyLeg(
                leg_number=3,
                mode="BUS",
                from_name=bus_rank["name"],
                to_name=dest_terminal["name"],
                from_coords=Coordinates(lat=bus_rank["lat"], lng=bus_rank["lng"]),
                to_coords=Coordinates(lat=dest_terminal["lat"], lng=dest_terminal["lng"]),
                route_id="bus-express",
                route_name=f"Intercity Express: {bus_rank['name']} → {dest_terminal['name']}",
                departure_time=bus_departure_time.strftime("%H:%M"),
                arrival_time=bus_arrival_time.strftime("%H:%M"),
                duration_minutes=intercity_duration_mins,
                distance_meters=round(bus_dist),
                fare_bwp=bus_fare,
                instruction=f"Board reserved Intercity Coach at Bay 4 ({bus_rank['name']}) departing at {bus_departure_time.strftime('%H:%M')}.",
                auto_hail_ready=False
            ))

            departure_time_str = taxi_departure_time.strftime("%H:%M")
            arrival_time_str = bus_arrival_time.strftime("%H:%M")
            summary = f"Multi-Modal Coordinated Trip (Taxi + Combi + Intercity Bus) to {destination.name}"

        else:
            # Local Urban Journey: Walk/Taxi to Combi Stop -> Combi to Destination Stop -> Walk to Destination
            pickup_stop = self._find_nearest_stop_by_type(orig_dict, "COMBI") or self.stops[0]
            dropoff_stop = self._find_nearest_stop_by_type(dest_dict, "COMBI") or self.stops[1]

            walk_first_dist = haversine_distance(orig_dict, {"lat": pickup_stop["lat"], "lng": pickup_stop["lng"]})
            combi_dist = haversine_distance({"lat": pickup_stop["lat"], "lng": pickup_stop["lng"]}, {"lat": dropoff_stop["lat"], "lng": dropoff_stop["lng"]})
            walk_last_dist = haversine_distance({"lat": dropoff_stop["lat"], "lng": dropoff_stop["lng"]}, dest_dict)

            start_time = now
            t1 = start_time + timedelta(minutes=max(3, int(walk_first_dist / 80)))
            t2 = t1 + timedelta(minutes=max(10, int(combi_dist / 400)))
            t3 = t2 + timedelta(minutes=max(2, int(walk_last_dist / 80)))

            if walk_first_dist > 500.0:
                # Suggest First-Mile Taxi
                legs.append(JourneyLeg(
                    leg_number=1,
                    mode="TAXI",
                    from_name=origin.name,
                    to_name=pickup_stop["name"],
                    from_coords=origin.coords,
                    to_coords=Coordinates(lat=pickup_stop["lat"], lng=pickup_stop["lng"]),
                    departure_time=start_time.strftime("%H:%M"),
                    arrival_time=t1.strftime("%H:%M"),
                    duration_minutes=int((t1 - start_time).total_seconds() / 60),
                    distance_meters=round(walk_first_dist),
                    fare_bwp=estimate_special_taxi_fare(orig_dict, {"lat": pickup_stop["lat"], "lng": pickup_stop["lng"]}),
                    instruction=f"Take direct Taxi connection to {pickup_stop['name']}.",
                    auto_hail_ready=True
                ))
            else:
                legs.append(JourneyLeg(
                    leg_number=1,
                    mode="WALK",
                    from_name=origin.name,
                    to_name=pickup_stop["name"],
                    from_coords=origin.coords,
                    to_coords=Coordinates(lat=pickup_stop["lat"], lng=pickup_stop["lng"]),
                    departure_time=start_time.strftime("%H:%M"),
                    arrival_time=t1.strftime("%H:%M"),
                    duration_minutes=int((t1 - start_time).total_seconds() / 60),
                    distance_meters=round(walk_first_dist),
                    fare_bwp=0.0,
                    instruction=f"Walk {round(walk_first_dist)}m to {pickup_stop['name']}.",
                    auto_hail_ready=False
                ))

            # Combi Trunk
            legs.append(JourneyLeg(
                leg_number=2,
                mode="COMBI",
                from_name=pickup_stop["name"],
                to_name=dropoff_stop["name"],
                from_coords=Coordinates(lat=pickup_stop["lat"], lng=pickup_stop["lng"]),
                to_coords=Coordinates(lat=dropoff_stop["lat"], lng=dropoff_stop["lng"]),
                route_id=pickup_stop.get("route_id", "route-u01"),
                route_name="Route U1 – Arterial",
                departure_time=t1.strftime("%H:%M"),
                arrival_time=t2.strftime("%H:%M"),
                duration_minutes=int((t2 - t1).total_seconds() / 60),
                distance_meters=round(combi_dist),
                fare_bwp=8.0,
                instruction=f"Board Combi to {dropoff_stop['name']}.",
                auto_hail_ready=True
            ))

            # Walk Last-Mile
            legs.append(JourneyLeg(
                leg_number=3,
                mode="WALK",
                from_name=dropoff_stop["name"],
                to_name=destination.name,
                from_coords=Coordinates(lat=dropoff_stop["lat"], lng=dropoff_stop["lng"]),
                to_coords=destination.coords,
                departure_time=t2.strftime("%H:%M"),
                arrival_time=t3.strftime("%H:%M"),
                duration_minutes=int((t3 - t2).total_seconds() / 60),
                distance_meters=round(walk_last_dist),
                fare_bwp=0.0,
                instruction=f"Walk {round(walk_last_dist)}m to reach your destination {destination.name}.",
                auto_hail_ready=False
            ))

            departure_time_str = start_time.strftime("%H:%M")
            arrival_time_str = t3.strftime("%H:%M")
            summary = f"Urban Transit Itinerary to {destination.name}"

        total_fare = sum(leg.fare_bwp for leg in legs)
        total_duration = sum(leg.duration_minutes for leg in legs)
        total_dist_km = round(sum(leg.distance_meters for leg in legs) / 1000.0, 2)

        return PlannedItinerary(
            plan_id=plan_id,
            passenger_id=req.passenger_id,
            origin_name=origin.name,
            destination_name=destination.name,
            summary=summary,
            total_duration_minutes=total_duration,
            total_fare_bwp=round(total_fare, 2),
            total_distance_km=total_dist_km,
            departure_time=departure_time_str,
            estimated_arrival_time=arrival_time_str,
            legs=legs,
            orchestration_confidence=0.96
        )

    def _find_nearest_stop_by_type(self, coords: Dict[str, float], stop_type: str) -> Optional[Dict[str, Any]]:
        filtered = [s for s in self.stops if s.get("type") == stop_type]
        if not filtered:
            filtered = self.stops
        
        nearest = None
        min_dist = float("inf")
        for s in filtered:
            dist = haversine_distance(coords, {"lat": s["lat"], "lng": s["lng"]})
            if dist < min_dist:
                min_dist = dist
                nearest = s
        return nearest

    def _find_stop_by_id(self, stop_id: str) -> Optional[Dict[str, Any]]:
        for s in self.stops:
            if s["id"] == stop_id:
                return s
        return None

ai_orchestrator = AITransitOrchestrator()
