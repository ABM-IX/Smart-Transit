import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/route_model.dart';
import '../../providers/transit_provider.dart';
import 'mode_selection_screen.dart';
import 'destinations_browser_screen.dart';
import 'bus_combi_map_screen.dart';
import 'taxi_flow_screen.dart';
import 'ai_planner_screen.dart';
import 'passenger_history_screen.dart';
import 'passenger_profile_screen.dart';

enum TransportMode { bus, combi, taxi }

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  int _currentTabIndex = 0;
  TransportMode? _selectedMode;
  TransitRoute? _selectedRoute;
  int _lastSeenTripResetVersion = 0;

  void _returnToLandingScreen() {
    if (!mounted) return;
    setState(() {
      _currentTabIndex = 0;
      _selectedRoute = null;
      _selectedMode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resetVersion = context.select<TransitProvider, int>(
      (t) => t.tripResetVersion,
    );
    if (resetVersion != _lastSeenTripResetVersion) {
      _lastSeenTripResetVersion = resetVersion;
      if (_selectedMode != null || _selectedRoute != null || _currentTabIndex != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _returnToLandingScreen();
        });
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildRideFlowTab(),
          PassengerHistoryScreen(
            isActive: _currentTabIndex == 1,
            onBack: () => setState(() => _currentTabIndex = 0),
          ),
          PassengerProfileScreen(
            onBack: () => setState(() => _currentTabIndex = 0),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        backgroundColor: AppTheme.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_transit_outlined),
            selectedIcon: Icon(Icons.directions_transit),
            label: 'Ride',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Trip History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildRideFlowTab() {
    if (_selectedMode == null) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'SmartTransit',
            style: TextStyle(fontWeight: FontWeight.w900),
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
      return TaxiFlowScreen(
        onExitToMain: _returnToLandingScreen,
      );
    }

    // Bus or Combi Flow
    if (_selectedRoute == null) {
      return Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: Text(
            _selectedMode == TransportMode.bus
                ? 'Select Bus Route'
                : 'Select Combi Route',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.black),
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
        title: Text(
          _selectedRoute!.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.black),
          onPressed: () => setState(() => _selectedRoute = null),
        ),
      ),
      body: BusCombiMapScreen(
        mode: _selectedMode!,
        route: _selectedRoute!,
        onExitToMain: _returnToLandingScreen,
      ),
    );
  }
}
