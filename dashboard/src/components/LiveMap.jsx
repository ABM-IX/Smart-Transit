import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Layers, Activity } from 'lucide-react';

export default function LiveMap({
  drivers = [],
  passengers = [],
  routes = [],
}) {
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const markersRef = useRef(new Map());
  const heatLayerRef = useRef(null);

  const [showDrivers, setShowDrivers] = useState(true);
  const [showPassengers, setShowPassengers] = useState(true);
  const [filterType, setFilterType] = useState('ALL');
  const [heatmapEnabled, setHeatmapEnabled] = useState(false);

  // Initialize Map
  useEffect(() => {
    if (!mapContainerRef.current || mapInstanceRef.current) return;

    // Centered on Gaborone, Botswana
    const map = L.map(mapContainerRef.current, {
      center: [-24.6282, 25.9231],
      zoom: 13,
      zoomControl: false,
    });

    // Dark styled Carto tiles
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      attribution: '© CARTO, OpenStreetMap contributors',
      maxZoom: 19,
    }).addTo(map);

    L.control.zoom({ position: 'bottomright' }).addTo(map);

    mapInstanceRef.current = map;

    return () => {
      map.remove();
      mapInstanceRef.current = null;
    };
  }, []);

  // Update Markers
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;

    const markers = markersRef.current;

    // Clear existing markers
    markers.forEach((marker) => map.removeLayer(marker));
    markers.clear();

    // Render Drivers
    if (showDrivers) {
      drivers.forEach((driver) => {
        if (!driver.coords || driver.coords.lat === undefined || driver.coords.lng === undefined) return;

        const isTaxi = driver.serviceType === 'TAXI' || driver.routeId === 'taxi-service';
        const isBus = driver.serviceType === 'BUS' || (driver.routeId && driver.routeId.startsWith('bus-'));
        const type = isTaxi ? 'TAXI' : isBus ? 'BUS' : 'COMBI';

        if (filterType !== 'ALL' && filterType !== type) return;

        const latlng = [driver.coords.lat, driver.coords.lng];
        const driverTitle = `Fleet Unit: Driver ${driver.driverId?.slice(-6) || 'Online'}`;
        const routeLabel = driver.routeId || 'Unassigned';
        const occupancy = driver.occupancy !== undefined ? `${driver.occupancy} PAX` : 'Available';

        const popupHtml = `
          <div style="font-family:'Space Grotesk',sans-serif; color:#0f172a; min-width:140px;">
            <div style="font-weight:700; font-size:14px; color:#1e3a8a; margin-bottom:4px;">${driverTitle}</div>
            <div style="font-size:12px; margin-bottom:2px;"><b>Service:</b> ${type}</div>
            <div style="font-size:12px; margin-bottom:2px;"><b>Route:</b> ${routeLabel}</div>
            <div style="font-size:12px;"><b>Occupancy:</b> ${occupancy}</div>
          </div>
        `;

        const circleMarker = L.circleMarker(latlng, {
          radius: 8,
          color: isTaxi ? '#f59e0b' : isBus ? '#22d3ee' : '#5b8cff',
          weight: 2,
          fillColor: isTaxi ? '#f59e0b' : isBus ? '#22d3ee' : '#5b8cff',
          fillOpacity: 0.85,
        }).addTo(map);

        circleMarker.bindPopup(popupHtml);
        markers.set(`driver-${driver.driverId}`, circleMarker);
      });
    }

    // Render Passengers
    if (showPassengers) {
      passengers.forEach((passenger) => {
        if (!passenger.coords || passenger.coords.lat === undefined || passenger.coords.lng === undefined) return;

        const latlng = [passenger.coords.lat, passenger.coords.lng];
        const passengerTitle = `Rider: ${passenger.passengerId?.slice(-6) || 'Waiting'}`;
        const routeLabel = passenger.routeId || 'Any Route';

        const popupHtml = `
          <div style="font-family:'Space Grotesk',sans-serif; color:#0f172a; min-width:130px;">
            <div style="font-weight:700; font-size:13px; color:#15803d; margin-bottom:4px;">${passengerTitle}</div>
            <div style="font-size:12px;"><b>Target:</b> ${routeLabel}</div>
            <div style="font-size:11px; color:#64748b; margin-top:2px;">Awaiting Pickup</div>
          </div>
        `;

        const circleMarker = L.circleMarker(latlng, {
          radius: 6,
          color: '#22c55e',
          weight: 2,
          fillColor: '#22c55e',
          fillOpacity: 0.9,
        }).addTo(map);

        circleMarker.bindPopup(popupHtml);
        markers.set(`passenger-${passenger.passengerId}`, circleMarker);
      });
    }
  }, [drivers, passengers, showDrivers, showPassengers, filterType]);

  return (
    <main className="map-container">
      {/* Top Floating Filters */}
      <div className="map-filters">
        <label className="filter-chip">
          <input
            type="checkbox"
            checked={showDrivers}
            onChange={(e) => setShowDrivers(e.target.checked)}
            style={{ width: '14px', height: '14px', accentColor: 'var(--accent)' }}
          />
          Drivers ({drivers.length})
        </label>
        <label className="filter-chip">
          <input
            type="checkbox"
            checked={showPassengers}
            onChange={(e) => setShowPassengers(e.target.checked)}
            style={{ width: '14px', height: '14px', accentColor: 'var(--success)' }}
          />
          Passengers ({passengers.length})
        </label>
        <label className="filter-chip">
          Transit Mode
          <select value={filterType} onChange={(e) => setFilterType(e.target.value)}>
            <option value="ALL">All Modes</option>
            <option value="COMBI">Combi</option>
            <option value="TAXI">Taxi</option>
            <option value="BUS">Bus</option>
          </select>
        </label>
      </div>

      {/* Floating Status Controls */}
      <div className="map-floating-controls">
        <div className="floating-card">
          <input
            type="checkbox"
            id="heatmap-toggle"
            checked={heatmapEnabled}
            onChange={(e) => setHeatmapEnabled(e.target.checked)}
            style={{ width: '16px', height: '16px', accentColor: 'var(--accent)' }}
          />
          <label htmlFor="heatmap-toggle" style={{ cursor: 'pointer' }}>Demand Overlay</label>
        </div>

        <div className="floating-card" style={{ color: 'var(--accent)' }}>
          <Activity size={15} />
          <span>{drivers.length} Active Fleet Units</span>
        </div>
      </div>

      {/* Leaflet DOM Element */}
      <div ref={mapContainerRef} className="map-element" />
    </main>
  );
}
