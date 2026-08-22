import React from 'react';

export default function MetricsGrid({ driversCount, passengersCount, routesCount, hailsCount }) {
  return (
    <section>
      <div className="section-label">Real-time Capacity</div>
      <div className="metrics-grid">
        <div className="metric-item">
          <span className="metric-val" style={{ color: 'var(--accent)' }}>
            {driversCount}
          </span>
          <span className="metric-label">Active Fleet</span>
        </div>
        <div className="metric-item">
          <span className="metric-val" style={{ color: 'var(--success)' }}>
            {passengersCount}
          </span>
          <span className="metric-label">Live Riders</span>
        </div>
        <div className="metric-item">
          <span className="metric-val" style={{ color: 'var(--text-primary)' }}>
            {routesCount}
          </span>
          <span className="metric-label">Transit Routes</span>
        </div>
        <div className="metric-item">
          <span className="metric-val" style={{ color: 'var(--warning)' }}>
            {hailsCount}
          </span>
          <span className="metric-label">Active Hails</span>
        </div>
      </div>
    </section>
  );
}
