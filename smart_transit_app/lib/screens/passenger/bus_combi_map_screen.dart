import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/route_model.dart';
import '../../models/driver_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../../widgets/custom_map_view.dart';
import '../../widgets/status_pill.dart';
import 'passenger_dashboard.dart';

class BusCombiMapScreen extends StatefulWidget {
  final TransportMode mode;
  final TransitRoute route;
  final VoidCallback onExitToMain;

  const BusCombiMapScreen({
    super.key,
    required this.mode,
    required this.route,
    required this.onExitToMain,
  });

  @override
  State<BusCombiMapScreen> createState() => _BusCombiMapScreenState();
}

class _BusCombiMapScreenState extends State<BusCombiMapScreen> {
  int _tripRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _stopRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transit = Provider.of<TransitProvider>(context, listen: false);
      transit.selectRoute(widget.route, 'passengers');
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transit = Provider.of<TransitProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Filter drivers to ONLY those on this route
    final routeDrivers = transit.activeDrivers.where((d) => d.routeId == widget.route.id).toList();

    return Stack(
      children: [
        // Map
        CustomMapView(
          userLocation: transit.currentLocation,
          stops: transit.stops,
          drivers: routeDrivers,
          onStopTapped: (stop) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stop: ${stop.name}')),
            );
          },
        ),

        // Top Route Info Bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusPill(
                  label: '${routeDrivers.length} Active ${widget.mode == TransportMode.bus ? "Buses" : "Combis"}',
                  color: AppTheme.black,
                  icon: widget.mode == TransportMode.bus ? Icons.directions_bus : Icons.airport_shuttle,
                ),
                StatusPill(
                  label: 'Fare: P${widget.route.baseFare.toStringAsFixed(2)}',
                  color: AppTheme.accentGreen,
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Sheet (Scrollable & Responsive to prevent any RenderFlex overflow)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).orientation == Orientation.landscape
                    ? MediaQuery.of(context).size.height * 0.55
                    : MediaQuery.of(context).size.height * 0.65,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildBottomPanel(context, transit, auth, routeDrivers),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(
    BuildContext context,
    TransitProvider transit,
    AuthProvider auth,
    List<LiveDriver> routeDrivers,
  ) {
    final activeDriverCount = routeDrivers.length;
    if (transit.passengerStatus == PassengerTripStatus.hailPending) {
      return _buildPendingHailCard(transit, auth, routeDrivers);
    } else if (transit.passengerStatus == PassengerTripStatus.driverAccepted) {
      return _buildDriverAcceptedCard(context, transit, auth, routeDrivers);
    } else if (transit.passengerStatus == PassengerTripStatus.onBoard) {
      return _buildOnBoardCard(context, transit, auth);
    } else if (transit.passengerStatus == PassengerTripStatus.completed) {
      return _buildCompletedCard(context, transit, auth);
    }

    // Default: Hail Button
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Route: ${widget.route.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.black),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$activeDriverCount Vehicles Active',
                style: const TextStyle(fontSize: 12, color: AppTheme.midGrey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.route.originName} → ${widget.route.destinationName}',
            style: const TextStyle(fontSize: 13, color: AppTheme.midGrey),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Live Approaching Vehicle Telemetry Card
          if (activeDriverCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: Row(
                children: [
                  // ETA
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 15, color: AppTheme.accentGreen),
                              const SizedBox(width: 4),
                              Text(
                                transit.etaDisplay,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transit.etaDistanceMeters != null
                              ? '${(transit.etaDistanceMeters! / 1000).toStringAsFixed(1)} km away'
                              : 'Closest Vehicle',
                          style: const TextStyle(fontSize: 10, color: AppTheme.midGrey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 28, width: 1, color: AppTheme.lightGrey),

                  // Live Speed
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const Icon(Icons.speed, size: 15, color: AppTheme.accentBlue),
                              const SizedBox(width: 4),
                              Text(
                                '${routeDrivers.first.speed.toStringAsFixed(0)} km/h',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text('Live Speed', style: TextStyle(fontSize: 10, color: AppTheme.midGrey)),
                      ],
                    ),
                  ),
                  Container(height: 28, width: 1, color: AppTheme.lightGrey),

                  // Occupancy
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline, size: 15, color: AppTheme.black),
                              const SizedBox(width: 4),
                              Text(
                                '${routeDrivers.first.occupancy} PAX',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text('Occupancy', style: TextStyle(fontSize: 10, color: AppTheme.midGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Fare Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Standard Fare:', style: TextStyle(color: AppTheme.midGrey, fontSize: 14)),
              Text(
                'P${widget.route.baseFare.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.black),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ElevatedButton.icon(
            onPressed: () => transit.requestCombiHail(auth.userId),
            icon: const Icon(Icons.pan_tool_alt_outlined, size: 20),
            label: Text(
              widget.mode == TransportMode.bus ? 'Hail Approaching Bus' : 'Hail Combi (P8.00)',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000.0;
  }

  Widget _buildPendingHailCard(TransitProvider transit, AuthProvider auth, List<LiveDriver> routeDrivers) {
    double? distMeters = transit.etaDistanceMeters;
    if (distMeters == null && routeDrivers.isNotEmpty) {
      distMeters = _calculateDistanceMeters(
        transit.currentLocation.latitude,
        transit.currentLocation.longitude,
        routeDrivers.first.latitude,
        routeDrivers.first.longitude,
      );
    }
    final isWithinProximity = distMeters != null && distMeters <= 25.0;
    final activeDriverCount = routeDrivers.length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Approaching Vehicle Telemetry Box (Always visible during hail)
          if (activeDriverCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: Row(
                children: [
                  // ETA & Distance
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 15, color: AppTheme.accentGreen),
                              const SizedBox(width: 4),
                              Text(
                                transit.etaDisplay,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          distMeters != null
                              ? (distMeters < 1000 ? '${distMeters.toStringAsFixed(0)}m away' : '${(distMeters / 1000).toStringAsFixed(1)}km away')
                              : 'Nearby',
                          style: const TextStyle(fontSize: 10, color: AppTheme.midGrey, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(height: 28, width: 1, color: AppTheme.lightGrey),

                  // Live Speed
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const Icon(Icons.speed, size: 15, color: AppTheme.accentBlue),
                              const SizedBox(width: 4),
                              Text(
                                '${routeDrivers.first.speed.toStringAsFixed(0)} km/h',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text('Live Speed', style: TextStyle(fontSize: 10, color: AppTheme.midGrey)),
                      ],
                    ),
                  ),
                  Container(height: 28, width: 1, color: AppTheme.lightGrey),

                  // Occupancy
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline, size: 15, color: AppTheme.black),
                              const SizedBox(width: 4),
                              Text(
                                '${routeDrivers.first.occupancy} PAX',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text('Occupancy', style: TextStyle(fontSize: 10, color: AppTheme.midGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: AppTheme.offWhite, shape: BoxShape.circle),
                child: const Icon(Icons.pan_tool_alt, color: AppTheme.accentGreen, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hand Raised on Route!',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.black),
                    ),
                    Text(
                      isWithinProximity
                          ? 'Vehicle has arrived at your stop (within 25m)!'
                          : 'Approaching vehicles have received your stop alert.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.midGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Proximity-Gated Boarding Button: Only visible when vehicle is within 25m
          if (isWithinProximity) ...[
            ElevatedButton.icon(
              onPressed: () => transit.confirmBoarding(auth.userId),
              icon: const Icon(Icons.directions_walk, size: 20),
              label: const Text('Confirm Boarding (I am on board)', style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
          ],

          TextButton(
            onPressed: () => transit.cancelHail(auth.userId),
            child: const Text('Cancel Hail', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAcceptedCard(
    BuildContext context,
    TransitProvider transit,
    AuthProvider auth,
    List<LiveDriver> routeDrivers,
  ) {
    double? distMeters = transit.etaDistanceMeters;
    if (distMeters == null && routeDrivers.isNotEmpty) {
      distMeters = _calculateDistanceMeters(
        transit.currentLocation.latitude,
        transit.currentLocation.longitude,
        routeDrivers.first.latitude,
        routeDrivers.first.longitude,
      );
    }
    final isWithinProximity = distMeters != null && distMeters <= 25.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.offWhite,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppTheme.accentGreen, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Arriving (${transit.assignedDriverId ?? ""})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isWithinProximity
                          ? 'Vehicle at pickup point!'
                          : (distMeters != null
                              ? 'Driver is en route (${distMeters < 1000 ? distMeters.toStringAsFixed(0) + "m" : (distMeters / 1000).toStringAsFixed(1) + "km"} away)'
                              : 'Driver is en route to your stop.'),
                      style: const TextStyle(color: AppTheme.midGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isWithinProximity) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => transit.confirmBoarding(auth.userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Confirm Boarding (I am on board)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnBoardCard(BuildContext context, TransitProvider transit, AuthProvider auth) {
    // Show "I've Arrived" only after stop is signaled AND vehicle has slowed/stopped
    final vehicleStationary = transit.vehicleSpeedKmh < 5.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: AppTheme.offWhite, shape: BoxShape.circle),
                child: Icon(
                  widget.mode == TransportMode.bus ? Icons.directions_bus : Icons.airport_shuttle,
                  color: AppTheme.accentGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'On-Board ${widget.mode == TransportMode.bus ? "Bus" : "Combi"}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.black),
                    ),
                    Text(
                      'Route: ${widget.route.name}',
                      style: const TextStyle(color: AppTheme.midGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Live vehicle speed badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: vehicleStationary ? Colors.orange.shade50 : AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: vehicleStationary ? Colors.orange.shade300 : AppTheme.lightGrey,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      vehicleStationary ? Icons.pause_circle_outline : Icons.speed,
                      size: 13,
                      color: vehicleStationary ? Colors.orange.shade700 : AppTheme.accentGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehicleStationary
                          ? 'Stopped'
                          : '${transit.vehicleSpeedKmh.toStringAsFixed(0)} km/h',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: vehicleStationary ? Colors.orange.shade700 : AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Request Stop Button
          OutlinedButton.icon(
            onPressed: _stopRequested
                ? null
                : () {
                    transit.requestStop(passengerId: auth.userId);
                    setState(() => _stopRequested = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stop signal sent to driver! 🔔 Wait for vehicle to stop.'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
            icon: Icon(
              _stopRequested ? Icons.check_circle : Icons.notifications_active_outlined,
              size: 18,
              color: _stopRequested ? AppTheme.accentGreen : AppTheme.accentAmber,
            ),
            label: Text(
              _stopRequested ? 'Stop Signaled ✅ — Wait for vehicle to stop' : 'Signal Stop / Request Next Stop 🔔',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _stopRequested ? AppTheme.accentGreen : AppTheme.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              side: BorderSide(
                color: _stopRequested ? AppTheme.accentGreen : AppTheme.accentAmber,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _stopRequested = false);
              transit.passengerEndTrip(passengerId: auth.userId, finalFare: widget.route.baseFare);
            },
            icon: const Icon(Icons.pin_drop, size: 18),
            label: const Text(
              'I Have Arrived • End My Trip',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(BuildContext context, TransitProvider transit, AuthProvider auth) {
    final driverIdToRate = transit.assignedDriverId ?? 
        (transit.activeDrivers.isNotEmpty ? transit.activeDrivers.first.driverId : 'driver-1');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppTheme.offWhite, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 32),
          ),
          const SizedBox(height: 10),
          const Text(
            'Trip Completed!',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Standard Fare: P${widget.route.baseFare.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.midGrey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Rate your Driver & Trip Experience',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Interactive 5-Star Rating Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNum = index + 1;
              return IconButton(
                icon: Icon(
                  starNum <= _tripRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30,
                ),
                onPressed: () => setState(() => _tripRating = starNum),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Feedback comment input
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Share feedback (cleanliness, driving, comfort)...',
              hintStyle: const TextStyle(fontSize: 12, color: AppTheme.midGrey),
              filled: true,
              fillColor: AppTheme.offWhite,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: () {
              transit.submitRating(
                driverId: driverIdToRate,
                passengerId: auth.userId,
                rating: _tripRating,
                comment: _commentController.text.trim(),
              );
              transit.resetPassengerTrip();
              widget.onExitToMain();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Submit Review & Finish', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
