import React, { useState, useEffect, useCallback } from 'react';
import Header from './components/Header';
import Sidebar from './components/Sidebar';
import LiveMap from './components/LiveMap';
import { socketService } from './services/socketService';

export default function App() {
  const [serverUrl, setServerUrl] = useState(() => {
    return localStorage.getItem('smarttransit_backend_url') ||
      import.meta.env.VITE_BACKEND_URL ||
      'https://smart-transit-uhyf.onrender.com';
  });
  const [isConnected, setIsConnected] = useState(false);
  const [drivers, setDrivers] = useState(new Map());
  const [passengers, setPassengers] = useState(new Map());
  const [hails, setHails] = useState([]);
  const [chartData, setChartData] = useState([2, 4, 3, 6, 7, 5, 8, 9, 7, 10, 11, 9, 12, 14, 13]);

  const handleServerUrlChange = (newUrl) => {
    const trimmed = newUrl.trim();
    setServerUrl(trimmed);
    localStorage.setItem('smarttransit_backend_url', trimmed);
  };


  // Connect to backend WebSocket
  const connectToServer = useCallback((url) => {
    socketService.connect(url, {
      onConnect: () => {
        setIsConnected(true);
      },
      onDisconnect: () => {
        setIsConnected(false);
      },
      onSnapshot: (snapshot) => {
        if (!snapshot) return;
        if (Array.isArray(snapshot.drivers)) {
          const nextDrivers = new Map();
          snapshot.drivers.forEach((d) => {
            const id = d.driverId || d.driver_id || d.id;
            if (id && d.status !== 'OFFLINE') {
              nextDrivers.set(id, { ...d, driverId: id, driver_id: id });
            }
          });
          setDrivers(nextDrivers);
        }

        if (Array.isArray(snapshot.passengers)) {
          const nextPassengers = new Map();
          snapshot.passengers.forEach((p) => {
            const id = p.passengerId || p.passenger_id || p.id;
            if (id) {
              nextPassengers.set(id, { ...p, passengerId: id, passenger_id: id });
            }
          });
          setPassengers(nextPassengers);
        }

        if (Array.isArray(snapshot.hails)) {
          setHails(snapshot.hails);
        }
      },
      onFleetUpdate: (data) => {
        if (!data) return;
        const driverId = data.driverId || data.driver_id || (data.type === 'driver' ? data.id : null);
        const passengerId = data.passengerId || data.passenger_id || (data.type === 'passenger' ? data.id : null);

        if (data.type === 'driver' || driverId) {
          if (!driverId) return; // Prevent setting undefined key
          setDrivers((prev) => {
            const next = new Map(prev);
            if (data.status === 'OFFLINE') {
              next.delete(driverId);
            } else {
              next.set(driverId, { ...data, driverId, driver_id: driverId });
            }
            return next;
          });
        } else if (data.type === 'passenger' || passengerId) {
          if (!passengerId) return; // Prevent setting undefined key
          setPassengers((prev) => {
            const next = new Map(prev);
            next.set(passengerId, { ...data, passengerId, passenger_id: passengerId });
            return next;
          });
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
          return [data, ...filtered.slice(0, 19)];
        });
        if (data.pickupLoc || data.coords) {
          const pId = data.passengerId || data.passenger_id;
          if (pId) {
            setPassengers((prev) => {
              const next = new Map(prev);
              next.set(pId, {
                passengerId: pId,
                coords: data.pickupLoc || data.coords,
                routeId: data.routeId || 'taxi-service',
                status: 'WAITING'
              });
              return next;
            });
          }
        }
      },
      onHailAccepted: (data) => {
        if (!data) return;
        const pId = data.passengerId || data.passenger_id;
        const reqId = data.requestId;
        setHails((prev) => prev.filter((h) => h.requestId !== reqId && (h.passengerId || h.passenger_id) !== pId));
      },
      onHailCancelled: (data) => {
        if (!data) return;
        const pId = data.passengerId || data.passenger_id;
        setHails((prev) => prev.filter((h) => (h.passengerId || h.passenger_id) !== pId));
      },
    });
  }, []);

  // Initial connection
  useEffect(() => {
    connectToServer(serverUrl);
    return () => socketService.disconnect();
  }, [connectToServer, serverUrl]);

  // Broadcast Emergency Alert
  const handleEmergencyAlert = () => {
    if (confirm('Broadcast emergency transit alert to all active drivers and dispatch?')) {
      socketService.emit('emergency-alert', {
        timestamp: new Date().toISOString(),
        issuer: 'Command Center Dispatch',
        severity: 'HIGH',
      });
      alert('Emergency transit advisory broadcasted across the active fleet network.');
    }
  };

  const driversList = Array.from(drivers.values());
  const passengersList = Array.from(passengers.values());

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
      <Header isConnected={isConnected} onEmergencyAlert={handleEmergencyAlert} />

      <div className="workspace">
        <Sidebar
          serverUrl={serverUrl}
          onServerUrlChange={handleServerUrlChange}
          onConnect={connectToServer}
          drivers={driversList}
          passengers={passengersList}
          hails={hails}
          routesCount={6}
          hailsCount={hails.length}
          chartData={chartData}
        />

        <LiveMap
          drivers={driversList}
          passengers={passengersList}
        />
      </div>
    </div>
  );
}
