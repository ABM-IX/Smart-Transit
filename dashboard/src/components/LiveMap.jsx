import React, { useEffect, useMemo, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Activity, AlertTriangle, Layers } from 'lucide-react';

const MODE_COLORS = {
  BUS: '#60a5fa',
  COMBI: '#22d3ee',
  TAXI: '#f59e0b',
  PASSENGER: '#ef4444',
};

function serviceType(record = {}) {
  const raw = String(record.serviceType || record.service_type || '').toUpperCase();
  const route = String(record.routeId || record.route_id || '').toLowerCase();
  if (raw.includes('TAXI') || route === 'taxi-service') return 'TAXI';
  if (raw.includes('BUS') || route.startsWith('bus-')) return 'BUS';
  return 'COMBI';
}

function coordsOf(record = {}) {
  const coords = record.coords || record.pickupLoc || record.pickup;
  if (!coords) return null;
  const lat = Number(coords.lat ?? coords.latitude);
  const lng = Number(coords.lng ?? coords.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lat, lng };
}

function isFresh(timestamp) {
  if (!timestamp) return false;
  const ms = typeof timestamp === 'number' ? timestamp * 1000 : Date.parse(timestamp);
  return Number.isFinite(ms) && Date.now() - ms <= 120000;
}

function lastSeen(timestamp) {
  if (!timestamp) return 'No timestamp';
  const ms = typeof timestamp === 'number' ? timestamp * 1000 : Date.parse(timestamp);
  if (!Number.isFinite(ms)) return 'Invalid timestamp';
  const seconds = Math.max(0, Math.floor((Date.now() - ms) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  return `${Math.floor(seconds / 60)}m ago`;
}

export default function LiveMap({
  drivers = [],
  passengers = [],
  routes = [],
  selectedMode = 'ALL',
  selectedVehicleId,
  onSelectVehicle,
}) {
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const markersRef = useRef(new Map());
  const routeLayerRef = useRef(null);
  const [showDrivers, setShowDrivers] = useState(true);
  const [showPassengers, setShowPassengers] = useState(true);
  const [filterType, setFilterType] = useState(selectedMode || 'ALL');
  const [selectedRoute, setSelectedRoute] = useState('ALL');
  const [tileStatus, setTileStatus] = useState('loading');

  useEffect(() => {
    setFilterType(selectedMode || 'ALL');
  }, [selectedMode]);

  useEffect(() => {
    if (!mapContainerRef.current || mapInstanceRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: [-24.6282, 25.9231],
      zoom: 12,
      zoomControl: false,
    });

    const tiles = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
      maxZoom: 19,
    });

    tiles.on('load', () => setTileStatus('ready'));
    tiles.on('tileerror', () => setTileStatus('error'));
    tiles.addTo(map);
    L.control.zoom({ position: 'bottomright' }).addTo(map);
    mapInstanceRef.current = map;

    return () => {
      map.remove();
      mapInstanceRef.current = null;
    };
  }, []);

  const visibleDrivers = useMemo(() => {
    return drivers.filter((driver) => {
      const type = serviceType(driver);
      const route = driver.routeId || driver.route_id;
      if (filterType !== 'ALL' && type !== filterType) return false;
      if (selectedRoute !== 'ALL' && route !== selectedRoute) return false;
      return Boolean(coordsOf(driver));
    });
  }, [drivers, filterType, selectedRoute]);

  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;

    const markers = markersRef.current;
    markers.forEach((marker) => marker.remove());
    markers.clear();

    if (showDrivers) {
      visibleDrivers.forEach((driver) => {
        const coords = coordsOf(driver);
        const type = serviceType(driver);
        const id = driver.driverId || driver.driver_id || driver.id;
        const selected = id && id === selectedVehicleId;
        const fresh = isFresh(driver.last_update || driver.lastUpdate);
        const color = fresh ? MODE_COLORS[type] : '#94a3b8';

        const marker = L.circleMarker([coords.lat, coords.lng], {
          radius: selected ? 12 : 8,
          color,
          weight: selected ? 4 : 2,
          fillColor: color,
          fillOpacity: fresh ? 0.9 : 0.45,
        }).addTo(map);

        marker.bindPopup(`
          <div style="font-family:Inter,Arial,sans-serif;color:#0f172a;min-width:180px">
            <strong>${type} unit ${String(id || 'unknown').slice(-8)}</strong>
            <div>Vehicle: ${driver.vehiclePlate || driver.vehicleId || 'Unregistered'}</div>
            <div>Route: ${driver.routeId || driver.route_id || 'Unassigned'}</div>
            <div>Status: ${fresh ? 'Live' : 'Stale or missing timestamp'}</div>
            <div>Last update: ${lastSeen(driver.last_update || driver.lastUpdate)}</div>
          </div>
        `);
        marker.on('click', () => {
          if (id && onSelectVehicle) onSelectVehicle(id);
        });
        markers.set(`driver-${id}`, marker);
      });
    }

    if (showPassengers) {
      passengers.forEach((passenger) => {
        const coords = coordsOf(passenger);
        if (!coords) return;
        const id = passenger.passengerId || passenger.passenger_id || passenger.id;
        const type = serviceType(passenger);
        if (filterType !== 'ALL' && type !== filterType) return;

        const modeColors = {
          BUS: '#60a5fa',
          COMBI: '#22d3ee',
          TAXI: '#f59e0b',
        };
        const color = modeColors[type] || MODE_COLORS.PASSENGER;

        const marker = L.circleMarker([coords.lat, coords.lng], {
          radius: 7,
          color,
          weight: 2,
          fillColor: color,
          fillOpacity: 0.85,
        }).addTo(map);

        marker.bindPopup(`
          <div style="font-family:Inter,Arial,sans-serif;color:#0f172a;min-width:160px">
            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px">
              <strong style="font-size:13px">${type} Commuter</strong>
              <span style="font-size:10px;padding:2px 6px;border-radius:4px;background:#e2e8f0;font-weight:700;color:#0f172a">${type}</span>
            </div>
            <div>Rider: <b>${String(id || 'waiting').slice(-8)}</b></div>
            <div>Route: ${passenger.routeId || passenger.route_id || 'On-Demand'}</div>
            <div>Status: ${passenger.status || 'WAITING'}</div>
          </div>
        `);
        markers.set(`passenger-${id}`, marker);
      });
    }
  }, [visibleDrivers, passengers, showDrivers, showPassengers, filterType, selectedVehicleId, onSelectVehicle]);

  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;
    if (routeLayerRef.current) {
      routeLayerRef.current.remove();
      routeLayerRef.current = null;
    }

    if (selectedRoute === 'ALL') return;
    const route = routes.find((item) => item.id === selectedRoute);
    const points = Array.isArray(route?.waypoints) ? route.waypoints.map(coordsOf).filter(Boolean) : [];
    if (points.length < 2) return;

    routeLayerRef.current = L.polyline(points.map((point) => [point.lat, point.lng]), {
      color: '#38bdf8',
      weight: 4,
      opacity: 0.8,
    }).addTo(map);
    map.fitBounds(routeLayerRef.current.getBounds(), { padding: [40, 40] });
  }, [routes, selectedRoute]);

  useEffect(() => {
    const map = mapInstanceRef.current;
    const marker = markersRef.current.get(`driver-${selectedVehicleId}`);
    if (map && marker) {
      map.setView(marker.getLatLng(), Math.max(map.getZoom(), 14), { animate: true });
      marker.openPopup();
    }
  }, [selectedVehicleId]);

  return (
    <main className="map-container">
      <div className="map-filters">
        <label className="filter-chip">
          <input type="checkbox" checked={showDrivers} onChange={(event) => setShowDrivers(event.target.checked)} />
          Vehicles ({visibleDrivers.length})
        </label>
        <label className="filter-chip">
          <input type="checkbox" checked={showPassengers} onChange={(event) => setShowPassengers(event.target.checked)} />
          Demand ({passengers.length})
        </label>
        <label className="filter-chip">
          <Layers size={14} />
          <select value={filterType} onChange={(event) => setFilterType(event.target.value)}>
            <option value="ALL">All Modes</option>
            <option value="BUS">Bus</option>
            <option value="COMBI">Combi</option>
            <option value="TAXI">Taxi</option>
          </select>
        </label>
        <label className="filter-chip">
          Route
          <select value={selectedRoute} onChange={(event) => setSelectedRoute(event.target.value)}>
            <option value="ALL">All verified</option>
            {routes.map((route) => (
              <option key={route.id} value={route.id}>{route.name || route.id}</option>
            ))}
          </select>
        </label>
      </div>

      <div className="map-floating-controls">
        {tileStatus === 'error' && (
          <div className="floating-card danger">
            <AlertTriangle size={15} />
            Map tiles unavailable
          </div>
        )}
        <div className="floating-card">
          <Activity size={15} />
          <span>{visibleDrivers.length} mapped vehicles</span>
        </div>
      </div>

      {visibleDrivers.length === 0 && passengers.length === 0 && (
        <div className="map-empty-state">
          <strong>No live locations</strong>
          <span>Waiting for driver or passenger telemetry from the backend.</span>
        </div>
      )}

      <div ref={mapContainerRef} className="map-element" />
    </main>
  );
}
