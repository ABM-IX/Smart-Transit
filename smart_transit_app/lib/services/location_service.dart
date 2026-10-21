import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
  Timer? _positionHeartbeat;

  Future<LatLng> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      // Try last known position if current times out
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          return LatLng(lastPos.latitude, lastPos.longitude);
        }
      } catch (_) {}
      return const LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    }
  }

  void startLocationTracking(void Function(Position position) onLocationChanged) {
    _positionStream?.cancel();
    _positionHeartbeat?.cancel();
    Position? lastDeliveredPosition;
    DateTime? lastDeliveredAt;
    var heartbeatInFlight = false;

    void deliver(Position position) {
      final now = DateTime.now();
      final previous = lastDeliveredPosition;
      final movedMeters = previous == null
          ? double.infinity
          : Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              position.latitude,
              position.longitude,
            );
      final secondsSinceLast = lastDeliveredAt == null
          ? double.infinity
          : now.difference(lastDeliveredAt!).inMilliseconds / 1000;
      if (movedMeters < 5 && secondsSinceLast < 3) return;
      lastDeliveredPosition = position;
      lastDeliveredAt = now;
      onLocationChanged(position);
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? const AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
              intervalDuration: Duration(seconds: 4),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
            ),
    ).listen(deliver);

    // Some platforms apply distanceFilter without emitting a fresh fix while
    // the passenger is stationary. Polling every four seconds keeps the GPS
    // timestamp fresh for proximity decisions without broadcasting every fix.
    _positionHeartbeat = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (heartbeatInFlight) return;
      heartbeatInFlight = true;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 3),
          ),
        );
        deliver(position);
      } catch (_) {
        // Keep the watch alive through temporary GPS/network gaps.
      } finally {
        heartbeatInFlight = false;
      }
    });
  }

  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _positionHeartbeat?.cancel();
    _positionHeartbeat = null;
  }
}
