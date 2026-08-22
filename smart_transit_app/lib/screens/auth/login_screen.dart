import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../passenger/passenger_dashboard.dart';
import '../driver/driver_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController(text: 'user@smarttransit.bw');
  final TextEditingController _passwordController = TextEditingController(text: 'password123');
  bool _showDriverOptions = false;
  bool _isLoading = false;

  void _handlePassengerLogin() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final transit = Provider.of<TransitProvider>(context, listen: false);

    auth.setRole(UserRole.passenger);
    transit.connectSocket(role: 'passengers', userId: auth.userId);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PassengerDashboard()),
      (route) => false,
    );
  }

  void _handleDriverLogin(UserRole driverRole) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final transit = Provider.of<TransitProvider>(context, listen: false);

    auth.setRole(driverRole);
    transit.connectSocket(
      role: 'drivers',
      userId: auth.userId,
      routeId: driverRole == UserRole.driverTaxi ? 'taxi-service' : auth.assignedRouteId,
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => DriverDashboard(initialRole: driverRole)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.black),
          onPressed: () {
            if (_showDriverOptions) {
              setState(() => _showDriverOptions = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
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
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                _showDriverOptions ? 'Select Driver Type' : 'Sign in',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _showDriverOptions
                    ? 'Choose the vehicle service you operate.'
                    : 'Sign in to continue with SmartTransit.',
                style: const TextStyle(fontSize: 14, color: AppTheme.midGrey),
              ),
              const SizedBox(height: 28),

              if (!_showDriverOptions) ...[
                // Email Field
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: AppTheme.midGrey),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.black),
                    filled: true,
                    fillColor: AppTheme.offWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.lightGrey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.lightGrey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: AppTheme.midGrey),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.black),
                    filled: true,
                    fillColor: AppTheme.offWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.lightGrey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.lightGrey),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Sign in as Passenger
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handlePassengerLogin,
                    child: const Text('Sign in as Passenger'),
                  ),
                ),
                const SizedBox(height: 14),

                // Sign in as Driver
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showDriverOptions = true),
                    child: const Text('Sign in as Driver'),
                  ),
                ),
              ] else ...[
                // Driver Cards
                _buildDriverCard(
                  title: 'Bus',
                  subtitle: 'Scheduled intercity service',
                  icon: Icons.directions_bus_outlined,
                  onTap: () => _handleDriverLogin(UserRole.driverBus),
                ),
                const SizedBox(height: 14),
                _buildDriverCard(
                  title: 'Combi',
                  subtitle: 'Urban flexible routes',
                  icon: Icons.airport_shuttle_outlined,
                  onTap: () => _handleDriverLogin(UserRole.driverCombi),
                ),
                const SizedBox(height: 14),
                _buildDriverCard(
                  title: 'Taxi',
                  subtitle: 'Private on-demand rides',
                  icon: Icons.local_taxi_outlined,
                  onTap: () => _handleDriverLogin(UserRole.driverTaxi),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showDriverOptions = false),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Sign in'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.black, width: 1.5),
                ),
                child: Icon(icon, color: AppTheme.black, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppTheme.midGrey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.midGrey),
            ],
          ),
        ),
      ),
    );
  }
}
