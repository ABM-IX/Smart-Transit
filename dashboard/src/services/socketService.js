import { io } from 'socket.io-client';

class DashboardSocketService {
  constructor() {
    this.socket = null;
    this.isConnected = false;
  }

  connect(url, { onConnect, onDisconnect, onSnapshot, onFleetUpdate, onFleetRemove, onNewHail, onHailAccepted, onHailCancelled }) {
    if (this.socket) {
      this.socket.disconnect();
    }

    this.socket = io(url, {
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionAttempts: 15,
      reconnectionDelay: 1000
    });

    this.socket.on('connect', () => {
      this.isConnected = true;
      this.socket.emit('join', { role: 'dashboard', id: 'cmd-center-01' });
      if (onConnect) onConnect();
    });

    this.socket.on('disconnect', () => {
      this.isConnected = false;
      if (onDisconnect) onDisconnect();
    });

    this.socket.on('dashboard-snapshot', (snapshot) => {
      if (onSnapshot) onSnapshot(snapshot);
    });

    this.socket.on('fleet-update', (data) => {
      if (onFleetUpdate) onFleetUpdate(data);
    });

    this.socket.on('fleet-remove', (data) => {
      if (onFleetRemove) onFleetRemove(data);
    });

    this.socket.on('new-hail', (data) => {
      if (onNewHail) onNewHail(data);
    });

    this.socket.on('hail-accepted', (data) => {
      if (onHailAccepted) onHailAccepted(data);
    });

    this.socket.on('hail-cancelled', (data) => {
      if (onHailCancelled) onHailCancelled(data);
    });
  }

  emit(event, data) {
    if (this.socket && this.isConnected) {
      this.socket.emit(event, data);
    }
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
      this.isConnected = false;
    }
  }
}

export const socketService = new DashboardSocketService();
