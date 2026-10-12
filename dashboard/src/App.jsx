import React, { useCallback, useEffect, useMemo, useState } from 'react';
import Header from './components/Header';
import Sidebar from './components/Sidebar';
import LiveMap from './components/LiveMap';
import FleetChart from './components/FleetChart';
import { socketService } from './services/socketService';
import { fetchDashboardBaseline, getDefaultBackendUrl, isSafeBackendUrl } from './services/apiService';
import {
  AlertTriangle,
  BarChart3,
  Bus,
  Car,
  ClipboardList,
  MapPinned,
  RefreshCcw,
  Route,
  Search,
  Settings,
  Users,
} from 'lucide-react';

const NAV_ITEMS = [
  { id: 'overview', label: 'Overview', icon: BarChart3 },
  { id: 'bus', label: 'Bus Management', icon: Bus, mode: 'BUS' },
  { id: 'combi', label: 'Combi Management', icon: Car, mode: 'COMBI' },
  { id: 'taxi', label: 'Taxi Management', icon: Car, mode: 'TAXI' },
  { id: 'operations', label: 'Live Operations', icon: MapPinned },
  { id: 'routes', label: 'Routes & Stops', icon: Route },
  { id: 'drivers', label: 'Drivers', icon: Users },
  { id: 'reports', label: 'Reports', icon: ClipboardList },
  { id: 'settings', label: 'System Settings', icon: Settings },
];

const MODE_OPTIONS = [
  { id: 'ALL', label: 'Network' },
  { id: 'BUS', label: 'Bus' },
  { id: 'COMBI', label: 'Combi' },
  { id: 'TAXI', label: 'Taxi' },
];

const MODE_META = {
  ALL: { label: 'Network', className: 'mode-network', noun: 'vehicles' },
  BUS: { label: 'Bus', className: 'mode-bus', noun: 'buses' },
  COMBI: { label: 'Combi', className: 'mode-combi', noun: 'combis' },
  TAXI: { label: 'Taxi', className: 'mode-taxi', noun: 'taxis' },
};

const STALE_SECONDS = 120;

function normalizeId(record, primary, fallback = 'unknown') {
  return record?.[primary] || record?.[primary.replace(/[A-Z]/g, (m) => `_${m.toLowerCase()}`)] || record?.id || fallback;
}

function getServiceType(record = {}) {
  const raw = String(record.serviceType || record.service_type || record.driverType || record.vehicle_type || '').toUpperCase();
  const route = String(record.routeId || record.route_id || '').toLowerCase();
  if (raw.includes('TAXI') || route === 'taxi-service') return 'TAXI';
  if (raw.includes('BUS') || route.startsWith('bus-')) return 'BUS';
  return 'COMBI';
}

function normalizeFleetUnit(record = {}) {
  const driverId = normalizeId(record, 'driverId', record.driver_id || record.driverId || 'driver');
  const lastUpdate = record.last_update || record.lastUpdate || record.updated_at || null;
  return {
    ...record,
    driverId,
    driver_id: driverId,
    serviceType: getServiceType(record),
    routeId: record.routeId || record.route_id || 'Unassigned',
    vehicleId: record.vehicleId || record.vehicle_id || record.vehiclePlate || record.vehicle_plate || 'Unregistered',
    vehiclePlate: record.vehiclePlate || record.vehicle_id || record.vehicleId || 'Unregistered',
    last_update: lastUpdate,
    status: record.status || 'ONLINE',
  };
}

function normalizePassenger(record = {}) {
  const passengerId = normalizeId(record, 'passengerId', record.passenger_id || record.passengerId || 'passenger');
  return {
    ...record,
    passengerId,
    passenger_id: passengerId,
    routeId: record.routeId || record.route_id || 'Unassigned',
    status: record.status || 'WAITING',
  };
}

function secondsSince(timestamp) {
  if (!timestamp) return null;
  const ms = typeof timestamp === 'number' ? timestamp * 1000 : Date.parse(timestamp);
  if (!Number.isFinite(ms)) return null;
  return Math.max(0, Math.floor((Date.now() - ms) / 1000));
}

function isFresh(unit) {
  const age = secondsSince(unit.last_update);
  return age !== null && age <= STALE_SECONDS;
}

function formatLastSeen(timestamp) {
  const age = secondsSince(timestamp);
  if (age === null) return 'No telemetry timestamp';
  if (age < 5) return 'Just now';
  if (age < 60) return `${age}s ago`;
  if (age < 3600) return `${Math.floor(age / 60)}m ago`;
  return `${Math.floor(age / 3600)}h ago`;
}

function dataLabel(state, readyLabel = 'Ready') {
  if (!state) return 'Not requested';
  if (state.status === 'ready') return readyLabel;
  if (state.status === 'timeout') return 'Timed out';
  return 'Unavailable';
}

export default function App() {
  const [serverUrl, setServerUrl] = useState(() => {
    return localStorage.getItem('smarttransit_backend_url') || getDefaultBackendUrl();
  });
  const [activeView, setActiveView] = useState('overview');
  const [selectedMode, setSelectedMode] = useState('ALL');
  const [selectedVehicleId, setSelectedVehicleId] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusMessage, setStatusMessage] = useState('Connecting to telemetry gateway...');

  const [connection, setConnection] = useState({
    socket: 'connecting',
    backend: 'loading',
    database: 'unknown',
    systemActive: null,
    lastRefresh: null,
    error: null,
  });
  const [drivers, setDrivers] = useState(new Map());
  const [passengers, setPassengers] = useState(new Map());
  const [hails, setHails] = useState([]);
  const [trips, setTrips] = useState([]);
  const [events, setEvents] = useState([]);
  const [baseline, setBaseline] = useState({
    routes: { status: 'idle', data: [], error: null },
    stops: { status: 'idle', data: [], error: null },
    analytics: { status: 'idle', data: null, error: null },
    health: { status: 'idle', data: null, error: null },
    activeFleet: { status: 'idle', data: [], error: null },
    refreshedAt: null,
  });

  const addEvent = useCallback((event) => {
    setEvents((prev) => [{ id: `${Date.now()}-${prev.length}`, at: new Date().toISOString(), ...event }, ...prev].slice(0, 40));
  }, []);

  const loadBaseline = useCallback(async (url = serverUrl) => {
    if (!isSafeBackendUrl(url)) {
      setConnection((prev) => ({ ...prev, backend: 'error', error: 'Invalid backend URL' }));
      return;
    }

    setConnection((prev) => ({ ...prev, backend: 'loading', error: null }));
    const next = await fetchDashboardBaseline(url);
    setBaseline(next);

    const health = next.health.data;
    setConnection((prev) => ({
      ...prev,
      backend: next.health.status === 'ready' ? health?.status || 'ready' : 'error',
      database: health?.database?.status || (next.health.status === 'ready' ? 'unknown' : 'unavailable'),
      systemActive: typeof health?.system_active === 'boolean' ? health.system_active : prev.systemActive,
      lastRefresh: next.refreshedAt,
      error: next.health.error,
    }));

    if (Array.isArray(next.activeFleet.data) && next.activeFleet.data.length > 0) {
      setDrivers((prev) => {
        const merged = new Map(prev);
        next.activeFleet.data.forEach((unit) => {
          const normalized = normalizeFleetUnit(unit);
          merged.set(normalized.driverId, normalized);
        });
        return merged;
      });
    }
  }, [serverUrl]);

  const handleServerUrlChange = (newUrl) => {
    const trimmed = newUrl.trim();
    setServerUrl(trimmed);
    localStorage.setItem('smarttransit_backend_url', trimmed);
    loadBaseline(trimmed);
  };

  const connectToServer = useCallback((url) => {
    if (!isSafeBackendUrl(url)) {
      setConnection((prev) => ({ ...prev, socket: 'error', error: 'Invalid backend URL' }));
      return;
    }

    setConnection((prev) => ({ ...prev, socket: 'connecting', error: null }));
    socketService.connect(url, {
      onConnect: () => {
        setConnection((prev) => ({ ...prev, socket: 'connected', error: null }));
        setStatusMessage('Telemetry gateway connected');
      },
      onDisconnect: () => {
        setConnection((prev) => ({ ...prev, socket: 'disconnected' }));
        setStatusMessage('Telemetry gateway disconnected');
      },
      onConnectError: (error) => {
        setConnection((prev) => ({ ...prev, socket: 'error', error: error?.message || 'Socket connection failed' }));
        setStatusMessage('Socket connection unavailable');
      },
      onSystemStatus: (data) => {
        setConnection((prev) => ({ ...prev, systemActive: Boolean(data?.active) }));
      },
      onSnapshot: (snapshot) => {
        if (!snapshot) return;
        if (Array.isArray(snapshot.drivers)) {
          const nextDrivers = new Map();
          snapshot.drivers.forEach((d) => {
            const normalized = normalizeFleetUnit(d);
            if (normalized.driverId && normalized.status !== 'OFFLINE') {
              nextDrivers.set(normalized.driverId, normalized);
            }
          });
          setDrivers(nextDrivers);
        }

        if (Array.isArray(snapshot.passengers)) {
          const nextPassengers = new Map();
          snapshot.passengers.forEach((p) => {
            const normalized = normalizePassenger(p);
            if (normalized.passengerId) nextPassengers.set(normalized.passengerId, normalized);
          });
          setPassengers(nextPassengers);
        }

        if (Array.isArray(snapshot.hails)) setHails(snapshot.hails);
        if (Array.isArray(snapshot.trips)) setTrips(snapshot.trips);
      },
      onFleetUpdate: (data) => {
        if (!data) return;
        const driverId = data.driverId || data.driver_id || (data.type === 'driver' ? data.id : null);
        const passengerId = data.passengerId || data.passenger_id || (data.type === 'passenger' ? data.id : null);

        if (data.type === 'driver' || driverId) {
          if (!driverId) return;
          const normalized = normalizeFleetUnit({ ...data, driverId });
          setDrivers((prev) => {
            const next = new Map(prev);
            if (normalized.status === 'OFFLINE') next.delete(driverId);
            else next.set(driverId, normalized);
            return next;
          });
        } else if (data.type === 'passenger' || passengerId) {
          if (!passengerId) return;
          const normalized = normalizePassenger({ ...data, passengerId });
          setPassengers((prev) => new Map(prev).set(passengerId, normalized));
        }
      },
      onFleetRemove: (data) => {
        if (!data) return;
        const id = data.id || data.driverId || data.driver_id || data.passengerId || data.passenger_id;
        if (!id) return;
        if (data.type === 'driver' || data.driverId || data.driver_id) {
          setDrivers((prev) => {
            const next = new Map(prev);
            next.delete(id);
            return next;
          });
        } else {
          setPassengers((prev) => {
            const next = new Map(prev);
            next.delete(id);
            return next;
          });
          setHails((prev) => prev.filter((h) => (h.passengerId || h.passenger_id) !== id));
        }
      },
      onNewHail: (data) => {
        if (!data) return;
        setHails((prev) => {
          const reqId = data.requestId || data.passengerId;
          const filtered = prev.filter((h) => (h.requestId || h.passengerId) !== reqId);
          return [data, ...filtered].slice(0, 30);
        });
        addEvent({ type: 'Taxi request', tone: 'warning', message: `Pending request ${data.requestId || data.passengerId || ''}` });
      },
      onHailAccepted: (data) => {
        const pId = data?.passengerId || data?.passenger_id;
        const reqId = data?.requestId;
        setHails((prev) => prev.filter((h) => h.requestId !== reqId && (h.passengerId || h.passenger_id) !== pId));
        addEvent({ type: 'Taxi assigned', tone: 'success', message: `Driver ${data?.driverId || 'confirmed'} accepted a request` });
      },
      onHailCancelled: (data) => {
        const pId = data?.passengerId || data?.passenger_id;
        setHails((prev) => prev.filter((h) => (h.passengerId || h.passenger_id) !== pId));
        addEvent({ type: 'Request cancelled', tone: 'muted', message: `Passenger ${pId || 'unknown'} cancelled` });
      },
      onTripStarted: (data) => {
        setTrips((prev) => [data, ...prev.filter((t) => (t.tripId || t.trip_id) !== (data.tripId || data.trip_id))].slice(0, 30));
        addEvent({ type: 'Trip started', tone: 'info', message: data?.tripId || data?.driverId || 'Live trip' });
      },
      onTripCompleted: (data) => {
        setTrips((prev) => prev.filter((t) => (t.tripId || t.trip_id) !== (data?.tripId || data?.trip_id)));
        addEvent({ type: 'Trip completed', tone: 'success', message: data?.tripId || data?.driverId || 'Trip completed' });
      },
      onBoarding: (data) => addEvent({ type: 'Boarding', tone: 'info', message: `${data?.passengerId || 'Passenger'} boarded ${data?.driverId || 'vehicle'}` }),
      onStopRequested: (data) => addEvent({ type: 'Stop request', tone: 'warning', message: `${data?.passengerId || 'Passenger'} requested a stop` }),
      onDriverFeedback: (data) => addEvent({ type: 'Driver feedback', tone: 'info', message: `Driver ${data?.driverId || ''} rated ${data?.avgRating || data?.rating || ''}` }),
    });
  }, [addEvent]);

  useEffect(() => {
    loadBaseline(serverUrl);
    connectToServer(serverUrl);
    return () => socketService.disconnect();
  }, [connectToServer, loadBaseline, serverUrl]);

  const handleEmergencyAlert = () => {
    if (!window.confirm('Prepare emergency advisory for active drivers? This will only emit when the telemetry gateway is connected.')) {
      return;
    }

    if (connection.socket !== 'connected') {
      window.alert('Emergency advisory not sent: telemetry gateway is not connected.');
      return;
    }

    socketService.emit('emergency-alert', {
      timestamp: new Date().toISOString(),
      issuer: 'Command Center Dispatch',
      severity: 'HIGH',
    });
    addEvent({ type: 'Emergency advisory', tone: 'danger', message: 'Broadcast requested; backend acknowledgement not implemented' });
    window.alert('Emergency advisory emitted. Backend acknowledgement workflow is not implemented in the current API.');
  };

  const driversList = useMemo(() => Array.from(drivers.values()).map(normalizeFleetUnit), [drivers]);
  const passengersList = useMemo(() => Array.from(passengers.values()).map(normalizePassenger), [passengers]);
  const routes = Array.isArray(baseline.routes.data) ? baseline.routes.data : [];
  const stops = Array.isArray(baseline.stops.data) ? baseline.stops.data : [];

  const visibleMode = NAV_ITEMS.find((item) => item.id === activeView)?.mode || selectedMode;
  const activeMode = visibleMode === 'ALL' ? selectedMode : visibleMode;
  const modeForData = activeMode === 'ALL' ? null : activeMode;

  const filteredFleet = useMemo(() => {
    const term = searchTerm.trim().toLowerCase();
    return driversList
      .filter((unit) => !modeForData || unit.serviceType === modeForData)
      .filter((unit) => {
        if (!term) return true;
        return [unit.driverId, unit.vehiclePlate, unit.vehicleId, unit.routeId, unit.serviceType]
          .filter(Boolean)
          .some((value) => String(value).toLowerCase().includes(term));
      })
      .sort((a, b) => Number(isFresh(b)) - Number(isFresh(a)));
  }, [driversList, modeForData, searchTerm]);

  const selectedVehicle = driversList.find((unit) => unit.driverId === selectedVehicleId) || null;

  const metrics = useMemo(() => {
    const liveUnits = driversList.filter(isFresh);
    const staleUnits = driversList.filter((unit) => unit.last_update && !isFresh(unit));
    const byMode = (mode) => driversList.filter((unit) => unit.serviceType === mode);
    const liveByMode = (mode) => liveUnits.filter((unit) => unit.serviceType === mode);
    const routesForMode = routes.filter((route) => !modeForData || String(route.route_type || '').toUpperCase() === modeForData);

    return {
      registeredVehicles: driversList.length,
      liveVehicles: liveUnits.length,
      staleVehicles: staleUnits.length,
      onlineDrivers: driversList.length,
      activeTrips: trips.length,
      pendingHails: hails.length,
      verifiedRoutes: routesForMode.length,
      verifiedStops: stops.length,
      bus: { registered: byMode('BUS').length, live: liveByMode('BUS').length },
      combi: { registered: byMode('COMBI').length, live: liveByMode('COMBI').length },
      taxi: { registered: byMode('TAXI').length, live: liveByMode('TAXI').length },
    };
  }, [driversList, routes, stops, trips.length, hails.length, modeForData]);

  const modeCounts = {
    BUS: metrics.bus.registered,
    COMBI: metrics.combi.registered,
    TAXI: metrics.taxi.registered,
  };

  return (
    <div className="app-shell">
      <Header
        connection={connection}
        isConnected={connection.socket === 'connected'}
        statusMessage={statusMessage}
        onEmergencyAlert={handleEmergencyAlert}
      />

      <div className="dashboard-layout">
        <Sidebar
          activeView={activeView}
          navItems={NAV_ITEMS}
          onNavigate={(view) => {
            setActiveView(view);
            const mode = NAV_ITEMS.find((item) => item.id === view)?.mode;
            if (mode) setSelectedMode(mode);
          }}
          serverUrl={serverUrl}
          onServerUrlChange={handleServerUrlChange}
          onConnect={connectToServer}
          connection={connection}
          modeCounts={modeCounts}
        />

        <main className="command-main">
          <section className="command-toolbar">
            <div>
              <p className="eyebrow">Gaborone Operations</p>
              <h2>{getViewTitle(activeView, selectedMode)}</h2>
              <p>{getViewSubtitle(activeView, selectedMode)}</p>
            </div>
            <div className="toolbar-actions">
              <div className="mode-selector" aria-label="Transport mode selector">
                {MODE_OPTIONS.map((mode) => (
                  <button
                    key={mode.id}
                    type="button"
                    className={selectedMode === mode.id ? 'active' : ''}
                    onClick={() => setSelectedMode(mode.id)}
                  >
                    {mode.label}
                  </button>
                ))}
              </div>
              <button type="button" className="icon-button" onClick={() => loadBaseline(serverUrl)} title="Refresh REST data">
                <RefreshCcw size={16} />
              </button>
            </div>
          </section>

          {activeView === 'overview' && (
            <OverviewView
              metrics={metrics}
              connection={connection}
              baseline={baseline}
              modeCounts={modeCounts}
              events={events}
            />
          )}

          {['bus', 'combi', 'taxi', 'drivers'].includes(activeView) && (
            <ManagementView
              mode={activeView === 'drivers' ? selectedMode : activeMode}
              fleet={filteredFleet}
              allFleet={driversList}
              hails={hails}
              trips={trips}
              routes={routes}
              routesState={baseline.routes}
              stopsState={baseline.stops}
              searchTerm={searchTerm}
              onSearchChange={setSearchTerm}
              selectedVehicle={selectedVehicle}
              onSelectVehicle={setSelectedVehicleId}
            />
          )}

          {activeView === 'operations' && (
            <OperationsView
              drivers={driversList}
              passengers={passengersList}
              routes={routes}
              selectedMode={selectedMode}
              selectedVehicleId={selectedVehicleId}
              onSelectVehicle={setSelectedVehicleId}
              events={events}
            />
          )}

          {activeView === 'routes' && (
            <RoutesView routes={routes} stops={stops} routesState={baseline.routes} stopsState={baseline.stops} selectedMode={selectedMode} />
          )}

          {activeView === 'reports' && (
            <ReportsView metrics={metrics} baseline={baseline} selectedMode={selectedMode} />
          )}

          {activeView === 'settings' && (
            <SettingsView
              serverUrl={serverUrl}
              onServerUrlChange={handleServerUrlChange}
              onConnect={connectToServer}
              connection={connection}
              baseline={baseline}
            />
          )}
        </main>
      </div>
    </div>
  );
}

function getViewTitle(view, mode) {
  if (view === 'overview') return 'Unified Network Overview';
  if (view === 'bus') return 'Bus Management';
  if (view === 'combi') return 'Combi Management';
  if (view === 'taxi') return 'Taxi Management';
  if (view === 'operations') return 'Live Operations Map';
  if (view === 'routes') return 'Routes & Stops';
  if (view === 'drivers') return `${MODE_META[mode]?.label || 'Network'} Drivers`;
  if (view === 'reports') return 'Operational Reports';
  return 'System Settings';
}

function getViewSubtitle(view, mode) {
  if (view === 'overview') return 'Truthful status across live telemetry, backend health, route data, and taxi demand.';
  if (view === 'taxi') return 'Availability and dispatch visibility using live hails, trips, and taxi telemetry.';
  if (view === 'combi') return 'Route-based minibus visibility with advisory states where timestamps and routes exist.';
  if (view === 'bus') return 'Bus fleet and route assignment monitoring backed by registered live telemetry.';
  if (view === 'operations') return 'Map filters and fleet selections stay synchronised when live locations are available.';
  if (view === 'routes') return 'Verified backend route and stop records; missing geometry is shown explicitly.';
  if (view === 'reports') return 'Reports are limited to data currently exposed by the backend and socket feed.';
  if (view === 'drivers') return `Driver and vehicle records filtered to ${MODE_META[mode]?.noun || 'all vehicles'}.`;
  return 'Connection controls and observable system health.';
}

function OverviewView({ metrics, connection, baseline, modeCounts, events }) {
  const cards = [
    { label: 'Registered vehicles', value: metrics.registeredVehicles, note: 'Live fleet cache, not full registry' },
    { label: 'Reporting telemetry', value: metrics.liveVehicles, note: `Fresh within ${STALE_SECONDS}s` },
    { label: 'Drivers online', value: metrics.onlineDrivers, note: 'Socket active driver records' },
    { label: 'Active trips', value: metrics.activeTrips, note: 'Socket trip lifecycle records' },
    { label: 'Pending taxi requests', value: metrics.pendingHails, note: 'Live hail queue' },
    { label: 'Verified routes', value: statefulCount(baseline.routes, metrics.verifiedRoutes), note: dataLabel(baseline.routes, 'Backend route dataset') },
    { label: 'Verified stops', value: statefulCount(baseline.stops, metrics.verifiedStops), note: dataLabel(baseline.stops, 'Backend stop dataset') },
    { label: 'Stale GPS signals', value: metrics.staleVehicles, note: 'Older than freshness threshold' },
  ];

  return (
    <div className="view-grid">
      <section className="kpi-grid">
        {cards.map((card) => (
          <article className="kpi-card" key={card.label}>
            <span>{card.label}</span>
            <strong>{card.value}</strong>
            <small>{card.note}</small>
          </article>
        ))}
      </section>

      <section className="panel span-7">
        <div className="panel-header">
          <div>
            <h3>Fleet Mix</h3>
            <p>Current live cache by service type.</p>
          </div>
        </div>
        <FleetChart modeCounts={modeCounts} />
      </section>

      <section className="panel span-5">
        <div className="panel-header">
          <div>
            <h3>System Health</h3>
            <p>Observable backend, database, socket, and map states.</p>
          </div>
        </div>
        <div className="health-stack">
          <HealthRow label="Backend API" value={connection.backend} tone={connection.backend === 'ok' ? 'success' : connection.backend === 'loading' ? 'warning' : 'danger'} />
          <HealthRow label="Database" value={connection.database} tone={connection.database === 'connected' ? 'success' : 'warning'} />
          <HealthRow label="Socket.IO" value={connection.socket} tone={connection.socket === 'connected' ? 'success' : 'danger'} />
          <HealthRow label="Telemetry engine" value={connection.systemActive === null ? 'Unknown' : connection.systemActive ? 'Active' : 'Inactive'} tone={connection.systemActive ? 'success' : 'warning'} />
          <HealthRow label="Last REST refresh" value={connection.lastRefresh ? new Date(connection.lastRefresh).toLocaleTimeString('en-GB') : 'Not refreshed'} tone="muted" />
        </div>
      </section>

      <section className="panel span-12">
        <div className="panel-header">
          <div>
            <h3>Operational Alerts</h3>
            <p>Live socket events and dashboard advisories.</p>
          </div>
        </div>
        <EventList events={events} />
      </section>
    </div>
  );
}

function ManagementView({
  mode,
  fleet,
  allFleet,
  hails,
  trips,
  routes,
  routesState,
  stopsState,
  searchTerm,
  onSearchChange,
  selectedVehicle,
  onSelectVehicle,
}) {
  const normalizedMode = mode === 'ALL' ? null : mode;
  const meta = MODE_META[mode] || MODE_META.ALL;
  const modeFleet = normalizedMode ? allFleet.filter((unit) => unit.serviceType === normalizedMode) : allFleet;
  const modeRoutes = routes.filter((route) => !normalizedMode || String(route.route_type || '').toUpperCase() === normalizedMode);
  const liveCount = modeFleet.filter(isFresh).length;
  const staleCount = modeFleet.filter((unit) => unit.last_update && !isFresh(unit)).length;
  const activeAssignments = modeFleet.filter((unit) => unit.routeId && unit.routeId !== 'Unassigned').length;

  const cards = [
    { label: `Registered ${meta.noun}`, value: modeFleet.length, note: 'Live fleet cache only' },
    { label: 'Reporting live locations', value: liveCount, note: `Fresh within ${STALE_SECONDS}s` },
    { label: mode === 'TAXI' ? 'Available or online' : 'Currently in service', value: modeFleet.length, note: 'Backend does not expose full duty roster' },
    { label: 'Active route assignments', value: activeAssignments, note: 'From driver telemetry payloads' },
    { label: 'Requires attention', value: staleCount, note: 'Stale telemetry signals' },
    { label: mode === 'TAXI' ? 'Pending dispatch requests' : 'Verified routes', value: mode === 'TAXI' ? hails.length : statefulCount(routesState, modeRoutes.length), note: mode === 'TAXI' ? 'Live hail queue' : dataLabel(routesState, 'Routes available') },
  ];

  return (
    <div className="view-grid">
      <section className="kpi-grid">
        {cards.map((card) => (
          <article className={`kpi-card ${meta.className}`} key={card.label}>
            <span>{card.label}</span>
            <strong>{card.value}</strong>
            <small>{card.note}</small>
          </article>
        ))}
      </section>

      <section className="panel span-8">
        <div className="panel-header">
          <div>
            <h3>{meta.label} Registry</h3>
            <p>Searchable vehicle records from live telemetry. Full registry CRUD awaits backend endpoints.</p>
          </div>
          <label className="search-box">
            <Search size={15} />
            <input value={searchTerm} onChange={(event) => onSearchChange(event.target.value)} placeholder="Search vehicle, driver, route" />
          </label>
        </div>
        <FleetTable fleet={fleet} onSelectVehicle={onSelectVehicle} selectedVehicleId={selectedVehicle?.driverId} />
      </section>

      <section className="panel span-4">
        <div className="panel-header">
          <div>
            <h3>Detail View</h3>
            <p>Vehicle, assignment, and data-quality state.</p>
          </div>
        </div>
        <VehicleDetail vehicle={selectedVehicle} />
      </section>

      {mode === 'COMBI' && (
        <section className="panel span-12">
          <div className="panel-header">
            <div>
              <h3>Route Coordination</h3>
              <p>Advisories are calculated only where route IDs and fresh timestamps exist.</p>
            </div>
          </div>
          <RouteCoordination fleet={modeFleet} />
        </section>
      )}

      {mode === 'TAXI' && (
        <section className="panel span-12">
          <div className="panel-header">
            <div>
              <h3>Dispatch Queue</h3>
              <p>Dashboard can observe requests and assignments; admin assignment endpoint is not exposed.</p>
            </div>
          </div>
          <TaxiDispatch hails={hails} trips={trips} taxis={modeFleet} />
        </section>
      )}

      <section className="panel span-12">
        <div className="panel-header">
          <div>
            <h3>Data Support</h3>
            <p>What this workspace can safely claim with the current backend.</p>
          </div>
        </div>
        <SupportMatrix mode={mode} routesState={routesState} stopsState={stopsState} />
      </section>
    </div>
  );
}

function OperationsView({ drivers, passengers, routes, selectedMode, selectedVehicleId, onSelectVehicle, events }) {
  return (
    <div className="operations-grid">
      <LiveMap
        drivers={drivers}
        passengers={passengers}
        routes={routes}
        selectedMode={selectedMode}
        selectedVehicleId={selectedVehicleId}
        onSelectVehicle={onSelectVehicle}
      />
      <section className="panel">
        <div className="panel-header">
          <div>
            <h3>Live Operations Log</h3>
            <p>Recent telemetry, dispatch, and service events.</p>
          </div>
        </div>
        <EventList events={events} />
      </section>
    </div>
  );
}

function RoutesView({ routes, stops, routesState, stopsState, selectedMode }) {
  const filteredRoutes = routes.filter((route) => selectedMode === 'ALL' || String(route.route_type || '').toUpperCase() === selectedMode);

  return (
    <div className="view-grid">
      <section className="panel span-7">
        <div className="panel-header">
          <div>
            <h3>Verified Routes</h3>
            <p>{dataLabel(routesState, 'Routes loaded from backend')}</p>
          </div>
        </div>
        {routesState.status !== 'ready' && <StateNotice tone="danger" title="Routes unavailable" detail={routesState.error || 'Backend route request did not complete.'} />}
        {routesState.status === 'ready' && filteredRoutes.length === 0 && <StateNotice title="No verified routes" detail="The backend returned zero route records for this filter." />}
        <div className="route-list">
          {filteredRoutes.map((route) => (
            <article key={route.id} className="route-row">
              <strong>{route.name}</strong>
              <span>{route.origin_name} to {route.destination_name}</span>
              <small>{route.route_type || 'Unknown'} route - P{Number(route.base_fare || 0).toFixed(2)} base fare</small>
            </article>
          ))}
        </div>
      </section>

      <section className="panel span-5">
        <div className="panel-header">
          <div>
            <h3>Stops Dataset</h3>
            <p>{dataLabel(stopsState, 'Stops loaded from backend')}</p>
          </div>
        </div>
        {stopsState.status !== 'ready' && <StateNotice tone="danger" title="Stops unavailable" detail={stopsState.error || 'Backend stop request did not complete.'} />}
        {stopsState.status === 'ready' && stops.length === 0 && <StateNotice title="No verified stops" detail="No stop records are currently available." />}
        <div className="stop-list">
          {stops.slice(0, 12).map((stop) => (
            <div key={stop.id} className="stop-row">
              <strong>{stop.name}</strong>
              <span>{Number(stop.latitude).toFixed(4)}, {Number(stop.longitude).toFixed(4)}</span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

function ReportsView({ metrics, baseline, selectedMode }) {
  const period = new Date().toLocaleDateString('en-GB', { timeZone: 'Africa/Gaborone' });

  return (
    <div className="view-grid">
      <section className="panel span-12">
        <div className="panel-header">
          <div>
            <h3>Available Reports</h3>
            <p>Generated {period}. Export is limited until backend report endpoints exist.</p>
          </div>
        </div>
        <div className="report-grid">
          <ReportCard title="Fleet Activity" status="Available" detail={`${metrics.liveVehicles} fresh telemetry records, ${metrics.staleVehicles} stale records.`} />
          <ReportCard title="Route & Stop Operations" status={baseline.routes.status === 'ready' ? 'Available' : 'Unavailable'} detail={`${statefulCount(baseline.routes, metrics.verifiedRoutes)} routes and ${statefulCount(baseline.stops, metrics.verifiedStops)} stops for ${MODE_META[selectedMode]?.label || 'Network'}.`} />
          <ReportCard title="Taxi Dispatch" status="Partial" detail={`${metrics.pendingHails} pending hails and ${metrics.activeTrips} active trips from live socket memory.`} />
          <ReportCard title="Occupancy & Capacity" status="Awaiting data" detail="Capacity and occupancy history are not exposed as a reliable reporting dataset yet." />
        </div>
      </section>
    </div>
  );
}

function SettingsView({ serverUrl, onServerUrlChange, onConnect, connection, baseline }) {
  const [urlInput, setUrlInput] = useState(serverUrl);

  useEffect(() => setUrlInput(serverUrl), [serverUrl]);

  const applyUrl = (url) => {
    setUrlInput(url);
    onServerUrlChange(url);
    onConnect(url);
  };

  return (
    <div className="view-grid">
      <section className="panel span-6">
        <div className="panel-header">
          <div>
            <h3>Gateway Connection</h3>
            <p>Cloud, LAN, and localhost options are preserved. URLs are validated before use.</p>
          </div>
        </div>
        <form className="connection-form" onSubmit={(event) => {
          event.preventDefault();
          applyUrl(urlInput);
        }}>
          <input value={urlInput} onChange={(event) => setUrlInput(event.target.value)} />
          <button className="btn-primary" type="submit">Link</button>
        </form>
        <div className="preset-row">
          <button type="button" onClick={() => applyUrl('https://smart-transit-uhyf.onrender.com')}>Cloud</button>
          <button type="button" onClick={() => applyUrl('http://10.189.239.26:8000')}>LAN</button>
          <button type="button" onClick={() => applyUrl('http://localhost:8000')}>Localhost</button>
        </div>
      </section>

      <section className="panel span-6">
        <div className="panel-header">
          <div>
            <h3>Connection Diagnostics</h3>
            <p>States are observed, not inferred from page load.</p>
          </div>
        </div>
        <div className="health-stack">
          <HealthRow label="Backend API" value={connection.backend} tone={connection.backend === 'ok' ? 'success' : 'warning'} />
          <HealthRow label="Database" value={connection.database} tone={connection.database === 'connected' ? 'success' : 'warning'} />
          <HealthRow label="Socket.IO" value={connection.socket} tone={connection.socket === 'connected' ? 'success' : 'danger'} />
          <HealthRow label="Routes request" value={dataLabel(baseline.routes)} tone={baseline.routes.status === 'ready' ? 'success' : 'warning'} />
          <HealthRow label="Stops request" value={dataLabel(baseline.stops)} tone={baseline.stops.status === 'ready' ? 'success' : 'warning'} />
        </div>
      </section>
    </div>
  );
}

function FleetTable({ fleet, onSelectVehicle, selectedVehicleId }) {
  if (fleet.length === 0) {
    return <StateNotice title="No vehicles match this view" detail="This may mean zero records, an inactive fleet, or a filter with no matches. Backend failures are shown separately in health." />;
  }

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Vehicle</th>
            <th>Driver</th>
            <th>Route</th>
            <th>Occupancy</th>
            <th>Status</th>
            <th>Last GPS</th>
          </tr>
        </thead>
        <tbody>
          {fleet.map((unit) => (
            <tr
              key={unit.driverId}
              className={selectedVehicleId === unit.driverId ? 'selected' : ''}
              onClick={() => onSelectVehicle(unit.driverId)}
            >
              <td>
                <strong>{unit.vehiclePlate}</strong>
                <span>{unit.serviceType}</span>
              </td>
              <td>{unit.driverId}</td>
              <td>{unit.routeId || 'Unassigned'}</td>
              <td>{unit.occupancy !== undefined ? `${unit.occupancy} pax` : 'Unavailable'}</td>
              <td><StatusBadge status={isFresh(unit) ? 'Live' : unit.last_update ? 'Stale' : 'No GPS'} /></td>
              <td>{formatLastSeen(unit.last_update)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function VehicleDetail({ vehicle }) {
  if (!vehicle) {
    return <StateNotice title="Select a vehicle" detail="Choose a vehicle row or map marker to inspect live assignment details." />;
  }

  return (
    <div className="detail-stack">
      <DetailRow label="Vehicle ID" value={vehicle.vehicleId} />
      <DetailRow label="Registration" value={vehicle.vehiclePlate} />
      <DetailRow label="Assigned driver" value={vehicle.driverId} />
      <DetailRow label="Assigned route" value={vehicle.routeId || 'Unassigned'} />
      <DetailRow label="Capacity" value="Unavailable from API" />
      <DetailRow label="Occupancy" value={vehicle.occupancy !== undefined ? `${vehicle.occupancy} passengers` : 'Unavailable'} />
      <DetailRow label="Telemetry" value={isFresh(vehicle) ? 'Live' : vehicle.last_update ? 'Stale' : 'Missing timestamp'} />
      <DetailRow label="Last GPS update" value={formatLastSeen(vehicle.last_update)} />
      <DetailRow label="Maintenance" value="Not exposed by backend" />
    </div>
  );
}

function RouteCoordination({ fleet }) {
  const byRoute = fleet.reduce((acc, unit) => {
    const routeId = unit.routeId || 'Unassigned';
    if (!acc[routeId]) acc[routeId] = [];
    acc[routeId].push(unit);
    return acc;
  }, {});
  const entries = Object.entries(byRoute).filter(([routeId]) => routeId !== 'Unassigned');

  if (entries.length === 0) {
    return <StateNotice title="No route assignments" detail="Combi spacing advisories require multiple fresh vehicles on the same verified route." />;
  }

  return (
    <div className="coordination-grid">
      {entries.map(([routeId, units]) => {
        const fresh = units.filter(isFresh);
        const advisory = fresh.length >= 2 ? 'Advisory-ready' : 'Insufficient fresh telemetry';
        return (
          <article key={routeId} className="coordination-card">
            <strong>{routeId}</strong>
            <span>{units.length} vehicles assigned, {fresh.length} fresh</span>
            <StatusBadge status={advisory} />
            <small>Distance/headway calculation requires route direction and ordered geometry before confirming bunching.</small>
          </article>
        );
      })}
    </div>
  );
}

function TaxiDispatch({ hails, trips, taxis }) {
  return (
    <div className="dispatch-grid">
      <div>
        <h4>Pending Requests</h4>
        {hails.length === 0 && <StateNotice title="No pending taxi requests" detail="The live hail queue is empty." />}
        {hails.map((hail) => (
          <article className="dispatch-row" key={hail.requestId || hail.passengerId}>
            <strong>{hail.requestId || 'Taxi request'}</strong>
            <span>Passenger {hail.passengerId || hail.passenger_id || 'unknown'} - {hail.serviceType || 'TAXI'}</span>
            <small>{hail.fareEstimate ? `Fare estimate P${Number(hail.fareEstimate).toFixed(2)}` : 'Fare unavailable'}</small>
          </article>
        ))}
      </div>
      <div>
        <h4>Taxi Availability</h4>
        <div className="availability-grid">
          <StatusMetric label="Available / online" value={taxis.length} />
          <StatusMetric label="Busy trips" value={trips.length} />
          <StatusMetric label="Offline" value="Unavailable" />
          <StatusMetric label="Unknown state" value={taxis.filter((taxi) => !taxi.last_update).length} />
        </div>
      </div>
    </div>
  );
}

function SupportMatrix({ mode, routesState, stopsState }) {
  const rows = [
    ['Live GPS', 'Supported through Socket.IO driver-location and fleet-update events'],
    ['Vehicle registry CRUD', 'Awaiting REST endpoints and permission contract'],
    ['Driver contact details', 'Hidden until backend permission model exposes authorised fields'],
    ['Routes and stops', routesState.status === 'ready' && stopsState.status === 'ready' ? 'Loaded from backend datasets' : 'Unavailable or degraded'],
    ['Occupancy history', 'Current payload only; historical series not available'],
    [mode === 'TAXI' ? 'Admin dispatch assignment' : 'Headway and bunching', mode === 'TAXI' ? 'Backend supports driver accept events, not admin assignment endpoint' : 'Advisory only unless route direction and timestamps are sufficient'],
  ];

  return (
    <div className="support-list">
      {rows.map(([label, value]) => (
        <div key={label}>
          <strong>{label}</strong>
          <span>{value}</span>
        </div>
      ))}
    </div>
  );
}

function EventList({ events }) {
  if (!events.length) {
    return <StateNotice title="No active alerts" detail="Socket lifecycle, taxi requests, boardings, and trip updates will appear here." />;
  }

  return (
    <div className="event-list">
      {events.map((event) => (
        <article className={`event-row ${event.tone || 'info'}`} key={event.id}>
          <AlertTriangle size={15} />
          <div>
            <strong>{event.type}</strong>
            <span>{event.message}</span>
          </div>
          <time>{new Date(event.at).toLocaleTimeString('en-GB')}</time>
        </article>
      ))}
    </div>
  );
}

function ReportCard({ title, status, detail }) {
  return (
    <article className="report-card">
      <strong>{title}</strong>
      <StatusBadge status={status} />
      <p>{detail}</p>
    </article>
  );
}

function StatusMetric({ label, value }) {
  return (
    <div className="status-metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function DetailRow({ label, value }) {
  return (
    <div className="detail-row">
      <span>{label}</span>
      <strong>{value || 'Unavailable'}</strong>
    </div>
  );
}

function HealthRow({ label, value, tone = 'muted' }) {
  return (
    <div className="health-row">
      <span>{label}</span>
      <StatusBadge status={value} tone={tone} />
    </div>
  );
}

function StatusBadge({ status, tone }) {
  const normalized = String(status || 'Unknown').toLowerCase();
  const badgeTone = tone || (normalized.includes('live') || normalized.includes('available') || normalized.includes('ready') || normalized.includes('connected') || normalized.includes('active') || normalized.includes('ok') ? 'success'
    : normalized.includes('stale') || normalized.includes('partial') || normalized.includes('awaiting') || normalized.includes('insufficient') || normalized.includes('loading') ? 'warning'
      : normalized.includes('unavailable') || normalized.includes('error') || normalized.includes('disconnected') || normalized.includes('no gps') ? 'danger'
        : 'muted');
  return <span className={`status-badge ${badgeTone}`}>{status || 'Unknown'}</span>;
}

function StateNotice({ title, detail, tone = 'muted' }) {
  return (
    <div className={`state-notice ${tone}`}>
      <strong>{title}</strong>
      <span>{detail}</span>
    </div>
  );
}

function statefulCount(state, count) {
  return state?.status === 'ready' ? count : 'Unavailable';
}
