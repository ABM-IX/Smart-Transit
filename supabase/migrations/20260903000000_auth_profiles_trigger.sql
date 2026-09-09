-- SmartTransit AI Platform - Supabase Auth Profiles Trigger & RLS Policies
-- Migration: 20260903000000_auth_profiles_trigger.sql
-- Integrates Supabase Free Tier Auth with public.users profile table

-- 1. Function to handle new auth user creation and metadata synchronization
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role TEXT;
    v_service_type TEXT;
BEGIN
    v_role := COALESCE(UPPER(NEW.raw_user_meta_data->>'role'), 'PASSENGER');
    v_service_type := COALESCE(UPPER(NEW.raw_user_meta_data->>'service_type'), 'PASSENGER');

    INSERT INTO public.users (
        id,
        email,
        full_name,
        phone_number,
        role,
        service_type,
        vehicle_plate,
        assigned_route_id,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id::text,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Commuter'),
        COALESCE(NEW.raw_user_meta_data->>'phone_number', ''),
        v_role,
        v_service_type,
        NEW.raw_user_meta_data->>'vehicle_plate',
        NEW.raw_user_meta_data->>'assigned_route_id',
        true,
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = CASE 
            WHEN EXCLUDED.full_name IS NOT NULL AND EXCLUDED.full_name != '' THEN EXCLUDED.full_name 
            ELSE public.users.full_name 
        END,
        phone_number = CASE 
            WHEN EXCLUDED.phone_number IS NOT NULL AND EXCLUDED.phone_number != '' THEN EXCLUDED.phone_number 
            ELSE public.users.phone_number 
        END,
        role = CASE 
            WHEN EXCLUDED.role IS NOT NULL THEN EXCLUDED.role 
            ELSE public.users.role 
        END,
        service_type = CASE 
            WHEN EXCLUDED.service_type IS NOT NULL THEN EXCLUDED.service_type 
            ELSE public.users.service_type 
        END,
        vehicle_plate = CASE 
            WHEN EXCLUDED.vehicle_plate IS NOT NULL THEN EXCLUDED.vehicle_plate 
            ELSE public.users.vehicle_plate 
        END,
        assigned_route_id = CASE 
            WHEN EXCLUDED.assigned_route_id IS NOT NULL THEN EXCLUDED.assigned_route_id 
            ELSE public.users.assigned_route_id 
        END,
        updated_at = timezone('utc'::text, now());

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger on auth.users for new signups or profile updates
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Row-Level Security Policies for Users Profile
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Allow public and authenticated read so drivers and passengers can see names/plates/ratings
DROP POLICY IF EXISTS "Allow public read access for users" ON public.users;
CREATE POLICY "Allow public read access for users" ON public.users 
    FOR SELECT USING (true);

-- Allow authenticated users to update their own profile
DROP POLICY IF EXISTS "Allow users to update their own profile" ON public.users;
CREATE POLICY "Allow users to update their own profile" ON public.users 
    FOR UPDATE USING (auth.uid()::text = id);

-- Allow authenticated users or service to insert their own profile
DROP POLICY IF EXISTS "Allow users to insert their own profile" ON public.users;
CREATE POLICY "Allow users to insert their own profile" ON public.users 
    FOR INSERT WITH CHECK (auth.uid()::text = id OR auth.uid() IS NULL);

-- 4. Row-Level Security Policies for Trips
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

-- Allow users to select trips where they are passenger or driver, or anon for live demo
DROP POLICY IF EXISTS "Allow users to select own trips" ON public.trips;
CREATE POLICY "Allow users to select own trips" ON public.trips
    FOR SELECT USING (
        auth.uid()::text = passenger_id 
        OR auth.uid()::text = driver_id 
        OR auth.uid() IS NULL
    );

DROP POLICY IF EXISTS "Allow authenticated to insert trips" ON public.trips;
CREATE POLICY "Allow authenticated to insert trips" ON public.trips
    FOR INSERT WITH CHECK (
        auth.uid()::text = passenger_id 
        OR auth.uid() IS NULL
    );

DROP POLICY IF EXISTS "Allow drivers to update assigned trips" ON public.trips;
CREATE POLICY "Allow drivers to update assigned trips" ON public.trips
    FOR UPDATE USING (
        auth.uid()::text = driver_id 
        OR auth.uid()::text = passenger_id 
        OR auth.uid() IS NULL
    );

-- 5. Active Routes View (Corridors with registered/online drivers)
CREATE OR REPLACE VIEW public.active_transit_routes AS
SELECT DISTINCT r.*
FROM public.routes r
WHERE EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.assigned_route_id = r.id 
    AND u.role = 'DRIVER' 
    AND u.is_active = true
)
OR EXISTS (
    SELECT 1 FROM public.driver_locations dl
    WHERE dl.route_id = r.id
    AND dl.is_online = true
);

-- Grant view access
GRANT SELECT ON public.active_transit_routes TO anon, authenticated;
