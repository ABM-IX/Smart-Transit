import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/route_model.dart';
import '../../models/user_role.dart';
import 'driver_route_select_screen.dart';
import 'driver_home_screen.dart';
import 'taxi_driver_screen.dart';
import 'driver_history_screen.dart';
import 'driver_profile_screen.dart';

class DriverDashboard extends StatefulWidget {
  final UserRole initialRole;

  const DriverDashboard({super.key, required this.initialRole});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentTabIndex = 0;
  TransitRoute? _selectedRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildShiftDriveTab(),
          DriverHistoryScreen(
            onBack: () => setState(() => _currentTabIndex = 0),
          ),
          DriverProfileScreen(
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
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Shift / Drive',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
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

  Widget _buildShiftDriveTab() {
    // Taxi drivers operate on-demand dispatch
    if (widget.initialRole == UserRole.driverTaxi) {
      return const TaxiDriverScreen();
    }

    // Bus and Combi drivers select route before starting shift
    if (_selectedRoute == null) {
      return DriverRouteSelectScreen(
        driverRole: widget.initialRole,
        onRouteConfirmed: (route) => setState(() => _selectedRoute = route),
      );
    }

    return DriverHomeScreen(
      driverRole: widget.initialRole,
      routeName: _selectedRoute!.name,
      routeId: _selectedRoute!.id,
    );
  }
}
