-- ====================================================================
-- SmartTransit AI Platform - Supabase PostgreSQL Production Setup
-- Run this script in the Supabase Dashboard -> SQL Editor
-- Project: https://xpphmiajwjkcxtxitcex.supabase.co
-- ====================================================================

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

-- Clean existing policies
DROP POLICY IF EXISTS "Allow public read access for routes" ON public.routes;
DROP POLICY IF EXISTS "Allow public read access for stops" ON public.stops;
DROP POLICY IF EXISTS "Allow public read access for route_stops" ON public.route_stops;
DROP POLICY IF EXISTS "Allow public read access for users" ON public.users;
DROP POLICY IF EXISTS "Allow public read access for trips" ON public.trips;
DROP POLICY IF EXISTS "Allow public read access for driver_locations" ON public.driver_locations;
DROP POLICY IF EXISTS "Allow public read access for hails" ON public.hails;

DROP POLICY IF EXISTS "Allow insert/update for routes" ON public.routes;
DROP POLICY IF EXISTS "Allow insert/update for stops" ON public.stops;
DROP POLICY IF EXISTS "Allow insert/update for route_stops" ON public.route_stops;
DROP POLICY IF EXISTS "Allow insert/update for users" ON public.users;
DROP POLICY IF EXISTS "Allow insert/update for trips" ON public.trips;
DROP POLICY IF EXISTS "Allow insert/update for driver_locations" ON public.driver_locations;
DROP POLICY IF EXISTS "Allow insert/update for hails" ON public.hails;

-- Recreate Public Access Policies
CREATE POLICY "Allow public read access for routes" ON public.routes FOR SELECT USING (true);
CREATE POLICY "Allow public read access for stops" ON public.stops FOR SELECT USING (true);
CREATE POLICY "Allow public read access for route_stops" ON public.route_stops FOR SELECT USING (true);
CREATE POLICY "Allow public read access for users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Allow public read access for trips" ON public.trips FOR SELECT USING (true);
CREATE POLICY "Allow public read access for driver_locations" ON public.driver_locations FOR SELECT USING (true);
CREATE POLICY "Allow public read access for hails" ON public.hails FOR SELECT USING (true);

CREATE POLICY "Allow insert/update for routes" ON public.routes FOR ALL USING (true);
CREATE POLICY "Allow insert/update for stops" ON public.stops FOR ALL USING (true);
CREATE POLICY "Allow insert/update for route_stops" ON public.route_stops FOR ALL USING (true);
CREATE POLICY "Allow insert/update for users" ON public.users FOR ALL USING (true);
CREATE POLICY "Allow insert/update for trips" ON public.trips FOR ALL USING (true);
CREATE POLICY "Allow insert/update for driver_locations" ON public.driver_locations FOR ALL USING (true);
CREATE POLICY "Allow insert/update for hails" ON public.hails FOR ALL USING (true);

-- 10. Seed Initial Data
INSERT INTO public.routes (id, name, origin_name, destination_name, route_type, base_fare) VALUES
('bus-molepolole', 'Gaborone → Molepolole Coach', 'Gaborone Bus Rank', 'Molepolole Bus Rank', 'BUS', 35.00),
('bus-francistown', 'Gaborone → Francistown Express', 'Gaborone Bus Rank', 'Francistown Central', 'BUS', 150.00),
('bus-lobatse', 'Gaborone → Lobatse Intercity', 'Gaborone Bus Rank', 'Lobatse Rank', 'BUS', 35.00),
('bus-kanye', 'Gaborone → Kanye Express', 'Gaborone Bus Rank', 'Kanye Bus Rank', 'BUS', 45.00),
('bus-mahalapye', 'Gaborone → Mahalapye Express', 'Gaborone Bus Rank', 'Mahalapye', 'BUS', 90.00),
('bus-palapye', 'Gaborone → Palapye Junction', 'Gaborone Bus Rank', 'Palapye', 'BUS', 110.00),
('bus-maun', 'Gaborone → Maun Safari Line', 'Gaborone Bus Rank', 'Maun Terminal', 'BUS', 280.00),
('route-m01', 'Route M1 – Molepolole Central to Mafitlhakgosi', 'Molepolole Rank', 'Mafitlhakgosi', 'COMBI', 8.00),
('route-m02', 'Route M2 – Molepolole to Borakalalo', 'Molepolole Rank', 'Borakalalo', 'COMBI', 8.00),
('route-u01', 'Route U1 – BAC to Bus Rank', 'BAC Stop', 'Gaborone Bus Rank', 'COMBI', 8.00),
('route-u02', 'Route U2 – UB to Main Mall', 'UB Gate', 'Main Mall CBD', 'COMBI', 8.00),
('route-u03', 'Route U3 – Botho to Bus Rank', 'Botho University', 'Gaborone Bus Rank', 'COMBI', 8.00),
('route-u04', 'Route U4 – Game City to Bus Rank', 'Game City', 'Gaborone Bus Rank', 'COMBI', 8.00),
('route-u05', 'Route U5 – Mogoditshane to Bus Rank', 'Mogoditshane Rank', 'Gaborone Bus Rank', 'COMBI', 8.00),
('route-u06', 'Route U6 – Tlokweng to Main Mall', 'Tlokweng Border', 'Main Mall', 'COMBI', 8.00)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    origin_name = EXCLUDED.origin_name,
    destination_name = EXCLUDED.destination_name,
    route_type = EXCLUDED.route_type,
    base_fare = EXCLUDED.base_fare;

INSERT INTO public.stops (id, name, latitude, longitude, description) VALUES
('stop-mol-1', 'Molepolole Central Bus Rank', -24.4069, 25.4951, 'Main transport interchange in Molepolole'),
('stop-mol-2', 'Mafitlhakgosi Stop', -24.4150, 25.5100, 'Mafitlhakgosi ward combi stop'),
('stop-mol-3', 'Borakalalo Station', -24.3980, 25.4850, 'Borakalalo junction'),
('stop-mol-4', 'Kweneng Rural Development', -24.4020, 25.5010, 'KRDA area stop'),
('stop-u01-1', 'BAC Stop', -24.6549, 25.9082, 'Botswana Accountancy College entrance'),
('stop-u01-2', 'Gaborone Bus Rank', -24.6546, 25.9145, 'Central transport hub'),
('stop-u02-1', 'UB Gate Stop', -24.6590, 25.9325, 'University of Botswana main gate'),
('stop-u02-2', 'Main Mall Station', -24.6543, 25.9189, 'Central Business Area'),
('stop-u03-1', 'Botho University Stop', -24.6407, 25.9295, 'Botho Park entrance'),
('stop-u04-1', 'Game City Mall Stop', -24.6832, 25.8952, 'Game City Mall rank'),
('stop-mogo-1', 'Mogoditshane Junction Stop', -24.6300, 25.8600, 'Mogoditshane main road'),
('stop-tlok-1', 'Tlokweng Main Stop', -24.6738, 26.0354, 'Tlokweng border corridor'),
('stop-francistown', 'Francistown Central Terminal', -21.1661, 27.5144, 'Francistown main terminal'),
('stop-lobatse', 'Lobatse Bus Rank', -25.2167, 25.6667, 'Lobatse town rank')
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    description = EXCLUDED.description;
