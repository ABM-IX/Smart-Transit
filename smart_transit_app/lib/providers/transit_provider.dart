import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/driver_model.dart';
import '../models/hail_request_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';

enum PassengerTripStatus {
  idle,
  searchingTaxi,
  hailPending,
  driverAccepted,
  onBoard,
  completed,
}

String _historyServiceType(String serviceType) {
  final normalized = serviceType.toUpperCase();
  return normalized == 'STANDARD' || normalized == 'SPECIAL'
      ? 'TAXI'
      : normalized;
}

class TransitProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();
  final LocationService _location = LocationService();

  // State
  List<TransitRoute> _routes = [];
  List<TransitStop> _stops = [];
  TransitRoute? _selectedRoute;
  final Map<String, LiveDriver> _activeDrivers = {};

  LatLng _currentLocation = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  bool _isConnected = false;

  // Passenger State
  PassengerTripStatus _passengerStatus = PassengerTripStatus.idle;
  String? _assignedDriverId;
  String? _matchedDriverName;
  String? _matchedDriverPhone;
  String? _matchedDriverPlate;
  String? _matchedPassengerName;
  String? _matchedPassengerPhone;
  double? _estimatedFare;
  String? _currentRequestId;
  LatLng? _livePassengerLocation;
  int? _etaSeconds;
  double? _etaDistanceMeters;

  // Driver State
  bool _isDriverOnline = false;
  SpacingAdvisory? _spacingAdvisory;
  final List<HailRequest> _incomingHails = [];
  HailRequest? _latestHailAlert;
  String? _lastStopRequest;
  int _passengersCarried = 0;
  int _driverTripsCompleted = 0;

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
  LatLng? get livePassengerLocation => _livePassengerLocation;
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
  int get driverTripsCompleted => _driverTripsCompleted;
  double get vehicleSpeedKmh => _vehicleSpeedKmh;

  String? get matchedDriverName => _matchedDriverName;
  String? get matchedDriverPhone => _matchedDriverPhone;
  String? get matchedDriverPlate => _matchedDriverPlate;
  String? get matchedPassengerName => _matchedPassengerName;
  String? get matchedPassengerPhone => _matchedPassengerPhone;

  Future<Map<String, String>?> fetchUserContact(String userId) async {
    final row = await Supabase.instance.client
        .from('users')
        .select('full_name, phone_number')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return {
      'full_name': row['full_name']?.toString() ?? '',
      'phone_number': row['phone_number']?.toString() ?? '',
    };
  }

  Future<void> loadDriverTripCount(String driverId) async {
    try {
      final rows = await Supabase.instance.client
          .from('trips')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'COMPLETED');
      _driverTripsCompleted = rows.length;
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load driver trip total: $error');
    }
  }

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
          'coords': {
            'lat': _currentLocation.latitude,
            'lng': _currentLocation.longitude,
          },
        });
      }
    }
    notifyListeners();
  }

  // --- WEBSOCKET INITIALIZATION ---
  void connectSocket({
    required String role,
    required String userId,
    String? routeId,
  }) {
    _socket.connect(
      onConnect: (_) {
        _isConnected = true;
        _socket.emit('join', {
          'role': role,
          'id': userId,
          'driverId': userId,
          'passengerId': userId,
          'routeId': routeId ?? _selectedRoute?.id ?? '',
          'coords': {
            'lat': _currentLocation.latitude,
            'lng': _currentLocation.longitude,
          },
        });
        if (role == 'passengers') {
          _socket.emit('passenger-location', {
            'passengerId': userId,
            'routeId': routeId ?? _selectedRoute?.id ?? '',
            'coords': {
              'lat': _currentLocation.latitude,
              'lng': _currentLocation.longitude,
            },
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
            _matchedPassengerName = null;
            _matchedPassengerPhone = null;
            final hail = HailRequest.fromJson(data);
            _incomingHails.removeWhere(
              (h) =>
                  h.requestId == hail.requestId ||
                  h.passengerId == hail.passengerId,
            );
            _incomingHails.add(hail);
            _latestHailAlert = hail;
            notifyListeners();
          }
        },
        'hail-queued': (data) {
          if (data is Map<String, dynamic>) {
            _currentRequestId = data['requestId']?.toString();
            notifyListeners();
          }
        },
        'taxi-dispatched': (data) {
          if (data is Map<String, dynamic>) {
            _currentRequestId = data['requestId']?.toString();
            notifyListeners();
          }
        },
        'new-taxi-request': (data) {
          if (data is Map<String, dynamic>) {
            _matchedPassengerName = null;
            _matchedPassengerPhone = null;
            final hail = HailRequest.fromJson(data);
            _incomingHails.removeWhere(
              (h) =>
                  h.requestId == hail.requestId ||
                  h.passengerId == hail.passengerId,
            );
            _incomingHails.add(hail);
            _latestHailAlert = hail;
            notifyListeners();
          }
        },
        'passenger-location': (data) {
          if (data is Map<String, dynamic>) {
            final coords = data['coords'];
            if (coords is Map<String, dynamic>) {
              final lat = (coords['lat'] ?? coords['latitude']) as num?;
              final lng = (coords['lng'] ?? coords['longitude']) as num?;
              if (lat != null && lng != null) {
                _livePassengerLocation = LatLng(lat.toDouble(), lng.toDouble());
                notifyListeners();
              }
            }
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
            if (userId == (data['passengerId']?.toString())) {
              if (data['driverName'] != null) _matchedDriverName = data['driverName']?.toString();
              if (data['driverPhone'] != null) _matchedDriverPhone = data['driverPhone']?.toString();
              if (data['driverPlate'] != null) _matchedDriverPlate = data['driverPlate']?.toString();
            } else if (userId == (data['driverId']?.toString())) {
              if (data['passengerName'] != null) _matchedPassengerName = data['passengerName']?.toString();
              if (data['passengerPhone'] != null) _matchedPassengerPhone = data['passengerPhone']?.toString();
            }
            _estimatedFare =
                (data['fareEstimate'] as num?)?.toDouble() ??
                (_passengerStatus == PassengerTripStatus.searchingTaxi
                    ? AppConstants.taxiBaseFareBWP
                    : _selectedRoute?.baseFare ?? AppConstants.standardFareBWP);
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
            _estimatedFare =
                (data['fare'] as num?)?.toDouble() ?? _estimatedFare;
          }
          _passengerStatus = PassengerTripStatus.completed;
          notifyListeners();
        },
        'taxi-trip-ended': (data) {
          if (data is Map<String, dynamic>) {
            _estimatedFare =
                (data['fare'] as num?)?.toDouble() ?? _estimatedFare;
          }
          _passengerStatus = PassengerTripStatus.completed;
          notifyListeners();
        },
      },
    );
  }

  // --- PASSENGER ACTIONS ---
  void requestCombiHail(String passengerId, {String? serviceType}) {
    if (_selectedRoute == null) return;
    _currentRequestId = null;
    final resolvedType =
        serviceType ??
        (_selectedRoute!.routeType.toUpperCase() == 'BUS' ||
                _selectedRoute!.id.startsWith('bus-')
            ? 'BUS'
            : 'COMBI');
    _passengerStatus = PassengerTripStatus.hailPending;
    _estimatedFare = _selectedRoute!.baseFare;
    _socket.emit('hail', {
      'passengerId': passengerId,
      'routeId': _selectedRoute!.id,
      'pickupLoc': {
        'lat': _currentLocation.latitude,
        'lng': _currentLocation.longitude,
      },
      'serviceType': resolvedType,
      'fareEstimate': _selectedRoute!.baseFare,
    });
    notifyListeners();
  }

  void requestTaxiBooking({
    required String passengerId,
    required String serviceType,
    required LatLng pickup,
    LatLng? dropoff,
    double? offeredFare,
  }) {
    _currentRequestId = null;
    _matchedDriverName = null;
    _matchedDriverPhone = null;
    _matchedDriverPlate = null;
    _matchedPassengerName = null;
    _matchedPassengerPhone = null;
    _selectedRoute = null;
    _estimatedFare = AppConstants.taxiBaseFareBWP;
    _livePassengerLocation = pickup;
    _passengerStatus = PassengerTripStatus.searchingTaxi;
    _socket.emit('passenger-request-taxi', {
      'passengerId': passengerId,
      'pickup': {'lat': pickup.latitude, 'lng': pickup.longitude},
      if (dropoff != null)
        'dropoff': {'lat': dropoff.latitude, 'lng': dropoff.longitude},
      'serviceType': serviceType,
      if (offeredFare != null) 'offeredFare': offeredFare,
    });
    _location.startLocationTracking((pos, _, __) {
      _currentLocation = pos;
      _livePassengerLocation = pos;
      _socket.emit('passenger-location', {
        'passengerId': passengerId,
        'routeId': 'taxi-service',
        'coords': {'lat': pos.latitude, 'lng': pos.longitude},
      });
      notifyListeners();
    });
    notifyListeners();
  }

  void confirmBoarding(String passengerId) {
    final driverId =
        _assignedDriverId ??
        (_activeDrivers.isNotEmpty ? _activeDrivers.keys.first : 'driver-1');
    final routeId =
        _selectedRoute?.id ??
        (_routes.isNotEmpty ? _routes.first.id : 'transit-line');

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
    final normalizedServiceType = serviceType.toUpperCase();
    if (occupancyText == 'Half Full') {
      paxCount = normalizedServiceType == 'BUS' ? 25 : 7;
    } else if (occupancyText == 'Almost Full') {
      paxCount = normalizedServiceType == 'BUS' ? 45 : 12;
    } else if (occupancyText == 'Full') {
      paxCount = normalizedServiceType == 'BUS' ? 60 : 15;
    }

    _passengersCarried = paxCount;

    _socket.emit('driver-location', {
      'driverId': driverId,
      'serviceType': serviceType,
      'routeId': routeId,
      'vehicleId': vehicleId,
      'coords': {
        'lat': _currentLocation.latitude,
        'lng': _currentLocation.longitude,
      },
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

  void markPassengerCompleted({String? passengerId, double? finalFare}) {
    if (passengerId != null) {
      passengerEndTrip(passengerId: passengerId, finalFare: finalFare);
    } else {
      _passengerStatus = PassengerTripStatus.completed;
      notifyListeners();
    }
  }

  Future<void> passengerEndTrip({
    required String passengerId,
    String? driverId,
    double? finalFare,
  }) async {
    final dId = driverId ?? _assignedDriverId;
    final fallbackFare =
        _selectedRoute?.baseFare ?? AppConstants.taxiBaseFareBWP;
    final fare = finalFare ?? _estimatedFare ?? fallbackFare;
    final routeId = _selectedRoute?.id;
    final serviceType = _selectedRoute?.routeType.toUpperCase() ?? 'TAXI';

    _socket.emit('passenger-end-trip', {
      'passengerId': passengerId,
      'driverId': dId,
      'routeId': routeId ?? 'taxi-service',
      'requestId': _currentRequestId,
      'fare': fare,
      'serviceType': serviceType,
      'pickupName': _selectedRoute?.originName ?? 'Pickup Point',
      'dropoffName': _selectedRoute?.destinationName ?? 'Destination',
      'pickup': {
        'lat': _livePassengerLocation?.latitude ?? _currentLocation.latitude,
        'lng': _livePassengerLocation?.longitude ?? _currentLocation.longitude,
      },
    });

    try {
      await Supabase.instance.client.from('trips').upsert({
        if (_currentRequestId != null) 'request_id': _currentRequestId,
        'passenger_id': passengerId,
        'driver_id': dId,
        'route_id': routeId,
        'service_type': serviceType == 'STANDARD' || serviceType == 'SPECIAL'
            ? 'TAXI'
            : serviceType,
        'status': 'COMPLETED',
        'fare': fare,
        'passenger_count': 1,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'pickup_name': _selectedRoute?.originName ?? 'Pickup Stop',
        'dropoff_name': _selectedRoute?.destinationName ?? 'Destination Stop',
      }, onConflict: 'request_id');
    } catch (error) {
      debugPrint('Could not save passenger trip history: $error');
    }

    _estimatedFare = fare;
    _passengerStatus = PassengerTripStatus.completed;
    _location.stopLocationTracking();
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
    _location.stopLocationTracking();
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
      _livePassengerLocation = null;
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

      // Update Supabase driver_locations
      try {
        Supabase.instance.client.from('driver_locations').upsert({
          'driver_id': driverId,
          'service_type': serviceType,
          'route_id': routeId,
          'vehicle_id': vehicleId,
          'latitude': _currentLocation.latitude,
          'longitude': _currentLocation.longitude,
          'is_online': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}

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

        // Broadcast to Supabase driver_locations
        try {
          Supabase.instance.client.from('driver_locations').upsert({
            'driver_id': driverId,
            'service_type': serviceType,
            'route_id': routeId,
            'vehicle_id': vehicleId,
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'speed': speed,
            'heading': heading,
            'occupancy': 5,
            'is_online': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}

        notifyListeners();
      });
    } else {
      _location.stopLocationTracking();
      _socket.emit('driver-offline', {'driverId': driverId});

      try {
        Supabase.instance.client.from('driver_locations').upsert({
          'driver_id': driverId,
          'service_type': serviceType,
          'route_id': routeId,
          'vehicle_id': vehicleId,
          'latitude': _currentLocation.latitude,
          'longitude': _currentLocation.longitude,
          'is_online': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}

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

  Future<void> completeTrip(HailRequest hail, String driverId) async {
    _socket.emit('trip-complete', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'requestId': hail.requestId,
      'fare': hail.fareEstimate,
    });

    try {
      await Supabase.instance.client.from('trips').upsert({
        'request_id': hail.requestId,
        'passenger_id': hail.passengerId,
        'driver_id': driverId,
        'route_id': hail.routeId == 'taxi-service' ? null : hail.routeId,
        'service_type': _historyServiceType(hail.serviceType),
        'status': 'COMPLETED',
        'fare': hail.fareEstimate,
        'passenger_count': 1,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'pickup_name': hail.stopName ?? 'Pickup Point',
        'dropoff_name': 'Destination',
      }, onConflict: 'request_id');
      _driverTripsCompleted++;
    } catch (error) {
      debugPrint('Could not save driver trip history: $error');
    }

    notifyListeners();
  }

  Future<void> endTrip(HailRequest hail, String driverId, double fare) async {
    _socket.emit('trip-end', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'requestId': hail.requestId,
      'revenue': fare,
    });

    try {
      await Supabase.instance.client.from('trips').upsert({
        'request_id': hail.requestId,
        'passenger_id': hail.passengerId,
        'driver_id': driverId,
        'route_id': hail.routeId == 'taxi-service' ? null : hail.routeId,
        'service_type': _historyServiceType(hail.serviceType),
        'status': 'COMPLETED',
        'fare': fare,
        'passenger_count': 1,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'pickup_name': hail.stopName ?? 'Pickup Point',
        'dropoff_name': 'Destination',
      }, onConflict: 'request_id');
      _driverTripsCompleted++;
    } catch (error) {
      debugPrint('Could not save driver trip history: $error');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _location.stopLocationTracking();
    _socket.disconnect();
    super.dispose();
  }
}
