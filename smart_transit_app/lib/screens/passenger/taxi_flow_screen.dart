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
  static const _navy = Color(0xFF101D2F);
  static const _panel = Color(0xFF19283D);
  static const _cyan = Color(0xFF22BCEB);
  String _serviceType = 'STANDARD';
  final TextEditingController _destController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  LatLng? _destinationLocation;
  int _tripRating = 5;
  double _offerFare = 12;
  List<LatLng> _routePoints = const [];
  double? _tripDistanceKm;
  int? _tripDurationMinutes;
  bool _routeLoading = false;
  String? _contactDriverId;
  String? _driverName;
  String? _driverPhone;

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  double get _specialFare {
    if (_destinationLocation == null) return 12;
    final pickup = context.read<TransitProvider>().currentLocation;
    const distance = Distance();
    final km = _tripDistanceKm ?? distance.as(LengthUnit.Kilometer, pickup, _destinationLocation!) * 1.25;
    final minutes = (_tripDurationMinutes ?? (km / 30 * 60).ceil()).toDouble();
    return math.max(12, 10 + math.max(0, km - 1) * 2.5 + math.max(0, minutes - 3) * .3).toDouble();
  }

  Widget _tierPill(String value, String title, String subtitle) {
    final selected = _serviceType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _serviceType = value;
        if (value == 'SPECIAL') _offerFare = _specialFare;
      }),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? _cyan : _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _cyan : const Color(0xFF34445D)),
        ),
        child: Row(children: [
          if (selected) const Icon(Icons.check, size: 16, color: Color(0xFF08233A)),
          if (selected) const SizedBox(width: 6),
          Expanded(child: Text('$title ($subtitle)', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF08233A) : Colors.white))),
        ]),
      ),
    );
  }

  Future<void> _loadRoute(LatLng destination) async {
    final pickup = context.read<TransitProvider>().currentLocation;
    setState(() => _routeLoading = true);
    try {
      final coords = '${pickup.longitude},${pickup.latitude};${destination.longitude},${destination.latitude}';
      final response = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson',
      )).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw StateError('Route unavailable');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final route = (data['routes'] as List).first as Map<String, dynamic>;
      final geometry = route['geometry']['coordinates'] as List;
      if (!mounted || destination != _destinationLocation) return;
      setState(() {
        _routePoints = geometry
            .map((point) => LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()))
            .toList();
        _tripDistanceKm = (route['distance'] as num).toDouble() / 1000;
        _tripDurationMinutes = ((route['duration'] as num).toDouble() / 60).ceil();
        _routeLoading = false;
        if (_serviceType == 'SPECIAL') _offerFare = _specialFare;
      });
    } catch (_) {
      if (!mounted || destination != _destinationLocation) return;
      const distance = Distance();
      final km = distance.as(LengthUnit.Kilometer, pickup, destination) * 1.25;
      setState(() {
        _routePoints = [pickup, destination];
        _tripDistanceKm = km;
        _tripDurationMinutes = (km / 25 * 60).ceil();
        _routeLoading = false;
        if (_serviceType == 'SPECIAL') _offerFare = _specialFare;
      });
    }
  }

  Future<void> _loadDriverContact(String driverId) async {
    try {
      final contact = await context.read<TransitProvider>().fetchUserContact(driverId);
      if (!mounted || _contactDriverId != driverId) return;
      setState(() {
        _driverName = contact?['full_name'];
        _driverPhone = contact?['phone_number'];
      });
    } catch (_) {}
  }

  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      if (mounted) setState(() => _suggestions = []);
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
        if (!mounted) return;
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
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1526),
        foregroundColor: Colors.white,
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
    final pickup = transit.currentLocation;
    const geo = Distance();
    final taxiDrivers = transit.activeDrivers
        .where((d) => d.serviceType == 'TAXI' && d.status == 'ONLINE')
        .where((d) => d.driverId == transit.assignedDriverId ||
            geo.as(LengthUnit.Meter, pickup, LatLng(d.latitude, d.longitude)) <= 4000)
        .toList();

    if (transit.passengerStatus == PassengerTripStatus.driverAccepted &&
        transit.assignedDriverId != null &&
        _contactDriverId != transit.assignedDriverId &&
        transit.matchedDriverPhone?.isNotEmpty != true) {
      _contactDriverId = transit.assignedDriverId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDriverContact(_contactDriverId!));
    }

    return Stack(
      children: [
        Theme(
          data: Theme.of(context).copyWith(brightness: Brightness.dark),
          child: CustomMapView(
            userLocation: pickup,
            drivers: taxiDrivers,
            routePoints: _routePoints,
            destination: _destinationLocation,
          ),
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
              color: Colors.white,
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
                    : MediaQuery.of(context).size.height * 0.52,
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
                        (transit.matchedDriverName?.isNotEmpty == true || _driverName?.isNotEmpty == true)
                            ? (transit.matchedDriverName?.isNotEmpty == true ? transit.matchedDriverName! : _driverName!)
                            : 'Your driver is on the way',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.brandNavy,
                        ),
                      ),
                      if (transit.matchedDriverPhone?.isNotEmpty == true || _driverPhone?.isNotEmpty == true)
                        SelectableText(
                          'Driver • ${transit.matchedDriverPhone?.isNotEmpty == true ? transit.matchedDriverPhone : _driverPhone}',
                          style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                        ),
                      if (transit.matchedDriverPlate?.isNotEmpty == true)
                        Text('Vehicle • ${transit.matchedDriverPlate}', style: TextStyle(color: AppTheme.secondaryText, fontSize: 12)),
                      if (transit.etaSeconds != null)
                        Text(
                          'Pickup ETA: ${transit.etaDisplay}',
                          style: const TextStyle(color: AppTheme.taxiColor, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      Text(
                        isWithinProximity
                            ? 'Cab arrived at pickup point!'
                            : (distMeters != null
                                  ? 'Cab is en route (${distMeters < 1000 ? "${distMeters.toStringAsFixed(0)}m" : "${(distMeters / 1000).toStringAsFixed(1)}km"} away) • P${(transit.estimatedFare ?? AppConstants.taxiBaseFareBWP).toStringAsFixed(2)}'
                                  : 'Driver is en route to pickup point'),
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
                        'Cruising with ${transit.matchedDriverName ?? _driverName ?? "your driver"} • Enjoy your ride!',
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
              onPressed: () async => transit.passengerEndTrip(
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
        color: _navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.lightGrey, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flexible tier pills keep the selector within narrow screens.
          Row(
            children: [
              Expanded(child: _tierPill('STANDARD', 'Standard', 'P10.00')),
              const SizedBox(width: 8),
              Expanded(child: _tierPill('SPECIAL', 'Special / Direct', 'Metered')),
            ],
          ),
          const SizedBox(height: 12),

          // Destination Search Field
          TextField(
            controller: _destController,
            style: const TextStyle(color: Colors.white),
            onChanged: (query) {
              _destinationLocation = null;
              _routePoints = const [];
              _tripDistanceKm = null;
              _tripDurationMinutes = null;
              _routeLoading = false;
              _searchAddress(query);
            },
            decoration: InputDecoration(
              hintText: 'Where to? (e.g. Main Mall, Game City)',
              hintStyle: const TextStyle(color: Color(0xFF9AA9BE)),
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: _cyan,
              ),
              suffixIcon: _isSearching
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      color: _cyan,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: _panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _cyan, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _cyan, width: 1.5),
              ),
            ),
          ),

          if (_routeLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 2,
              color: _cyan,
              backgroundColor: _panel,
            ),
          ] else if (_tripDistanceKm != null && _tripDurationMinutes != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.route, color: _cyan, size: 18),
              const SizedBox(width: 8),
              Text('${_tripDistanceKm!.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(width: 14),
              const Icon(Icons.schedule, color: _cyan, size: 18),
              const SizedBox(width: 6),
              Text('About $_tripDurationMinutes min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ],

          // Suggestions List
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: _panel,
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
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    onTap: () {
                      _destController.text = s['name'] ?? '';
                      _destinationLocation = LatLng(s['lat'], s['lon']);
                      _offerFare = _specialFare;
                      setState(() => _suggestions = []);
                      _loadRoute(_destinationLocation!);
                    },
                  );
                },
              ),
            ),
          ],

          if (_serviceType == 'SPECIAL' && _destinationLocation != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('Recommended P${_specialFare.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
              IconButton(onPressed: () => setState(() => _offerFare = math.max(12, _offerFare - 2).toDouble()), icon: const Icon(Icons.remove_circle_outline, color: _cyan)),
              Text('P${_offerFare.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => setState(() => _offerFare += 2), icon: const Icon(Icons.add_circle_outline, color: _cyan)),
            ]),
          ],

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _driverName = null;
              _driverPhone = null;
              _contactDriverId = null;
              transit.requestTaxiBooking(
                passengerId: auth.userId,
                serviceType: _serviceType,
                pickup: transit.currentLocation,
                dropoff: _destinationLocation,
                offeredFare: _serviceType == 'SPECIAL' ? _offerFare : AppConstants.taxiBaseFareBWP,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _cyan, foregroundColor: const Color(0xFF08233A), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(_serviceType == 'SPECIAL' ? 'Offer P${_offerFare.toStringAsFixed(2)} for Special Cab' : 'Request STANDARD Cab Now', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
