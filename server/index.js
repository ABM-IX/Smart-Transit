require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const admin = require('firebase-admin');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    },
    allowEIO3: true,
    // Tunnels / mobile networks can pause background traffic; be more tolerant.
    pingTimeout: 60000,
    pingInterval: 25000,
    // Force polling for stability via localtunnel
    transports: ['polling']
});

app.use(cors());
app.use(express.json());

// Serve the admin dashboard from the same origin to avoid tunnel/browser header limits.
app.use('/', express.static(path.join(__dirname, '..', 'dashboard')));

// Firebase Initialization
const serviceAccount = require("./smarttransit-5453c-firebase-adminsdk-fbsvc-324f41bc8a.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();
const PORT = process.env.PORT || 3000;
const DEBUG_SOCKETS = process.env.SOCKET_DEBUG === '1';

function getRoomCounts() {
  const rooms = {};
  for (const [name, room] of io.sockets.adapter.rooms) {
    // Skip private rooms that are just socket IDs
    if (io.sockets.sockets.get(name)) continue;
    rooms[name] = room.size;
  }
  return rooms;
}

// ==========================================
// 1. STATE & CACHE (Redis Substitute)
// ==========================================
const activeDrivers = new Map();
const activePassengers = new Map();
const activeTrips = new Map(); // tripId -> trip data
const taxiAssignments = new Map(); // passengerId -> { driverId, startedAt }
const activeHails = new Map(); // passengerId -> hail data
const activeTaxiRequests = new Map(); // requestId -> request data
const driverRatings = new Map(); // driverId -> { total, count, avg }
const activeBoardings = new Map(); // passengerId -> { driverId, routeId, since }
const proximityTracker = new Map(); // key => { lastCloseAt }
const complaints = []; // { driverId, passengerId, message, at }
let systemActive = true; 

const TAXI_STANDARD_FARE = 8;
const TAXI_SPECIAL_BASE = 10;
const TAXI_SPECIAL_PER_KM = 2.5;
const TAXI_SPECIAL_PER_MIN = 0.5;
const TAXI_AVG_SPEED_KMH = 30;
const BUS_COMBI_FARE = 8;
const HAIL_MAX_DISTANCE_METERS = 60;
const HAIL_TTL_MS = 5 * 60 * 1000;
const BOARDING_DISTANCE_METERS = 20;
const BOARDING_CONFIRM_WINDOW_MS = 12 * 1000;

function estimateSpecialFare(pickup, destination) {
  if (!pickup || !destination) return TAXI_SPECIAL_BASE;
  const distanceMeters = getDistance(pickup, destination);
  const distanceKm = distanceMeters / 1000;
  const durationMin = (distanceKm / TAXI_AVG_SPEED_KMH) * 60;
  const fare = TAXI_SPECIAL_BASE + (distanceKm * TAXI_SPECIAL_PER_KM) + (durationMin * TAXI_SPECIAL_PER_MIN);
  return Math.max(TAXI_SPECIAL_BASE, Math.round(fare));
}

function updateDriverRating(driverId, rating) {
  if (!driverId || !rating) return;
  const current = driverRatings.get(driverId) || { total: 0, count: 0, avg: 0 };
  current.total += rating;
  current.count += 1;
  current.avg = Number((current.total / current.count).toFixed(2));
  driverRatings.set(driverId, current);
  return current;
}

function findNearestStop(routeId, coords) {
  if (!routeId || !coords) return null;
  const stopsForRoute = MOCK_STOPS.filter(s => s.route_id === routeId);
  if (!stopsForRoute.length) return null;
  let nearest = null;
  for (const s of stopsForRoute) {
    const dist = getDistance(coords, { lat: s.latitude, lng: s.longitude });
    if (!nearest || dist < nearest.distanceMeters) {
      nearest = { ...s, distanceMeters: dist };
    }
  }
  return nearest;
}

function getNearestTaxiDrivers(coords, limit = 3) {
  const drivers = Array.from(activeDrivers.values())
    .filter(d => d.serviceType === 'TAXI' && d.status === "ONLINE" && d.coords);
  return drivers
    .map(d => ({ ...d, distanceMeters: getDistance(coords, d.coords) }))
    .sort((a, b) => a.distanceMeters - b.distanceMeters)
    .slice(0, limit);
}

// Mock Data for Route Engine
// BUS: Intercity routes (all from Gaborone Bus Rank)
// COMBI: Urban / local routes
const MOCK_ROUTES = [
  // Intercity BUS routes
  { route_id: "bus-francistown", route_name: "Gaborone → Francistown", start: "Gaborone Bus Rank", end: "Francistown", route_type: "BUS" },
  { route_id: "bus-lobatse", route_name: "Gaborone → Lobatse", start: "Gaborone Bus Rank", end: "Lobatse", route_type: "BUS" },
  { route_id: "bus-molepolole", route_name: "Gaborone → Molepolole", start: "Gaborone Bus Rank", end: "Molepolole", route_type: "BUS" },
  { route_id: "bus-mahalapye", route_name: "Gaborone → Mahalapye", start: "Gaborone Bus Rank", end: "Mahalapye", route_type: "BUS" },
  { route_id: "bus-palapye", route_name: "Gaborone → Palapye", start: "Gaborone Bus Rank", end: "Palapye", route_type: "BUS" },
  { route_id: "bus-kanye", route_name: "Gaborone → Kanye", start: "Gaborone Bus Rank", end: "Kanye", route_type: "BUS" },
  { route_id: "bus-maun", route_name: "Gaborone → Maun", start: "Gaborone Bus Rank", end: "Maun", route_type: "BUS" },
  { route_id: "bus-kopong", route_name: "Gaborone → Kopong", start: "Gaborone Bus Rank", end: "Kopong", route_type: "BUS" },

  // Local COMBI routes
  { route_id: "route-u01", route_name: "Route U1 – BAC to Bus Rank", start: "BAC", end: "Bus Rank", route_type: "COMBI" },
  { route_id: "route-u02", route_name: "Route U2 – UB to Main Mall", start: "UB", end: "Main Mall", route_type: "COMBI" },
  { route_id: "route-u03", route_name: "Route U3 – Botho to Bus Rank", start: "Botho University", end: "Bus Rank", route_type: "COMBI" },
  { route_id: "route-u04", route_name: "Route U4 – Gamecity to Bus Rank", start: "Gamecity", end: "Bus Rank", route_type: "COMBI" }
];
const MOCK_STOPS = [
  { stop_id: "stop-4-1", route_id: "route-004", name: "Tlokweng Border Post", latitude: -24.6738, longitude: 26.0354 },
  { stop_id: "stop-4-2", route_id: "route-004", name: "UB Gate", latitude: -24.6590, longitude: 25.9325 },
  { stop_id: "stop-4-3", route_id: "route-004", name: "Main Mall", latitude: -24.6543, longitude: 25.9189 }
  ,
  { stop_id: "stop-u01-1", route_id: "route-u01", name: "BAC Stop", latitude: -24.6549, longitude: 25.9082 },
  { stop_id: "stop-u01-2", route_id: "route-u01", name: "Bus Rank", latitude: -24.6546, longitude: 25.9145 },
  { stop_id: "stop-u02-1", route_id: "route-u02", name: "UB Stop", latitude: -24.6590, longitude: 25.9325 },
  { stop_id: "stop-u02-2", route_id: "route-u02", name: "Main Mall", latitude: -24.6543, longitude: 25.9189 },
  { stop_id: "stop-u03-1", route_id: "route-u03", name: "Botho University", latitude: -24.6407, longitude: 25.9295 },
  { stop_id: "stop-u03-2", route_id: "route-u03", name: "Bus Rank", latitude: -24.6546, longitude: 25.9145 },
  { stop_id: "stop-u04-1", route_id: "route-u04", name: "Gamecity", latitude: -24.6832, longitude: 25.8952 },
  { stop_id: "stop-u04-2", route_id: "route-u04", name: "Bus Rank", latitude: -24.6546, longitude: 25.9145 },
  { stop_id: "stop-bus-1", route_id: "bus-francistown", name: "Gaborone Bus Rank", latitude: -24.6546, longitude: 25.9145 },
  { stop_id: "stop-bus-2", route_id: "bus-lobatse", name: "Gaborone Bus Rank", latitude: -24.6546, longitude: 25.9145 }
];

// ==========================================
// SOCKET COMMUNICATIONS GATEWAY
// ==========================================
io.on('connection', (socket) => {
    const deviceId = socket.handshake.query.deviceId || 'unknown';
    console.log(`[CONNECTED] ID: ${socket.id} | Device: ${deviceId} | Total: ${io.engine.clientsCount}`);

    socket.on('error', (err) => console.error(`[SOCKET ERROR] ID: ${socket.id}:`, err));

    socket.on('join', async (data) => {
        const payload = typeof data === 'string' ? { role: data } : (data || {});
        const role = payload.role;
        const routeId = payload.routeId || "default";
        
        if (role) {
            socket.join(role);
            socket.join(`${role}-${routeId}`);

            if (DEBUG_SOCKETS) {
                console.log(`[JOIN] ${socket.id} -> role=${role} route=${routeId}`);
            }
            
            if (role === 'dashboard') {
                socket.emit('system-status', { active: systemActive });
            }

            // Track passengers as soon as they join so hail / boarding
            // responses can be routed back correctly.
            if (role === 'passengers' && payload.passengerId) {
                const passengerId = payload.passengerId;
                activePassengers.set(passengerId, { 
                    passengerId, 
                    routeId, 
                    coords: payload.coords || null,
                    lastUpdate: Date.now(), 
                    socketId: socket.id 
                });
            }
        }
    });

    // ----------------------------------------------------
    // ENGINE 1: TRACKING ENGINE (Location Streaming)
    // ----------------------------------------------------
    socket.on('driver-online', async (data) => {
        const { driverId, routeId = "default-route", vehicleId } = data;
        if (!driverId) return;

        // Derive service type from driverType when not explicitly provided
        const rawType = (data.serviceType || data.driverType || "").toString().toUpperCase();
        const serviceType = rawType.includes("TAXI") ? "TAXI" : "COMBI";

        activeDrivers.set(driverId, { 
            driverId, routeId, vehicleId, serviceType, status: "ONLINE", socketId: socket.id, lastUpdate: Date.now() 
        });
        io.to('dashboard').emit('fleet-update', { type: 'driver', ...activeDrivers.get(driverId) });
        syncDriverToDb(driverId, { status: "ONLINE", route_id: routeId, service_type: serviceType, vehicle_id: vehicleId });
    });

    socket.on('driver-offline', async (data) => {
        const { driverId } = data;
        if (!driverId) return;
        const driver = activeDrivers.get(driverId);
        if (driver) {
            driver.status = "OFFLINE";
            io.to('dashboard').emit('fleet-update', { type: 'driver', ...driver });
        }
        syncDriverToDb(driverId, { status: "OFFLINE" });
    });

    socket.on('driver-location', (data) => {
        if (!systemActive) return; 
        const { driverId, routeId: incomingRouteId = "default-route", coords, occupancy, speed = 0, heading = 0 } = data;
        if (!driverId || !coords) return;
        
        const existing = activeDrivers.get(driverId) || {};
        const routeId = existing.routeId || incomingRouteId;
        if (!routeId) return;

        activeDrivers.set(driverId, { ...existing, driverId, routeId, coords, occupancy, speed, heading, lastUpdate: Date.now(), socketId: socket.id });
        
        if (existing.serviceType === 'TAXI') {
            checkTaxiPickup(driverId); // Taxi point-to-point tracking
            // Send live driver location to assigned passenger (if any)
            for (const [passengerId, assignment] of taxiAssignments.entries()) {
                if (assignment.driverId === driverId) {
                    const passenger = activePassengers.get(passengerId);
                    if (passenger) {
                        io.to(passenger.socketId).emit('driver-location', { ...data, routeId: 'taxi-service' });
                    }
                }
            }
        } else {
            // Combi/Bus broadcast
            io.to(`passengers-${routeId}`).emit('vehicle-update', { type: 'driver', ...data });
            calculateETA(routeId, driverId); // Trigger ETA Engine
            calculateSpacingAdvisory(routeId); // Dispatch advisory

            // Auto-boarding detection
            for (const [passengerId, passenger] of activePassengers.entries()) {
                if (passenger.routeId !== routeId || !passenger.coords) continue;
                const dist = getDistance(coords, passenger.coords);
                const key = `${driverId}:${passengerId}`;
                if (dist <= BOARDING_DISTANCE_METERS) {
                    const now = Date.now();
                    const prev = proximityTracker.get(key);
                    if (prev && (now - prev.lastCloseAt) <= BOARDING_CONFIRM_WINDOW_MS) {
                        if (!activeBoardings.has(passengerId)) {
                            activeBoardings.set(passengerId, { driverId, routeId, since: now });
                            io.to('dashboard').emit('boarding', { passengerId, driverId, routeId, auto: true });
                            const driver = activeDrivers.get(driverId);
                            if (driver) io.to(driver.socketId).emit('passenger-boarded', { passengerId, driverId, routeId, auto: true });
                            const passengerSocket = activePassengers.get(passengerId);
                            if (passengerSocket) io.to(passengerSocket.socketId).emit('boarding-confirmed', { passengerId, driverId, routeId, auto: true });
                        }
                    } else {
                        proximityTracker.set(key, { lastCloseAt: now });
                    }
                }
            }
        }
        // Unified event name used by the mobile app screens
        io.to(`passengers-${routeId}`).emit('driver-location', { ...data, routeId });
        io.to('dashboard').emit('fleet-update', { type: 'driver', ...data, routeId });
    });

    socket.on('passenger-location', (data) => {
        const { passengerId, routeId: incomingRouteId = "default-route", coords } = data;
        if (!passengerId || !coords) return;
        const existing = activePassengers.get(passengerId) || {};
        const routeId = existing.routeId || incomingRouteId;
        if (!routeId) return;

        activePassengers.set(passengerId, { passengerId, routeId, coords, lastUpdate: Date.now(), socketId: socket.id });
        // Let drivers on that route see passenger pings (driver UI subscribes to this)
        io.to(`drivers-${routeId}`).emit('passenger-location', { ...data, routeId });
        io.to('dashboard').emit('fleet-update', { type: 'passenger', ...data, routeId });

        // Auto-boarding detection from passenger side (mirror)
        for (const [driverId, driver] of activeDrivers.entries()) {
            if (driver.routeId !== routeId || !driver.coords) continue;
            const dist = getDistance(driver.coords, coords);
            const key = `${driverId}:${passengerId}`;
            if (dist <= BOARDING_DISTANCE_METERS) {
                const now = Date.now();
                const prev = proximityTracker.get(key);
                if (prev && (now - prev.lastCloseAt) <= BOARDING_CONFIRM_WINDOW_MS) {
                    if (!activeBoardings.has(passengerId)) {
                        activeBoardings.set(passengerId, { driverId, routeId, since: now });
                        io.to('dashboard').emit('boarding', { passengerId, driverId, routeId, auto: true });
                        io.to(driver.socketId).emit('passenger-boarded', { passengerId, driverId, routeId, auto: true });
                        io.to(socket.id).emit('boarding-confirmed', { passengerId, driverId, routeId, auto: true });
                    }
                } else {
                    proximityTracker.set(key, { lastCloseAt: now });
                }
            }
        }
    });

    // ----------------------------------------------------
    // ENGINE 2: DISPATCH ENGINE (Matching & Taxies)
    // ----------------------------------------------------
    // Combi / Bus Dispatch
    socket.on('passenger-request-route', (data) => {
        const { passengerId, routeId, coords } = data;
        if (!passengerId || !coords) return;
        const nearest = findNearestVehicle(routeId, coords, "COMBI");
        socket.emit('route-status', { routeId, nearestVehicle: nearest ? { driverId: nearest.driverId, distance: nearest.distanceMeters } : null });
    });

    socket.on('boarding', (data) => {
        const { driverId, passengerId } = data;
        const driver = activeDrivers.get(driverId);
        // Smart Boarding Logic
        if (driver) io.to(driver.socketId).emit('passenger-boarded', data);
        io.to('dashboard').emit('boarding', data);

        // Confirm boarding back to the passenger app so it can
        // transition into "on-board" state.
        const passenger = activePassengers.get(passengerId);
        if (passenger) {
            io.to(passenger.socketId).emit('boarding-confirmed', data);
        }
        if (driver && passenger) {
            activeBoardings.set(passengerId, { driverId, routeId: driver.routeId, since: Date.now() });
        }
    });

    // Taxi Dispatch
    socket.on('passenger-request-taxi', async (data) => {
        const { passengerId, pickup, dropoff, type = 'STANDARD', destination, serviceType } = data;
        const pickupLoc = pickup || data.pickupLoc;
        const destinationLoc = dropoff || destination || data.destinationLoc || null;
        const resolvedType = (serviceType || type || 'STANDARD').toString().toUpperCase();
        if (!passengerId || !pickupLoc) return;

        const requestId = `req-${Math.random().toString(36).slice(2, 10)}`;
        const fareEstimate = resolvedType === 'STANDARD' ? TAXI_STANDARD_FARE : estimateSpecialFare(pickupLoc, destinationLoc);
        const request = {
            requestId,
            passengerId,
            pickupLoc,
            destinationLoc,
            serviceType: resolvedType,
            fareEstimate,
            requestedAt: Date.now()
        };
        activeTaxiRequests.set(requestId, request);

        const nearbyDrivers = getNearestTaxiDrivers(pickupLoc, 3);
        if (nearbyDrivers.length) {
            // broadcast to the closest drivers first
            nearbyDrivers.forEach(d => io.to(d.socketId).emit('new-taxi-request', request));
            socket.emit('taxi-dispatched', { status: 'finding_driver', requestId, fareEstimate });
        } else {
            socket.emit('taxi-rejected', { reason: 'No taxi drivers available' });
        }
    });

    socket.on('taxi-accept', (data = {}) => {
        const { passengerId, driverId, routeId = "taxi-service", requestId } = data;
        if (!passengerId || !driverId) return;
        if (taxiAssignments.has(passengerId)) {
            socket.emit('taxi-error', { reason: "Ride already assigned" });
            return;
        }
        const req = requestId ? activeTaxiRequests.get(requestId) : null;
        taxiAssignments.set(passengerId, { driverId, startedAt: Date.now(), requestId: requestId || null });
        const passenger = activePassengers.get(passengerId);
        if (passenger) io.to(passenger.socketId).emit('taxi-arrived', { driverId, routeId, requestId, fareEstimate: req?.fareEstimate });
        io.to('dashboard').emit('route-status', { type: 'taxi-assign', passengerId, driverId, requestId });
    });

    // ----------------------------------------------------
    // HAIL MARKETPLACE (Shared for Combi / Bus / Taxi)
    // ----------------------------------------------------

    // Passenger raises a hand for a service (bus/combi/taxi)
    socket.on('hail', (data = {}) => {
        const { passengerId, routeId = "taxi-service", pickupLoc, destinationLoc } = data;
        if (!passengerId || !routeId || !pickupLoc) return;

        const serviceType = (data.serviceType || "STANDARD").toString().toUpperCase();
        const requestId = `req-${Math.random().toString(36).slice(2, 10)}`;
        const fareEstimate = serviceType === 'STANDARD' ? TAXI_STANDARD_FARE : estimateSpecialFare(pickupLoc, destinationLoc);
        const hail = {
            requestId,
            passengerId,
            routeId,
            pickupLoc,
            destinationLoc: destinationLoc || null,
            serviceType,
            fareEstimate,
            requestedAt: Date.now()
        };

        // Enforce stop proximity for bus/combi hails
        if (routeId !== 'taxi-service') {
            const stop = findNearestStop(routeId, pickupLoc);
            if (stop) {
                hail.stopId = stop.stop_id || null;
                hail.stopName = stop.name || null;
                hail.stopDistanceMeters = Math.round(stop.distanceMeters);
                hail.nearStop = stop.distanceMeters <= HAIL_MAX_DISTANCE_METERS;
                if (!hail.nearStop) {
                    socket.emit('hail-warning', { reason: 'Not near a stop', distanceMeters: hail.stopDistanceMeters });
                }
            } else {
                hail.stopId = null;
                hail.stopName = null;
                hail.nearStop = false;
                socket.emit('hail-warning', { reason: 'No stop data for route' });
            }
        }

        activeHails.set(passengerId, hail);
        if (routeId === 'taxi-service') {
            activeTaxiRequests.set(requestId, hail);
        }

        // Notify drivers serving this route and the admin dashboard
        if (routeId !== 'taxi-service' && hail.stopName) {
            const countAtStop = Array.from(activeHails.values()).filter(h => h.routeId === routeId && h.stopId === hail.stopId).length;
            io.to(`drivers-${routeId}`).emit('new-hail', { ...hail, message: `${countAtStop} passengers waiting at ${hail.stopName}` });
        } else {
            io.to(`drivers-${routeId}`).emit('new-hail', hail);
        }
        io.to('dashboard').emit('new-hail', hail);
    });

    // Passenger stop request (bus/combi)
    socket.on('stop-request', (data = {}) => {
        const { passengerId, routeId = "default-route" } = data;
        if (!passengerId || !routeId) return;
        const boarding = activeBoardings.get(passengerId);
        if (!boarding || boarding.routeId !== routeId) {
            socket.emit('stop-request-error', { reason: 'Not onboard' });
            return;
        }
        io.to(`drivers-${routeId}`).emit('stop-request', { passengerId, routeId, requestedAt: Date.now() });
        io.to('dashboard').emit('stop-request', { passengerId, routeId, requestedAt: Date.now() });
    });

    // Passenger cancels a hail request
    socket.on('cancel-hail', (data = {}) => {
        const { passengerId, routeId = "taxi-service" } = data;
        if (!passengerId) return;

        activeHails.delete(passengerId);

        io.to(`drivers-${routeId}`).emit('hail-cancelled', { passengerId, routeId });
        io.to('dashboard').emit('hail-cancelled', { passengerId, routeId });

        const passenger = activePassengers.get(passengerId);
        if (passenger) {
            io.to(passenger.socketId).emit('hail-rejected', { passengerId, routeId, reason: 'cancelled' });
        }
    });

    // Driver accepts a hail
    socket.on('accept-hail', (data = {}) => {
        const { passengerId, driverId, routeId = "taxi-service", requestId } = data;
        if (!passengerId || !driverId) return;

        activeHails.delete(passengerId);

        const passenger = activePassengers.get(passengerId);
        const req = requestId ? activeTaxiRequests.get(requestId) : null;
        if (passenger) {
            io.to(passenger.socketId).emit('hail-accepted', { passengerId, driverId, routeId, requestId, fareEstimate: req?.fareEstimate, serviceType: req?.serviceType });
        }

        io.to(`drivers-${routeId}`).emit('hail-accepted', { passengerId, driverId, routeId });
        io.to('dashboard').emit('hail-accepted', { passengerId, driverId, routeId });

        if (routeId === 'taxi-service') {
            taxiAssignments.set(passengerId, { driverId, startedAt: Date.now(), requestId: requestId || null });
        }
    });

    // Driver rejects a hail
    socket.on('reject-hail', (data = {}) => {
        const { passengerId, driverId, routeId = "taxi-service" } = data;
        if (!passengerId) return;

        const passenger = activePassengers.get(passengerId);
        if (passenger) {
            io.to(passenger.socketId).emit('hail-rejected', { passengerId, driverId, routeId });
        }

        io.to('dashboard').emit('hail-rejected', { passengerId, driverId, routeId });
    });

    // ----------------------------------------------------
    // ENGINE 4: TRIP ENGINE (Lifecycle & Revenue)
    // ----------------------------------------------------
    socket.on('trip-start', async (data) => {
        const { tripId, driverId, vehicleId, routeId, passengerCount = 0, type = 'COMBI' } = data;
        if (!tripId || !driverId) return;
        const driver = activeDrivers.get(driverId);
        const trip = { 
            trip_id: tripId, 
            driver_id: driverId, 
            route_id: routeId, 
            type, 
            start_time: new Date().toISOString(), 
            passenger_count: passengerCount, 
            revenue: type === 'TAXI' ? 0 : BUS_COMBI_FARE,
            start_coords: driver?.coords || null
        };
        activeTrips.set(tripId, trip);
        try { await db.collection('trips').doc(tripId).set(trip); } catch (e) { console.warn("DB offline, trip saved in memory."); }
    });

    socket.on('trip-end', async (data) => {
        const { tripId, passengerCount = 0, revenue = 0 } = data;
        const trip = activeTrips.get(tripId);
        if (trip) {
            trip.end_time = new Date().toISOString();
            trip.passenger_count = passengerCount;
            trip.revenue = trip.type === 'TAXI' ? revenue : BUS_COMBI_FARE;
            const driver = activeDrivers.get(trip.driver_id);
            if (trip.start_coords && driver?.coords) {
                trip.distance_meters = Math.round(getDistance(trip.start_coords, driver.coords));
            }
            if (trip.start_time) {
                trip.duration_seconds = Math.round((Date.now() - new Date(trip.start_time).getTime()) / 1000);
            }
        }
        try { await db.collection('trips').doc(tripId).set({ ...trip }, { merge: true }); } catch (e) { console.warn("DB offline."); }

        // Notify passenger for rating if this was a taxi trip
        if (trip && trip.type === 'TAXI') {
            for (const [passengerId, assignment] of taxiAssignments.entries()) {
                if (assignment.driverId === trip.driver_id) {
                    const passenger = activePassengers.get(passengerId);
                    if (passenger) io.to(passenger.socketId).emit('taxi-trip-ended', { tripId, driverId: trip.driver_id });
                }
            }
        }
    });

    // Subscriptions
    socket.on('subscribe-route', ({ role = "passengers", routeId }) => { socket.join(`${role}-${routeId}`); });
    socket.on('unsubscribe-route', ({ role = "passengers", routeId }) => { socket.leave(`${role}-${routeId}`); });

    if (DEBUG_SOCKETS) {
        socket.onAny((event, ...args) => {
            if (["driver-location", "passenger-location", "hail", "accept-hail", "reject-hail", "boarding", "trip-start", "trip-end"].includes(event)) {
                const safe = args.map(a => {
                    try { return typeof a === 'string' ? a : JSON.stringify(a); }
                    catch { return '[unserializable]'; }
                });
                console.log(`[EVENT] ${event} from ${socket.id} | ${safe.join(' ')}`);
            }
        });
    }

    socket.on('disconnect', () => {
        for (const [id, driver] of activeDrivers) {
            if (driver.socketId === socket.id) { activeDrivers.delete(id); io.to('dashboard').emit('fleet-remove', { type: 'driver', id }); break; }
        }
        for (const [id, passenger] of activePassengers) {
            if (passenger.socketId === socket.id) { activePassengers.delete(id); io.to('dashboard').emit('fleet-remove', { type: 'passenger', id }); break; }
        }
    });

    socket.on('driver-rating', (data = {}) => {
        const { driverId, rating = 0 } = data;
        const r = Number(rating);
        if (!driverId || !r) return;
        const stats = updateDriverRating(driverId, r);
        io.to('dashboard').emit('driver-rating', { driverId, rating: r, stats });
    });

    socket.on('driver-complaint', (data = {}) => {
        const { driverId, passengerId, message } = data;
        if (!driverId || !passengerId || !message) return;
        const item = { driverId, passengerId, message, at: Date.now() };
        complaints.push(item);
        io.to('dashboard').emit('driver-complaint', item);
    });

    // Legacy fallback bindings
    socket.on('location-update', (data) => { socket.emit('unsupported', 'Use driver-location'); });
});


// ==========================================
// INTERNAL LOGIC / ENGINES
// ==========================================

// Helper: Sync to Firestore silently
async function syncDriverToDb(driverId, data) {
    try {
        await db.collection('drivers').doc(driverId).set({
            driver_id: driverId,
            ...data,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    } catch (e) {
        // Suppressing so API offline doesn't crash server
    }
}

// Haversine formula
function getDistance(c1, c2) {
    const R = 6371e3;
    const lat1 = c1.lat * Math.PI / 180, lat2 = c2.lat * Math.PI / 180;
    const deltaLat = (c2.lat - c1.lat) * Math.PI / 180, deltaLng = (c2.lng - c1.lng) * Math.PI / 180;
    const a = Math.sin(deltaLat/2) * Math.sin(deltaLat/2) + Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLng/2) * Math.sin(deltaLng/2);
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Dispatch Engine Helper
function findNearestVehicle(routeId, coords, serviceType = "COMBI") {
    const list = Array.from(activeDrivers.values()).filter(d => 
        (serviceType === 'TAXI' ? d.serviceType === 'TAXI' : d.routeId === routeId) && d.coords && d.status === "ONLINE"
    );
    if (!list.length) return null;
    let nearest = null;
    for (const d of list) {
        const distanceMeters = getDistance(coords, d.coords);
        if (!nearest || distanceMeters < nearest.distanceMeters) {
            nearest = { ...d, distanceMeters };
        }
    }
    return nearest;
}

// ENGINE 5: ETA ENGINE
function calculateETA(routeId, driverId) {
    const driver = activeDrivers.get(driverId);
    if (!driver || driver.serviceType === 'TAXI') return;
    const passengersOnRoute = Array.from(activePassengers.values()).filter(p => p.routeId === routeId && p.coords);
    if (!passengersOnRoute.length) return;
    
    const speedMs = Math.max(2, Number(driver.speed) || 5); // Assumes ~18km/h minimum if crawling
    for (const p of passengersOnRoute) {
        const distanceMeters = getDistance(driver.coords, p.coords);
        const etaSeconds = Math.round(distanceMeters / speedMs);
        io.to(p.socketId).emit('eta-update', {
            driverId, passengerId: p.passengerId, routeId, distanceMeters: Math.round(distanceMeters), etaSeconds
        });
    }
}

// Spacing Advisory (Dispatch Engine Addon)
function calculateSpacingAdvisory(routeId) {
    const drivers = Array.from(activeDrivers.values()).filter(d => d.routeId === routeId).sort((a,b) => a.coords.lat - b.coords.lat);
    for (let i = 0; i < drivers.length; i++) {
        const current = drivers[i], ahead = drivers[i+1];
        if (ahead && getDistance(current.coords, ahead.coords) < 150) {
            io.to(current.socketId).emit('spacing-advisory', { status: "SLOW DOWN", ahead: "150m" });
        }
    }
}

// Taxi Pickup Detection
function checkTaxiPickup(driverId) {
    for (const [passengerId, assignment] of taxiAssignments.entries()) {
        if (assignment.driverId !== driverId) continue;
        const driver = activeDrivers.get(driverId);
        const passenger = activePassengers.get(passengerId);
        if (!driver || !passenger) continue;
        const dist = getDistance(driver.coords, passenger.coords);
        if (dist <= 20) {
            io.to(driver.socketId).emit('taxi-pickup', { passengerId, driverId, dist });
        }
    }
}

// ==========================================
// HTTP API GATEWAY (ENGINE 3: ROUTE ENGINE)
// ==========================================
app.get('/health', (req, res) => res.json({ status: "ok" }));

app.get('/api/routes', (req, res) => {
    // Serve from cache/mock if DB is down
    res.json(MOCK_ROUTES);
});

app.get('/api/stops', (req, res) => {
    const routeId = req.query.routeId;
    let stops = MOCK_STOPS;
    if (routeId) stops = stops.filter(s => s.route_id === routeId);
    res.json(stops);
});

app.get('/api/analytics', (req, res) => {
    res.json({
        activeDrivers: activeDrivers.size,
        activePassengers: activePassengers.size,
        activeTrips: activeTrips.size,
        taxiAssignments: taxiAssignments.size
    });
});

// Detailed live state snapshot for admin/debugging (safe: excludes socket IDs)
app.get('/api/state', (req, res) => {
    const drivers = Array.from(activeDrivers.values()).map(d => ({
        driverId: d.driverId,
        routeId: d.routeId,
        serviceType: d.serviceType,
        status: d.status,
        vehicleId: d.vehicleId || null,
        lastUpdate: d.lastUpdate || null,
        coords: d.coords || null,
        speed: d.speed ?? null,
        heading: d.heading ?? null,
        occupancy: d.occupancy ?? null
    }));

    const passengers = Array.from(activePassengers.values()).map(p => ({
        passengerId: p.passengerId,
        routeId: p.routeId,
        lastUpdate: p.lastUpdate || null,
        coords: p.coords || null
    }));

    const trips = Array.from(activeTrips.values());

    const hails = Array.from(activeHails.values());

    res.json({
        counts: {
            drivers: drivers.length,
            passengers: passengers.length,
            trips: trips.length,
            taxiAssignments: taxiAssignments.size,
            hails: hails.length,
            complaints: complaints.length
        },
        drivers,
        passengers,
        trips,
        hails,
        ratings: Object.fromEntries(driverRatings.entries()),
        complaints
    });
});

// Socket/room debug snapshot
app.get('/api/clients', (req, res) => {
    res.json({
        totalSockets: io.engine.clientsCount,
        rooms: getRoomCounts()
    });
});

setInterval(() => {
  const now = Date.now();
  for (const [passengerId, hail] of activeHails.entries()) {
    if (now - hail.requestedAt > HAIL_TTL_MS) {
      activeHails.delete(passengerId);
      io.to(`drivers-${hail.routeId}`).emit('hail-expired', { passengerId, routeId: hail.routeId });
      const passenger = activePassengers.get(passengerId);
      if (passenger) {
        io.to(passenger.socketId).emit('hail-rejected', { passengerId, routeId: hail.routeId, reason: 'timeout' });
      }
    }
  }
}, 15000);

server.listen(PORT, () => {
    console.log('-------------------------------------------');
    console.log('  SmartTransit V2 Architecture ACTIVE       ');
    console.log('  Engines: Track, Dispatch, Route, Trip, ETA');
    console.log(`  Listening on port ${PORT}                     `);
    console.log('-------------------------------------------');
});
