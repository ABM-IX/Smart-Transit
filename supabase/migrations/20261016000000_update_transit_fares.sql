-- Apply the current public fare defaults and update active route records.
ALTER TABLE public.routes ALTER COLUMN base_fare DROP DEFAULT;
ALTER TABLE public.trips ALTER COLUMN fare SET DEFAULT 9.00;
ALTER TABLE public.hails ALTER COLUMN fare_estimate SET DEFAULT 9.00;

UPDATE public.routes
SET base_fare = 9.00
WHERE UPPER(route_type) = 'COMBI'
  AND (
      (lower(origin_name) LIKE '%gopong%' AND lower(destination_name) LIKE '%hab%')
      OR (lower(origin_name) LIKE '%hab%' AND lower(destination_name) LIKE '%gopong%')
      OR (lower(name) LIKE '%gopong%' AND lower(name) LIKE '%hab%')
  );

UPDATE public.routes
SET base_fare = 10.00
WHERE id = 'taxi-dispatch' AND UPPER(route_type) = 'TAXI';

-- The auth trigger can create the taxi route on first driver signup.
DO $$
DECLARE
    trigger_function TEXT;
BEGIN
    SELECT pg_get_functiondef('public.handle_new_user()'::regprocedure)
    INTO trigger_function;
    trigger_function := replace(trigger_function, '''TAXI'', 15.00', '''TAXI'', 10.00');
    EXECUTE trigger_function;
END;
$$;

UPDATE public.hails
SET fare_estimate = CASE UPPER(service_type)
    WHEN 'COMBI' THEN 9.00
    WHEN 'TAXI' THEN 10.00
    WHEN 'STANDARD' THEN 10.00
    WHEN 'SPECIAL' THEN GREATEST(fare_estimate, 10.00)
    ELSE fare_estimate
END
WHERE status = 'WAITING'
  AND UPPER(service_type) IN ('COMBI', 'TAXI', 'STANDARD', 'SPECIAL');
