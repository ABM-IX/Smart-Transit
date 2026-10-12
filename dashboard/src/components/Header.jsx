import React, { useEffect, useState } from 'react';
import { AlertTriangle, Database, Radio, ShieldCheck } from 'lucide-react';
import { isSupabaseConfigured } from '../services/supabaseClient';

export default function Header({ isConnected, connection, statusMessage, onEmergencyAlert }) {
  const [timeStr, setTimeStr] = useState('');

  useEffect(() => {
    const updateTime = () => {
      setTimeStr(new Date().toLocaleTimeString('en-GB', {
        hour12: false,
        timeZone: 'Africa/Gaborone',
      }));
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  const dbConnected = connection?.database === 'connected';

  return (
    <header className="app-header">
      <div className="brand-container">
        <img
          src="/Gemini_Generated_Image_pptoivpptoivppto.png"
          alt="SmartTransit"
          className="logo-img"
          onError={(event) => {
            event.currentTarget.style.display = 'none';
          }}
        />
        <div className="header-info">
          <h1>SmartTransit Command Center</h1>
          <p>{timeStr || '00:00:00'} - Gaborone Transit Grid</p>
        </div>
      </div>

      <div className="header-actions">
        <div className="status-pill" title="Database status reported by backend health endpoint">
          <Database size={14} />
          <span>{dbConnected ? 'DB CONNECTED' : isSupabaseConfigured() ? 'SUPABASE CONFIGURED' : 'DB UNVERIFIED'}</span>
        </div>

        <div className="status-pill" title={statusMessage || 'Socket.IO telemetry gateway'}>
          <Radio size={14} />
          <div className={`dot ${isConnected ? 'online' : ''}`} />
          <span>{isConnected ? 'TELEMETRY LIVE' : 'TELEMETRY OFFLINE'}</span>
        </div>

        <div className="status-pill" title="Security state is not asserted unless backend verifies it">
          <ShieldCheck size={14} />
          <span>AUTH PRESERVED</span>
        </div>

        <button
          className="emergency-btn"
          onClick={onEmergencyAlert}
          title="Prepare emergency advisory"
          type="button"
        >
          <AlertTriangle size={14} />
          Emergency Alert
        </button>
      </div>
    </header>
  );
}
