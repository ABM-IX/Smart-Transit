-- Keep a single completed history row when both the passenger and driver
-- confirm the same ride, and retain passenger totals for driver reports.
ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS request_id TEXT;

ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS passenger_count INTEGER NOT NULL DEFAULT 1;

CREATE UNIQUE INDEX IF NOT EXISTS trips_request_id_unique
    ON public.trips (request_id);

DROP POLICY IF EXISTS "Allow authenticated to insert trips" ON public.trips;
CREATE POLICY "Allow passengers or drivers to insert trips" ON public.trips
    FOR INSERT WITH CHECK (
        auth.uid()::text = passenger_id
        OR auth.uid()::text = driver_id
        OR auth.uid() IS NULL
    );
