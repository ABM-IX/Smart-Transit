import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/driver_model.dart';
import '../models/route_model.dart';

class CustomMapView extends StatefulWidget {
  final LatLng userLocation;
  final List<TransitStop> stops;
  final List<LiveDriver> drivers;
  final Function(TransitStop)? onStopTapped;
  final Function(LiveDriver)? onDriverTapped;

  const CustomMapView({
    super.key,
    required this.userLocation,
    this.stops = const [],
    this.drivers = const [],
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
        ),

        // Markers Layer
        MarkerLayer(
          markers: [
            // User Location Marker
            Marker(
              point: widget.userLocation,
              width: 44,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.white, width: 3),
                    ),
                  ),
                ),
              ),
            ),

            // Stop Markers
            ...widget.stops.map((stop) {
              return Marker(
                point: LatLng(stop.latitude, stop.longitude),
                width: 32,
                height: 32,
                child: GestureDetector(
                  onTap: () => widget.onStopTapped?.call(stop),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.black, width: 2),
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: AppTheme.black,
                      size: 16,
                    ),
                  ),
                ),
              );
            }),

            // Live Driver Markers
            ...widget.drivers.map((driver) {
              final isTaxi = driver.serviceType == 'TAXI';
              final color = isTaxi ? AppTheme.accentAmber : AppTheme.accentGreen;
              return Marker(
                point: LatLng(driver.latitude, driver.longitude),
                width: 38,
                height: 38,
                child: GestureDetector(
                  onTap: () => widget.onDriverTapped?.call(driver),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.white, width: 2),
                    ),
                    child: Icon(
                      isTaxi ? Icons.local_taxi : Icons.airport_shuttle,
                      color: AppTheme.black,
                      size: 18,
                    ),
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
