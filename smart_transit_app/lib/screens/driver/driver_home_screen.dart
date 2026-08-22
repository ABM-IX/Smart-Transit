import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../../widgets/custom_map_view.dart';
import '../../widgets/status_pill.dart';
import 'spacing_advisory_widget.dart';
import '../auth/welcome_screen.dart';

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
  final int _tripsCompleted = 0;
  final double _shiftRevenue = 0.0;
  String? _displayedHailId;
  bool _showHailAlert = false;

  @override
  Widget build(BuildContext context) {
    final transit = Provider.of<TransitProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    // Filter incoming hails to only those matching this driver's route
    final targetRoute = widget.driverRole == UserRole.driverTaxi ? 'taxi-service' : widget.routeId;
    final relevantHails = transit.incomingHails.where((h) => h.routeId == targetRoute).toList();

    // Trigger non-intrusive 5s auto-dismissing hail toast on new hail
    if (relevantHails.isNotEmpty && relevantHails.first.requestId != _displayedHailId) {
      _displayedHailId = relevantHails.first.requestId;
      _showHailAlert = true;
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showHailAlert = false);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          // Live Map
          CustomMapView(
            userLocation: transit.currentLocation,
            stops: transit.stops,
            drivers: transit.activeDrivers,
          ),

          // Top Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Back / Logout button
                      CircleAvatar(
                        backgroundColor: AppTheme.white,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppTheme.black, size: 20),
                          onPressed: () {
                            if (transit.isDriverOnline) {
                              transit.toggleDriverOnline(
                                driverId: auth.userId,
                                serviceType: widget.driverRole.serviceType,
                                routeId: widget.routeId,
                                vehicleId: auth.vehiclePlate,
                              );
                            }
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Route & Vehicle Info
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${widget.driverRole.displayName} Shift',
                                style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
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
                          backgroundColor: transit.isDriverOnline ? AppTheme.accentRed : AppTheme.accentGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(
                          transit.isDriverOnline ? 'GO OFFLINE' : 'GO ONLINE',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Connection & GPS Badges (Responsive Wrap to prevent any horizontal overflow)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusPill(
                        label: transit.isDriverOnline ? 'ONLINE • GPS Active' : 'OFFLINE',
                        color: transit.isDriverOnline ? AppTheme.accentGreen : AppTheme.midGrey,
                        icon: transit.isDriverOnline ? Icons.sensors : Icons.sensors_off,
                      ),
                      if (relevantHails.isNotEmpty)
                        StatusPill(
                          label: '${relevantHails.length} Waiting on Route',
                          color: AppTheme.accentAmber,
                          icon: Icons.pan_tool_alt_outlined,
                        ),
                      StatusPill(
                        label: 'Shift Rev: P${_shiftRevenue.toStringAsFixed(2)}',
                        color: AppTheme.black,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Spacing Advisory Banner
          if (transit.isDriverOnline && widget.driverRole != UserRole.driverTaxi)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: SpacingAdvisoryWidget(advisory: transit.spacingAdvisory),
            ),

          // 🔔 Passenger Stop Requested Banner
          if (transit.lastStopRequest != null)
            Positioned(
              top: 185,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'STOP REQUESTED!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          const Text(
                            'Passenger signaling to get off ahead 🛑',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => transit.dismissStopRequest(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('OK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

          // ✋ Non-intrusive 5s Auto-Dismissing Hail Banner
          if (_showHailAlert && relevantHails.isNotEmpty)
            Positioned(
              top: 185,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pan_tool_alt, color: AppTheme.accentGreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Passenger Hail on Route!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          Text(
                            relevantHails.first.stopName != null
                                ? 'Waiting at ${relevantHails.first.stopName} (P${relevantHails.first.fareEstimate.toStringAsFixed(2)})'
                                : 'Waiting along corridor (P${relevantHails.first.fareEstimate.toStringAsFixed(2)})',
                            style: const TextStyle(color: AppTheme.lightGrey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showHailAlert = false),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('OK', style: TextStyle(color: AppTheme.black, fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
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
                  maxHeight: MediaQuery.of(context).size.height * 0.50,
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
    List<dynamic> relevantHails,
  ) {
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
          if (relevantHails.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pan_tool_alt_outlined, size: 16, color: AppTheme.accentGreen),
                  const SizedBox(width: 8),
                  Text(
                    '${relevantHails.length} passenger(s) waiting along this route',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.black),
                  ),
                ],
              ),
            ),

          // Occupancy Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vehicle Occupancy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.black),
              ),
              Text(
                '$_tripsCompleted Trips • ${transit.passengersCarried} Passengers',
                style: const TextStyle(fontSize: 12, color: AppTheme.midGrey),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: ['Empty', 'Half Full', 'Almost Full', 'Full'].map((level) {
              final isSelected = _occupancy == level;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ChoiceChip(
                    label: Text(level, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? AppTheme.white : AppTheme.black)),
                    selected: isSelected,
                    selectedColor: AppTheme.black,
                    backgroundColor: AppTheme.offWhite,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _occupancy = level);
                      final route = widget.driverRole == UserRole.driverTaxi ? 'taxi-service' : widget.routeId;
                      transit.updateDriverOccupancy(
                        driverId: auth.userId,
                        routeId: route,
                        serviceType: widget.driverRole.serviceType,
                        vehicleId: auth.vehiclePlate,
                        occupancyText: level,
                      );
                    },
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
