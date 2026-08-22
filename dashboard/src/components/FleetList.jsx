import React, { useState } from 'react';
import { Car, User, Navigation } from 'lucide-react';

export default function FleetList({ drivers = [], passengers = [], hails = [] }) {
  const [activeTab, setActiveTab] = useState('drivers'); // 'drivers' | 'passengers' | 'hails'

  return (
    <section style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      <div className="section-label">
        <span>Fleet & Rider Log</span>
        <div style={{ display: 'flex', gap: '6px' }}>
          <button
            onClick={() => setActiveTab('drivers')}
            style={{
              background: activeTab === 'drivers' ? 'var(--accent)' : 'rgba(15,20,34,0.6)',
              color: 'white',
              border: 'none',
              padding: '2px 8px',
              borderRadius: '6px',
              fontSize: '0.68rem',
              fontWeight: 700,
              cursor: 'pointer',
            }}
          >
            Fleet ({drivers.length})
          </button>
          <button
            onClick={() => setActiveTab('passengers')}
            style={{
              background: activeTab === 'passengers' ? 'var(--success)' : 'rgba(15,20,34,0.6)',
              color: 'white',
              border: 'none',
              padding: '2px 8px',
              borderRadius: '6px',
              fontSize: '0.68rem',
              fontWeight: 700,
              cursor: 'pointer',
            }}
          >
            Riders ({passengers.length})
          </button>
          <button
            onClick={() => setActiveTab('hails')}
            style={{
              background: activeTab === 'hails' ? '#f59e0b' : 'rgba(15,20,34,0.6)',
              color: 'white',
              border: 'none',
              padding: '2px 8px',
              borderRadius: '6px',
              fontSize: '0.68rem',
              fontWeight: 700,
              cursor: 'pointer',
            }}
          >
            Hails ({hails.length})
          </button>
        </div>
      </div>

      <div className="list-stack" style={{ overflowY: 'auto', flex: 1, paddingRight: '4px' }}>
        {activeTab === 'drivers' && drivers.length === 0 && (
          <div style={{ color: 'var(--text-muted)', fontSize: '0.78rem', textAlign: 'center', padding: '16px 0' }}>
            No active fleet units online
          </div>
        )}

        {activeTab === 'drivers' &&
          drivers.map((d, index) => {
            const isTaxi = d.serviceType === 'TAXI' || d.routeId === 'taxi-service';
            const isBus = d.serviceType === 'BUS' || (d.routeId && d.routeId.startsWith('bus-'));
            const typeLabel = isTaxi ? 'TAXI' : isBus ? 'BUS' : 'COMBI';

            return (
              <div className="item-row" key={d.driverId || index}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div
                    style={{
                      padding: '6px',
                      borderRadius: '8px',
                      background: 'rgba(91, 140, 255, 0.15)',
                      color: 'var(--accent)',
                    }}
                  >
                    <Car size={16} />
                  </div>
                  <div className="item-meta">
                    <b>Driver {d.driverId?.length > 12 ? d.driverId.slice(-6) : d.driverId}</b>
                    <span>
                      {d.routeId || typeLabel} • {d.vehiclePlate || 'B-BW'}
                      {d.rating && ` • ⭐ ${Number(d.rating).toFixed(1)}`}
                    </span>
                  </div>
                </div>
                <span className="badge-pill">
                  {d.occupancy !== undefined ? `${d.occupancy} PAX` : typeLabel}
                </span>
              </div>
            );
          })}

        {activeTab === 'passengers' && passengers.length === 0 && (
          <div style={{ color: 'var(--text-muted)', fontSize: '0.78rem', textAlign: 'center', padding: '16px 0' }}>
            No active passengers waiting
          </div>
        )}

        {activeTab === 'passengers' &&
          passengers.map((p, index) => (
            <div className="item-row" key={p.passengerId || index}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div
                  style={{
                    padding: '6px',
                    borderRadius: '8px',
                    background: 'rgba(34, 197, 94, 0.15)',
                    color: 'var(--success)',
                  }}
                >
                  <User size={16} />
                </div>
                <div className="item-meta">
                  <b>Rider {p.passengerId?.length > 12 ? p.passengerId.slice(-6) : p.passengerId}</b>
                  <span>{p.routeId || 'Awaiting Combi/Taxi'}</span>
                </div>
              </div>
              <span className="badge-pill warning">WAITING</span>
            </div>
          ))}

        {activeTab === 'hails' && hails.length === 0 && (
          <div style={{ color: 'var(--text-muted)', fontSize: '0.78rem', textAlign: 'center', padding: '16px 0' }}>
            No active hail requests
          </div>
        )}

        {activeTab === 'hails' &&
          hails.map((h, index) => (
            <div className="item-row" key={h.requestId || h.passengerId || index}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div
                  style={{
                    padding: '6px',
                    borderRadius: '8px',
                    background: 'rgba(245, 158, 11, 0.15)',
                    color: '#f59e0b',
                  }}
                >
                  <Navigation size={16} />
                </div>
                <div className="item-meta">
                  <b>{h.serviceType || 'TAXI'} Hail</b>
                  <span>{h.routeId || 'On-Demand'} • Rider {h.passengerId?.slice(-6) || ''}</span>
                </div>
              </div>
              <span className="badge-pill warning">
                {h.fareEstimate ? `P${Number(h.fareEstimate).toFixed(2)}` : 'PENDING'}
              </span>
            </div>
          ))}
      </div>
    </section>
  );
}
