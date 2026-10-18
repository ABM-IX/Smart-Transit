import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/hail_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
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
      _currentHail = taxiHails.first;
      _phase = TaxiDriverTripPhase.requestReceived;
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          // Live Map
          CustomMapView(
            userLocation: transit.currentLocation,
            stops: const [],
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
                          'Rider ${_currentHail!.passengerId.length > 8 ? _currentHail!.passengerId.substring(0, 8) : _currentHail!.passengerId}',
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
                          'Pickup: ${(transit.livePassengerLocation?.latitude ?? _currentHail!.pickupLat).toStringAsFixed(5)}, ${(transit.livePassengerLocation?.longitude ?? _currentHail!.pickupLng).toStringAsFixed(5)}',
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
                              ? 'Destination: ${_currentHail!.destinationLat!.toStringAsFixed(5)}, ${_currentHail!.destinationLng!.toStringAsFixed(5)}'
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
                  if (_currentHail != null) {
                    await transit.endTrip(_currentHail!, auth.userId, fare);
                  }
                  setState(() {
                    _shiftEarnings += fare;
                    _tripsCompleted += 1;
                    _phase = TaxiDriverTripPhase.searching;
                    _currentHail = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Trip Completed! P${fare.toStringAsFixed(2)} collected.',
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
