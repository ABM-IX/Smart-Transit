import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transit_provider.dart';
import '../../widgets/theme_preference_tile.dart';
import '../../services/auth_service.dart';
import '../../widgets/profile_identity_editor.dart';
import '../auth/login_screen.dart';

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

  Future<void> _showEditPhoneDialog(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final phoneController = TextEditingController(text: auth.phoneNumber);
    final formKey = GlobalKey<FormState>();
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit phone number'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
            validator: (value) => (value ?? '').trim().length < 7
                ? 'Enter a valid phone number.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated != true || !context.mounted) return;
    try {
      await auth.updatePhoneNumber(phoneController.text);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number updated.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.formatAuthErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppThemeProvider>();
    final auth = Provider.of<AuthProvider>(context);
    final transit = Provider.of<TransitProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text(
          'Driver Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: widget.onBack != null
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppTheme.black),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: AppTheme.black),
            tooltip: 'Edit phone number',
            onPressed: () => _showEditPhoneDialog(context, auth),
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
                  ProfileIdentityEditor(auth: auth),
                  const SizedBox(height: 2),
                  Text(
                    '${auth.serviceType} Operator • Plate: ${auth.vehiclePlate}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${auth.userId.length > 12 ? "${auth.userId.substring(0, 12)}..." : auth.userId}',
                    style: TextStyle(fontSize: 11, color: AppTheme.midGrey),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentGreen),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: AppTheme.accentGreen,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Licensed Transit Operator 🇧🇼',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentGreen,
                          ),
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
                    _ratingCount > 0
                        ? '$_ratingCount Reviews'
                        : 'No ratings yet',
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

            _buildSectionHeader('Preferences'),
            const Card(elevation: 0, child: ThemePreferenceTile()),
            const SizedBox(height: 20),

            // Vehicle & License Information
            _buildSectionHeader('Vehicle & Permit Details'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.lightGrey),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.directions_car, color: AppTheme.black),
                    title: const Text(
                      'Registered Vehicle',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${auth.vehiclePlate} (${auth.serviceType} Service)',
                    ),
                    trailing: const Icon(Icons.lock_outline, size: 18),
                  ),
                  Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(
                      Icons.alt_route,
                      color: AppTheme.accentBlue,
                    ),
                    title: const Text(
                      'Assigned Corridor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(auth.assignedRouteId),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: AppTheme.accentGreen,
                      size: 20,
                    ),
                  ),
                  Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: Icon(Icons.phone_android, color: AppTheme.black),
                    title: const Text(
                      'Driver Phone Number',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(auth.phoneNumber),
                    trailing: IconButton(
                      tooltip: 'Edit phone number',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showEditPhoneDialog(context, auth),
                    ),
                  ),
                  Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: Icon(Icons.email_outlined, color: AppTheme.black),
                    title: const Text(
                      'Email Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
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
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.midGrey,
          ),
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
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: AppTheme.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.midGrey)),
        ],
      ),
    );
  }
}
