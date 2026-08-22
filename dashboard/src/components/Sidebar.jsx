import React, { useState } from 'react';
import MetricsGrid from './MetricsGrid';
import FleetChart from './FleetChart';
import FleetList from './FleetList';
import { Link2 } from 'lucide-react';

export default function Sidebar({
  serverUrl,
  onServerUrlChange,
  onConnect,
  drivers = [],
  passengers = [],
  hails = [],
  routesCount = 8,
  hailsCount = 0,
  chartData = [],
}) {
  const [urlInput, setUrlInput] = useState(serverUrl);

  const handleLink = (e) => {
    e.preventDefault();
    onServerUrlChange(urlInput);
    onConnect(urlInput);
  };

  return (
    <aside className="sidebar">
      {/* Real-time Capacity Metrics */}
      <MetricsGrid
        driversCount={drivers.length}
        passengersCount={passengers.length}
        routesCount={routesCount}
        hailsCount={hailsCount}
      />

      {/* Fleet Distribution Chart */}
      <FleetChart dataPoints={chartData.length > 0 ? chartData : undefined} />

      {/* Connection Management */}
      <section>
        <div className="section-label">Server Gateway Link (Cloud / LAN)</div>
        <form onSubmit={handleLink} style={{ display: 'flex', gap: '8px', marginBottom: '8px' }}>
          <input
            type="text"
            value={urlInput}
            onChange={(e) => setUrlInput(e.target.value)}
            placeholder="https://smart-transit-uhyf.onrender.com"
          />
          <button type="submit" className="btn-primary" title="Connect WebSocket Server">
            <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              <Link2 size={15} />
              Link
            </span>
          </button>
        </form>
        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          <button
            type="button"
            className="btn-secondary"
            style={{ fontSize: '11px', padding: '3px 8px' }}
            onClick={() => {
              const u = 'https://smart-transit-uhyf.onrender.com';
              setUrlInput(u);
              onServerUrlChange(u);
              onConnect(u);
            }}
          >
            Cloud (Render)
          </button>
          <button
            type="button"
            className="btn-secondary"
            style={{ fontSize: '11px', padding: '3px 8px' }}
            onClick={() => {
              const u = 'http://10.189.239.26:8000';
              setUrlInput(u);
              onServerUrlChange(u);
              onConnect(u);
            }}
          >
            LAN (10.189)
          </button>
          <button
            type="button"
            className="btn-secondary"
            style={{ fontSize: '11px', padding: '3px 8px' }}
            onClick={() => {
              const u = 'http://localhost:8000';
              setUrlInput(u);
              onServerUrlChange(u);
              onConnect(u);
            }}
          >
            Localhost
          </button>
        </div>
      </section>

      {/* Real-time Fleet & Rider Log */}
      <FleetList drivers={drivers} passengers={passengers} hails={hails} />
    </aside>
  );
}
