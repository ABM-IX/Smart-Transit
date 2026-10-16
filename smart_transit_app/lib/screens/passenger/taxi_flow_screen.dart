import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../../widgets/custom_map_view.dart';
import '../../widgets/status_pill.dart';

class TaxiFlowScreen extends StatefulWidget {
  final VoidCallback? onExitToMain;

  const TaxiFlowScreen({super.key, this.onExitToMain});

  @override
  State<TaxiFlowScreen> createState() => _TaxiFlowScreenState();
}

class _TaxiFlowScreenState extends State<TaxiFlowScreen> {
  String _serviceType = 'STANDARD';
  final TextEditingController _destController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  LatLng? _destinationLocation;
  int _tripRating = 5;

  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=bw',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'SmartTransit-App'},
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _suggestions = data
              .take(5)
              .map(
                (item) => {
                  'name': item['display_name']?.toString() ?? '',
                  'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
                  'lon': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
                },
              )
              .toList();
        });
      }
    } catch (_) {
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to main screen',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onExitToMain ?? () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Taxi Service',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _buildTaxiMapTab(),
    );
  }

  Widget _buildTaxiMapTab() {
    final transit = Provider.of<TransitProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Only taxi drivers
    final taxiDrivers = transit.activeDrivers
        .where((d) => d.serviceType == 'TAXI')
        .toList();

    return Stack(
      children: [
        CustomMapView(
          userLocation: transit.currentLocation,
          drivers: taxiDrivers,
        ),

        // Live Taxis Count Badge
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: StatusPill(
              label: '${taxiDrivers.length} Online Cabs Nearby',
              color: AppTheme.black,
              icon: Icons.local_taxi,
            ),
          ),
        ),

        // Bottom Booking Card
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
                child: _buildTaxiBottomCard(transit, auth),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxiBottomCard(TransitProvider transit, AuthProvider auth) {
    if (transit.passengerStatus == PassengerTripStatus.searchingTaxi) {
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
            CircularProgressIndicator(color: AppTheme.black, strokeWidth: 2),
            const SizedBox(height: 16),
            Text(
              'Finding Closest Available Cab...',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dispatching request to drivers nearby.',
              style: TextStyle(color: AppTheme.midGrey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => transit.cancelHail(auth.userId),
              child: const Text(
                'Cancel Request',
                style: TextStyle(color: AppTheme.accentRed),
              ),
            ),
          ],
        ),
      );
    }

    if (transit.passengerStatus == PassengerTripStatus.driverAccepted) {
      final taxiDrivers = transit.activeDrivers
          .where((d) => d.serviceType == 'TAXI')
          .toList();
      double? distMeters = transit.etaDistanceMeters;
      if (distMeters == null && taxiDrivers.isNotEmpty) {
        const double p = 0.017453292519943295;
        final lat1 = transit.currentLocation.latitude;
        final lon1 = transit.currentLocation.longitude;
        final lat2 = taxiDrivers.first.latitude;
        final lon2 = taxiDrivers.first.longitude;
        final a =
            0.5 -
            math.cos((lat2 - lat1) * p) / 2 +
            math.cos(lat1 * p) *
                math.cos(lat2 * p) *
                (1 - math.cos((lon2 - lon1) * p)) /
                2;
        distMeters = 12742 * math.asin(math.sqrt(a)) * 1000.0;
      }
      final isWithinProximity = distMeters != null && distMeters <= 25.0;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
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
                    color: AppTheme.taxiColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    color: AppTheme.taxiColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxi Assigned (${transit.assignedDriverId ?? "Driver En Route"})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.brandNavy,
                        ),
                      ),
                      Text(
                        isWithinProximity
                            ? 'Cab arrived at pickup point!'
                            : (distMeters != null
                                  ? 'Cab is en route (${distMeters < 1000 ? "${distMeters.toStringAsFixed(0)}m" : "${(distMeters / 1000).toStringAsFixed(1)}km"} away) • P${(transit.estimatedFare ?? AppConstants.taxiBaseFareBWP).toStringAsFixed(2)}'
                                  : 'Driver is en route to pickup point • P${(transit.estimatedFare ?? AppConstants.taxiBaseFareBWP).toStringAsFixed(2)}'),
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
            if (isWithinProximity) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => transit.confirmBoarding(auth.userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Confirm Boarding (In the Cab)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (transit.passengerStatus == PassengerTripStatus.onBoard) {
      final vehicleStationary = transit.vehicleSpeedKmh < 5.0;
      return Container(
        padding: const EdgeInsets.all(20),
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
                    color: AppTheme.taxiColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppTheme.taxiColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip in Progress',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppTheme.brandNavy,
                        ),
                      ),
                      Text(
                        'Cruising with ${transit.assignedDriverId ?? "Driver"} • Enjoy your ride!',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Live speed badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: vehicleStationary
                        ? AppTheme.statusWarning.withValues(alpha: 0.12)
                        : AppTheme.surfaceGrey,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: vehicleStationary
                          ? AppTheme.statusWarning
                          : AppTheme.borderGrey,
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trip Fare:',
                    style: TextStyle(
                      color: AppTheme.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'P${(transit.estimatedFare ?? AppConstants.taxiBaseFareBWP).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppTheme.brandNavy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => transit.passengerEndTrip(
                passengerId: auth.userId,
                driverId: transit.assignedDriverId,
                finalFare:
                    transit.estimatedFare ?? AppConstants.taxiBaseFareBWP,
              ),
              icon: const Icon(Icons.pin_drop, size: 18),
              label: const Text(
                'I Have Arrived • End My Trip',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandNavy,
                foregroundColor: Colors.white,
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

    if (transit.passengerStatus == PassengerTripStatus.completed) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppTheme.borderGrey, width: 1)),
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
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Trip Completed!',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppTheme.brandNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Fare: P${(transit.estimatedFare ?? AppConstants.taxiBaseFareBWP).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Rate your Driver',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.brandNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                return IconButton(
                  icon: Icon(
                    starNum <= _tripRating ? Icons.star : Icons.star_border,
                    color: AppTheme.statusWarning,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _tripRating = starNum),
                );
              }),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                transit.submitRating(
                  driverId: transit.assignedDriverId ?? 'driver-1',
                  passengerId: auth.userId,
                  rating: _tripRating,
                );
                setState(() => _tripRating = 5);
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
                'Submit Rating & Done',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

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
          // Standard vs Special Chips
          Row(
            children: [
              ChoiceChip(
                label: Text(
                  'Standard (P${AppConstants.taxiBaseFareBWP.toStringAsFixed(2)})',
                ),
                selected: _serviceType == 'STANDARD',
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: AppTheme.surfaceContainer,
                side: BorderSide(
                  color: _serviceType == 'STANDARD'
                      ? Theme.of(context).colorScheme.primary
                      : AppTheme.outline,
                ),
                labelStyle: TextStyle(
                  color: _serviceType == 'STANDARD'
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _serviceType = 'STANDARD'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Special / Direct (Metered)'),
                selected: _serviceType == 'SPECIAL',
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: AppTheme.surfaceContainer,
                side: BorderSide(
                  color: _serviceType == 'SPECIAL'
                      ? Theme.of(context).colorScheme.primary
                      : AppTheme.outline,
                ),
                labelStyle: TextStyle(
                  color: _serviceType == 'SPECIAL'
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _serviceType = 'SPECIAL'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Destination Search Field
          TextField(
            controller: _destController,
            onChanged: _searchAddress,
            decoration: InputDecoration(
              hintText: 'Where to? (e.g. Main Mall, Game City)',
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: AppTheme.black,
              ),
              suffixIcon: _isSearching
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.black,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.offWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.lightGrey),
              ),
            ),
          ),

          // Suggestions List
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (ctx, idx2) =>
                    Divider(height: 1, color: AppTheme.lightGrey),
                itemBuilder: (context, idx) {
                  final s = _suggestions[idx];
                  return ListTile(
                    dense: true,
                    title: Text(
                      s['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppTheme.black),
                    ),
                    onTap: () {
                      _destController.text = s['name'] ?? '';
                      _destinationLocation = LatLng(s['lat'], s['lon']);
                      setState(() => _suggestions = []);
                    },
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              transit.requestTaxiBooking(
                passengerId: auth.userId,
                serviceType: _serviceType,
                pickup: transit.currentLocation,
                dropoff: _destinationLocation,
              );
            },
            child: Text('Request $_serviceType Cab Now'),
          ),
        ],
      ),
    );
  }
}
