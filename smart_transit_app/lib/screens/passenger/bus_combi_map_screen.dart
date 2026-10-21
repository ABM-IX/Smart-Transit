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
    final routeDrivers = transit.activeDrivers
        .where((d) => d.routeId == widget.route.id)
        .toList();

    return Stack(
      children: [
        // Map
        CustomMapView(
          userLocation: transit.currentLocation,
          stops: transit.stops,
          drivers: routeDrivers,
          onStopTapped: (stop) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Stop: ${stop.name}')));
          },
        ),

        // Top Route Info Bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusPill(
                  label:
                      '${routeDrivers.length} Active ${widget.mode == TransportMode.bus ? "Buses" : "Combis"}',
                  color: AppTheme.brandNavy,
                  icon: widget.mode == TransportMode.bus
                      ? Icons.directions_bus
                      : Icons.airport_shuttle,
                ),
                if (widget.mode == TransportMode.combi)
                  StatusPill(
                    label: 'Fare: P${widget.route.baseFare.toStringAsFixed(2)}',
                    color: AppTheme.primaryTeal,
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
                maxHeight:
                    MediaQuery.of(context).orientation == Orientation.landscape
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
    } else if (transit.passengerStatus == PassengerTripStatus.driverAccepted ||
        transit.passengerStatus == PassengerTripStatus.driverArrived) {
      return _buildDriverAcceptedCard(context, transit, auth, routeDrivers);
    } else if (transit.passengerStatus == PassengerTripStatus.onBoard) {
      return _buildOnBoardCard(context, transit, auth);
    } else if (transit.passengerStatus == PassengerTripStatus.completed) {
      return _buildCompletedCard(context, transit, auth);
    }

    // Default: Hail Button
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$activeDriverCount Vehicles Active',
                style: TextStyle(fontSize: 12, color: AppTheme.midGrey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.route.originName} → ${widget.route.destinationName}',
            style: TextStyle(fontSize: 13, color: AppTheme.midGrey),
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
                              const Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: AppTheme.accentGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                transit.etaDisplay,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: AppTheme.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transit.etaDistanceMeters != null
                              ? '${(transit.etaDistanceMeters! / 1000).toStringAsFixed(1)} km away'
                              : 'Closest Vehicle',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.midGrey,
                          ),
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
                              const Icon(
                                Icons.speed,
                                size: 15,
                                color: AppTheme.accentBlue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${routeDrivers.first.speed.toStringAsFixed(0)} km/h',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: AppTheme.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Live Speed',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.midGrey,
                          ),
                        ),
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
                              Icon(
                                Icons.people_outline,
                                size: 15,
                                color: AppTheme.black,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${routeDrivers.first.occupancy} PAX',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: AppTheme.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Occupancy',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.midGrey,
                          ),
                        ),
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
              if (widget.mode == TransportMode.combi ||
                  widget.mode == TransportMode.bus) ...[
                Text(
                  widget.mode == TransportMode.bus ? 'Route Fare:' : 'Fare:',
                  style: TextStyle(color: AppTheme.midGrey, fontSize: 14),
                ),
                Text(
                  widget.route.baseFare > 0
                      ? 'P${widget.route.baseFare.toStringAsFixed(2)}'
                      : 'Not set',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppTheme.black,
                  ),
                ),
              ] else
                Text(
                  'Bus fare varies by route',
                  style: TextStyle(color: AppTheme.midGrey, fontSize: 14),
                ),
            ],
          ),
          const SizedBox(height: 14),

          ElevatedButton.icon(
            onPressed: () => transit.requestCombiHail(
              auth.userId,
              serviceType: widget.mode == TransportMode.bus ? 'BUS' : 'COMBI',
            ),
            icon: const Icon(Icons.pan_tool_alt_outlined, size: 20),
            label: Text(
              widget.mode == TransportMode.bus
                  ? widget.route.baseFare > 0
                        ? 'Hail Bus (P${widget.route.baseFare.toStringAsFixed(2)})'
                        : 'Hail Approaching Bus'
                  : 'Hail Combi (P${widget.route.baseFare.toStringAsFixed(2)})',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)) * 1000.0;
  }

  Widget _buildPendingHailCard(
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
    final activeDriverCount = routeDrivers.length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
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
                              const Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: AppTheme.accentGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                transit.etaDisplay,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: AppTheme.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          distMeters != null
                              ? (distMeters < 1000
                                    ? '${distMeters.toStringAsFixed(0)}m away'
                                    : '${(distMeters / 1000).toStringAsFixed(1)}km away')
                              : 'Nearby',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.midGrey,
                            fontWeight: FontWeight.bold,
                          ),
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
                              const Icon(
                                Icons.speed,
                                size: 15,
                                color: AppTheme.accentBlue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${routeDrivers.first.speed.toStringAsFixed(0)} km/h',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: AppTheme.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Live Speed',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.midGrey,
                          ),
                        ),
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
                              Icon(
                                Icons.people_outline,
                                size: 15,
                                color: AppTheme.black,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${routeDrivers.first.occupancy} PAX',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: AppTheme.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Occupancy',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.midGrey,
                          ),
                        ),
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
                decoration: BoxDecoration(
                  color: AppTheme.hailColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pan_tool_alt,
                  color: AppTheme.hailColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hand Raised on Route!',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppTheme.brandNavy,
                      ),
                    ),
                    Text(
                      'Approaching vehicles have received your stop alert.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => transit.cancelHail(auth.userId),
            child: const Text(
              'Cancel Hail',
              style: TextStyle(
                color: AppTheme.accentRed,
                fontWeight: FontWeight.bold,
              ),
            ),
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
    final assignedDrivers = routeDrivers
        .where((driver) => driver.driverId == transit.assignedDriverId)
        .toList();
    final assignedDriver = assignedDrivers.isNotEmpty
        ? assignedDrivers.first
        : null;
    double? distMeters = transit.etaDistanceMeters;
    if (distMeters == null && assignedDriver != null) {
      distMeters = _calculateDistanceMeters(
        transit.currentLocation.latitude,
        transit.currentLocation.longitude,
        assignedDriver.latitude,
        assignedDriver.longitude,
      );
    }
    final driverHasArrived =
        transit.passengerStatus == PassengerTripStatus.driverArrived;
    final pickupArea = transit.taxiPickupName ?? 'your pickup point';
    final vehiclePlate =
        (transit.matchedDriverPlate?.isNotEmpty == true &&
            transit.matchedDriverPlate != 'B-BW')
        ? transit.matchedDriverPlate!
        : (assignedDriver?.vehicleId ?? 'Active Vehicle');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: driverHasArrived
                  ? AppTheme.statusSuccess.withValues(alpha: 0.12)
                  : AppTheme.primaryTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: driverHasArrived
                    ? AppTheme.statusSuccess
                    : AppTheme.primaryTeal,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  driverHasArrived
                      ? Icons.where_to_vote
                      : Icons.access_time_filled,
                  color: driverHasArrived
                      ? AppTheme.statusSuccess
                      : AppTheme.primaryTeal,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    driverHasArrived
                        ? '${widget.mode == TransportMode.bus ? 'A bus' : 'A combi'} is near $pickupArea!'
                        : '${widget.mode == TransportMode.bus ? 'A bus' : 'A combi'} is approaching $pickupArea',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppTheme.brandNavy,
                    ),
                  ),
                ),
                if (!driverHasArrived)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandNavy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ETA: ${transit.etaDisplay}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.statusSuccess.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.mode == TransportMode.bus
                      ? Icons.directions_bus
                      : Icons.airport_shuttle,
                  color: AppTheme.statusSuccess,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transit.matchedDriverName?.isNotEmpty == true
                          ? transit.matchedDriverName!
                          : (driverHasArrived
                                ? '${widget.mode == TransportMode.bus ? 'Bus' : 'Combi'} nearby'
                                : 'Vehicles on your route'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.brandNavy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (transit.matchedDriverPhone?.isNotEmpty == true)
                      Text(
                        'Phone • ${transit.matchedDriverPhone!}',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      'Vehicle • $vehiclePlate',
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      driverHasArrived
                          ? 'Your ${widget.mode == TransportMode.bus ? 'bus' : 'combi'} is near. Please board at a safe stop.'
                          : (distMeters != null
                                ? 'En route (${distMeters < 1000 ? "${distMeters.toStringAsFixed(0)}m" : "${(distMeters / 1000).toStringAsFixed(1)} km"} away) • Est. arrival: ${transit.etaDisplay}'
                                : 'En route to $pickupArea • Est. arrival: ${transit.etaDisplay}'),
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (driverHasArrived) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => transit.confirmBoarding(auth.userId),
              icon: const Icon(Icons.hail, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: const Text(
                'Confirm Boarding (I am on board)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnBoardCard(
    BuildContext context,
    TransitProvider transit,
    AuthProvider auth,
  ) {
    // Show "I've Arrived" only after stop is signaled AND vehicle has slowed/stopped
    final vehicleStationary = transit.vehicleSpeedKmh < 5.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.borderGrey, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (widget.mode == TransportMode.bus
                              ? AppTheme.busColor
                              : AppTheme.combiColor)
                          .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.mode == TransportMode.bus
                      ? Icons.directions_bus
                      : Icons.airport_shuttle,
                  color: widget.mode == TransportMode.bus
                      ? AppTheme.busColor
                      : AppTheme.combiColor,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppTheme.black,
                      ),
                    ),
                    Text(
                      'Route: ${widget.route.name}',
                      style: TextStyle(color: AppTheme.midGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Live vehicle speed badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: vehicleStationary
                      ? Colors.orange.shade50
                      : AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: vehicleStationary
                        ? Colors.orange.shade300
                        : AppTheme.lightGrey,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      vehicleStationary
                          ? Icons.pause_circle_outline
                          : Icons.speed,
                      size: 13,
                      color: vehicleStationary
                          ? AppTheme.statusWarning
                          : AppTheme.statusSuccess,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehicleStationary
                          ? 'Stopped'
                          : '${transit.vehicleSpeedKmh.toStringAsFixed(0)} km/h',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: vehicleStationary
                            ? AppTheme.statusWarning
                            : AppTheme.statusSuccess,
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
                        content: Text(
                          'Stop signal sent to driver! 🔔 Wait for vehicle to stop.',
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
            icon: Icon(
              _stopRequested
                  ? Icons.check_circle
                  : Icons.notifications_active_outlined,
              size: 18,
              color: _stopRequested
                  ? AppTheme.statusSuccess
                  : AppTheme.statusWarning,
            ),
            label: Text(
              _stopRequested
                  ? 'Stop Signaled ✅ — Wait for vehicle to stop'
                  : 'Signal Stop / Request Next Stop 🔔',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _stopRequested
                    ? AppTheme.statusSuccess
                    : AppTheme.brandNavy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              side: BorderSide(
                color: _stopRequested
                    ? AppTheme.statusSuccess
                    : AppTheme.statusWarning,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              setState(() => _stopRequested = false);
              await transit.passengerEndTrip(
                passengerId: auth.userId,
                finalFare: widget.route.baseFare,
              );
            },
            icon: const Icon(Icons.pin_drop, size: 18),
            label: const Text(
              'I Have Arrived • End My Trip',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(
    BuildContext context,
    TransitProvider transit,
    AuthProvider auth,
  ) {
    final driverIdToRate =
        transit.assignedDriverId ??
        (transit.activeDrivers.isNotEmpty
            ? transit.activeDrivers.first.driverId
            : 'driver-1');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.statusSuccess.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppTheme.statusSuccess,
              size: 32,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Trip Completed!',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppTheme.brandNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            widget.mode == TransportMode.bus
                ? widget.route.baseFare > 0
                      ? 'Route fare: P${widget.route.baseFare.toStringAsFixed(2)}'
                      : 'Route fare not set'
                : 'Fare: P${widget.route.baseFare.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Rate your Driver & Trip Experience',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.brandNavy,
            ),
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
                  color: AppTheme.statusWarning,
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
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              filled: true,
              fillColor: AppTheme.surfaceGrey,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderGrey),
              ),
            ),
            style: TextStyle(fontSize: 13, color: AppTheme.brandNavy),
          ),
          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: () {
              final ratingToSubmit = _tripRating;
              final commentToSubmit = _commentController.text.trim();
              _commentController.clear();
              if (mounted) {
                setState(() {
                  _tripRating = 5;
                  _stopRequested = false;
                });
              }
              transit.submitRating(
                driverId: driverIdToRate,
                passengerId: auth.userId,
                rating: ratingToSubmit,
                comment: commentToSubmit,
              );
              widget.onExitToMain();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Submit Review & Finish',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
