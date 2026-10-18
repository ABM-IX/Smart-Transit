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
import '../../services/place_name_service.dart';
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
  String? _destinationName;
  int _tripRating = 5;
  double _offerFare = 12;
  List<LatLng> _routePoints = const [];
  double? _tripDistanceKm;
  int? _tripDurationMinutes;
  bool _routeLoading = false;
  bool _routeError = false;
  String? _contactDriverId;
  String? _driverName;
  String? _driverPhone;
  String? _driverPlate;
  List<LatLng> _driverToPickupRoutePoints = const [];
  LatLng? _lastDriverRouteOrigin;
  double? _driverToPickupDistanceMeters;
  int? _driverToPickupDurationSeconds;

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  void _clearLocalTripState() {
    _destController.clear();
    _suggestions = [];
    _destinationLocation = null;
    _destinationName = null;
    _tripRating = 5;
    _offerFare = 12;
    _routePoints = const [];
    _driverToPickupRoutePoints = const [];
    _lastDriverRouteOrigin = null;
    _driverToPickupDistanceMeters = null;
    _driverToPickupDurationSeconds = null;
    _tripDistanceKm = null;
    _tripDurationMinutes = null;
    _routeLoading = false;
    _routeError = false;
    _contactDriverId = null;
    _driverName = null;
    _driverPhone = null;
    _driverPlate = null;
  }

  Future<void> _ensureDriverToPickupRoute(
    LatLng driverOrigin,
    LatLng pickupTarget,
  ) async {
    const distance = Distance();
    if (_lastDriverRouteOrigin != null &&
        distance.as(LengthUnit.Meter, _lastDriverRouteOrigin!, driverOrigin) <
            250 &&
        _driverToPickupRoutePoints.isNotEmpty) {
      return;
    }
    _lastDriverRouteOrigin = driverOrigin;
    try {
      final coords =
          '${driverOrigin.longitude},${driverOrigin.latitude};${pickupTarget.longitude},${pickupTarget.latitude}';
      final response = await http
          .get(
            Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry']['coordinates'] as List;
      if (geometry.length < 2 || !mounted) return;
      setState(() {
        _driverToPickupRoutePoints = geometry
            .map(
              (point) => LatLng(
                (point[1] as num).toDouble(),
                (point[0] as num).toDouble(),
              ),
            )
            .toList();
        _driverToPickupDistanceMeters = (route['distance'] as num?)?.toDouble();
        _driverToPickupDurationSeconds = (route['duration'] as num?)?.round();
      });
    } catch (_) {}
  }

  double get _specialFare {
    if (_destinationLocation == null) return 12;
    final pickup = context.read<TransitProvider>().currentLocation;
    const distance = Distance();
    final km =
        _tripDistanceKm ??
        distance.as(LengthUnit.Kilometer, pickup, _destinationLocation!) * 1.25;
    final minutes = (_tripDurationMinutes ?? (km / 30 * 60).ceil()).toDouble();
    return math
        .max(12, 10 + math.max(0, km - 1) * 2.5 + math.max(0, minutes - 3) * .3)
        .toDouble();
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
        child: Row(
          children: [
            if (selected)
              const Icon(Icons.check, size: 16, color: Color(0xFF08233A)),
            if (selected) const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$title ($subtitle)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF08233A) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRoute(LatLng destination) async {
    final pickup = context.read<TransitProvider>().currentLocation;
    setState(() => _routeLoading = true);
    try {
      final coords =
          '${pickup.longitude},${pickup.latitude};${destination.longitude},${destination.latitude}';
      final response = await http
          .get(
            Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw StateError('Route unavailable');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final route = (data['routes'] as List).first as Map<String, dynamic>;
      final geometry = route['geometry']['coordinates'] as List;
      if (geometry.length < 2) throw StateError('No drivable road route found');
      if (!mounted || destination != _destinationLocation) return;
      setState(() {
        _routePoints = geometry
            .map(
              (point) => LatLng(
                (point[1] as num).toDouble(),
                (point[0] as num).toDouble(),
              ),
            )
            .toList();
        _tripDistanceKm = (route['distance'] as num).toDouble() / 1000;
        _tripDurationMinutes = ((route['duration'] as num).toDouble() / 60)
            .ceil();
        _routeLoading = false;
        _routeError = false;
        if (_serviceType == 'SPECIAL') _offerFare = _specialFare;
      });
    } catch (_) {
      if (!mounted || destination != _destinationLocation) return;
      setState(() {
        _routePoints = const [];
        _tripDistanceKm = null;
        _tripDurationMinutes = null;
        _routeLoading = false;
        _routeError = true;
      });
    }
  }

  Future<void> _loadDriverContact(String driverId) async {
    try {
      final contact = await context.read<TransitProvider>().fetchUserContact(
        driverId,
      );
      if (!mounted || _contactDriverId != driverId) return;
      setState(() {
        _driverName = contact?['full_name'];
        _driverPhone = contact?['phone_number'];
        _driverPlate = contact?['vehicle_plate'];
      });
    } catch (_) {}
  }

  Widget _pickupMetric(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppTheme.primaryTeal),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.secondaryText,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.brandNavy,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
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
        .where(
          (d) =>
              d.driverId == transit.assignedDriverId ||
              geo.as(
                    LengthUnit.Meter,
                    pickup,
                    LatLng(d.latitude, d.longitude),
                  ) <=
                  4000,
        )
        .toList();
    final visibleDrivers = transit.assignedDriverId == null
        ? taxiDrivers
        : taxiDrivers
              .where((d) => d.driverId == transit.assignedDriverId)
              .toList();

    if ((transit.passengerStatus == PassengerTripStatus.driverAccepted ||
            transit.passengerStatus == PassengerTripStatus.driverArrived) &&
        transit.assignedDriverId != null) {
      if (_contactDriverId != transit.assignedDriverId &&
          transit.matchedDriverPhone?.isNotEmpty != true) {
        _contactDriverId = transit.assignedDriverId;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadDriverContact(_contactDriverId!),
        );
      }
      final assignedList = taxiDrivers
          .where((d) => d.driverId == transit.assignedDriverId)
          .toList();
      if (assignedList.isNotEmpty) {
        final d = assignedList.first;
        if (d.latitude != 0.0 && d.longitude != 0.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureDriverToPickupRoute(LatLng(d.latitude, d.longitude), pickup);
          });
        }
      }
    }

    final activePolylines =
        (transit.passengerStatus == PassengerTripStatus.driverAccepted &&
            _driverToPickupRoutePoints.isNotEmpty)
        ? _driverToPickupRoutePoints
        : _routePoints;

    return Stack(
      children: [
        Theme(
          data: Theme.of(context).copyWith(brightness: Brightness.dark),
          child: CustomMapView(
            userLocation: pickup,
            drivers: visibleDrivers,
            highlightDriverId: transit.assignedDriverId,
            routePoints: activePolylines,
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

    if (transit.passengerStatus == PassengerTripStatus.driverAccepted ||
        transit.passengerStatus == PassengerTripStatus.driverArrived) {
      final taxiDrivers = transit.activeDrivers
          .where((d) => d.serviceType == 'TAXI')
          .toList();
      final assignedDrivers = taxiDrivers
          .where((d) => d.driverId == transit.assignedDriverId)
          .toList();
      final assignedDriver = assignedDrivers.isEmpty
          ? null
          : assignedDrivers.first;
      final driverSpeedKmh = transit.vehicleSpeedKmh;
      double? distMeters =
          _driverToPickupDistanceMeters ?? transit.etaDistanceMeters;
      if (distMeters == null && assignedDriver != null) {
        const double p = 0.017453292519943295;
        final lat1 = transit.currentLocation.latitude;
        final lon1 = transit.currentLocation.longitude;
        final lat2 = assignedDriver.latitude;
        final lon2 = assignedDriver.longitude;
        final a =
            0.5 -
            math.cos((lat2 - lat1) * p) / 2 +
            math.cos(lat1 * p) *
                math.cos(lat2 * p) *
                (1 - math.cos((lon2 - lon1) * p)) /
                2;
        distMeters = 12742 * math.asin(math.sqrt(a)) * 1000.0;
      }
      final driverHasArrived =
          transit.passengerStatus == PassengerTripStatus.driverArrived;
      if (driverHasArrived) distMeters = 0;
      final hasLocalDriverDistance =
          distMeters != null && distMeters >= 0 && distMeters <= 300000;
      if (!hasLocalDriverDistance) distMeters = null;
      int? remainingSeconds;
      if (!driverHasArrived && _driverToPickupDistanceMeters != null) {
        if (driverSpeedKmh > 3) {
          remainingSeconds =
              (_driverToPickupDistanceMeters! / (driverSpeedKmh * 1000 / 3600))
                  .ceil();
        } else {
          remainingSeconds = _driverToPickupDurationSeconds;
        }
      }
      remainingSeconds ??= transit.etaSeconds;
      final etaLabel =
          remainingSeconds != null &&
              remainingSeconds > 0 &&
              remainingSeconds <= 3 * 60 * 60
          ? (remainingSeconds < 60
                ? 'under 1 min'
                : '${(remainingSeconds / 60).ceil()} min')
          : null;
      final arrivalClock = etaLabel == null
          ? null
          : TimeOfDay.fromDateTime(
              DateTime.now().add(Duration(seconds: remainingSeconds!)),
            ).format(context);
      final resolvedDriverName = (transit.matchedDriverName?.isNotEmpty == true)
          ? transit.matchedDriverName!
          : (_driverName?.isNotEmpty == true
                ? _driverName!
                : 'Assigned Cab Driver');
      final resolvedDriverPhone =
          (transit.matchedDriverPhone?.isNotEmpty == true)
          ? transit.matchedDriverPhone!
          : (_driverPhone?.isNotEmpty == true ? _driverPhone! : null);
      final resolvedDriverPlate =
          (transit.matchedDriverPlate?.isNotEmpty == true &&
              transit.matchedDriverPlate != 'B-BW')
          ? transit.matchedDriverPlate!
          : (_driverPlate?.isNotEmpty == true
                ? _driverPlate!
                : (assignedDriver?.vehicleId ??
                      transit.matchedDriverPlate ??
                      'Cab Registered'));
      final pickupArea = transit.taxiPickupName ?? 'your location';

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.borderGrey, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status & ETA Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: driverHasArrived
                    ? AppTheme.statusSuccess.withValues(alpha: 0.12)
                    : AppTheme.taxiColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: driverHasArrived
                      ? AppTheme.statusSuccess
                      : AppTheme.taxiColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    driverHasArrived
                        ? Icons.where_to_vote
                        : Icons.access_time_filled,
                    color: driverHasArrived
                        ? AppTheme.statusSuccess
                        : AppTheme.taxiColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      driverHasArrived
                          ? 'Driver has arrived at $pickupArea!'
                          : 'Driver is coming to $pickupArea',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppTheme.brandNavy,
                      ),
                    ),
                  ),
                  if (!driverHasArrived && etaLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1F2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.botswanaSky,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        arrivalClock == null
                            ? 'ETA: $etaLabel'
                            : 'Arrives $arrivalClock',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Live pickup information: road distance, estimated arrival, and GPS speed.
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceGrey,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _pickupMetric(
                      Icons.route,
                      _driverToPickupDistanceMeters == null
                          ? 'DIRECT DIST.'
                          : 'ROAD DIST.',
                      driverHasArrived
                          ? 'At pickup'
                          : distMeters == null
                          ? 'Updating'
                          : distMeters < 1000
                          ? '${distMeters.round()} m'
                          : '${(distMeters / 1000).toStringAsFixed(1)} km',
                    ),
                  ),
                  Expanded(
                    child: _pickupMetric(
                      Icons.schedule,
                      'ARRIVAL',
                      driverHasArrived
                          ? 'Arrived'
                          : arrivalClock == null
                          ? 'Calculating'
                          : '$arrivalClock ($etaLabel)',
                    ),
                  ),
                  Expanded(
                    child: _pickupMetric(
                      Icons.speed,
                      'SPEED',
                      assignedDriver == null
                          ? 'Updating'
                          : driverSpeedKmh < 3
                          ? 'Stopped'
                          : '${driverSpeedKmh.round()} km/h',
                    ),
                  ),
                ],
              ),
            ),

            // Driver Details Card
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
                        resolvedDriverName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.brandNavy,
                        ),
                      ),
                      if (resolvedDriverPhone != null)
                        SelectableText(
                          'Phone • $resolvedDriverPhone',
                          style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      Text(
                        'Vehicle • $resolvedDriverPlate • P${(transit.estimatedFare ?? AppConstants.taxiBaseFareBWP).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        driverHasArrived
                            ? 'Your cab is waiting for you at $pickupArea. Please board the vehicle.'
                            : (distMeters != null
                                  ? 'En route (${distMeters < 1000 ? "${distMeters.toStringAsFixed(0)}m" : "${(distMeters / 1000).toStringAsFixed(1)} km"} away) • Est. arrival: ${arrivalClock ?? transit.etaDisplay}'
                                  : 'En route to $pickupArea • Est. arrival: ${arrivalClock ?? transit.etaDisplay}'),
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
            if (driverHasArrived) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => transit.confirmBoarding(auth.userId),
                icon: const Icon(Icons.hail, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: const Text(
                  'I AM ON BOARD • START TRIP',
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
                final driverToRate = transit.assignedDriverId ?? 'driver-1';
                final ratingToSubmit = _tripRating;
                _clearLocalTripState();
                transit.submitRating(
                  driverId: driverToRate,
                  passengerId: auth.userId,
                  rating: ratingToSubmit,
                );
                if (widget.onExitToMain != null) {
                  widget.onExitToMain!.call();
                } else {
                  Navigator.maybePop(context);
                }
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
              Expanded(
                child: _tierPill('SPECIAL', 'Special / Direct', 'Metered'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Destination Search Field
          TextField(
            controller: _destController,
            style: const TextStyle(color: Colors.white),
            onChanged: (query) {
              _destinationLocation = null;
              _destinationName = null;
              _routePoints = const [];
              _tripDistanceKm = null;
              _tripDurationMinutes = null;
              _routeLoading = false;
              _routeError = false;
              _searchAddress(query);
            },
            decoration: InputDecoration(
              hintText: 'Where to? (e.g. Main Mall, Game City)',
              hintStyle: const TextStyle(color: Color(0xFF9AA9BE)),
              prefixIcon: Icon(Icons.location_on_outlined, color: _cyan),
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
          ] else if (_tripDistanceKm != null &&
              _tripDurationMinutes != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.route, color: _cyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_tripDistanceKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.schedule, color: _cyan, size: 18),
                const SizedBox(width: 6),
                Text(
                  'About $_tripDurationMinutes min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else if (_routeError) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'No drivable road route found. Retry or choose another destination.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => _loadRoute(_destinationLocation!),
                  icon: const Icon(Icons.refresh, color: _cyan),
                  tooltip: 'Retry route',
                ),
              ],
            ),
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
                      _destinationName = s['name'] as String?;
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recommended P${_specialFare.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _offerFare = math.max(12, _offerFare - 2).toDouble(),
                  ),
                  icon: const Icon(Icons.remove_circle_outline, color: _cyan),
                ),
                Text(
                  'P${_offerFare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _offerFare += 2),
                  icon: const Icon(Icons.add_circle_outline, color: _cyan),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed:
                _destinationLocation != null &&
                    (_routeLoading || _routeError || _tripDistanceKm == null)
                ? null
                : () async {
                    _driverName = null;
                    _driverPhone = null;
                    _driverPlate = null;
                    _contactDriverId = null;
                    _driverToPickupRoutePoints = const [];
                    _lastDriverRouteOrigin = null;
                    final pickupName = await PlaceNameService.resolvePlaceName(
                      transit.currentLocation,
                    );
                    if (!mounted) return;
                    transit.requestTaxiBooking(
                      passengerId: auth.userId,
                      serviceType: _serviceType,
                      pickup: transit.currentLocation,
                      dropoff: _destinationLocation,
                      pickupName: pickupName,
                      destinationName: _destinationName,
                      offeredFare: _serviceType == 'SPECIAL'
                          ? _offerFare
                          : AppConstants.taxiBaseFareBWP,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyan,
              foregroundColor: const Color(0xFF08233A),
              disabledBackgroundColor: _panel,
              disabledForegroundColor: Colors.white54,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _serviceType == 'SPECIAL'
                  ? 'Offer P${_offerFare.toStringAsFixed(2)} for Special Cab'
                  : 'Request STANDARD Cab Now',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
