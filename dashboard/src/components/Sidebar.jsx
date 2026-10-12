import React, { useEffect, useState } from 'react';
import { Link2 } from 'lucide-react';

export default function Sidebar({
  activeView,
  navItems = [],
  onNavigate,
  serverUrl,
  onServerUrlChange,
  onConnect,
  connection,
  modeCounts = {},
}) {
  const [urlInput, setUrlInput] = useState(serverUrl);

  useEffect(() => setUrlInput(serverUrl), [serverUrl]);

  const handleLink = (event) => {
    event.preventDefault();
    onServerUrlChange(urlInput);
    onConnect(urlInput);
  };

  return (
    <aside className="sidebar">
      <section>
        <div className="section-label">Primary Navigation</div>
        <nav className="nav-stack" aria-label="Command center navigation">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                type="button"
                className={activeView === item.id ? 'active' : ''}
                onClick={() => onNavigate(item.id)}
              >
                <Icon size={17} />
                <span>{item.label}</span>
                {item.mode && <small>{modeCounts[item.mode] ?? 0}</small>}
              </button>
            );
          })}
        </nav>
      </section>

      <section>
        <div className="section-label">Server Gateway Link</div>
        <form onSubmit={handleLink} className="sidebar-link-form">
          <input
            type="text"
            value={urlInput}
            onChange={(event) => setUrlInput(event.target.value)}
            placeholder="https://smart-transit-uhyf.onrender.com"
          />
          <button type="submit" className="btn-primary" title="Connect server">
            <Link2 size={15} />
          </button>
        </form>
        <div className="preset-row">
          <button type="button" onClick={() => {
            const url = 'https://smart-transit-uhyf.onrender.com';
            setUrlInput(url);
            onServerUrlChange(url);
            onConnect(url);
          }}>
            Cloud
          </button>
          <button type="button" onClick={() => {
            const url = 'http://10.189.239.26:8000';
            setUrlInput(url);
            onServerUrlChange(url);
            onConnect(url);
          }}>
            LAN
          </button>
          <button type="button" onClick={() => {
            const url = 'http://localhost:8000';
            setUrlInput(url);
            onServerUrlChange(url);
            onConnect(url);
          }}>
            Localhost
          </button>
        </div>
      </section>

      <section className="sidebar-health">
        <div className="section-label">Observed Health</div>
        <div>
          <span>Backend</span>
          <strong>{connection?.backend || 'unknown'}</strong>
        </div>
        <div>
          <span>Database</span>
          <strong>{connection?.database || 'unknown'}</strong>
        </div>
        <div>
          <span>Socket</span>
          <strong>{connection?.socket || 'unknown'}</strong>
        </div>
      </section>
    </aside>
  );
}
