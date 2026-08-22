import 'package:flutter/material.dart';
import '../../models/route_model.dart';
import '../../models/user_role.dart';
import 'driver_route_select_screen.dart';
import 'driver_home_screen.dart';
import 'taxi_driver_screen.dart';

class DriverDashboard extends StatefulWidget {
  final UserRole initialRole;

  const DriverDashboard({super.key, required this.initialRole});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  TransitRoute? _selectedRoute;

  @override
  Widget build(BuildContext context) {
    // Taxi drivers operate on-demand dispatch (Yango/inDrive style)
    if (widget.initialRole == UserRole.driverTaxi) {
      return const TaxiDriverScreen();
    }

    // Bus and Combi drivers pick their route before starting the shift
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
