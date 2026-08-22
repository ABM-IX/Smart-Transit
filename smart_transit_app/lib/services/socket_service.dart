import 'package:socket_io_client/socket_io_client.dart' as io_client;
import '../core/constants.dart';

class SocketService {
  io_client.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void connect({
    String? serverUrl,
    required Function(dynamic) onConnect,
    required Function(dynamic) onDisconnect,
    required Map<String, Function(dynamic)> listeners,
  }) {
    if (_socket != null && _isConnected) return;
    final targetUrl = serverUrl ?? AppConstants.defaultServerUrl;

    _socket = io_client.io(
      targetUrl,
      io_client.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((data) {
      _isConnected = true;
      onConnect(data);
    });

    _socket!.onDisconnect((data) {
      _isConnected = false;
      onDisconnect(data);
    });

    _socket!.onConnectError((err) {});

    // Register dynamic event listeners
    listeners.forEach((event, handler) {
      _socket!.on(event, handler);
    });

    _socket!.connect();
  }

  void emit(String event, dynamic data) {
    if (_socket != null) {
      _socket!.emit(event, data);
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }
}
