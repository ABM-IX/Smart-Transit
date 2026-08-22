import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../auth/welcome_screen.dart';

class DriverProfileScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const DriverProfileScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final transit = Provider.of<TransitProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Driver Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.black),
                onPressed: onBack,
              )
            : null,
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
                    'Driver ID: ${auth.userId} • License: BW-DL-88392',
                    style: const TextStyle(fontSize: 12, color: AppTheme.midGrey),
                  ),
                  const SizedBox(height: 8),
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
                  child: _buildStatTile('4.9 ★', 'Driver Rating', Icons.star),
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
                    subtitle: Text('${auth.vehiclePlate} (Toyota Quantum / Coaster)'),
                    trailing: const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 20),
                  ),
                  const Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(Icons.assignment_turned_in, color: AppTheme.accentBlue),
                    title: const Text('Roadworthiness Certificate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Valid until Dec 2026'),
                    trailing: const Icon(Icons.verified, color: AppTheme.accentGreen, size: 20),
                  ),
                  const Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(Icons.phone_android, color: AppTheme.black),
                    title: const Text('Driver Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('+267 72 987 654'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Go Offline & Logout
            ElevatedButton.icon(
              onPressed: () {
                if (transit.isDriverOnline) {
                  transit.toggleDriverOnline(
                    driverId: auth.userId,
                    serviceType: 'COMBI',
                    routeId: 'route-u01',
                    vehicleId: auth.vehiclePlate,
                  );
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('End Shift & Logout'),
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
