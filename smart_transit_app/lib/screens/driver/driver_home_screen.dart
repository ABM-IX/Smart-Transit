import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/hail_request_model.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../../services/place_name_service.dart';
import '../../widgets/custom_map_view.dart';
import '../../widgets/status_pill.dart';
import 'spacing_advisory_widget.dart';

class DriverHomeScreen extends StatefulWidget {
  final UserRole driverRole;
  final String routeName;
  final String routeId;

  const DriverHomeScreen({
    super.key,
    required this.driverRole,
    required this.routeName,
    required this.routeId,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String _occupancy = 'Empty';
  final double _shiftRevenue = 0.0;
  String? _displayedHailId;
  bool _showHailAlert = false;
  String? _resolvedHailPickupName;
  String? _lookupRequestId;

  Future<void> _resolveHailDetails(HailRequest hail) async {
    if (_lookupRequestId == hail.requestId) return;
    _lookupRequestId = hail.requestId;
    final name = await PlaceNameService.resolvePlaceName(
      LatLng(hail.pickupLat, hail.pickupLng),
      preferredName: hail.pickupName ?? hail.stopName,
    );
    if (mounted) {
      setState(() => _resolvedHailPickupName = name);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<TransitProvider>(
        context,
        listen: false,
      ).loadDriverTripCount(auth.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final transit = Provider.of<TransitProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    // Filter incoming hails to only those matching this driver's route
    final targetRoute = widget.driverRole == UserRole.driverTaxi
        ? 'taxi-service'
        : widget.routeId;
    final relevantHails = transit.incomingHails
        .where((h) => h.routeId == targetRoute)
        .toList();

    final activeHail = relevantHails.isNotEmpty ? relevantHails.first : null;
    if (activeHail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveHailDetails(activeHail);
      });
    } else if (_lookupRequestId != null) {
      _lookupRequestId = null;
      _resolvedHailPickupName = null;
    }

    // Trigger non-intrusive 5s auto-dismissing hail toast on new hail
    if (relevantHails.isNotEmpty &&
        relevantHails.first.requestId != _displayedHailId) {
      _displayedHailId = relevantHails.first.requestId;
      _showHailAlert = true;
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showHailAlert = false);
        }
      });
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          // Live Real-Time Map View (Pure GPS tracking without simulated static turn HUD)
          CustomMapView(
            userLocation: transit.currentLocation,
            stops: transit.stops,
            // Route drivers follow their predefined corridor. Show waiting
            // passengers on the map without routing the vehicle off-route.
            activeHails: relevantHails,
            drivers: transit.activeDrivers
                .where((d) => d.driverId != auth.userId)
                .toList(),
          ),

          // Top Header & Responsive Notification Stack
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 6.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Route & Vehicle Info
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${widget.routeName} • ${auth.vehiclePlate}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${widget.driverRole.displayName} Shift',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.midGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Online / Offline Toggle
                      ElevatedButton(
                        onPressed: () {
                          transit.toggleDriverOnline(
                            driverId: auth.userId,
                            serviceType: widget.driverRole.serviceType,
                            routeId: targetRoute,
                            vehicleId: auth.vehiclePlate,
                          );
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
                  const SizedBox(height: 6),

                  // Connection & GPS Badges (Responsive Wrap to prevent any horizontal overflow)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusPill(
                        label: transit.isDriverOnline
                            ? 'ONLINE • GPS Active'
                            : 'OFFLINE',
                        color: transit.isDriverOnline
                            ? AppTheme.accentGreen
                            : AppTheme.midGrey,
                        icon: transit.isDriverOnline
                            ? Icons.sensors
                            : Icons.sensors_off,
                      ),
                      if (transit.isDriverOnline)
                        StatusPill(
                          label: transit.vehicleSpeedKmh > 1.0
                              ? '${transit.vehicleSpeedKmh.toStringAsFixed(0)} km/h'
                              : '0 km/h (Stationary)',
                          color: transit.vehicleSpeedKmh > 1.0
                              ? AppTheme.accentBlue
                              : AppTheme.darkGrey,
                          icon: Icons.speed,
                        ),
                      if (relevantHails.isNotEmpty)
                        StatusPill(
                          label: '${relevantHails.length} Waiting on Route',
                          color: AppTheme.accentAmber,
                          icon: Icons.pan_tool_alt_outlined,
                        ),
                      StatusPill(
                        label:
                            'Shift Rev: P${_shiftRevenue.toStringAsFixed(2)}',
                        color: AppTheme.black,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),

                  // Spacing Advisory Banner (Flows naturally in column)
                  if (transit.isDriverOnline &&
                      widget.driverRole != UserRole.driverTaxi &&
                      transit.spacingAdvisory != null) ...[
                    const SizedBox(height: 6),
                    SpacingAdvisoryWidget(advisory: transit.spacingAdvisory),
                  ],

                  // 🔔 Passenger Stop Requested Banner
                  if (transit.lastStopRequest != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'STOP REQUESTED!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Passenger signaling to get off ahead 🛑',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => transit.dismissStopRequest(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'OK',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ✋ Non-intrusive 5s Auto-Dismissing Hail Banner
                  if (_showHailAlert && relevantHails.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.black,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pan_tool_alt,
                            color: AppTheme.hailColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Passenger Hail on Route!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Waiting near ${_resolvedHailPickupName ?? PlaceNameService.sanitizeLocationName(relevantHails.first.pickupName ?? relevantHails.first.stopName) ?? "your route"}',
                                  style: TextStyle(
                                    color: AppTheme.borderGrey,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showHailAlert = false),
                            style: TextButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'OK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Control Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: isLandscape
                      ? MediaQuery.of(context).size.height * 0.42
                      : MediaQuery.of(context).size.height * 0.50,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildDriverBottomPanel(transit, auth, relevantHails),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverBottomPanel(
    TransitProvider transit,
    AuthProvider auth,
    List<HailRequest> relevantHails,
  ) {
    final pendingHail = relevantHails.isNotEmpty ? relevantHails.first : null;
    final waitingArea =
        _resolvedHailPickupName ??
        PlaceNameService.sanitizeLocationName(
          pendingHail?.pickupName ?? pendingHail?.stopName,
        ) ??
        'Route Corridor';

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
          if (pendingHail != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_pin_circle_outlined,
                        size: 18,
                        color: AppTheme.hailColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${relevantHails.length} passenger${relevantHails.length == 1 ? '' : 's'} waiting on your route',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Passenger location: $waitingArea. Continue along your assigned route and stop at the next safe pickup point.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Occupancy Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vehicle Occupancy',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.black,
                ),
              ),
              Text(
                '${transit.driverTripsCompleted} Trips • ${transit.passengersCarried} Passengers',
                style: TextStyle(fontSize: 12, color: AppTheme.midGrey),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: ['Empty', 'Half Full', 'Almost Full', 'Full'].map((
              level,
            ) {
              final isSelected = _occupancy == level;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final selectedBackground = Theme.of(context).colorScheme.primary;
              final selectedForeground = Theme.of(
                context,
              ).colorScheme.onPrimary;
              final idleBackground = isDark
                  ? const Color(0xFF1B2A40)
                  : const Color(0xFFF0F3F8);
              final idleForeground = isDark
                  ? const Color(0xFFF4F7FB)
                  : const Color(0xFF263445);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Material(
                    color: isSelected ? selectedBackground : idleBackground,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() => _occupancy = level);
                        final route = widget.driverRole == UserRole.driverTaxi
                            ? 'taxi-service'
                            : widget.routeId;
                        transit.updateDriverOccupancy(
                          driverId: auth.userId,
                          routeId: route,
                          serviceType: widget.driverRole.serviceType,
                          vehicleId: auth.vehiclePlate,
                          occupancyText: level,
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 38),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? selectedBackground
                                : (isDark
                                      ? const Color(0xFF40516A)
                                      : const Color(0xFFD4DCE7)),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            level,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? selectedForeground
                                  : idleForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
