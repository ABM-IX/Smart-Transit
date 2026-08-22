-- SmartTransit AI Platform - Supabase PostgreSQL Database Schema
-- Version: 2.0.0

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Transit Routes Table
CREATE TABLE IF NOT EXISTS public.routes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    origin_name TEXT NOT NULL,
    destination_name TEXT NOT NULL,
    route_type TEXT NOT NULL DEFAULT 'COMBI', -- COMBI, TAXI, BUS
    base_fare NUMERIC(10, 2) NOT NULL DEFAULT 8.00,
    waypoints JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. Transit Stops Table
CREATE TABLE IF NOT EXISTS public.stops (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. Route Stops Association Table
CREATE TABLE IF NOT EXISTS public.route_stops (
    id SERIAL PRIMARY KEY,
    route_id TEXT NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
    stop_id TEXT NOT NULL REFERENCES public.stops(id) ON DELETE CASCADE,
    sequence_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(route_id, stop_id)
);

-- 5. Users / Profiles Table
CREATE TABLE IF NOT EXISTS public.users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE,
    full_name TEXT,
    phone_number TEXT,
    role TEXT NOT NULL DEFAULT 'PASSENGER', -- PASSENGER, DRIVER, DISPATCHER, ADMIN
    vehicle_plate TEXT,
    service_type TEXT, -- COMBI, TAXI, BUS
    assigned_route_id TEXT REFERENCES public.routes(id) ON DELETE SET NULL,
    rating NUMERIC(3, 2) DEFAULT 5.00,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 6. Trips & Rides Table
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    passenger_id TEXT NOT NULL,
    driver_id TEXT,
    route_id TEXT REFERENCES public.routes(id) ON DELETE SET NULL,
    service_type TEXT NOT NULL DEFAULT 'COMBI', -- COMBI, TAXI, BUS
    status TEXT NOT NULL DEFAULT 'PENDING', -- PENDING, ACCEPTED, ONBOARD, COMPLETED, CANCELLED
    pickup_lat DOUBLE PRECISION,
    pickup_lng DOUBLE PRECISION,
    pickup_name TEXT,
    dropoff_lat DOUBLE PRECISION,
    dropoff_lng DOUBLE PRECISION,
    dropoff_name TEXT,
    fare NUMERIC(10, 2) NOT NULL DEFAULT 8.00,
    rating INTEGER,
    rating_comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ
);

-- 7. Live Driver Locations (Real-Time State)
CREATE TABLE IF NOT EXISTS public.driver_locations (
    driver_id TEXT PRIMARY KEY,
    service_type TEXT NOT NULL DEFAULT 'COMBI',
    route_id TEXT,
    vehicle_id TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    heading DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    occupancy INTEGER NOT NULL DEFAULT 0,
    occupancy_text TEXT DEFAULT 'Available',
    is_online BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 8. Live Hail Requests
CREATE TABLE IF NOT EXISTS public.hails (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    passenger_id TEXT NOT NULL,
    route_id TEXT REFERENCES public.routes(id) ON DELETE SET NULL,
    service_type TEXT NOT NULL DEFAULT 'COMBI',
    status TEXT NOT NULL DEFAULT 'WAITING', -- WAITING, ACCEPTED, BOARDED, CANCELLED
    pickup_lat DOUBLE PRECISION NOT NULL,
    pickup_lng DOUBLE PRECISION NOT NULL,
    dropoff_lat DOUBLE PRECISION,
    dropoff_lng DOUBLE PRECISION,
    fare_estimate NUMERIC(10, 2) DEFAULT 8.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 9. Row Level Security (RLS) Configuration
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hails ENABLE ROW LEVEL SECURITY;

-- Public Read Policies (Allows anyone anywhere in the world to view transit data)
CREATE POLICY "Allow public read access for routes" ON public.routes FOR SELECT USING (true);
CREATE POLICY "Allow public read access for stops" ON public.stops FOR SELECT USING (true);
CREATE POLICY "Allow public read access for route_stops" ON public.route_stops FOR SELECT USING (true);
CREATE POLICY "Allow public read access for users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Allow public read access for trips" ON public.trips FOR SELECT USING (true);
CREATE POLICY "Allow public read access for driver_locations" ON public.driver_locations FOR SELECT USING (true);
CREATE POLICY "Allow public read access for hails" ON public.hails FOR SELECT USING (true);

-- Public / Anon Insert & Update Policies (Permits app users to request rides & update live state)
CREATE POLICY "Allow insert/update for routes" ON public.routes FOR ALL USING (true);
CREATE POLICY "Allow insert/update for stops" ON public.stops FOR ALL USING (true);
CREATE POLICY "Allow insert/update for route_stops" ON public.route_stops FOR ALL USING (true);
CREATE POLICY "Allow insert/update for users" ON public.users FOR ALL USING (true);
CREATE POLICY "Allow insert/update for trips" ON public.trips FOR ALL USING (true);
CREATE POLICY "Allow insert/update for driver_locations" ON public.driver_locations FOR ALL USING (true);
CREATE POLICY "Allow insert/update for hails" ON public.hails FOR ALL USING (true);

-- 10. Enable Supabase Realtime for Realtime Dispatch & Live Map Tracking
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE public.driver_locations, public.hails, public.trips;
COMMIT;
