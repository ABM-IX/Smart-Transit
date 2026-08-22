import React, { useState, useEffect } from 'react';
import { Shield, Radio, Database, AlertTriangle } from 'lucide-react';
import { isSupabaseConfigured } from '../services/supabaseClient';

export default function Header({ isConnected, onEmergencyAlert }) {
  const [timeStr, setTimeStr] = useState('');

  useEffect(() => {
    const updateTime = () => {
      setTimeStr(new Date().toLocaleTimeString('en-US', { hour12: false }));
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <header>
      <div className="brand-container">
        <img
          src="/Gemini_Generated_Image_pptoivpptoivppto.png"
          alt="SmartTransit Logo"
          className="logo-img"
          onError={(e) => {
            e.target.style.display = 'none';
          }}
        />
        <div className="header-info">
          <h1>SmartTransit Command Center</h1>
          <p>{timeStr || '00:00:00'} • Gaborone Transit Grid</p>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
        {/* Supabase status badge */}
        <div className="status-pill" title="Supabase Database Status">
          <Database size={14} color={isSupabaseConfigured() ? '#22c55e' : '#94a3b8'} />
          <span style={{ fontSize: '0.72rem', color: isSupabaseConfigured() ? '#86efac' : '#94a3b8' }}>
            {isSupabaseConfigured() ? 'SUPABASE ACTIVE' : 'LOCAL DB'}
          </span>
        </div>

        {/* WebSocket Connection pill */}
        <div className="status-pill">
          <div className={`dot ${isConnected ? 'online' : ''}`} />
          <span>{isConnected ? 'SYSTEM SECURED' : 'DISCONNECTED'}</span>
        </div>

        {/* Emergency Alert Button */}
        <button
          className="emergency-btn"
          onClick={onEmergencyAlert}
          title="Broadcast Emergency Fleet Alert"
        >
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
            <AlertTriangle size={13} />
            EMERGENCY ALERT
          </span>
        </button>
      </div>
    </header>
  );
}
