-- Persist the live location and lifecycle of bus/combi passenger hails.
ALTER TABLE public.hails
    ADD COLUMN IF NOT EXISTS request_id TEXT,
    ADD COLUMN IF NOT EXISTS driver_id TEXT,
    ADD COLUMN IF NOT EXISTS passenger_lat DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS passenger_lng DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS passenger_accuracy DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS passenger_speed DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS passenger_heading DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS boarded_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS idx_hails_request_id
    ON public.hails (request_id)
    WHERE request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_hails_route_status
    ON public.hails (route_id, status);

ALTER TABLE public.hails ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access for hails" ON public.hails;
DROP POLICY IF EXISTS "Allow insert/update for hails" ON public.hails;
DROP POLICY IF EXISTS "Passengers read their own hails" ON public.hails;
DROP POLICY IF EXISTS "Passengers create their own hails" ON public.hails;
DROP POLICY IF EXISTS "Passengers update their own hails" ON public.hails;

CREATE POLICY "Passengers read their own hails" ON public.hails
    FOR SELECT TO authenticated
    USING (passenger_id = auth.uid()::text);
CREATE POLICY "Passengers create their own hails" ON public.hails
    FOR INSERT TO authenticated
    WITH CHECK (passenger_id = auth.uid()::text);
CREATE POLICY "Passengers update their own hails" ON public.hails
    FOR UPDATE TO authenticated
    USING (passenger_id = auth.uid()::text)
    WITH CHECK (passenger_id = auth.uid()::text);
DROP POLICY IF EXISTS "Drivers update assigned hail lifecycle" ON public.hails;
CREATE POLICY "Drivers update assigned hail lifecycle" ON public.hails
    FOR UPDATE TO authenticated
    USING (driver_id = auth.uid()::text)
    WITH CHECK (driver_id = auth.uid()::text);

GRANT SELECT, INSERT, UPDATE ON public.hails TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.hails TO service_role;
