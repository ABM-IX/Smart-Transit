-- SmartTransit AI Platform - Seed Data
-- Botswana Public Transport Network (Molepolole, Gaborone & Intercity Corridors)

-- 1. Insert Routes
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

-- 2. Insert Stops
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

-- 3. Route-Stop Sequences
INSERT INTO public.route_stops (route_id, stop_id, sequence_order) VALUES
('route-m01', 'stop-mol-1', 1),
('route-m01', 'stop-mol-2', 2),
('route-m02', 'stop-mol-1', 1),
('route-m02', 'stop-mol-3', 2),
('route-u01', 'stop-u01-1', 1),
('route-u01', 'stop-u01-2', 2),
('route-u02', 'stop-u02-1', 1),
('route-u02', 'stop-u02-2', 2),
('route-u03', 'stop-u03-1', 1),
('route-u03', 'stop-u01-2', 2),
('route-u04', 'stop-u04-1', 1),
('route-u04', 'stop-u01-2', 2),
('route-u05', 'stop-mogo-1', 1),
('route-u05', 'stop-u01-2', 2),
('route-u06', 'stop-tlok-1', 1),
('route-u06', 'stop-u02-2', 2),
('bus-molepolole', 'stop-u01-2', 1),
('bus-molepolole', 'stop-mol-1', 2),
('bus-francistown', 'stop-u01-2', 1),
('bus-francistown', 'stop-francistown', 2),
('bus-lobatse', 'stop-u01-2', 1),
('bus-lobatse', 'stop-lobatse', 2)
ON CONFLICT (route_id, stop_id) DO NOTHING;
