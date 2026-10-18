import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/hail_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../../services/place_name_service.dart';
import '../../widgets/custom_map_view.dart';
import '../../widgets/status_pill.dart';

enum TaxiDriverTripPhase {
  searching,
  requestReceived,
  enRouteToPickup,
  arrivedAtPickup,
  onTrip,
  completed,
}

class TaxiDriverScreen extends StatefulWidget {
  const TaxiDriverScreen({super.key});

  @override
  State<TaxiDriverScreen> createState() => _TaxiDriverScreenState();
}

class _TaxiDriverScreenState extends State<TaxiDriverScreen> {
  TaxiDriverTripPhase _phase = TaxiDriverTripPhase.searching;
  HailRequest? _currentHail;
  double _shiftEarnings = 0.0;
  int _tripsCompleted = 0;
  String? _riderName;
  String? _riderPhone;
  String? _placeLookupRequestId;
  String? _pickupLabel;
  String? _destinationLabel;
  String? _routeKey;
  LatLng? _lastRouteOrigin;
  List<LatLng> _driverRoutePoints = const [];

  void _ensureRoute(TransitProvider transit) {
    final hail = _currentHail;
    if (hail == null ||
        (_phase != TaxiDriverTripPhase.enRouteToPickup &&
            _phase != TaxiDriverTripPhase.arrivedAtPickup &&
            _phase != TaxiDriverTripPhase.onTrip)) {
      return;
    }
    final target = _phase == TaxiDriverTripPhase.onTrip &&
            hail.destinationLat != null && hail.destinationLng != null
        ? LatLng(hail.destinationLat!, hail.destinationLng!)
        : LatLng(hail.pickupLat, hail.pickupLng);
    final key = '${hail.requestId}:${_phase == TaxiDriverTripPhase.onTrip ? 'destination' : 'pickup'}';
    final origin = transit.currentLocation;
    const distance = Distance();
    if (_routeKey == key &&
        _lastRouteOrigin != null &&
        distance.as(LengthUnit.Meter, _lastRouteOrigin!, origin) < 400) {
      return;
    }
    _routeKey = key;
    _lastRouteOrigin = origin;
    _loadDriverRoute(key, origin, target);
  }

  Future<void> _loadDriverRoute(String key, LatLng origin, LatLng target) async {
    try {
      final coords = '${origin.longitude},${origin.latitude};${target.longitude},${target.latitude}';
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson',
      )).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final coordinates = routes.first['geometry']['coordinates'] as List;
      final points = coordinates
          .map((point) => LatLng(
                (point[1] as num).toDouble(),
                (point[0] as num).toDouble(),
              ))
          .toList();
      if (!mounted || _routeKey != key || points.length < 2) return;
      setState(() => _driverRoutePoints = points);
    } catch (_) {}
  }

  void _ensureRiderAndPlaceNames() {
    final hail = _currentHail;
    if (hail == null || _placeLookupRequestId == hail.requestId) return;
    _placeLookupRequestId = hail.requestId;
    _loadRiderContact(context.read<TransitProvider>(), hail.passengerId);
    _loadPlaceNames(hail);
  }

  Future<void> _loadPlaceNames(HailRequest hail) async {
    final pickup = hail.pickupName ?? hail.stopName ??
        await PlaceNameService.reverseGeocode(LatLng(hail.pickupLat, hail.pickupLng));
    final destination = hail.destinationName ??
        (hail.destinationLat != null && hail.destinationLng != null
            ? await PlaceNameService.reverseGeocode(LatLng(hail.destinationLat!, hail.destinationLng!))
            : null);
    if (!mounted || _currentHail?.requestId != hail.requestId) return;
    setState(() {
      _pickupLabel = pickup ?? 'Passenger pickup';
      _destinationLabel = destination ?? 'Destination';
    });
  }

  Future<void> _loadRiderContact(TransitProvider transit, String passengerId) async {
    try {
      final contact = await transit.fetchUserContact(passengerId);
      if (!mounted) return;
      setState(() {
        _riderName = contact?['full_name'];
        _riderPhone = contact?['phone_number'];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final transit = Provider.of<TransitProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    // Watch for incoming taxi hails
    final taxiHails = transit.incomingHails
        .where((h) => h.routeId == 'taxi-service' || h.serviceType == 'TAXI')
        .toList();
    if (taxiHails.isNotEmpty &&
        _phase == TaxiDriverTripPhase.searching &&
        transit.isDriverOnline) {
      _routeKey = null;
      _lastRouteOrigin = null;
      _driverRoutePoints = const [];
      _pickupLabel = null;
      _destinationLabel = null;
      _placeLookupRequestId = null;
      _riderName = null;
      _riderPhone = null;
      _currentHail = taxiHails.first;
      _phase = TaxiDriverTripPhase.requestReceived;
    }
    if (_currentHail != null) {
      _ensureRiderAndPlaceNames();
      _ensureRoute(transit);
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          // Live Map
          CustomMapView(
            userLocation: transit.currentLocation,
            stops: const [],
            routePoints: _currentHail == null ? const [] : _driverRoutePoints,
            pickupMarker: _currentHail == null
                ? null
                : (transit.livePassengerLocation ??
                    LatLng(_currentHail!.pickupLat, _currentHail!.pickupLng)),
            destination: _currentHail?.destinationLat != null &&
                    _currentHail?.destinationLng != null
                ? LatLng(_currentHail!.destinationLat!, _currentHail!.destinationLng!)
                : null,
            drivers: transit.activeDrivers
                .where((d) => d.serviceType == 'TAXI')
                .toList(),
          ),

          // Top Driver Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Taxi Badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppTheme.lightGrey),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_taxi,
                                size: 18,
                                color: AppTheme.black,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cab Shift • ${auth.vehiclePlate}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Online / Offline Switch
                      ElevatedButton(
                        onPressed: () {
                          transit.toggleDriverOnline(
                            driverId: auth.userId,
                            serviceType: 'TAXI',
                            routeId: 'taxi-service',
                            vehicleId: auth.vehiclePlate,
                          );
                          if (!transit.isDriverOnline) {
                            setState(() {
                              _phase = TaxiDriverTripPhase.searching;
                              _currentHail = null;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: transit.isDriverOnline
                              ? AppTheme.accentRed
                              : AppTheme.accentGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          transit.isDriverOnline ? 'GO OFFLINE' : 'GO ONLINE',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Status bar: Shift Earnings & GPS State (Wrap to prevent overflow)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusPill(
                        label: transit.isDriverOnline
                            ? 'ONLINE • Dispatch Ready'
                            : 'OFFLINE',
                        color: transit.isDriverOnline
                            ? AppTheme.accentGreen
                            : AppTheme.midGrey,
                        icon: transit.isDriverOnline
                            ? Icons.sensors
                            : Icons.sensors_off,
                      ),
                      StatusPill(
                        label:
                            'Earnings: P${_shiftEarnings.toStringAsFixed(2)}',
                        color: AppTheme.black,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom inDrive/Yango Dispatch Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? MediaQuery.of(context).size.height * 0.45
                      : MediaQuery.of(context).size.height * 0.55,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildTaxiBottomDispatchPanel(transit, auth),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxiBottomDispatchPanel(
    TransitProvider transit,
    AuthProvider auth,
  ) {
    if (!transit.isDriverOnline) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nightlight_round, size: 36, color: AppTheme.midGrey),
            const SizedBox(height: 12),
            Text(
              'You are Currently Offline',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "GO ONLINE" above to start receiving ride requests in Gaborone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.midGrey),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    // Phase 1: Searching for requests (inDrive radar mode)
    if (_phase == TaxiDriverTripPhase.searching) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                color: AppTheme.black,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Searching for Nearby Ride Requests...',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_tripsCompleted trips completed today • Active in Gaborone',
              style: TextStyle(fontSize: 13, color: AppTheme.midGrey),
            ),
          ],
        ),
      );
    }

    // Phase 2: Incoming Ride Request (Yango / inDrive Style Popup)
    if (_phase == TaxiDriverTripPhase.requestReceived && _currentHail != null) {
      final fare = _currentHail!.fareEstimate > 0
          ? _currentHail!.fareEstimate
          : AppConstants.taxiBaseFareBWP;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rider Info & Estimated Fare
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.offWhite,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: AppTheme.black,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _riderName?.isNotEmpty == true ? _riderName! : 'Passenger',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppTheme.black,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: AppTheme.accentGreen,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified Commuter',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.midGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentGreen),
                  ),
                  child: Text(
                    'P${fare.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pickup & Destination info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.my_location,
                        size: 18,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pickup: ${_pickupLabel ?? _currentHail!.pickupName ?? _currentHail!.stopName ?? 'Finding place…'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: AppTheme.accentRed,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentHail!.destinationLat != null &&
                                  _currentHail!.destinationLng != null
                              ? 'Destination: ${_destinationLabel ?? _currentHail!.destinationName ?? 'Finding place…'}'
                              : 'Destination not provided',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons: Accept / Decline
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      transit.rejectHail(_currentHail!, auth.userId);
                      setState(() {
                        _phase = TaxiDriverTripPhase.searching;
                        _currentHail = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppTheme.lightGrey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        color: AppTheme.midGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      _riderName = null;
                      _riderPhone = null;
                      transit.acceptHail(_currentHail!, auth.userId);
                      setState(
                        () => _phase = TaxiDriverTripPhase.enRouteToPickup,
                      );
                      _loadRiderContact(transit, _currentHail!.passengerId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'ACCEPT RIDE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Phase 3 & 4: Active Trip Stepper (En Route -> Arrived -> On Board -> Complete)
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _phase == TaxiDriverTripPhase.enRouteToPickup
                    ? 'Navigating to Pickup'
                    : (_phase == TaxiDriverTripPhase.arrivedAtPickup
                          ? 'Waiting for Passenger'
                          : 'Trip in Progress'),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: AppTheme.black,
                ),
              ),
              StatusPill(
                label: _phase == TaxiDriverTripPhase.onTrip
                    ? 'IN PROGRESS'
                    : 'EN ROUTE',
                color: AppTheme.accentGreen,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_phase == TaxiDriverTripPhase.enRouteToPickup && _currentHail != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.person_pin_circle, color: AppTheme.taxiColor),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transit.matchedPassengerName?.isNotEmpty == true ? transit.matchedPassengerName! : (_riderName?.isNotEmpty == true ? _riderName! : 'Passenger'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (transit.matchedPassengerPhone?.isNotEmpty == true || _riderPhone?.isNotEmpty == true)
                      SelectableText(transit.matchedPassengerPhone?.isNotEmpty == true ? transit.matchedPassengerPhone! : _riderPhone!, style: TextStyle(color: AppTheme.secondaryText)),
                  ],
                )),
              ]),
            ),
          ],

          // Primary Step Progress Button
          if (_phase == TaxiDriverTripPhase.enRouteToPickup)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.pin_drop),
                label: const Text('I HAVE ARRIVED AT PICKUP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.black,
                ),
                onPressed: () {
                  if (_currentHail != null) {
                    transit.notifyDriverArrived(_currentHail!, auth.userId);
                  }
                  setState(() => _phase = TaxiDriverTripPhase.arrivedAtPickup);
                },
              ),
            )
          else if (_phase == TaxiDriverTripPhase.arrivedAtPickup)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions_car),
                label: const Text('PASSENGER BOARDED • START TRIP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.black,
                ),
                onPressed: () {
                  if (_currentHail != null) {
                    transit.startTrip(_currentHail!, auth.userId);
                  }
                  setState(() => _phase = TaxiDriverTripPhase.onTrip);
                },
              ),
            )
          else if (_phase == TaxiDriverTripPhase.onTrip)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: Text(
                  'COMPLETE TRIP & COLLECT P${(_currentHail?.fareEstimate ?? AppConstants.taxiBaseFareBWP).toStringAsFixed(2)}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                ),
                onPressed: () async {
                  final fare =
                      _currentHail?.fareEstimate ??
                      AppConstants.taxiBaseFareBWP;
                  final historySaved = _currentHail == null
                      ? false
                      : await transit.endTrip(_currentHail!, auth.userId, fare);
                  setState(() {
                    _shiftEarnings += fare;
                    _tripsCompleted += 1;
                    _phase = TaxiDriverTripPhase.searching;
                    _currentHail = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        historySaved
                            ? 'Trip completed! P${fare.toStringAsFixed(2)} collected.'
                            : 'Trip completed, but the trip history could not be saved. Please try again when connected.',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
