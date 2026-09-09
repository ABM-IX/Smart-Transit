import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../models/driver_model.dart';
import '../models/hail_request_model.dart';
import '../models/route_model.dart';

class DrivingMapView extends StatefulWidget {
  final LatLng userLocation;
  final double heading; // 0..360 degrees
  final double speedKmh;
  final String routeName;
  final String? destinationName;
  final List<TransitStop> stops;
  final List<HailRequest> activeHails;
  final List<LiveDriver> otherDrivers;
  final SpacingAdvisory? spacingAdvisory;
  final VoidCallback? onToggleOnline;
  final bool isOnline;
  final double? topPadding;
  final double? bottomPadding;

  const DrivingMapView({
    super.key,
    required this.userLocation,
    this.heading = 0.0,
    this.speedKmh = 0.0,
    required this.routeName,
    this.destinationName,
    this.stops = const [],
    this.activeHails = const [],
    this.otherDrivers = const [],
    this.spacingAdvisory,
    this.onToggleOnline,
    this.isOnline = false,
    this.topPadding,
    this.bottomPadding,
  });

  @override
  State<DrivingMapView> createState() => _DrivingMapViewState();
}

class _DrivingMapViewState extends State<DrivingMapView> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Animation controllers for smooth gliding and pulsing
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _hailPulseController;
  late Animation<double> _hailPulseAnimation;

  // Free-Explore & Auto-Recenter Timer State
  bool _isFreeExplore = false;
  int _countdownSeconds = 8;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _hailPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _hailPulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _hailPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant DrivingMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isFreeExplore) {
      // Auto-follow vehicle in Driving Mode with smooth glide
      _mapController.move(widget.userLocation, 17.2);
      if (widget.heading > 0) {
        _mapController.rotate(-widget.heading);
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _hailPulseController.dispose();
    super.dispose();
  }

  void _onUserPannedMap() {
    if (!_isFreeExplore) {
      setState(() {
        _isFreeExplore = true;
        _countdownSeconds = 8;
      });
      _startRecenterCountdown();
    } else {
      // Reset timer on continuous interactions
      setState(() {
        _countdownSeconds = 8;
      });
    }
  }

  void _startRecenterCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        _recenterCamera();
      }
    });
  }

  void _recenterCamera() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isFreeExplore = false;
      _countdownSeconds = 8;
    });
    _mapController.move(widget.userLocation, 17.2);
    if (widget.heading > 0) {
      _mapController.rotate(-widget.heading);
    }
  }

  // Calculate distance between two GPS coordinates in meters
  double _calculateDistanceMeters(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    final dLat = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * (math.pi / 180.0)) *
            math.cos(p2.latitude * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Proximity vehicle check
  LiveDriver? _getNearestVehicleAhead() {
    LiveDriver? nearest;
    double minDistance = double.infinity;

    for (final driver in widget.otherDrivers) {
      final dLoc = LatLng(driver.latitude, driver.longitude);
      final dist = _calculateDistanceMeters(widget.userLocation, dLoc);
      if (dist < 400 && dist > 10 && dist < minDistance) {
        minDistance = dist;
        nearest = driver;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final topOffset = widget.topPadding ?? (isLandscape ? 6.0 : 8.0);
    final bottomOffset = widget.bottomPadding ?? (isLandscape ? 70.0 : 120.0);

    final nearestVehicle = _getNearestVehicleAhead();
    final double? vehicleDistance = nearestVehicle != null
        ? _calculateDistanceMeters(
            widget.userLocation,
            LatLng(nearestVehicle.latitude, nearestVehicle.longitude),
          )
        : null;

    // Next Stop / Waypoint calculation
    String nextStopTitle = widget.destinationName?.isNotEmpty == true
        ? widget.destinationName!
        : 'Main Terminal / Station';
    int estimatedDistanceM = 320;

    if (widget.stops.isNotEmpty) {
      nextStopTitle = widget.stops.first.name;
    } else if (widget.activeHails.isNotEmpty) {
      nextStopTitle = 'Hailer on Route (${widget.activeHails.first.stopName ?? "Waiting passenger"})';
      estimatedDistanceM = 180;
    }

    return Stack(
      children: [
        // Base Map Layer
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.userLocation,
            initialZoom: 17.2,
            minZoom: 6.0,
            maxZoom: 18.5,
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) {
                _onUserPannedMap();
              }
            },
          ),
          children: [
            // OpenStreetMap Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.smarttransit.app',
            ),

            // Map Markers Layer
            MarkerLayer(
              markers: [
                // 1. Other Vehicles / Drivers
                ...widget.otherDrivers.map((d) {
                  return Marker(
                    point: LatLng(d.latitude, d.longitude),
                    width: 44,
                    height: 44,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            d.vehicleId ?? d.serviceType,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(Icons.airport_shuttle, color: AppTheme.accentAmber, size: 24),
                      ],
                    ),
                  );
                }),

                // 2. Active Waiting Hailers / People at Stops with Animation
                ...widget.activeHails.map((hail) {
                  return Marker(
                    point: LatLng(hail.pickupLat, hail.pickupLng),
                    width: 70,
                    height: 70,
                    child: AnimatedBuilder(
                      animation: _hailPulseAnimation,
                      builder: (ctx, child) {
                        return Transform.scale(
                          scale: _hailPulseAnimation.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentGreen.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pan_tool_alt, color: Colors.white, size: 12),
                                    SizedBox(width: 3),
                                    Text(
                                      'WAITING',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.accentGreen, width: 2.5),
                                ),
                                child: const Center(
                                  child: Icon(Icons.person, color: AppTheme.black, size: 16),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }),

                // 3. Driver's Moving Vehicle Marker (3D Google Maps Style Chevron & Forward Beam)
                Marker(
                  point: widget.userLocation,
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Forward Headlight / Trajectory Beam Pulse
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (ctx, child) {
                          return Transform.rotate(
                            angle: (widget.heading * (math.pi / 180.0)),
                            child: Container(
                              width: 80 * _pulseAnimation.value,
                              height: 80 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppTheme.accentGreen.withValues(alpha: 0.35),
                                    AppTheme.accentGreen.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Animated Vehicle Chevron
                      Transform.rotate(
                        angle: (widget.heading * (math.pi / 180.0)),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppTheme.black,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.navigation,
                              color: AppTheme.accentGreen,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // TOP HUD: Google Maps-Style Advance Turn & Stop Guidance Banner
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 14.0,
              right: 14.0,
              top: topOffset,
              bottom: 6.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Navigation Direction Banner
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: isLandscape ? 8 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20), // Google Maps Green
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.straight,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'In ${estimatedDistanceM}m',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${widget.speedKmh.toStringAsFixed(0)} km/h',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextStopTitle,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Vehicle Ahead Proximity Alert (if car ahead detected)
                if (nearestVehicle != null && vehicleDistance != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: vehicleDistance < 150 ? AppTheme.accentAmber : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.lightGrey),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 18,
                          color: vehicleDistance < 150 ? Colors.black : AppTheme.accentAmber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Vehicle Ahead • ${vehicleDistance.toStringAsFixed(0)}m ahead • Normal Spacing',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: vehicleDistance < 150 ? Colors.black : AppTheme.black,
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

        // FLOATING RE-CENTER BUTTON (Appears when map is panned/pinched)
        if (_isFreeExplore)
          Positioned(
            bottom: bottomOffset,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _recenterCamera,
                icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
                label: Text(
                  'Re-center (${_countdownSeconds}s)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 6,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
