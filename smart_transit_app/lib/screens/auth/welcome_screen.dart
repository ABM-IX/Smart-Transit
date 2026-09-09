import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  void _showServerSettingsDialog() {
    final textController = TextEditingController(text: AppConstants.defaultServerUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_sync, color: AppTheme.black),
            SizedBox(width: 8),
            Text('Server & Cloud Config', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Supabase Cloud Database & Storage is active globally. Enter your live backend/tunnel URL for real-time dispatch:',
                style: TextStyle(fontSize: 13, color: AppTheme.darkGrey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Backend Server URL',
                  hintText: 'https://smarttransit-backend.onrender.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Cloud (Render)', style: TextStyle(fontSize: 11)),
                    onPressed: () => textController.text = AppConstants.cloudServerUrl,
                  ),
                  ActionChip(
                    label: const Text('Local LAN', style: TextStyle(fontSize: 11)),
                    onPressed: () => textController.text = AppConstants.lanServerUrl,
                  ),
                  ActionChip(
                    label: const Text('Localhost', style: TextStyle(fontSize: 11)),
                    onPressed: () => textController.text = AppConstants.localhostUrl,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                AppConstants.customServerUrl = textController.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Server endpoint set to: ${AppConstants.defaultServerUrl}'),
                  backgroundColor: AppTheme.black,
                ),
              );
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: AppTheme.darkGrey),
            tooltip: 'Server & Cloud Config',
            onPressed: _showServerSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32 > 0 ? constraints.maxHeight - 32 : 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      // ST Wordmark
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.black, width: 2),
                        ),
                        child: const Center(
                          child: Text(
                            'ST',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.black,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'SmartTransit',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      const Text(
                        'GABORONE, BOTSWANA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppTheme.midGrey,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Feature Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFeatureChip('Bus'),
                          const SizedBox(width: 8),
                          _buildFeatureChip('Combi'),
                          const SizedBox(width: 8),
                          _buildFeatureChip('Taxi'),
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Divider(color: AppTheme.lightGrey, thickness: 1),
                      const SizedBox(height: 32),

                      // Get Started Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Get Started'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Create Account Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                            );
                          },
                          child: const Text('Create Account'),
                        ),
                      ),

                      const Spacer(flex: 3),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_done, size: 14, color: AppTheme.midGrey),
                          const SizedBox(width: 6),
                          Text(
                            'Supabase Cloud Active • ${AppConstants.defaultServerUrl.contains("10.") ? "LAN Mode" : "Cloud Mode"}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
                          ),
                        ],
                      ),
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

  Widget _buildFeatureChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.black, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.black,
        ),
      ),
    );
  }
}

