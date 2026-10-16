import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/driver_model.dart';
import '../models/hail_request_model.dart';
import '../models/route_model.dart';
import 'map_tile_theme.dart';

class CustomMapView extends StatefulWidget {
  final LatLng userLocation;
  final List<TransitStop> stops;
  final List<LiveDriver> drivers;
  final List<HailRequest> activeHails;
  final Function(TransitStop)? onStopTapped;
  final Function(LiveDriver)? onDriverTapped;

  const CustomMapView({
    super.key,
    required this.userLocation,
    this.stops = const [],
    this.drivers = const [],
    this.activeHails = const [],
    this.onStopTapped,
    this.onDriverTapped,
  });

  @override
  State<CustomMapView> createState() => _CustomMapViewState();
}

class _CustomMapViewState extends State<CustomMapView> {
  final MapController _mapController = MapController();
  bool _hasCenteredOnUser = false;

  @override
  void didUpdateWidget(covariant CustomMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When real GPS coordinates arrive from device (different from default mock), center map
    if (!_hasCenteredOnUser &&
        (widget.userLocation.latitude != AppConstants.defaultLatitude ||
            widget.userLocation.longitude != AppConstants.defaultLongitude)) {
      _hasCenteredOnUser = true;
      _mapController.move(widget.userLocation, AppConstants.defaultZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.userLocation,
        initialZoom: AppConstants.defaultZoom,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        // OpenStreetMap Tile Layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.smarttransit.app',
          tileBuilder: Theme.of(context).brightness == Brightness.dark
              ? smartTransitDarkTileBuilder
              : null,
        ),

        // Markers Layer
        MarkerLayer(
          markers: [
            // User Location Marker (Botswana sky pulse + brand navy core)
            Marker(
              point: widget.userLocation,
              width: 48,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.botswanaSky.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.brandNavy,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.cardSurface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandNavy.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Stop Markers (High contrast, distinct shape + icon)
            ...widget.stops.map((stop) {
              return Marker(
                point: LatLng(stop.latitude, stop.longitude),
                width: 32,
                height: 32,
                child: GestureDetector(
                  onTap: () => widget.onStopTapped?.call(stop),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.brandNavy, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandNavy.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.place,
                      color: AppTheme.brandNavy,
                      size: 16,
                    ),
                  ),
                ),
              );
            }),

            // Active Passenger Hail Markers (Urgent red hailColor + hand icon)
            ...widget.activeHails.map((hail) {
              return Marker(
                point: LatLng(hail.pickupLat, hail.pickupLng),
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.hailColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardSurface, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.hailColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.pan_tool_alt,
                      color: AppTheme.onPrimary,
                      size: 22,
                    ),
                  ),
                ),
              );
            }),

            // Live Driver Markers: Distinct by color + icon + shape
            ...widget.drivers.map((driver) {
              final isTaxi = driver.serviceType == 'TAXI';
              final isBus =
                  driver.serviceType == 'BUS' ||
                  (driver.routeId?.startsWith('bus-') ?? false);

              final Color modeColor = isTaxi
                  ? AppTheme.taxiColor
                  : isBus
                  ? AppTheme.busColor
                  : AppTheme.combiColor;

              final IconData modeIcon = isTaxi
                  ? Icons.local_taxi
                  : isBus
                  ? Icons.directions_bus
                  : Icons.airport_shuttle;

              final BorderRadius borderRadius = isBus
                  ? BorderRadius.circular(8) // Squircle for Bus
                  : isTaxi
                  ? BorderRadius.circular(100) // Circular for Taxi
                  : BorderRadius.circular(12); // Rounded rectangle for Combi

              return Marker(
                point: LatLng(driver.latitude, driver.longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => widget.onDriverTapped?.call(driver),
                  child: Container(
                    decoration: BoxDecoration(
                      color: modeColor,
                      borderRadius: borderRadius,
                      border: Border.all(
                        color: AppTheme.cardSurface,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: modeColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(modeIcon, color: AppTheme.onPrimary, size: 20),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}
