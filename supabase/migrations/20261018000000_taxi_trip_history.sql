-- Keep the deployed trips table compatible with the app's idempotent trip writes.
ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS request_id TEXT,
    ADD COLUMN IF NOT EXISTS passenger_count INTEGER NOT NULL DEFAULT 1;

-- A request can produce only one completed trip row. PostgreSQL permits multiple
-- NULL values, so existing non-request trip records remain valid.
CREATE UNIQUE INDEX IF NOT EXISTS idx_trips_request_id_unique
    ON public.trips (request_id);
