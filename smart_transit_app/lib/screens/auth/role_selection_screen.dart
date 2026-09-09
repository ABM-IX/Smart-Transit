import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'passenger_register_screen.dart';
import 'driver_register_screen.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24 > 0 ? constraints.maxHeight - 24 : 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.black, width: 2),
                        ),
                        child: const Center(
                          child: Text(
                            'ST',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppTheme.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Join SmartTransit',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select how you would like to use SmartTransit across Botswana.',
                        style: TextStyle(fontSize: 14, color: AppTheme.midGrey, height: 1.4),
                      ),
                      const SizedBox(height: 24),

                      // Option 1: Passenger / Commuter
                      _buildRoleCard(
                        context: context,
                        title: 'Register as Passenger',
                        badge: 'COMMUTER',
                        badgeColor: AppTheme.accentBlue,
                        description:
                            'Real-time combi & bus tracking, instant taxi hailing, ETA alerts, and digital transit itineraries.',
                        icon: Icons.person_outline,
                        features: ['Live Bus & Combi Radar', 'Hail Nearby Cabs', 'Personal Trip History'],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PassengerRegisterScreen()),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Option 2: Driver / Transit Operator
                      _buildRoleCard(
                        context: context,
                        title: 'Register as Driver',
                        badge: 'TRANSIT OPERATOR',
                        badgeColor: AppTheme.accentGreen,
                        description:
                            'Operate a combi, intercity coach, or taxi service. Receive live dispatch alerts and headway spacing advisory.',
                        icon: Icons.directions_bus_outlined,
                        features: ['Assigned Corridor GPS', 'Live Passenger Dispatch', 'Digital Shift Earnings'],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DriverRegisterScreen()),
                          );
                        },
                      ),

                      const Spacer(),
                      const SizedBox(height: 16),

                      // Already have an account prompt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(color: AppTheme.darkGrey, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: AppTheme.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String badge,
    required Color badgeColor,
    required String description,
    required IconData icon,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.lightGrey, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.offWhite,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.black, width: 1.5),
                  ),
                  child: Icon(icon, color: AppTheme.black, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.midGrey),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: AppTheme.darkGrey, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: features.map((feat) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.accentGreen),
                    const SizedBox(width: 4),
                    Text(
                      feat,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.midGrey),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
