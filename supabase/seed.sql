-- SmartTransit AI Platform - Seed Data
-- Production baseline: authentic routes and stops are mapped and registered through live operations.

-- Metropolitan Taxi Dispatch corridor for on-demand taxi cabs
INSERT INTO public.routes (id, name, origin_name, destination_name, route_type, base_fare, is_active)
VALUES ('taxi-dispatch', 'Metropolitan Taxi Dispatch', 'Gaborone Metro', 'On-Demand Dispatch', 'TAXI', 10.00, true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    origin_name = EXCLUDED.origin_name,
    destination_name = EXCLUDED.destination_name,
    route_type = EXCLUDED.route_type,
    base_fare = EXCLUDED.base_fare,
    is_active = EXCLUDED.is_active;
