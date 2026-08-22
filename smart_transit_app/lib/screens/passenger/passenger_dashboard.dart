import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/route_model.dart';
import '../auth/welcome_screen.dart';
import 'mode_selection_screen.dart';
import 'destinations_browser_screen.dart';
import 'bus_combi_map_screen.dart';
import 'taxi_flow_screen.dart';
import 'ai_planner_screen.dart';

enum TransportMode { bus, combi, taxi }

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  TransportMode? _selectedMode;
  TransitRoute? _selectedRoute;

  @override
  Widget build(BuildContext context) {
    if (_selectedMode == null) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: const Text('SmartTransit', style: TextStyle(fontWeight: FontWeight.w900)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.black),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: AppTheme.accentBlue),
              tooltip: 'AI Journey Facilitator',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiPlannerScreen()),
                );
              },
            ),
          ],
        ),
        body: ModeSelectionScreen(
          onModeSelected: (mode) => setState(() => _selectedMode = mode),
        ),
      );
    }

    if (_selectedMode == TransportMode.taxi) {
      return TaxiFlowScreen(onBack: () => setState(() => _selectedMode = null));
    }

    // Bus or Combi Flow
    if (_selectedRoute == null) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: Text(
            _selectedMode == TransportMode.bus ? 'Select Bus Route' : 'Select Combi Route',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.black),
            onPressed: () => setState(() => _selectedMode = null),
          ),
        ),
        body: DestinationsBrowserScreen(
          mode: _selectedMode!,
          onRouteSelected: (route) => setState(() => _selectedRoute = route),
        ),
      );
    }

    // Live Map Screen for Selected Route
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(_selectedRoute!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.black),
          onPressed: () => setState(() => _selectedRoute = null),
        ),
      ),
      body: BusCombiMapScreen(
        mode: _selectedMode!,
        route: _selectedRoute!,
        onExitToMain: () => setState(() {
          _selectedRoute = null;
          _selectedMode = null;
        }),
      ),
    );
  }
}
