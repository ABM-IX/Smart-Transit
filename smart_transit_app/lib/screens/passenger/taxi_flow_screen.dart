import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../../widgets/custom_map_view.dart';
import '../../widgets/status_pill.dart';
import 'passenger_history_screen.dart';
import 'passenger_profile_screen.dart';

class TaxiFlowScreen extends StatefulWidget {
  final VoidCallback onBack;

  const TaxiFlowScreen({super.key, required this.onBack});

  @override
  State<TaxiFlowScreen> createState() => _TaxiFlowScreenState();
}

class _TaxiFlowScreenState extends State<TaxiFlowScreen> {
  int _selectedTab = 0;
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
      final res = await http.get(uri, headers: {'User-Agent': 'SmartTransit-App'});
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _suggestions = data.take(5).map((item) => {
            'name': item['display_name']?.toString() ?? '',
            'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
            'lon': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
          }).toList();
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
        title: const Text('Taxi Service', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.black),
          onPressed: widget.onBack,
        ),
      ),
      body: _buildTaxiMapTab(),
    );
  }

  Widget _buildTaxiMapTab() {
    final transit = Provider.of<TransitProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Only taxi drivers
    final taxiDrivers = transit.activeDrivers.where((d) => d.serviceType == 'TAXI').toList();

    return Stack(
      children: [
        CustomMapView(
          userLocation: transit.currentLocation,
          drivers: taxiDrivers,
        ),

        // Live Taxis Count Badge
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                maxHeight: MediaQuery.of(context).size.height * 0.65,
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
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.black, strokeWidth: 2),
            const SizedBox(height: 16),
            const Text(
              'Finding Closest Available Cab...',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.black),
            ),
            const SizedBox(height: 6),
            const Text('Dispatching request to drivers nearby.', style: TextStyle(color: AppTheme.midGrey, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => transit.cancelHail(auth.userId),
              child: const Text('Cancel Request', style: TextStyle(color: AppTheme.accentRed)),
            ),
          ],
        ),
      );
    }

    if (transit.passengerStatus == PassengerTripStatus.driverAccepted) {
      final taxiDrivers = transit.activeDrivers.where((d) => d.serviceType == 'TAXI').toList();
      double? distMeters = transit.etaDistanceMeters;
      if (distMeters == null && taxiDrivers.isNotEmpty) {
        const double p = 0.017453292519943295;
        final lat1 = transit.currentLocation.latitude;
        final lon1 = transit.currentLocation.longitude;
        final lat2 = taxiDrivers.first.latitude;
        final lon2 = taxiDrivers.first.longitude;
        final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 + math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
        distMeters = 12742 * math.asin(math.sqrt(a)) * 1000.0;
      }
      final isWithinProximity = distMeters != null && distMeters <= 25.0;

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
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppTheme.offWhite, shape: BoxShape.circle),
                  child: const Icon(Icons.local_taxi, color: AppTheme.accentGreen, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxi Assigned (${transit.assignedDriverId ?? "Driver En Route"})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.black),
                      ),
                      Text(
                        isWithinProximity
                            ? 'Cab arrived at pickup point (within 25m)!'
                            : 'Estimated Fare: P${(transit.estimatedFare ?? 25.0).toStringAsFixed(2)}',
                        style: const TextStyle(color: AppTheme.midGrey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isWithinProximity)
              ElevatedButton(
                onPressed: () => transit.confirmBoarding(auth.userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Confirm Boarding (In the Cab)', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightGrey),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sensors, color: AppTheme.midGrey, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        distMeters != null
                            ? 'Cab is ${distMeters.toStringAsFixed(0)}m away. Boarding button unlocks within 25m.'
                            : 'Cab en route. Boarding button unlocks within 25m.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.midGrey, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (transit.passengerStatus == PassengerTripStatus.onBoard) {
      final vehicleStationary = transit.vehicleSpeedKmh < 5.0;
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
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppTheme.offWhite, shape: BoxShape.circle),
                  child: const Icon(Icons.directions_car, color: AppTheme.accentGreen, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trip in Progress',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.black),
                      ),
                      Text(
                        'Cruising with ${transit.assignedDriverId ?? "Driver"} • Enjoy your ride!',
                        style: const TextStyle(color: AppTheme.midGrey, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Live speed badge
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Trip Fare:', style: TextStyle(color: AppTheme.midGrey, fontWeight: FontWeight.w600)),
                  Text(
                    'P${(transit.estimatedFare ?? 25.0).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => transit.passengerEndTrip(
                passengerId: auth.userId,
                driverId: transit.assignedDriverId,
                finalFare: transit.estimatedFare ?? 25.0,
              ),
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

    if (transit.passengerStatus == PassengerTripStatus.completed) {
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
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.offWhite,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 36),
            ),
            const SizedBox(height: 12),
            const Text(
              'Trip Completed!',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Fare: P${(transit.estimatedFare ?? 25.0).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.midGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Rate your Driver',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.black),
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
                    color: Colors.amber,
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
                backgroundColor: AppTheme.accentGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Submit Rating & Done', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ],
        ),
      );
    }

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
          // Standard vs Special Chips
          Row(
            children: [
              ChoiceChip(
                label: const Text('Standard (P8.00)'),
                selected: _serviceType == 'STANDARD',
                selectedColor: AppTheme.black,
                backgroundColor: AppTheme.white,
                labelStyle: TextStyle(
                  color: _serviceType == 'STANDARD' ? AppTheme.white : AppTheme.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _serviceType = 'STANDARD'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Special / Direct (Metered)'),
                selected: _serviceType == 'SPECIAL',
                selectedColor: AppTheme.black,
                backgroundColor: AppTheme.white,
                labelStyle: TextStyle(
                  color: _serviceType == 'SPECIAL' ? AppTheme.white : AppTheme.black,
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
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.black),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.black),
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.offWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.lightGrey),
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
                separatorBuilder: (ctx, idx2) => const Divider(height: 1, color: AppTheme.lightGrey),
                itemBuilder: (context, idx) {
                  final s = _suggestions[idx];
                  return ListTile(
                    dense: true,
                    title: Text(
                      s['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppTheme.black),
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

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.local_taxi, color: AppTheme.black),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trip to Main Mall CBD', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Completed • Standard Taxi', style: TextStyle(fontSize: 12, color: AppTheme.midGrey)),
                    ],
                  ),
                ),
                Text('P8.00', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    final auth = Provider.of<AuthProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.offWhite,
            child: const Icon(Icons.person, size: 40, color: AppTheme.black),
          ),
          const SizedBox(height: 16),
          Text(auth.userName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          Text(auth.userId, style: const TextStyle(color: AppTheme.midGrey, fontSize: 13)),
          const SizedBox(height: 24),
          const Divider(color: AppTheme.lightGrey),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Phone Number'),
            subtitle: const Text('+267 71 234 567'),
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Default Payment'),
            subtitle: const Text('Cash / Mobile Money'),
          ),
        ],
      ),
    );
  }
}
