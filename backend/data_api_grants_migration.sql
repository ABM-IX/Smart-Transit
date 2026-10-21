-- Run once in the Supabase SQL Editor for the currently deployed project.
-- Keep the matching table grants in schema_supabase.sql beside each CREATE TABLE
-- so fresh projects and `supabase db reset` receive the same API privileges.

GRANT SELECT ON TABLE public.users TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.users TO authenticated, service_role;

GRANT SELECT ON TABLE public.vehicles TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehicles TO authenticated, service_role;

GRANT SELECT ON TABLE public.routes TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.routes TO authenticated, service_role;

GRANT SELECT ON TABLE public.stops TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stops TO authenticated, service_role;

GRANT SELECT ON TABLE public.route_stops TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.route_stops TO authenticated, service_role;
GRANT USAGE, SELECT ON SEQUENCE public.route_stops_id_seq TO authenticated, service_role;

GRANT SELECT ON TABLE public.driver_profiles TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.driver_profiles TO authenticated, service_role;

GRANT SELECT ON TABLE public.trips TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.trips TO authenticated, service_role;

GRANT SELECT ON TABLE public.taxi_bookings TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.taxi_bookings TO authenticated, service_role;

GRANT SELECT ON TABLE public.taxi_booking_offers TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.taxi_booking_offers TO authenticated, service_role;

GRANT SELECT ON TABLE public.reviews TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.reviews TO authenticated, service_role;
GRANT USAGE, SELECT ON SEQUENCE public.reviews_id_seq TO authenticated, service_role;

-- Default privileges apply to future tables/sequences created by the role
-- executing this migration (normally `postgres` in Supabase).
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO authenticated, service_role;
