import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/welcome_screen.dart';

class PassengerProfileScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const PassengerProfileScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Passenger Profile', style: TextStyle(fontWeight: FontWeight.w900)),
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
            // User Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.lightGrey),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.black,
                        child: Text(
                          auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 14, color: AppTheme.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.userName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.black),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Passenger ID: ${auth.userId}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.midGrey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SmartTransit Verified Rider 🇧🇼',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Riding Stats Bar
            Row(
              children: [
                Expanded(
                  child: _buildStatTile('12', 'Total Trips', Icons.directions_bus),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile('P145.00', 'Total Spent', Icons.payments),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile('4.9 ★', 'Rider Rating', Icons.star),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Profile Details & Settings Sections
            _buildSectionHeader('Account & Contact'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.lightGrey),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_android, color: AppTheme.black),
                    title: const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('+267 71 234 567'),
                    trailing: const Icon(Icons.edit, size: 18, color: AppTheme.midGrey),
                  ),
                  const Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: AppTheme.black),
                    title: const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('passenger@smarttransit.bw'),
                    trailing: const Icon(Icons.edit, size: 18, color: AppTheme.midGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('Payments & Preferences'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.lightGrey),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: AppTheme.accentGreen),
                    title: const Text('Default Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Cash / Mobile Money (MyZaka / Orange Money)'),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.midGrey),
                  ),
                  const Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(Icons.alt_route, color: AppTheme.accentBlue),
                    title: const Text('Preferred Transport Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Combi (Express Routes)'),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.midGrey),
                  ),
                  const Divider(height: 1, color: AppTheme.lightGrey),
                  ListTile(
                    leading: const Icon(Icons.security, color: AppTheme.black),
                    title: const Text('Safety & Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('1 Contact Saved'),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.midGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Switch Role / Logout
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                );
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Switch Role / Logout'),
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
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.black),
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
