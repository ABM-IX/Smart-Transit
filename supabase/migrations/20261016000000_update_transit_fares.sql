-- Apply the current public fare defaults and update active route records.
ALTER TABLE public.routes ALTER COLUMN base_fare SET DEFAULT 9.00;
ALTER TABLE public.trips ALTER COLUMN fare SET DEFAULT 9.00;
ALTER TABLE public.hails ALTER COLUMN fare_estimate SET DEFAULT 9.00;

UPDATE public.routes
SET base_fare = CASE UPPER(route_type)
    WHEN 'COMBI' THEN 9.00
    WHEN 'TAXI' THEN 10.00
    ELSE base_fare
END
WHERE UPPER(route_type) IN ('COMBI', 'TAXI');

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
