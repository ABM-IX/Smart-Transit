import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/driver_model.dart';
import '../models/hail_request_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import '../services/place_name_service.dart';

enum PassengerTripStatus {
  idle,
  searchingTaxi,
  hailPending,
  driverAccepted,
  driverArrived,
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
  double? _currentLocationAccuracy;
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
  String? _activeServiceType;
  LatLng? _livePassengerLocation;
  int? _etaSeconds;
  double? _etaDistanceMeters;
  String? _taxiPickupName;
  String? _taxiDestinationName;
  LatLng? _taxiPickupLocation;
  LatLng? _taxiDestinationLocation;
  DateTime? _driverAcceptedAt;
  Timer? _arrivalCheckTimer;
  Timer? _driverHeartbeatTimer;
  int _tripResetVersion = 0;
  int _taxiRequestGeneration = 0;
  static const _savedPassengerTripKey = 'smarttransit_active_passenger_trip';

  // Driver State
  bool _isDriverOnline = false;
  Map<String, dynamic>? _driverOnlinePayload;
  static const _savedDriverPresenceKey = 'smarttransit_driver_presence';
  SpacingAdvisory? _spacingAdvisory;
  final List<HailRequest> _incomingHails = [];
  final List<HailRequest> _boardedRoutePassengers = [];
  final List<HailRequest> _acceptedSharedHails = [];
  HailRequest? _latestHailAlert;
  HailRequest? _acceptedDriverHail;
  bool _driverAtPickup = false;
  bool _driverTripStarted = false;
  bool _driverTripEnded = false;
  double? _driverTripEndedFare;
  String? _driverTripCancelledRequestId;
  final Set<String> _countedBoardingIds = {};
  String? _lastStopRequest;
  int _passengersCarried = 0;
  int _driverTripsCompleted = 0;
  String _driverOccupancyText = 'Empty';

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
  String? get taxiPickupName => _taxiPickupName;
  String? get taxiDestinationName => _taxiDestinationName;
  int get tripResetVersion => _tripResetVersion;
  String get etaDisplay {
    if (_etaSeconds == null || _etaSeconds! <= 0) return '1 min (Arriving)';
    if (_etaSeconds! > 3 * 60 * 60) return 'Updating';
    final mins = (_etaSeconds! / 60).round();
    if (mins <= 1) return '1 min (Arriving)';
    return '$mins mins';
  }

  bool get isDriverOnline => _isDriverOnline;
  bool get driverAtPickup => _driverAtPickup;
  bool get driverTripStarted => _driverTripStarted;
  bool get driverTripEnded => _driverTripEnded;
  double? get driverTripEndedFare => _driverTripEndedFare;
  HailRequest? get acceptedDriverHail => _acceptedDriverHail;
  List<HailRequest> get acceptedSharedHails =>
      List.unmodifiable(_acceptedSharedHails);
  bool get canAcceptSharedTaxiRequests =>
      _acceptedDriverHail?.serviceType.toUpperCase() == 'STANDARD' &&
      _acceptedSharedHails.every(
        (hail) => hail.serviceType.toUpperCase() == 'STANDARD',
      );

  void _promoteNextSharedHail() {
    if (_acceptedDriverHail != null || _acceptedSharedHails.isEmpty) return;
    _acceptedDriverHail = _acceptedSharedHails.removeAt(0);
    _driverAtPickup = false;
    _driverTripStarted = false;
  }

  String? get driverTripCancelledRequestId => _driverTripCancelledRequestId;
  void acknowledgeDriverTripCancelled(String requestId) {
    if (_driverTripCancelledRequestId == requestId) {
      _driverTripCancelledRequestId = null;
    }
  }

  void acknowledgeDriverTripEnded() {
    _driverTripEnded = false;
    _driverTripEndedFare = null;
  }

  SpacingAdvisory? get spacingAdvisory => _spacingAdvisory;
  List<HailRequest> get incomingHails => _incomingHails;
  List<HailRequest> get boardedRoutePassengers =>
      List.unmodifiable(_boardedRoutePassengers);
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
        .select('full_name, phone_number, vehicle_plate')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return {
      'full_name': row['full_name']?.toString() ?? '',
      'phone_number': row['phone_number']?.toString() ?? '',
      'vehicle_plate': row['vehicle_plate']?.toString() ?? '',
    };
  }

  void _updateEtaFromDriverCoords(LatLng driverPos, {double? speedKmh}) {
    final target =
        _taxiPickupLocation ?? _livePassengerLocation ?? _currentLocation;
    const distance = Distance();
    final distMeters = distance.as(LengthUnit.Meter, driverPos, target);
    _etaDistanceMeters = distMeters;
    final effectiveSpeed = (speedKmh != null && speedKmh > 10.0)
        ? speedKmh
        : 35.0;
    final rawSec = (distMeters / (effectiveSpeed * 1000.0 / 3600.0)).round();
    _etaSeconds = math.max(45, rawSec);
    _checkProximityArrival();
  }

  void _checkProximityArrival() {
    final routeHail =
        _passengerStatus == PassengerTripStatus.hailPending &&
        (_activeServiceType == 'COMBI' || _activeServiceType == 'BUS');
    if (!routeHail && _passengerStatus != PassengerTripStatus.driverAccepted) {
      return;
    }
    final dist = _etaDistanceMeters;
    if (dist == null || dist > 35.0) return;

    if (routeHail) {
      _arrivalCheckTimer?.cancel();
      _passengerStatus = PassengerTripStatus.driverArrived;
      unawaited(_persistPassengerTrip());
      notifyListeners();
      return;
    }

    final acceptedAt = _driverAcceptedAt ?? DateTime.now();
    final elapsedMs = DateTime.now().difference(acceptedAt).inMilliseconds;
    const minAcceptedDisplayMs = 4500;

    if (elapsedMs >= minAcceptedDisplayMs) {
      _arrivalCheckTimer?.cancel();
      _passengerStatus = PassengerTripStatus.driverArrived;
      notifyListeners();
    } else {
      _arrivalCheckTimer?.cancel();
      _arrivalCheckTimer = Timer(
        Duration(milliseconds: minAcceptedDisplayMs - elapsedMs),
        () {
          if (_passengerStatus == PassengerTripStatus.driverAccepted &&
              (_etaDistanceMeters == null || _etaDistanceMeters! <= 40.0)) {
            _passengerStatus = PassengerTripStatus.driverArrived;
            notifyListeners();
          }
        },
      );
    }
  }

  bool _isRouteHailForDriver(LiveDriver driver) =>
      _passengerStatus == PassengerTripStatus.hailPending &&
      (_activeServiceType == 'COMBI' || _activeServiceType == 'BUS') &&
      driver.routeId == (_selectedRoute?.id ?? '') &&
      driver.serviceType.toUpperCase() == _activeServiceType;

  void _refreshIncomingHailLocation(String? passengerId, LatLng location) {
    if (passengerId == null || passengerId.isEmpty) return;
    for (var index = 0; index < _incomingHails.length; index++) {
      final hail = _incomingHails[index];
      if (hail.passengerId != passengerId) continue;
      _incomingHails[index] = HailRequest(
        requestId: hail.requestId,
        passengerId: hail.passengerId,
        routeId: hail.routeId,
        pickupLat: location.latitude,
        pickupLng: location.longitude,
        destinationLat: hail.destinationLat,
        destinationLng: hail.destinationLng,
        serviceType: hail.serviceType,
        fareEstimate: hail.fareEstimate,
        stopName: null,
        pickupName: null,
        destinationName: hail.destinationName,
        message: hail.message,
      );
    }
    final alert = _latestHailAlert;
    if (alert?.passengerId == passengerId) {
      _latestHailAlert = HailRequest(
        requestId: alert!.requestId,
        passengerId: alert.passengerId,
        routeId: alert.routeId,
        pickupLat: location.latitude,
        pickupLng: location.longitude,
        destinationLat: alert.destinationLat,
        destinationLng: alert.destinationLng,
        serviceType: alert.serviceType,
        fareEstimate: alert.fareEstimate,
        stopName: null,
        pickupName: null,
        destinationName: alert.destinationName,
        message: alert.message,
      );
    }
  }

  void _startTransitPassengerLocationTracking({
    required String passengerId,
    required String routeId,
    required String requestId,
    required int requestGeneration,
  }) {
    _location.startLocationTracking((position) {
      if (requestGeneration != _taxiRequestGeneration ||
          !{
            PassengerTripStatus.hailPending,
            PassengerTripStatus.driverAccepted,
            PassengerTripStatus.driverArrived,
            PassengerTripStatus.onBoard,
          }.contains(_passengerStatus)) return;
      final location = LatLng(position.latitude, position.longitude);
      _currentLocation = location;
      _currentLocationAccuracy = position.accuracy;
      _livePassengerLocation = location;
      if (_passengerStatus != PassengerTripStatus.onBoard) {
        _taxiPickupLocation = location;
      }
      final updatedAt = position.timestamp.toUtc().toIso8601String();
      _socket.emit('passenger-location', {
        'passengerId': passengerId,
        'routeId': routeId,
        'requestId': requestId,
        'coords': {'lat': position.latitude, 'lng': position.longitude},
        'accuracy': position.accuracy,
        'speed': position.speed * 3.6,
        'heading': position.heading,
        'updatedAt': updatedAt,
      });
      unawaited(_persistTransitHailLocation(
        passengerId: passengerId,
        requestId: requestId,
        position: position,
      ));
      notifyListeners();
    });
  }

  Future<void> _createTransitHailRecord({
    required String requestId,
    required String passengerId,
    required String routeId,
    required String serviceType,
    required LatLng pickup,
    required double fare,
  }) async {
    try {
      await Supabase.instance.client.from('hails').insert({
        'request_id': requestId,
        'passenger_id': passengerId,
        'route_id': routeId,
        'service_type': serviceType,
        'status': 'WAITING',
        'pickup_lat': pickup.latitude,
        'pickup_lng': pickup.longitude,
        'passenger_lat': pickup.latitude,
        'passenger_lng': pickup.longitude,
        'fare_estimate': fare,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      debugPrint('Could not create transit hail record: $error');
    }
  }

  Future<void> _persistTransitHailLocation({
    required String passengerId,
    required String requestId,
    required Position position,
  }) async {
    try {
      await Supabase.instance.client
          .from('hails')
          .update({
            'passenger_lat': position.latitude,
            'passenger_lng': position.longitude,
            'passenger_accuracy': position.accuracy,
            'passenger_speed': position.speed * 3.6,
            'passenger_heading': position.heading,
            'updated_at': position.timestamp.toUtc().toIso8601String(),
          })
          .eq('request_id', requestId)
          .eq('passenger_id', passengerId)
          .inFilter('status', ['WAITING', 'ACCEPTED', 'BOARDED']);
    } catch (error) {
      debugPrint('Could not update transit hail location: $error');
    }
  }

  Future<void> _persistTransitHailStatus(
    String? requestId,
    String status, {
    String? driverId,
    DateTime? boardedAt,
  }) async {
    if (requestId == null || requestId.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final update = <String, dynamic>{'status': status, 'updated_at': now};
    if (driverId != null && driverId.isNotEmpty) update['driver_id'] = driverId;
    if (boardedAt != null) {
      update['boarded_at'] = boardedAt.toUtc().toIso8601String();
    }
    if (status == 'COMPLETED' || status == 'CANCELLED') {
      update.addAll({
        'completed_at': now,
        'passenger_lat': null,
        'passenger_lng': null,
        'passenger_accuracy': null,
        'passenger_speed': null,
        'passenger_heading': null,
      });
    }
    try {
      await Supabase.instance.client
          .from('hails')
          .update(update)
          .eq('request_id', requestId);
    } catch (error) {
      debugPrint('Could not update transit hail status: $error');
    }
  }

  Future<void> _hydrateMatchedDriverProfile(String driverId) async {
    try {
      final contact = await fetchUserContact(driverId);
      if (contact == null || _assignedDriverId != driverId) return;
      bool changed = false;
      if ((_matchedDriverName == null || _matchedDriverName!.isEmpty) &&
          contact['full_name']?.isNotEmpty == true) {
        _matchedDriverName = contact['full_name'];
        changed = true;
      }
      if ((_matchedDriverPhone == null || _matchedDriverPhone!.isEmpty) &&
          contact['phone_number']?.isNotEmpty == true) {
        _matchedDriverPhone = contact['phone_number'];
        changed = true;
      }
      if ((_matchedDriverPlate == null ||
              _matchedDriverPlate!.isEmpty ||
              _matchedDriverPlate == 'B-BW') &&
          contact['vehicle_plate']?.isNotEmpty == true) {
        _matchedDriverPlate = contact['vehicle_plate'];
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (_) {}
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
    await _restorePassengerTrip();
    await _restoreDriverPresence();
    await fetchInitialData();
    await updateCurrentLocation();
  }

  void _checkDriverPickupProximity() {
    final hail = _acceptedDriverHail;
    if (!_isDriverOnline ||
        hail == null ||
        _driverAtPickup ||
        _driverTripStarted) {
      return;
    }
    const distance = Distance();
    final meters = distance.as(
      LengthUnit.Meter,
      _currentLocation,
      LatLng(hail.pickupLat, hail.pickupLng),
    );
    // Match the combi stop arrival radius: the cab is considered at pickup within 35m.
    if (meters > 35) return;
    _driverAtPickup = true;
    _socket.emit('driver-arrived', {
      'passengerId': hail.passengerId,
      'driverId': _driverOnlinePayload?['driverId'],
      'requestId': hail.requestId,
    });
    notifyListeners();
  }

  Future<void> _restoreDriverPresence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedDriverPresenceKey);
      if (raw == null) return;
      _driverOnlinePayload = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _driverOccupancyText =
          _driverOnlinePayload?['occupancyText']?.toString() ?? 'Empty';
      _isDriverOnline = true;
    } catch (_) {}
  }

  Future<void> _persistPassengerTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_passengerStatus == PassengerTripStatus.idle ||
          _passengerStatus == PassengerTripStatus.completed) {
        await prefs.remove(_savedPassengerTripKey);
        return;
      }
      await prefs.setString(
        _savedPassengerTripKey,
        jsonEncode({
          'status': _passengerStatus.name,
          'serviceType': _activeServiceType,
          'requestId': _currentRequestId,
          'driverId': _assignedDriverId,
          'driverName': _matchedDriverName,
          'driverPhone': _matchedDriverPhone,
          'driverPlate': _matchedDriverPlate,
          'fare': _estimatedFare,
          'pickupName': _taxiPickupName,
          'destinationName': _taxiDestinationName,
          'pickup': _taxiPickupLocation == null
              ? null
              : {
                  'lat': _taxiPickupLocation!.latitude,
                  'lng': _taxiPickupLocation!.longitude,
                },
          'destination': _taxiDestinationLocation == null
              ? null
              : {
                  'lat': _taxiDestinationLocation!.latitude,
                  'lng': _taxiDestinationLocation!.longitude,
                },
        }),
      );
    } catch (_) {}
  }

  Future<void> _restorePassengerTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedPassengerTripKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final statusName = data['status']?.toString();
      PassengerTripStatus? status;
      for (final candidate in PassengerTripStatus.values) {
        if (candidate.name == statusName) status = candidate;
      }
      if (status == null ||
          status == PassengerTripStatus.idle ||
          status == PassengerTripStatus.completed) {
        await prefs.remove(_savedPassengerTripKey);
        return;
      }
      _passengerStatus = status;
      _activeServiceType = data['serviceType']?.toString();
      _currentRequestId = data['requestId']?.toString();
      _assignedDriverId = data['driverId']?.toString();
      _matchedDriverName = data['driverName']?.toString();
      _matchedDriverPhone = data['driverPhone']?.toString();
      _matchedDriverPlate = data['driverPlate']?.toString();
      _estimatedFare = (data['fare'] as num?)?.toDouble();
      _taxiPickupName = data['pickupName']?.toString();
      _taxiDestinationName = data['destinationName']?.toString();
      final pickup = data['pickup'];
      final destination = data['destination'];
      if (pickup is Map)
        _taxiPickupLocation = LatLng(
          (pickup['lat'] as num).toDouble(),
          (pickup['lng'] as num).toDouble(),
        );
      if (destination is Map)
        _taxiDestinationLocation = LatLng(
          (destination['lat'] as num).toDouble(),
          (destination['lng'] as num).toDouble(),
        );
    } catch (_) {}
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
    }
    notifyListeners();
  }

  // --- WEBSOCKET INITIALIZATION ---
  Future<void> connectSocket({
    required String role,
    required String userId,
    String? routeId,
  }) async {
    await _restorePassengerTrip();
    await _restoreDriverPresence();
    _socket.connect(
      onConnect: (_) {
        _isConnected = true;
        _socket.emit('join', {
          'role': role,
          'id': userId,
          'driverId': userId,
          'passengerId': userId,
          'routeId': routeId ?? _selectedRoute?.id ?? '',
        });
        if (role == 'drivers' &&
            _isDriverOnline &&
            _driverOnlinePayload != null) {
          final acceptedHail = _acceptedDriverHail;
          _socket.emit('driver-online', {
            ..._driverOnlinePayload!,
            if (acceptedHail != null) ...{
              'activeRequestId': acceptedHail.requestId,
              'activePassengerId': acceptedHail.passengerId,
            },
          });
          _location.startLocationTracking((position) {
            final pos = LatLng(position.latitude, position.longitude);
            final speed = position.speed * 3.6;
            final heading = position.heading;
            _currentLocation = pos;
            _currentLocationAccuracy = position.accuracy;
            _vehicleSpeedKmh = speed;
            _checkDriverPickupProximity();
            final acceptedHail = _acceptedDriverHail;
            _socket.emit('driver-location', {
              ...?_driverOnlinePayload,
              if (acceptedHail != null) ...{
                'activeRequestId': acceptedHail.requestId,
                'activePassengerId': acceptedHail.passengerId,
              },
              'coords': {'lat': pos.latitude, 'lng': pos.longitude},
              'speed': speed,
              'heading': heading,
              'accuracy': position.accuracy,
              'occupancyText': _driverOccupancyText,
            });
            notifyListeners();
          });
        }
        _socket.emit('resume-session', {'role': role, 'userId': userId});
        notifyListeners();
      },
      onDisconnect: (_) {
        _isConnected = false;
        notifyListeners();
      },
      listeners: {
        'session-restored': (data) {
          if (data is! Map<String, dynamic>) return;
          final request = data['request'];
          if (request is Map<String, dynamic> &&
              _passengerStatus != PassengerTripStatus.idle) {
            _currentRequestId ??= request['requestId']?.toString();
            _estimatedFare ??= (request['fareEstimate'] as num?)?.toDouble();
            final pickup = request['pickupLoc'] ?? request['pickup'];
            final destination = request['destinationLoc'] ?? request['dropoff'];
            if (pickup is Map<String, dynamic>)
              _taxiPickupLocation ??= LatLng(
                (pickup['lat'] as num).toDouble(),
                (pickup['lng'] as num).toDouble(),
              );
            if (destination is Map<String, dynamic>)
              _taxiDestinationLocation ??= LatLng(
                (destination['lat'] as num).toDouble(),
                (destination['lng'] as num).toDouble(),
              );
            _taxiPickupName ??= request['pickupName']?.toString();
            _taxiDestinationName ??= request['destinationName']?.toString();
            final restoredRoute = (request['routeId'] ?? request['route_id'])?.toString();
            final restoredType = (request['serviceType'] ?? request['service_type'])?.toString().toUpperCase();
            if (restoredRoute != null &&
                _currentRequestId != null &&
                (restoredType == 'BUS' || restoredType == 'COMBI')) {
              _activeServiceType = restoredType;
              if (data['boarded'] == true) _passengerStatus = PassengerTripStatus.onBoard;
              _startTransitPassengerLocationTracking(
                passengerId: userId,
                routeId: restoredRoute,
                requestId: _currentRequestId!,
                requestGeneration: _taxiRequestGeneration,
              );
            }
          }
          final assignment = data['assignment'];
          if (assignment is Map<String, dynamic>) {
            _assignedDriverId =
                assignment['driverId']?.toString() ??
                assignment['driver_id']?.toString();
            _passengerStatus = data['boarded'] == true
                ? PassengerTripStatus.onBoard
                : (assignment['arrived'] == true
                      ? PassengerTripStatus.driverArrived
                      : PassengerTripStatus.driverAccepted);
            if (_assignedDriverId != null)
              _hydrateMatchedDriverProfile(_assignedDriverId!);
          }
          unawaited(_persistPassengerTrip());
          notifyListeners();
        },
        'driver-location': (data) {
          if (data is Map<String, dynamic>) {
            final driver = LiveDriver.fromJson(data);
            _activeDrivers[driver.driverId] = driver;
            if (_isRouteHailForDriver(driver) &&
                driver.latitude != 0.0 &&
                driver.longitude != 0.0) {
              _vehicleSpeedKmh = driver.speed;
              _updateEtaFromDriverCoords(
                LatLng(driver.latitude, driver.longitude),
                speedKmh: driver.speed,
              );
              if (_passengerStatus == PassengerTripStatus.driverArrived) {
                _assignedDriverId = driver.driverId;
              }
            }
            if (_assignedDriverId != null &&
                driver.driverId == _assignedDriverId &&
                driver.latitude != 0.0 &&
                driver.longitude != 0.0) {
              _vehicleSpeedKmh = driver.speed;
              _updateEtaFromDriverCoords(
                LatLng(driver.latitude, driver.longitude),
                speedKmh: driver.speed,
              );
              if (_passengerStatus == PassengerTripStatus.driverArrived) {
                _assignedDriverId = driver.driverId;
              }
            }
            notifyListeners();
          }
        },
        'vehicle-update': (data) {
          if (data is Map<String, dynamic>) {
            final driver = LiveDriver.fromJson(data);
            _activeDrivers[driver.driverId] = driver;
            if (_isRouteHailForDriver(driver) &&
                driver.latitude != 0.0 &&
                driver.longitude != 0.0) {
              _vehicleSpeedKmh = driver.speed;
              _updateEtaFromDriverCoords(
                LatLng(driver.latitude, driver.longitude),
                speedKmh: driver.speed,
              );
              if (_passengerStatus == PassengerTripStatus.driverArrived) {
                _assignedDriverId = driver.driverId;
              }
            }
            if (_assignedDriverId != null &&
                driver.driverId == _assignedDriverId &&
                driver.latitude != 0.0 &&
                driver.longitude != 0.0) {
              _vehicleSpeedKmh = driver.speed;
              _updateEtaFromDriverCoords(
                LatLng(driver.latitude, driver.longitude),
                speedKmh: driver.speed,
              );
            }
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
            final etaDriverId = data['driverId']?.toString();
            if (_assignedDriverId != null && etaDriverId != _assignedDriverId) {
              return;
            }
            _etaSeconds = (data['etaSeconds'] as num?)?.toInt() ?? _etaSeconds;
            _etaDistanceMeters =
                (data['distanceMeters'] as num?)?.toDouble() ??
                _etaDistanceMeters;
            if (_passengerStatus == PassengerTripStatus.hailPending &&
                (_activeServiceType == 'COMBI' ||
                    _activeServiceType == 'BUS') &&
                etaDriverId != null &&
                _etaDistanceMeters != null &&
                _etaDistanceMeters! <= 35.0) {
              _assignedDriverId = etaDriverId;
            }
            final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;
            // Keep vehicle speed updated so passenger UI can show "I've Arrived" when stationary
            _vehicleSpeedKmh = speed;
            _checkProximityArrival();
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
          if (data is Map<String, dynamic> &&
              _passengerStatus == PassengerTripStatus.hailPending) {
            _currentRequestId ??= data['requestId']?.toString();
            notifyListeners();
          }
        },
        'taxi-dispatched': (data) {
          if (data is Map<String, dynamic> &&
              _passengerStatus == PassengerTripStatus.searchingTaxi) {
            _currentRequestId = data['requestId']?.toString();
            notifyListeners();
          }
        },
        'taxi-request-rejected': (data) {
          if (_passengerStatus == PassengerTripStatus.searchingTaxi) {
            _taxiRequestGeneration++;
            _passengerStatus = PassengerTripStatus.idle;
            _activeServiceType = null;
            _currentRequestId = null;
            _location.stopLocationTracking();
            unawaited(_persistPassengerTrip());
            notifyListeners();
          }
        },
        'hail-request-rejected': (data) {
          if (_passengerStatus == PassengerTripStatus.hailPending) {
            _taxiRequestGeneration++;
            _passengerStatus = PassengerTripStatus.idle;
            _activeServiceType = null;
            _currentRequestId = null;
            unawaited(_persistPassengerTrip());
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
                _refreshIncomingHailLocation(
                  (data['passengerId'] ?? data['passenger_id'])?.toString(),
                  _livePassengerLocation!,
                );
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
            final boardingId = (data['requestId'] ?? pId)?.toString();
            final boardedDriverId = (data['driverId'] ?? data['driver_id'])
                ?.toString();
            HailRequest? waitingHail;
            for (final hail in _incomingHails) {
              if ((pId != null && hail.passengerId == pId) ||
                  (boardingId != null && hail.requestId == boardingId)) {
                waitingHail = hail;
                break;
              }
            }
            _incomingHails.removeWhere((h) => h.passengerId == pId);
            if (_latestHailAlert?.passengerId == pId) {
              _latestHailAlert = null;
            }
            if (boardedDriverId == userId &&
                boardingId != null &&
                _countedBoardingIds.add(boardingId)) {
              _passengersCarried += 1;
              if (waitingHail != null &&
                  (waitingHail.serviceType.toUpperCase() == 'BUS' ||
                      waitingHail.serviceType.toUpperCase() == 'COMBI')) {
                _boardedRoutePassengers.add(waitingHail);
              }
              unawaited(_persistTransitHailStatus(
                boardingId,
                'BOARDED',
                driverId: boardedDriverId,
                boardedAt: DateTime.tryParse(data['boardedAt']?.toString() ?? ''),
              ));
            }
            if (_acceptedDriverHail?.passengerId == pId) {
              _driverAtPickup = true;
              _driverTripStarted = true;
            }
            notifyListeners();
          }
        },
        'passenger-alighted': (data) {
          if (data is! Map<String, dynamic> ||
              data['driverId']?.toString() != userId) return;
          final pId = (data['passengerId'] ?? data['passenger_id'])?.toString();
          final requestId = (data['requestId'] ?? data['tripId'])?.toString();
          final index = _boardedRoutePassengers.indexWhere((hail) =>
              (requestId != null && hail.requestId == requestId) ||
              (pId != null && hail.passengerId == pId));
          if (index >= 0) {
            final hail = _boardedRoutePassengers.removeAt(index);
            _passengersCarried = math.max(0, _passengersCarried - 1);
            if (requestId != null) _countedBoardingIds.remove(requestId);
            unawaited(_persistTransitHailStatus(requestId, 'COMPLETED'));
            unawaited(endTrip(hail, userId, hail.fareEstimate));
          }
          notifyListeners();
        },
        'hail-cancelled': (data) {
          if (data is Map<String, dynamic>) {
            final pId = data['passengerId']?.toString();
            final requestId = data['requestId']?.toString();
            bool isThisRequest(HailRequest hail) =>
                (pId != null && hail.passengerId == pId) ||
                (requestId != null && hail.requestId == requestId);
            _incomingHails.removeWhere(isThisRequest);
            if (_latestHailAlert != null && isThisRequest(_latestHailAlert!)) {
              _latestHailAlert = null;
            }
            if (data['status'] == 'CANCELLED' &&
                _acceptedDriverHail != null &&
                (isThisRequest(_acceptedDriverHail!) ||
                    data['driverId']?.toString() == userId)) {
              _driverTripCancelledRequestId = _acceptedDriverHail!.requestId;
              _acceptedDriverHail = null;
              _driverAtPickup = false;
              _driverTripStarted = false;
            }
            notifyListeners();
          }
        },
        'hail-accept-rejected': (data) {
          if (data is Map<String, dynamic>) {
            final requestId = data['requestId']?.toString();
            _acceptedSharedHails.removeWhere(
              (hail) => hail.requestId == requestId,
            );
            if (_acceptedDriverHail?.requestId == requestId) {
              _acceptedDriverHail = null;
              _driverAtPickup = false;
              _driverTripStarted = false;
              _promoteNextSharedHail();
            }
            notifyListeners();
          }
        },
        'hail-cancel-rejected': (data) {
          if (data is Map<String, dynamic>) {
            _assignedDriverId = data['driverId']?.toString();
            _currentRequestId = data['requestId']?.toString();
            _activeServiceType =
                data['serviceType']?.toString().toUpperCase() ?? 'TAXI';
            _passengerStatus = switch (data['status']) {
              'ON_BOARD' => PassengerTripStatus.onBoard,
              'DRIVER_ARRIVED' => PassengerTripStatus.driverArrived,
              _ => PassengerTripStatus.driverAccepted,
            };
            _driverAcceptedAt = DateTime.now();
            if (_assignedDriverId != null) {
              _hydrateMatchedDriverProfile(_assignedDriverId!);
            }
            unawaited(_persistPassengerTrip());
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
            final acceptedDriverId = data['driverId']?.toString();
            _assignedDriverId = acceptedDriverId;
            if (userId == (data['passengerId']?.toString())) {
              final dName = data['driverName']?.toString() ?? '';
              final dPhone = data['driverPhone']?.toString() ?? '';
              final dPlate = data['driverPlate']?.toString() ?? '';
              if (dName.isNotEmpty) _matchedDriverName = dName;
              if (dPhone.isNotEmpty) _matchedDriverPhone = dPhone;
              if (dPlate.isNotEmpty) _matchedDriverPlate = dPlate;
            } else if (userId == acceptedDriverId) {
              final pName = data['passengerName']?.toString() ?? '';
              final pPhone = data['passengerPhone']?.toString() ?? '';
              if (pName.isNotEmpty) _matchedPassengerName = pName;
              if (pPhone.isNotEmpty) _matchedPassengerPhone = pPhone;
            }
            _estimatedFare =
                (data['fareEstimate'] as num?)?.toDouble() ??
                (_passengerStatus == PassengerTripStatus.searchingTaxi
                    ? AppConstants.taxiBaseFareBWP
                    : _selectedRoute?.baseFare ?? AppConstants.standardFareBWP);

            _driverAcceptedAt = DateTime.now();
            _passengerStatus = PassengerTripStatus.driverAccepted;

            // Upsert driver in _activeDrivers if coords were included in hail-accepted
            final coords = data['coords'];
            if (acceptedDriverId != null && coords is Map<String, dynamic>) {
              final lat = (coords['lat'] ?? coords['latitude']) as num?;
              final lng = (coords['lng'] ?? coords['longitude']) as num?;
              if (lat != null && lng != null && lat != 0 && lng != 0) {
                final reportedSpeed =
                    (data['speed'] as num?)?.toDouble() ?? 0.0;
                final liveDriver = LiveDriver(
                  driverId: acceptedDriverId,
                  routeId: data['routeId']?.toString() ?? 'taxi-service',
                  serviceType: data['serviceType']?.toString() ?? 'TAXI',
                  vehicleId: data['driverPlate']?.toString() ?? 'B-BW',
                  latitude: lat.toDouble(),
                  longitude: lng.toDouble(),
                  speed: reportedSpeed,
                  heading: 0.0,
                  occupancy: 1,
                  status: 'ONLINE',
                );
                _activeDrivers[acceptedDriverId] = liveDriver;
                _vehicleSpeedKmh = reportedSpeed;
                _updateEtaFromDriverCoords(
                  LatLng(lat.toDouble(), lng.toDouble()),
                  speedKmh: reportedSpeed,
                );
              }
            } else if (acceptedDriverId != null &&
                _activeDrivers.containsKey(acceptedDriverId)) {
              final existing = _activeDrivers[acceptedDriverId]!;
              if (existing.latitude != 0.0 && existing.longitude != 0.0) {
                _updateEtaFromDriverCoords(
                  LatLng(existing.latitude, existing.longitude),
                  speedKmh: existing.speed,
                );
              }
            }

            if (data['etaSeconds'] != null) {
              _etaSeconds = (data['etaSeconds'] as num).toInt();
            }
            if (data['distanceMeters'] != null) {
              _etaDistanceMeters = (data['distanceMeters'] as num).toDouble();
            }
            // Ensure passenger always sees an immediate ETA even before the next GPS tick
            _etaSeconds ??= 60;
            _checkProximityArrival();

            if (acceptedDriverId != null) {
              _hydrateMatchedDriverProfile(acceptedDriverId);
            }
            unawaited(_persistPassengerTrip());
            notifyListeners();
          }
        },
        'taxi-arrived': (data) {
          if (data is Map<String, dynamic>) {
            _assignedDriverId =
                data['driverId']?.toString() ?? _assignedDriverId;
            if (data['status'] == 'ARRIVED_AT_PICKUP') {
              _arrivalCheckTimer?.cancel();
              _passengerStatus = PassengerTripStatus.driverArrived;
              _etaSeconds = null;
              _etaDistanceMeters =
                  (data['distanceMeters'] as num?)?.toDouble() ??
                  _etaDistanceMeters;
            } else if (_passengerStatus != PassengerTripStatus.driverArrived &&
                _passengerStatus != PassengerTripStatus.onBoard) {
              _driverAcceptedAt ??= DateTime.now();
              _passengerStatus = PassengerTripStatus.driverAccepted;
              if (data['etaSeconds'] != null) {
                _etaSeconds = (data['etaSeconds'] as num).toInt();
              }
              if (data['distanceMeters'] != null) {
                _etaDistanceMeters = (data['distanceMeters'] as num).toDouble();
              }
              _etaSeconds ??= 60;
              _checkProximityArrival();
            }
            if (_assignedDriverId != null) {
              _hydrateMatchedDriverProfile(_assignedDriverId!);
            }
            unawaited(_persistPassengerTrip());
            notifyListeners();
          }
        },
        'driver-arrived-pickup': (data) {
          if (data is Map<String, dynamic>) {
            _arrivalCheckTimer?.cancel();
            _assignedDriverId =
                data['driverId']?.toString() ?? _assignedDriverId;
            _passengerStatus = PassengerTripStatus.driverArrived;
            _etaSeconds = null;
            _etaDistanceMeters = null;
            unawaited(_persistPassengerTrip());
            notifyListeners();
          }
        },
        'boarding-confirmed': (data) {
          _arrivalCheckTimer?.cancel();
          if (_activeServiceType == 'TAXI') _location.stopLocationTracking();
          _passengerStatus = PassengerTripStatus.onBoard;
          if (data is Map<String, dynamic>) {
            _assignedDriverId = data['driverId']?.toString() ?? _assignedDriverId;
            _currentRequestId ??= data['requestId']?.toString();
          }
          unawaited(_persistTransitHailStatus(
            _currentRequestId, 'BOARDED',
            driverId: _assignedDriverId,
            boardedAt: DateTime.now().toUtc(),
          ));
          unawaited(_persistPassengerTrip());
          notifyListeners();
        },
        'trip-started': (data) {
          _arrivalCheckTimer?.cancel();
          if (data is Map<String, dynamic> &&
              data['driverId']?.toString() == userId &&
              data['passengerId']?.toString() ==
                  _acceptedDriverHail?.passengerId) {
            _driverAtPickup = true;
            _driverTripStarted = true;
            notifyListeners();
            return;
          }
          if (_activeServiceType == 'TAXI') _location.stopLocationTracking();
          _passengerStatus = PassengerTripStatus.onBoard;
          if (data is Map<String, dynamic>) {
            _assignedDriverId = data['driverId']?.toString() ?? _assignedDriverId;
            _currentRequestId ??= data['requestId']?.toString();
          }
          unawaited(_persistTransitHailStatus(
            _currentRequestId, 'BOARDED',
            driverId: _assignedDriverId,
            boardedAt: DateTime.now().toUtc(),
          ));
          unawaited(_persistPassengerTrip());
          notifyListeners();
        },
        'passenger-trip-ended': (data) {
          if (data is! Map<String, dynamic> ||
              data['driverId']?.toString() != userId ||
              _driverTripEnded) {
            return;
          }
          final hail = _acceptedDriverHail;
          final passengerId = (data['passengerId'] ?? data['passenger_id'])
              ?.toString();
          final queuedIndex = _acceptedSharedHails.indexWhere(
            (item) => item.passengerId == passengerId,
          );
          if (queuedIndex >= 0) {
            _acceptedSharedHails.removeAt(queuedIndex);
            notifyListeners();
            return;
          }
          if (hail == null || hail.passengerId != passengerId) return;

          final fare =
              (data['fare'] as num?)?.toDouble() ??
              hail.fareEstimate ??
              AppConstants.taxiBaseFareBWP;
          _driverTripEnded = true;
          _driverTripEndedFare = fare;
          _acceptedDriverHail = null;
          _driverAtPickup = false;
          _driverTripStarted = false;
          _promoteNextSharedHail();
          unawaited(endTrip(hail, userId, fare));
          notifyListeners();
        },
        'passenger-trip-cancelled': (data) {
          if (data is! Map<String, dynamic> ||
              data['driverId']?.toString() != userId) {
            return;
          }
          final hail = _acceptedDriverHail;
          final passengerId = (data['passengerId'] ?? data['passenger_id'])
              ?.toString();
          final requestId = (data['requestId'] ?? data['tripId'])?.toString();
          final queuedCount = _acceptedSharedHails.length;
          _acceptedSharedHails.removeWhere(
            (item) =>
                item.passengerId == passengerId ||
                (requestId != null && item.requestId == requestId),
          );
          if (_acceptedSharedHails.length < queuedCount) {
            notifyListeners();
            return;
          }
          if (hail == null ||
              (passengerId != null && hail.passengerId != passengerId)) {
            return;
          }
          _driverTripCancelledRequestId = hail.requestId;
          _acceptedDriverHail = null;
          _driverAtPickup = false;
          _driverTripStarted = false;
          _promoteNextSharedHail();
          notifyListeners();
        },
        'trip-completed': (data) {
          _arrivalCheckTimer?.cancel();
          final completedRequestId = data is Map<String, dynamic>
              ? (data['requestId'] ?? data['tripId'])?.toString()
              : null;
          unawaited(_persistTransitHailStatus(completedRequestId ?? _currentRequestId, 'COMPLETED'));
          _location.stopLocationTracking();
          if (data is Map<String, dynamic>) {
            _estimatedFare =
                (data['fare'] as num?)?.toDouble() ?? _estimatedFare;
          }
          _passengerStatus = PassengerTripStatus.completed;
          unawaited(_persistPassengerTrip());
          notifyListeners();
        },
        'taxi-trip-ended': (data) {
          _arrivalCheckTimer?.cancel();
          _location.stopLocationTracking();
          if (data is Map<String, dynamic>) {
            _estimatedFare =
                (data['fare'] as num?)?.toDouble() ?? _estimatedFare;
          }
          _passengerStatus = PassengerTripStatus.completed;
          unawaited(_persistPassengerTrip());
          notifyListeners();
        },
      },
    );
  }

  // --- PASSENGER ACTIONS ---
  Future<void> requestCombiHail(
    String passengerId, {
    String? serviceType,
  }) async {
    if (_selectedRoute == null) return;
    final requestGeneration = ++_taxiRequestGeneration;
    _currentRequestId = null;
    final resolvedType =
        serviceType ??
        (_selectedRoute!.routeType.toUpperCase() == 'BUS' ||
                _selectedRoute!.id.startsWith('bus-')
            ? 'BUS'
            : 'COMBI');
    _activeServiceType = resolvedType.toUpperCase();
    _passengerStatus = PassengerTripStatus.hailPending;
    _assignedDriverId = null;
    _estimatedFare = _selectedRoute!.baseFare;
    _taxiPickupLocation = _currentLocation;
    final requestId = 'hail-${DateTime.now().microsecondsSinceEpoch}';
    _currentRequestId = requestId;
    _livePassengerLocation = _currentLocation;
    _etaSeconds = null;
    _etaDistanceMeters = null;
    unawaited(_persistPassengerTrip());
    notifyListeners();

    final pickupName = await PlaceNameService.resolvePlaceName(
      _currentLocation,
      preferredName: _taxiPickupName,
    );
    if (requestGeneration != _taxiRequestGeneration ||
        _passengerStatus != PassengerTripStatus.hailPending) {
      return;
    }
    _taxiPickupName = pickupName;

    await _createTransitHailRecord(
      requestId: requestId,
      passengerId: passengerId,
      routeId: _selectedRoute!.id,
      serviceType: resolvedType.toUpperCase(),
      pickup: _currentLocation,
      fare: _selectedRoute!.baseFare,
    );

    _socket.emit('hail', {
      'requestId': requestId,
      'passengerId': passengerId,
      'routeId': _selectedRoute!.id,
      'pickupLoc': {
        'lat': _currentLocation.latitude,
        'lng': _currentLocation.longitude,
      },
      'pickupName': pickupName,
      'stopName': pickupName,
      'serviceType': resolvedType,
      'fareEstimate': _selectedRoute!.baseFare,
      'accuracy': _currentLocationAccuracy ?? 999,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    final routeId = _selectedRoute!.id;
    _startTransitPassengerLocationTracking(
      passengerId: passengerId,
      routeId: routeId,
      requestId: requestId,
      requestGeneration: requestGeneration,
    );
    notifyListeners();
  }

  Future<void> requestTaxiBooking({
    required String passengerId,
    required String serviceType,
    required LatLng pickup,
    LatLng? dropoff,
    String? pickupName,
    String? destinationName,
    double? offeredFare,
  }) async {
    if (dropoff == null) {
      debugPrint('Taxi request ignored because no destination was selected.');
      return;
    }
    final requestGeneration = ++_taxiRequestGeneration;
    _activeServiceType = 'TAXI';
    _passengerStatus = PassengerTripStatus.searchingTaxi;
    _currentRequestId = null;
    _matchedDriverName = null;
    _matchedDriverPhone = null;
    _matchedDriverPlate = null;
    _matchedPassengerName = null;
    _matchedPassengerPhone = null;
    _selectedRoute = null;
    _estimatedFare = offeredFare ?? AppConstants.taxiBaseFareBWP;
    _livePassengerLocation = pickup;
    _etaSeconds = null;
    _etaDistanceMeters = null;
    _vehicleSpeedKmh = 0;
    _taxiPickupLocation = pickup;
    _taxiDestinationLocation = dropoff;
    unawaited(_persistPassengerTrip());
    notifyListeners();
    final resolvedPickupName = await PlaceNameService.resolvePlaceName(
      pickup,
      preferredName: pickupName,
    );
    if (requestGeneration != _taxiRequestGeneration ||
        _passengerStatus != PassengerTripStatus.searchingTaxi) {
      return;
    }
    _taxiPickupName = resolvedPickupName;
    _taxiDestinationName =
        PlaceNameService.sanitizeLocationName(destinationName) ??
        destinationName;
    unawaited(_persistPassengerTrip());
    final payload = <String, dynamic>{
      'passengerId': passengerId,
      'pickup': {'lat': pickup.latitude, 'lng': pickup.longitude},
      'pickupName': resolvedPickupName,
      'serviceType': serviceType,
    };
    if (dropoff != null) {
      payload['dropoff'] = {'lat': dropoff.latitude, 'lng': dropoff.longitude};
    }
    if (_taxiDestinationName != null) {
      payload['destinationName'] = _taxiDestinationName;
    }
    if (offeredFare != null) {
      payload['offeredFare'] = offeredFare;
    }
    _socket.emit('passenger-request-taxi', payload);
    _location.startLocationTracking((position) {
      if (requestGeneration != _taxiRequestGeneration ||
          !{
            PassengerTripStatus.searchingTaxi,
            PassengerTripStatus.driverAccepted,
            PassengerTripStatus.driverArrived,
          }.contains(_passengerStatus)) {
        return;
      }
      final pos = LatLng(position.latitude, position.longitude);
      _currentLocation = pos;
      _currentLocationAccuracy = position.accuracy;
      _livePassengerLocation = pos;
      _socket.emit('passenger-location', {
        'passengerId': passengerId,
        'routeId': 'taxi-service',
        'coords': {'lat': pos.latitude, 'lng': pos.longitude},
        'accuracy': position.accuracy,
        'speed': position.speed * 3.6,
        'heading': position.heading,
        'updatedAt': position.timestamp.toUtc().toIso8601String(),
      });
      notifyListeners();
    });
    notifyListeners();
  }

  void confirmBoarding(String passengerId) {
    _arrivalCheckTimer?.cancel();
    final routeHail = _activeServiceType == 'COMBI' || _activeServiceType == 'BUS';
    if (!routeHail) _location.stopLocationTracking();
    final driverId =
        _assignedDriverId ??
        (_activeDrivers.isNotEmpty ? _activeDrivers.keys.first : 'driver-1');
    final routeId = _activeServiceType == 'TAXI'
        ? 'taxi-service'
        : (_selectedRoute?.id ??
              (_routes.isNotEmpty ? _routes.first.id : 'transit-line'));

    _socket.emit('boarding', {
      'driverId': driverId,
      'passengerId': passengerId,
      'routeId': routeId,
      if (_activeServiceType != null) 'serviceType': _activeServiceType,
      if (_currentRequestId != null) 'requestId': _currentRequestId,
    });
    _assignedDriverId = driverId;
    _passengerStatus = PassengerTripStatus.onBoard;
    unawaited(_persistTransitHailStatus(
      _currentRequestId,
      'BOARDED',
      driverId: driverId,
      boardedAt: DateTime.now().toUtc(),
    ));
    unawaited(_persistPassengerTrip());
    notifyListeners();
  }

  void updateDriverOccupancy({
    required String driverId,
    required String routeId,
    required String serviceType,
    required String vehicleId,
    required String occupancyText,
  }) {
    _driverOccupancyText = occupancyText;
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
    _driverOnlinePayload = {
      ...?_driverOnlinePayload,
      'occupancyText': occupancyText,
      'occupancy': paxCount,
    };
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(
          _savedDriverPresenceKey,
          jsonEncode(_driverOnlinePayload),
        ),
      ),
    );

    _socket.emit('driver-location', {
      'driverId': driverId,
      'serviceType': serviceType,
      'routeId': routeId,
      'vehicleId': vehicleId,
      'coords': {
        'lat': _currentLocation.latitude,
        'lng': _currentLocation.longitude,
      },
      'speed': _vehicleSpeedKmh,
      'heading': 0.0,
      'occupancy': paxCount,
      'occupancyText': occupancyText,
      'accuracy': _currentLocationAccuracy ?? 999,
    });
    notifyListeners();
  }

  void submitRating({
    required String driverId,
    required String passengerId,
    required int rating,
    String? comment,
  }) {
    final requestId = _currentRequestId;
    final ratingPayload = <String, dynamic>{
      'driverId': driverId,
      'passengerId': passengerId,
      'rating': rating,
      'comment': comment,
    };
    if (requestId != null) {
      ratingPayload['tripId'] = requestId;
    }
    _socket.emit('driver-rating', ratingPayload);

    // Also persist rating directly to Supabase trips if available
    if (requestId != null) {
      Supabase.instance.client
          .from('trips')
          .update({'rating': rating})
          .eq('request_id', requestId)
          .then((_) {}, onError: (_) {});
    }

    resetPassengerTrip();
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
    _arrivalCheckTimer?.cancel();
    final dId = driverId ?? _assignedDriverId;
    final fallbackFare =
        _selectedRoute?.baseFare ?? AppConstants.taxiBaseFareBWP;
    final fare = finalFare ?? _estimatedFare ?? fallbackFare;
    final routeId = _selectedRoute?.id;
    final serviceType = _selectedRoute?.routeType.toUpperCase() ?? 'TAXI';
    final pickupPoint =
        _taxiPickupLocation ?? _livePassengerLocation ?? _currentLocation;
    final resolvedPickup =
        PlaceNameService.sanitizeLocationName(_taxiPickupName) ??
        await PlaceNameService.resolvePlaceName(pickupPoint);

    _socket.emit('passenger-end-trip', {
      'passengerId': passengerId,
      'driverId': dId,
      'routeId': routeId ?? 'taxi-service',
      'requestId': _currentRequestId,
      'fare': fare,
      'serviceType': serviceType,
      'pickupName': resolvedPickup,
      'dropoffName':
          _taxiDestinationName ??
          _selectedRoute?.destinationName ??
          'Destination',
      'pickup': {'lat': pickupPoint.latitude, 'lng': pickupPoint.longitude},
      if (_taxiDestinationLocation != null)
        'dropoff': {
          'lat': _taxiDestinationLocation!.latitude,
          'lng': _taxiDestinationLocation!.longitude,
        },
    });
    if (serviceType == 'BUS' || serviceType == 'COMBI') {
      unawaited(_persistTransitHailStatus(_currentRequestId, 'COMPLETED'));
    }

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
        'pickup_name': resolvedPickup,
        'dropoff_name':
            _taxiDestinationName ??
            _selectedRoute?.destinationName ??
            'Destination Stop',
        'pickup_lat': pickupPoint.latitude,
        'pickup_lng': pickupPoint.longitude,
        if (_taxiDestinationLocation != null) ...{
          'dropoff_lat': _taxiDestinationLocation!.latitude,
          'dropoff_lng': _taxiDestinationLocation!.longitude,
        },
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
    _taxiRequestGeneration++;
    _arrivalCheckTimer?.cancel();
    final routeId = _selectedRoute?.id ?? 'taxi-service';
    _socket.emit('cancel-hail', {
      'passengerId': passengerId,
      'routeId': routeId,
      if (_currentRequestId != null) 'requestId': _currentRequestId,
    });
    if (_activeServiceType == 'COMBI' || _activeServiceType == 'BUS') {
      unawaited(_persistTransitHailStatus(_currentRequestId, 'CANCELLED'));
    }
    _location.stopLocationTracking();
    _passengerStatus = PassengerTripStatus.idle;
    _activeServiceType = null;
    unawaited(_persistPassengerTrip());
    _assignedDriverId = null;
    _currentRequestId = null;
    _driverAcceptedAt = null;
    notifyListeners();
  }

  void resetPassengerTrip({String? passengerId}) {
    _arrivalCheckTimer?.cancel();
    if (passengerId != null) {
      cancelHail(passengerId);
    } else {
      _passengerStatus = PassengerTripStatus.idle;
      _activeServiceType = null;
    }
    _assignedDriverId = null;
    _matchedDriverName = null;
    _matchedDriverPhone = null;
    _matchedDriverPlate = null;
    _matchedPassengerName = null;
    _matchedPassengerPhone = null;
    _estimatedFare = null;
    _currentRequestId = null;
    _livePassengerLocation = null;
    _etaSeconds = null;
    _etaDistanceMeters = null;
    _vehicleSpeedKmh = 0;
    _taxiPickupName = null;
    _taxiDestinationName = null;
    _taxiPickupLocation = null;
    _taxiDestinationLocation = null;
    _selectedRoute = null;
    _driverAcceptedAt = null;
    _tripResetVersion++;
    _location.stopLocationTracking();
    notifyListeners();
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
      final initialCoords = {
        'lat': _currentLocation.latitude,
        'lng': _currentLocation.longitude,
      };
      _driverOnlinePayload = {
        'driverId': driverId,
        'routeId': routeId,
        'serviceType': serviceType,
        'vehicleId': vehicleId,
        'vehiclePlate': vehicleId,
        'coords': initialCoords,
        'occupancyText': _driverOccupancyText,
      };
      unawaited(
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setString(
            _savedDriverPresenceKey,
            jsonEncode(_driverOnlinePayload),
          ),
        ),
      );
      _socket.emit('driver-online', _driverOnlinePayload);

      // Immediately emit initial driver-location so stationary test devices have live coords & ETA
      _socket.emit('driver-location', {
        'driverId': driverId,
        'routeId': routeId,
        'serviceType': serviceType,
        'vehicleId': vehicleId,
        'vehiclePlate': vehicleId,
        'coords': initialCoords,
        'speed': 0.0,
        'heading': 0.0,
        'occupancy': _passengersCarried,
        'occupancyText': _driverOccupancyText,
        'accuracy': _currentLocationAccuracy ?? 999,
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

      _driverHeartbeatTimer?.cancel();
      _driverHeartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_isDriverOnline) return;
        final acceptedHail = _acceptedDriverHail;
        _socket.emit('driver-location', {
          'driverId': driverId,
          'routeId': routeId,
          'serviceType': serviceType,
          'vehicleId': vehicleId,
          'vehiclePlate': vehicleId,
          'coords': {
            'lat': _currentLocation.latitude,
            'lng': _currentLocation.longitude,
          },
          'speed': _vehicleSpeedKmh,
          'heading': 0.0,
          'occupancy': _passengersCarried,
          'occupancyText': _driverOccupancyText,
          'accuracy': _currentLocationAccuracy ?? 999,
          if (acceptedHail != null) ...{
            'activeRequestId': acceptedHail.requestId,
            'activePassengerId': acceptedHail.passengerId,
          },
        });
      });

      _location.startLocationTracking((position) {
        final pos = LatLng(position.latitude, position.longitude);
        final speed = position.speed * 3.6;
        final heading = position.heading;
        _currentLocation = pos;
        _currentLocationAccuracy = position.accuracy;
        _vehicleSpeedKmh = speed;
        _checkDriverPickupProximity();
        final acceptedHail = _acceptedDriverHail;
        _socket.emit('driver-location', {
          'driverId': driverId,
          'routeId': routeId,
          'serviceType': serviceType,
          'vehicleId': vehicleId,
          'vehiclePlate': vehicleId,
          'coords': {'lat': pos.latitude, 'lng': pos.longitude},
          'speed': speed,
          'heading': heading,
          'occupancy': _passengersCarried,
          'occupancyText': _driverOccupancyText,
          'accuracy': position.accuracy,
          if (acceptedHail != null) ...{
            'activeRequestId': acceptedHail.requestId,
            'activePassengerId': acceptedHail.passengerId,
          },
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
            'occupancy': _passengersCarried,
            'is_online': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}

        notifyListeners();
      });
    } else {
      _driverOnlinePayload = null;
      unawaited(
        SharedPreferences.getInstance().then(
          (prefs) => prefs.remove(_savedDriverPresenceKey),
        ),
      );
      _driverHeartbeatTimer?.cancel();
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

  void acceptHail(
    HailRequest hail,
    String driverId, {
    String? driverName,
    String? driverPhone,
    String? driverPlate,
  }) {
    final isAdditionalSharedRide = _acceptedDriverHail != null;
    if (isAdditionalSharedRide) {
      if (!canAcceptSharedTaxiRequests ||
          hail.serviceType.toUpperCase() != 'STANDARD') {
        return;
      }
      if (!_acceptedSharedHails.any(
        (item) => item.requestId == hail.requestId,
      )) {
        _acceptedSharedHails.add(hail);
      }
    } else {
      _acceptedDriverHail = hail;
      _driverAtPickup = false;
      _driverTripStarted = false;
    }
    _socket.emit('accept-hail', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'routeId': hail.routeId,
      'requestId': hail.requestId,
      'coords': {
        'lat': _currentLocation.latitude,
        'lng': _currentLocation.longitude,
      },
      if (driverName != null && driverName.isNotEmpty) 'driverName': driverName,
      if (driverPhone != null && driverPhone.isNotEmpty)
        'driverPhone': driverPhone,
      if (driverPlate != null && driverPlate.isNotEmpty)
        'driverPlate': driverPlate,
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
    _driverAtPickup = true;
    _socket.emit('driver-arrived', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'requestId': hail.requestId,
    });
    notifyListeners();
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
    final resolvedPickup = await PlaceNameService.resolvePlaceName(
      LatLng(hail.pickupLat, hail.pickupLng),
      preferredName: hail.pickupName ?? hail.stopName,
    );
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
        'pickup_name': resolvedPickup,
        'dropoff_name': hail.destinationName ?? 'Destination',
        'pickup_lat': hail.pickupLat,
        'pickup_lng': hail.pickupLng,
        if (hail.destinationLat != null) 'dropoff_lat': hail.destinationLat,
        if (hail.destinationLng != null) 'dropoff_lng': hail.destinationLng,
      }, onConflict: 'request_id');
      _driverTripsCompleted++;
    } catch (error) {
      debugPrint('Could not save driver trip history: $error');
    }

    notifyListeners();
  }

  Future<bool> endTrip(HailRequest hail, String driverId, double fare) async {
    if (_acceptedDriverHail?.requestId == hail.requestId) {
      _acceptedDriverHail = null;
      _driverAtPickup = false;
      _driverTripStarted = false;
      _promoteNextSharedHail();
    }
    final resolvedPickup = await PlaceNameService.resolvePlaceName(
      LatLng(hail.pickupLat, hail.pickupLng),
      preferredName: hail.pickupName ?? hail.stopName,
    );
    _socket.emit('trip-end', {
      'passengerId': hail.passengerId,
      'driverId': driverId,
      'requestId': hail.requestId,
      'tripId': hail.requestId,
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
        'pickup_name': resolvedPickup,
        'dropoff_name': hail.destinationName ?? 'Destination',
        'pickup_lat': hail.pickupLat,
        'pickup_lng': hail.pickupLng,
        if (hail.destinationLat != null) 'dropoff_lat': hail.destinationLat,
        if (hail.destinationLng != null) 'dropoff_lng': hail.destinationLng,
      }, onConflict: 'request_id');
      _driverTripsCompleted++;
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Could not save driver trip history: $error');
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _arrivalCheckTimer?.cancel();
    _driverHeartbeatTimer?.cancel();
    _location.stopLocationTracking();
    _socket.disconnect();
    super.dispose();
  }
}
