import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/route_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../auth/welcome_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DriverProfileScreen({super.key, this.onBack});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  double? _averageRating;
  int _ratingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRealDriverRating();
  }

  Future<void> _loadRealDriverRating() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('trips')
          .select('rating')
          .eq('driver_id', auth.userId)
          .not('rating', 'is', null)
          .timeout(const Duration(seconds: 4));

      if (response.isNotEmpty) {
        double sum = 0;
        int count = 0;
        for (final row in response) {
          final r = (row['rating'] as num?)?.toDouble();
          if (r != null && r > 0) {
            sum += r;
            count++;
          }
        }
        if (mounted) {
          setState(() {
            _ratingCount = count;
            _averageRating = count > 0 ? (sum / count) : null;
          });
        }
      }
    } catch (_) {}
  }

  void _showEditVehicleRouteDialog(BuildContext context, AuthProvider auth, TransitProvider transit) {
    final plateController = TextEditingController(text: auth.vehiclePlate);
    TransitRoute? selectedRoute;
    try {
      final friendlyFallback = auth.assignedRouteId
          .replaceAll('-', ' ')
          .replaceAll('_', ' ')
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

      selectedRoute = transit.routes.firstWhere(
        (r) => r.id == auth.assignedRouteId,
        orElse: () => TransitRoute(
          id: auth.assignedRouteId,
          name: friendlyFallback.isNotEmpty ? friendlyFallback : 'Assigned Corridor',
          originName: 'Terminal A',
          destinationName: 'Terminal B',
          routeType: auth.serviceType,
          baseFare: 8.0,
        ),
      );
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: AppTheme.black),
              SizedBox(width: 8),
              Text('Update Shift Config', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle Number Plate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. B-123-BW',
                    filled: true,
                    fillColor: AppTheme.offWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                if (auth.serviceType != 'TAXI') ...[
                  const Text('Assigned Corridor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.offWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.lightGrey),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TransitRoute>(
                        isExpanded: true,
                        value: selectedRoute,
                        items: transit.routes.map((r) {
                          return DropdownMenuItem<TransitRoute>(
                            value: r,
                            child: Text(
                              r.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (r) {
                          setDialogState(() => selectedRoute = r);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.midGrey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPlate = plateController.text.trim().toUpperCase();
                final newRouteId = selectedRoute?.id ?? auth.assignedRouteId;
                if (newPlate.isNotEmpty) {
                  await auth.updateDriverConfig(
                    serviceType: auth.serviceType,
                    routeId: newRouteId,
                    vehiclePlate: newPlate,
                  );
                }
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vehicle and route updated in Supabase.'),
                      backgroundColor: AppTheme.black,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final transit = Provider.of<TransitProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Driver Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.black),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.black),
            tooltip: 'Update Vehicle & Route',
            onPressed: () => _showEditVehicleRouteDialog(context, auth, transit),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Driver Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.black,
                    child: Text(
                      auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'D',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.userName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.black),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${auth.serviceType} Operator • Plate: ${auth.vehiclePlate}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkGrey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${auth.userId.length > 12 ? "${auth.userId.substring(0, 12)}..." : auth.userId}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentGreen),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: AppTheme.accentGreen),
                        SizedBox(width: 4),
                        Text(
                          'Licensed Transit Operator 🇧🇼',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Performance Metrics
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    _ratingCount > 0 && _averageRating != null
                        ? '${_averageRating!.toStringAsFixed(1)} ★'
                        : 'New ★',
                    _ratingCount > 0 ? '$_ratingCount Reviews' : 'No ratings yet',
                    Icons.star,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    '${transit.passengersCarried}',
                    'Shift Pax',
                    Icons.people,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    auth.vehiclePlate,
                    'Vehicle Plate',
                    Icons.directions_bus,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Vehicle & License Information
            _buildSectionHeader('Vehicle & Permit Details'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.lightGrey),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.directions_car, color: AppTheme.black),
                    title: const Text('Registered Vehicle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${auth.vehiclePlate} (${auth.serviceType} Service)'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.midGrey),
                      onPressed: () => _showEditVehicleRouteDialog(context, auth, transit),
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(Icons.alt_route, color: AppTheme.accentBlue),
                    title: const Text('Assigned Corridor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(auth.assignedRouteId),
                    trailing: const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 20),
                  ),
                  const Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(Icons.phone_android, color: AppTheme.black),
                    title: const Text('Driver Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(auth.phoneNumber),
                  ),
                  const Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: AppTheme.black),
                    title: const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(auth.userEmail),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Go Offline & Logout
            ElevatedButton.icon(
              onPressed: () async {
                if (transit.isDriverOnline) {
                  transit.toggleDriverOnline(
                    driverId: auth.userId,
                    serviceType: auth.serviceType,
                    routeId: auth.assignedRouteId,
                    vehicleId: auth.vehiclePlate,
                  );
                }
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('End Shift & Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.midGrey),
        ),
      ),
    );
  }

  Widget _buildStatTile(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.offWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightGrey),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.black),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.black),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
          ),
        ],
      ),
    );
  }
}
