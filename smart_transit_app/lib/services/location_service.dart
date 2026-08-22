import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;

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

  void startLocationTracking(Function(LatLng pos, double speed, double heading) onLocationChanged) {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3, // Update every 3 meters
      ),
    ).listen((pos) {
      onLocationChanged(LatLng(pos.latitude, pos.longitude), pos.speed * 3.6, pos.heading);
    });
  }

  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}
