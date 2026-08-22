import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/driver_model.dart';
import '../models/hail_request_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';

enum PassengerTripStatus { idle, searchingTaxi, hailPending, driverAccepted, onBoard, completed }

class TransitProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();
  final LocationService _location = LocationService();

  // State
  List<TransitRoute> _routes = [];
  List<TransitStop> _stops = [];
  TransitRoute? _selectedRoute;
  final Map<String, LiveDriver> _activeDrivers = {};
  
  LatLng _currentLocation = const LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
  bool _isConnected = false;

  // Passenger State
  PassengerTripStatus _passengerStatus = PassengerTripStatus.idle;
  String? _assignedDriverId;
  double? _estimatedFare;
  String? _currentRequestId;
  int? _etaSeconds;
  double? _etaDistanceMeters;

  // Driver State
  bool _isDriverOnline = false;
  SpacingAdvisory? _spacingAdvisory;
  final List<HailRequest> _incomingHails = [];
  HailRequest? _latestHailAlert;
  String? _lastStopRequest;
  int _passengersCarried = 0;

  // Live vehicle speed received from ETA updates (used by passenger for stop logic)
  double _vehicleSpeedKmh = 0.0;

  // Getters
  List<TransitRoute> get routes => _routes;
  List<TransitStop> get stops => _stops;
  TransitRoute? get selectedRoute => _selectedRoute;
  List<LiveDriver> get activeDrivers => _activeDrivers.values.toList();
  LatLng get currentLocation => _currentLocation;
  bool get isConnected => _isConnected;
  PassengerTripStatus get passengerStatus => _passengerStatus;
  String? get assignedDriverId => _assignedDriverId;
  double? get estimatedFare => _estimatedFare;
  String? get currentRequestId => _currentRequestId;
  int? get etaSeconds => _etaSeconds;
  double? get etaDistanceMeters => _etaDistanceMeters;
  String get etaDisplay {
    if (_etaSeconds == null || _etaSeconds! <= 0) return 'Arriving Soon';
    final mins = (_etaSeconds! / 60).round();
    if (mins <= 1) return '1 min (Arriving)';
    return '$mins mins';
  }
  bool get isDriverOnline => _isDriverOnline;
  SpacingAdvisory? get spacingAdvisory => _spacingAdvisory;
  List<HailRequest> get incomingHails => _incomingHails;
  HailRequest? get latestHailAlert => _latestHailAlert;
  String? get lastStopRequest => _lastStopRequest;
  int get passengersCarried => _passengersCarried;
  double get vehicleSpeedKmh => _vehicleSpeedKmh;

  void dismissHailAlert() {
    _latestHailAlert = null;
    notifyListeners();
  }

  void dismissStopRequest() {
    _lastStopRequest = null;
    notifyListeners();
  }

  TransitProvider() {
    init();
  }

  Future<void> init() async {
    await fetchInitialData();
    await updateCurrentLocation();
  }

  Future<void> fetchInitialData() async {
    _routes = await _api.fetchRoutes();
    _stops = await _api.fetchStops();
    if (_routes.isNotEmpty && _selectedRoute == null) {
      _selectedRoute = _routes.first;
    }
    notifyListeners();
  }

  Future<void> updateCurrentLocation() async {
    _currentLocation = await _location.getCurrentLocation();
    notifyListeners();
  }

  void selectRoute(TransitRoute route, String role) {
    _selectedRoute = route;
    if (_isConnected) {
      _socket.emit('subscribe-route', {'role': role, 'routeId': route.id});
      if (role == 'passengers') {
        _socket.emit('passenger-location', {
          'routeId': route.id,
          'coords': {'lat': _currentLocation.latitude, 'lng': _currentLocation.longitude}
        });
      }
    }
    notifyListeners();
  }

  // --- WEBSOCKET INITIALIZATION ---
  void connectSocket({required String role, required String userId, String? routeId}) {
    _socket.connect(
      onConnect: (_) {
        _isConnected = true;
        _socket.emit('join', {
          'role': role,
          'id': userId,
          'driverId': userId,
          'passengerId': userId,
          'routeId': routeId ?? _selectedRoute?.id ?? 'route-u01',
          'coords': {'lat': _currentLocation.latitude, 'lng': _currentLocation.longitude}
        });
        if (role == 'passengers') {
          _socket.emit('passenger-location', {
            'passengerId': userId,
            'routeId': routeId ?? _selectedRoute?.id ?? 'route-u01',
            'coords': {'lat': _currentLocation.latitude, 'lng': _currentLocation.longitude}
          });
        }
        notifyListeners();
      },
      onDisconnect: (_) {
        _isConnected = false;
        notifyListeners();
      },
      listeners: {
        'driver-location': (data) {
          if (data is Map<String, dynamic>) {
            final driver = LiveDriver.fromJson(data);
            _activeDrivers[driver.driverId] = driver;
            notifyListeners();
          }
        },
        'vehicle-update': (data) {
          if (data is Map<String, dynamic>) {
            final driver = LiveDriver.fromJson(data);
            _activeDrivers[driver.driverId] = driver;
            notifyListeners();
          }
        },
        'fleet-update': (data) {
          if (data is Map<String, dynamic> && data['type'] == 'driver') {
            final driver = LiveDriver.fromJson(data);
            _activeDrivers[driver.driverId] = driver;
            notifyListeners();
          }
        },
        'fleet-remove': (data) {
          if (data is Map<String, dynamic> && data['type'] == 'driver') {
            _activeDrivers.remove(data['id']);
            notifyListeners();
          }
        },
        'eta-update': (data) {
          if (data is Map<String, dynamic>) {
            _etaSeconds = data['etaSeconds'];
            _etaDistanceMeters = (data['distanceMeters'] as num?)?.toDouble();
            final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;
            // Keep vehicle speed updated so passenger UI can show "I've Arrived" when stationary
            _vehicleSpeedKmh = speed;
            notifyListeners();
          }
        },
        'spacing-advisory': (data) {
          if (data is Map<String, dynamic>) {
            _spacingAdvisory = SpacingAdvisory.fromJson(data);
            notifyListeners();
          }
        },
        'new-hail': (data) {
          if (data is Map<String, dynamic>) {
            final hail = HailRequest.fromJson(data);
            _incomingHails.removeWhere((h) => h.requestId == hail.requestId || h.passengerId == hail.passengerId);
            _incomingHails.add(hail);
            _latestHailAlert = hail;
            notifyListeners();
          }
        },
        'new-taxi-request': (data) {
          if (data is Map<String, dynamic>) {
            final hail = HailRequest.fromJson(data);
            _incomingHails.removeWhere((h) => h.requestId == hail.requestId || h.passengerId == hail.passengerId);
            _incomingHails.add(hail);
            _latestHailAlert = hail;
            notifyListeners();
          }
        },
        'stop-requested': (data) {
          _lastStopRequest = 'Passenger signaling stop ahead';
          notifyListeners();
        },
        'passenger-boarded': (data) {
          if (data is Map<String, dynamic>) {
            final pId = data['passengerId'] ?? data['passenger_id'];
            _incomingHails.removeWhere((h) => h.passengerId == pId);
            if (_latestHailAlert?.passengerId == pId) {
              _latestHailAlert = null;
            }
            // Increment driver's live passenger count when a passenger confirms boarding
            _passengersCarried += 1;
            notifyListeners();
          }
        },
        'hail-cancelled': (data) {
          if (data is Map<String, dynamic>) {
            final pId = data['passengerId'];
            _incomingHails.removeWhere((h) => h.passengerId == pId);
            if (_latestHailAlert?.passengerId == pId) {
              _latestHailAlert = null;
            }
            notifyListeners();
          }
        },
        'active-drivers-snapshot': (data) {
          if (data is List) {
            for (var item in data) {
              if (item is Map<String, dynamic>) {
                final d = LiveDriver.fromJson(item);
                _activeDrivers[d.driverId] = d;
              }
            }
            notifyListeners();
          }
        },
        'hail-accepted': (data) {
          if (data is Map<String, dynamic>) {
            _assignedDriverId = data['driverId'];
            _estimatedFare = (data['fareEstimate'] as num?)?.toDouble() ?? 8.0;
            _passengerStatus = PassengerTripStatus.driverAccepted;
            notifyListeners();
          }
        },
        'taxi-arrived': (data) {
          if (data is Map<String, dynamic>) {
            _assignedDriverId = data['driverId'] ?? _assignedDriverId;
            _passengerStatus = PassengerTripStatus.driverAccepted;
            notifyListeners();
          }
        },
        'driver-arrived-pickup': (data) {
          if (data is Map<String, dynamic>) {
            _assignedDriverId = data['driverId'] ?? _assignedDriverId;
            _passengerStatus = PassengerTripStatus.driverAccepted;
            notifyListeners();
          }
        },
        'boarding-confirmed': (data) {
          _passengerStatus = PassengerTripStatus.onBoard;
          notifyListeners();
        },
        'trip-started': (data) {
          _passengerStatus = PassengerTripStatus.onBoard;
          notifyListeners();
        },
        'trip-completed': (data) {
          if (data is Map<String, dynamic>) {
            _estimatedFare = (data['fare'] as num?)?.toDouble() ?? _estimatedFare;
          }
          _passengerStatus = PassengerTripStatus.completed;
          notifyListeners();
        },
        'taxi-trip-ended': (data) {
          if (data is Map<String, dynamic>) {
            _estimatedFare = (data['fare'] as num?)?.toDouble() ?? _estimatedFare;
          }
          _passengerStatus = PassengerTripStatus.completed;
          notifyListeners();
        },
      },
    );
  }

  // --- PASSENGER ACTIONS ---
  void requestCombiHail(String passengerId) {
    if (_selectedRoute == null) return;
    _passengerStatus = PassengerTripStatus.hailPending;
    _socket.emit('hail', {
      'passengerId': passengerId,
      'routeId': _selectedRoute!.id,
      'pickupLoc': {'lat': _currentLocation.latitude, 'lng': _currentLocation.longitude},
      'serviceType': 'COMBI'
    });
    notifyListeners();
  }

  void requestTaxiBooking({
    required String passengerId,
    required String serviceType,
    required LatLng pickup,
    LatLng? dropoff,
  }) {
    _passengerStatus = PassengerTripStatus.searchingTaxi;
    _socket.emit('passenger-request-taxi', {
      'passengerId': passengerId,
      'pickup': {'lat': pickup.latitude, 'lng': pickup.longitude},
      if (dropoff != null) 'dropoff': {'lat': dropoff.latitude, 'lng': dropoff.longitude},
      'serviceType': serviceType,
    });
    notifyListeners();
  }

  void confirmBoarding(String passengerId) {
    final driverId = _assignedDriverId ??
        (_activeDrivers.isNotEmpty ? _activeDrivers.keys.first : 'driver-1');
    final routeId = _selectedRoute?.id ?? 'route-u01';

    _socket.emit('boarding', {
      'driverId': driverId,
      'passengerId': passengerId,
      'routeId': routeId,
    });
    _assignedDriverId = driverId;
    _passengerStatus = PassengerTripStatus.onBoard;
    notifyListeners();
  }

  void updateDriverOccupancy({
    required String driverId,
    required String routeId,
    required String serviceType,
    required String vehicleId,
    required String occupancyText,
  }) {
    int paxCount = 0;
    if (occupancyText == 'Half Full') {
      paxCount = serviceType == 'BUS' ? 25 : 7;
    } else if (occupancyText == 'Almost Full') {
      paxCount = serviceType == 'BUS' ? 45 : 12;
    } else if (occupancyText == 'Full') {
      paxCount = serviceType == 'BUS' ? 60 : 15;
    }

    _socket.emit('driver-location', {
      'driverId': driverId,
      'serviceType': serviceType,
      'routeId': routeId,
      'vehicleId': vehicleId,
      'coords': {'lat': _currentLocation.latitude, 'lng': _currentLocation.longitude},
      'speed': 35.0,
      'heading': 0.0,
      'occupancy': paxCount,
      'occupancyText': occupancyText,
    });
    notifyListeners();
  }

  void submitRating({
    required String driverId,
    required String passengerId,
    required int rating,
    String? comment,
  }) {
    _socket.emit('driver-rating', {
      'driverId': driverId,
      'passengerId': passengerId,
      'rating': rating,
      'comment': comment,
    });
    _passengerStatus = PassengerTripStatus.idle;
    _assignedDriverId = null;
    notifyListeners();
  }

  void markPassengerCompleted() {
    _passengerStatus = PassengerTripStatus.completed;
    notifyListeners();
  }

  void requestStop({required String passengerId}) {
    final routeId = _selectedRoute?.id ?? '';
    _socket.emit('request-stop', {
      'passengerId': passengerId,
      'routeId': routeId,
      'driverId': _assignedDriverId,
    });
  }

  void cancelHail(String passengerId) {
    final routeId = _selectedRoute?.id ?? 'taxi-service';
    _socket.emit('cancel-hail', {
      'passengerId': passengerId,
      'routeId': routeId,
    });
    _passengerStatus = PassengerTripStatus.idle;
    _assignedDriverId = null;
    _currentRequestId = null;
    notifyListeners();
  }

  void resetPassengerTrip({String? passengerId}) {
    if (passengerId != null) {
      cancelHail(passengerId);
    } else {
      _passengerStatus = PassengerTripStatus.idle;
      _assignedDriverId = null;
      _currentRequestId = null;
      notifyListeners();
    }
  }

  // --- DRIVER ACTIONS ---
  void toggleDriverOnline({
    required String driverId,
    required String serviceType,
    required String routeId,
    required String vehicleId,
  }) {
    _isDriverOnline = !_isDriverOnline;
    if (_isDriverOnline) {
      _socket.emit('driver-online', {
        'driverId': driverId,
        'routeId': routeId,
        'serviceType': serviceType,
        'vehicleId': vehicleId,
      });

      _location.startLocationTracking((pos, speed, heading) {
        _currentLocation = pos;
        _socket.emit('driver-location', {
          'driverId': driverId,
          'routeId': routeId,
          'serviceType': serviceType,
          'coords': {'lat': pos.latitude, 'lng': pos.longitude},
          'speed': speed,
          'heading': heading,
          'occupancy': 5,
        });
        notifyListeners();
      });
    } else {
      _location.stopLocationTracking();
      _socket.emit('driver-offline', {'driverId': driverId});
      _incomingHails.clear();
      _spacingAdvisory = null;
      // Reset shift counters when going offline
      _passengersCarried = 0;
    }
    notifyListeners();
  }

  void acceptHail(HailRequest hail, String driverId) {
    _socket.emit('accept-hail', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'routeId': hail.routeId,
      'requestId': hail.requestId,
    });
    _incomingHails.removeWhere((h) => h.requestId == hail.requestId);
    notifyListeners();
  }

  void rejectHail(HailRequest hail, String driverId) {
    _socket.emit('reject-hail', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'routeId': hail.routeId,
    });
    _incomingHails.removeWhere((h) => h.requestId == hail.requestId);
    notifyListeners();
  }

  void notifyDriverArrived(HailRequest hail, String driverId) {
    _socket.emit('driver-arrived', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'requestId': hail.requestId,
    });
  }

  void startTrip(HailRequest hail, String driverId) {
    _socket.emit('trip-start', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'requestId': hail.requestId,
      'routeId': hail.routeId,
      'type': hail.serviceType,
      'revenue': hail.fareEstimate,
    });
  }

  void endTrip(HailRequest hail, String driverId, double fare) {
    _socket.emit('trip-end', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'requestId': hail.requestId,
      'revenue': fare,
    });
  }

  @override
  void dispose() {
    _location.stopLocationTracking();
    _socket.disconnect();
    super.dispose();
  }
}
