-- ====================================================================
-- SmartTransit AI Platform - Supabase PostgreSQL Production Schema
-- Aligned 1-to-1 with System Architecture Defense & Database ERD Specification
-- Reference: docs/system_architecture_defense_and_database_specification.md
-- ====================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Users Table (Core Platform Identity)
CREATE TABLE IF NOT EXISTS public.users (
    id VARCHAR(64) PRIMARY KEY,
    full_name VARCHAR(128) NOT NULL,
    phone_number VARCHAR(32) UNIQUE,
    email VARCHAR(128) UNIQUE,
    role VARCHAR(20) NOT NULL DEFAULT 'PASSENGER', -- PASSENGER, DRIVER, ADMIN
    avatar_url TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now());

-- 3. Vehicles Registry Table
CREATE TABLE IF NOT EXISTS public.vehicles (
    id VARCHAR(64) PRIMARY KEY,
    license_plate VARCHAR(20) UNIQUE NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL DEFAULT 'COMBI', -- COMBI (15 seats), TAXI (4 seats), BUS (65 seats)
    capacity INTEGER NOT NULL DEFAULT 15,
    model VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. Transit Corridors / Routes Table
CREATE TABLE IF NOT EXISTS public.routes (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    origin_name VARCHAR(64) NOT NULL,
    destination_name VARCHAR(64) NOT NULL,
    route_type VARCHAR(20) NOT NULL DEFAULT 'COMBI', -- COMBI, TAXI, BUS
    base_fare NUMERIC(10, 2) NOT NULL,
    waypoints JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 5. Transit Stops Table
CREATE TABLE IF NOT EXISTS public.stops (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    description VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 6. Route Stops Junction Table (Sequential Topology & Distances)
CREATE TABLE IF NOT EXISTS public.route_stops (
    id SERIAL PRIMARY KEY,
    route_id VARCHAR(64) NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
    stop_id VARCHAR(64) NOT NULL REFERENCES public.stops(id) ON DELETE CASCADE,
    stop_sequence INTEGER NOT NULL DEFAULT 1,
    distance_from_start_meters FLOAT NOT NULL DEFAULT 0.0,
    UNIQUE(route_id, stop_id)
);

-- 7. Driver Profiles Table (Operational State & Real-time Metadata)
CREATE TABLE IF NOT EXISTS public.driver_profiles (
    driver_id VARCHAR(64) PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    vehicle_id VARCHAR(64) REFERENCES public.vehicles(id) ON DELETE SET NULL,
    assigned_route_id VARCHAR(64) REFERENCES public.routes(id) ON DELETE SET NULL,
    service_type VARCHAR(20) NOT NULL DEFAULT 'COMBI', -- COMBI, TAXI, BUS
    is_online BOOLEAN NOT NULL DEFAULT false,
    rating_avg FLOAT NOT NULL DEFAULT 5.00,
    rating_count INTEGER NOT NULL DEFAULT 0,
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 8. Trips Table (Completed Journey Records & Analytics)
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id TEXT,
    passenger_id TEXT NOT NULL,
    driver_id VARCHAR(64) NOT NULL REFERENCES public.users(id),
    route_id VARCHAR(64) REFERENCES public.routes(id) ON DELETE SET NULL,
    vehicle_id VARCHAR(64) REFERENCES public.vehicles(id) ON DELETE SET NULL,
    service_type VARCHAR(20) NOT NULL DEFAULT 'COMBI', -- COMBI, TAXI, BUS
    passenger_count INTEGER NOT NULL DEFAULT 1,
    fare NUMERIC(10, 2) NOT NULL DEFAULT 9.00,
    pickup_name TEXT,
    dropoff_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ,
    revenue NUMERIC(10, 2) NOT NULL DEFAULT 9.00,
    distance_meters FLOAT NOT NULL DEFAULT 0.0,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    start_lat DOUBLE PRECISION,
    start_lng DOUBLE PRECISION,
    end_lat DOUBLE PRECISION,
    end_lng DOUBLE PRECISION,
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED', -- IN_PROGRESS, COMPLETED, CANCELLED
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    ended_at TIMESTAMPTZ
);

-- Keep databases created from an earlier version of this schema compatible.
ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS request_id TEXT,
    ADD COLUMN IF NOT EXISTS passenger_count INTEGER NOT NULL DEFAULT 1;
CREATE UNIQUE INDEX IF NOT EXISTS idx_trips_request_id_unique
    ON public.trips (request_id);

-- 9. Taxi Bookings Table (Real-Time State Machine for Cabs)
CREATE TABLE IF NOT EXISTS public.taxi_bookings (
    id VARCHAR(64) PRIMARY KEY,
    passenger_id VARCHAR(64) NOT NULL REFERENCES public.users(id),
    driver_id VARCHAR(64) REFERENCES public.users(id) ON DELETE SET NULL,
    pickup_lat DOUBLE PRECISION NOT NULL,
    pickup_lng DOUBLE PRECISION NOT NULL,
    dropoff_lat DOUBLE PRECISION,
    dropoff_lng DOUBLE PRECISION,
    service_type VARCHAR(20) NOT NULL DEFAULT 'STANDARD', -- STANDARD, SPECIAL
    estimated_fare NUMERIC(10, 2) NOT NULL DEFAULT 10.00,
    final_fare NUMERIC(10, 2),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, ACCEPTED, ON_TRIP, COMPLETED, CANCELLED
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ
);

-- Keep the existing SmartTransit identity and booking tables while adding the
-- destination and bidding fields needed by direct taxi dispatch.
ALTER TABLE public.taxi_bookings
    ADD COLUMN IF NOT EXISTS pickup_address TEXT,
    ADD COLUMN IF NOT EXISTS dropoff_address TEXT,
    ADD COLUMN IF NOT EXISTS distance_km NUMERIC(7, 2),
    ADD COLUMN IF NOT EXISTS duration_minutes INTEGER,
    ADD COLUMN IF NOT EXISTS offered_fare NUMERIC(10, 2),
    ADD COLUMN IF NOT EXISTS surge_multiplier NUMERIC(4, 2) NOT NULL DEFAULT 1.0,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now());

CREATE TABLE IF NOT EXISTS public.taxi_booking_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id VARCHAR(64) NOT NULL REFERENCES public.taxi_bookings(id) ON DELETE CASCADE,
    driver_id VARCHAR(64) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    counter_price NUMERIC(10, 2) NOT NULL CHECK (counter_price >= 12),
    eta_minutes INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_taxi_booking_offers_booking ON public.taxi_booking_offers(booking_id, created_at);
ALTER TABLE public.taxi_booking_offers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access for taxi booking offers" ON public.taxi_booking_offers FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for taxi booking offers" ON public.taxi_booking_offers FOR ALL USING (true);

-- Nearby taxi count uses the live coordinates already maintained by drivers.
CREATE OR REPLACE FUNCTION public.get_nearby_active_taxis(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters DOUBLE PRECISION DEFAULT 4000
) RETURNS TABLE(driver_id VARCHAR, distance_meters DOUBLE PRECISION)
LANGUAGE sql STABLE AS $$
    SELECT dp.driver_id,
        6371000 * 2 * asin(sqrt(
          power(sin(radians(dp.current_lat - user_lat) / 2), 2) +
          cos(radians(user_lat)) * cos(radians(dp.current_lat)) *
          power(sin(radians(dp.current_lng - user_lng) / 2), 2)
        )) AS distance_meters
    FROM public.driver_profiles dp
    WHERE dp.service_type = 'TAXI' AND dp.is_online = true
      AND dp.current_lat IS NOT NULL AND dp.current_lng IS NOT NULL
      AND dp.updated_at > timezone('utc'::text, now()) - INTERVAL '30 seconds'
      AND 6371000 * 2 * asin(sqrt(
          power(sin(radians(dp.current_lat - user_lat) / 2), 2) +
          cos(radians(user_lat)) * cos(radians(dp.current_lat)) *
          power(sin(radians(dp.current_lng - user_lng) / 2), 2)
      )) <= radius_meters
    ORDER BY distance_meters;
$$;

-- 10. Reviews Table (Post-Trip Commuter Feedback)
CREATE TABLE IF NOT EXISTS public.reviews (
    id SERIAL PRIMARY KEY,
    trip_id VARCHAR(64) REFERENCES public.trips(id) ON DELETE SET NULL,
    driver_id VARCHAR(64) NOT NULL REFERENCES public.users(id),
    passenger_id VARCHAR(64) NOT NULL REFERENCES public.users(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for Fast Geospatial & Telemetry Lookups
CREATE INDEX IF NOT EXISTS idx_driver_profiles_coords ON public.driver_profiles(current_lat, current_lng);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_route ON public.driver_profiles(assigned_route_id);
CREATE INDEX IF NOT EXISTS idx_taxi_bookings_passenger ON public.taxi_bookings(passenger_id);
CREATE INDEX IF NOT EXISTS idx_taxi_bookings_driver ON public.taxi_bookings(driver_id);
CREATE INDEX IF NOT EXISTS idx_taxi_bookings_status ON public.taxi_bookings(status);
CREATE INDEX IF NOT EXISTS idx_trips_driver ON public.trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_route ON public.trips(route_id);
CREATE INDEX IF NOT EXISTS idx_route_stops_route ON public.route_stops(route_id);

-- Row Level Security (RLS) Configuration
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.taxi_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Allow Public/Service Access Policies
CREATE POLICY "Allow public read access for users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for users" ON public.users FOR ALL USING (true);

CREATE POLICY "Allow public read access for vehicles" ON public.vehicles FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for vehicles" ON public.vehicles FOR ALL USING (true);

CREATE POLICY "Allow public read access for routes" ON public.routes FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for routes" ON public.routes FOR ALL USING (true);

CREATE POLICY "Allow public read access for stops" ON public.stops FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for stops" ON public.stops FOR ALL USING (true);

CREATE POLICY "Allow public read access for route_stops" ON public.route_stops FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for route_stops" ON public.route_stops FOR ALL USING (true);

CREATE POLICY "Allow public read access for driver_profiles" ON public.driver_profiles FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for driver_profiles" ON public.driver_profiles FOR ALL USING (true);

CREATE POLICY "Allow public read access for trips" ON public.trips FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for trips" ON public.trips FOR ALL USING (true);

CREATE POLICY "Allow public read access for taxi_bookings" ON public.taxi_bookings FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for taxi_bookings" ON public.taxi_bookings FOR ALL USING (true);

CREATE POLICY "Allow public read access for reviews" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Allow insert/update for reviews" ON public.reviews FOR ALL USING (true);

-- Public profile photos; uploads are restricted to the signed-in user's folder.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profile-photos', 'profile-photos', true, 5242880, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Profile photos are publicly readable" ON storage.objects;
CREATE POLICY "Profile photos are publicly readable"
    ON storage.objects FOR SELECT USING (bucket_id = 'profile-photos');
DROP POLICY IF EXISTS "Users upload their own profile photos" ON storage.objects;
CREATE POLICY "Users upload their own profile photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "Users update their own profile photos" ON storage.objects;
CREATE POLICY "Users update their own profile photos"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = auth.uid()::text)
    WITH CHECK (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "Users delete their own profile photos" ON storage.objects;
CREATE POLICY "Users delete their own profile photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Default Metropolitan Taxi Dispatch corridor
INSERT INTO public.routes (id, name, origin_name, destination_name, route_type, base_fare)
VALUES ('taxi-dispatch', 'Metropolitan Taxi Dispatch', 'Gaborone Metro', 'On-Demand Dispatch', 'TAXI', 10.00)
ON CONFLICT (id) DO NOTHING;
