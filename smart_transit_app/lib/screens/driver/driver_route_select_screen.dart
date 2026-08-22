import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/route_model.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';

class DriverRouteSelectScreen extends StatefulWidget {
  final UserRole driverRole;
  final Function(TransitRoute) onRouteConfirmed;

  const DriverRouteSelectScreen({
    super.key,
    required this.driverRole,
    required this.onRouteConfirmed,
  });

  @override
  State<DriverRouteSelectScreen> createState() => _DriverRouteSelectScreenState();
}

class _DriverRouteSelectScreenState extends State<DriverRouteSelectScreen> {
  TransitRoute? _chosenRoute;
  final TextEditingController _plateController = TextEditingController(text: 'B-789-BW');

  @override
  Widget build(BuildContext context) {
    final transit = Provider.of<TransitProvider>(context);
    final targetType = widget.driverRole == UserRole.driverBus ? 'BUS' : 'COMBI';
    final availableRoutes = transit.routes.where((r) => r.routeType.toUpperCase() == targetType).toList();

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          widget.driverRole == UserRole.driverBus ? 'Select Bus Route' : 'Select Combi Route',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shift Setup: ${widget.driverRole.displayName}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.black),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the route corridor you will operate during this shift.',
                style: TextStyle(color: AppTheme.midGrey, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Vehicle Plate Field
              TextField(
                controller: _plateController,
                decoration: InputDecoration(
                  labelText: 'Vehicle License Plate',
                  prefixIcon: const Icon(Icons.pin, color: AppTheme.black),
                  filled: true,
                  fillColor: AppTheme.offWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.lightGrey),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Select Operating Route',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.black),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ListView.separated(
                  itemCount: availableRoutes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final r = availableRoutes[idx];
                    final isSelected = _chosenRoute?.id == r.id;
                    return Card(
                      color: isSelected ? AppTheme.black : AppTheme.white,
                      child: InkWell(
                        onTap: () => setState(() => _chosenRoute = r),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                widget.driverRole == UserRole.driverBus ? Icons.directions_bus : Icons.airport_shuttle,
                                color: isSelected ? AppTheme.white : AppTheme.black,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isSelected ? AppTheme.white : AppTheme.black,
                                      ),
                                    ),
                                    Text(
                                      '${r.originName} → ${r.destinationName}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isSelected ? AppTheme.lightGrey : AppTheme.midGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: AppTheme.accentGreen),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _chosenRoute == null
                      ? null
                      : () {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          auth.updateDriverConfig(
                            serviceType: widget.driverRole.serviceType,
                            routeId: _chosenRoute!.id,
                            vehiclePlate: _plateController.text,
                          );
                          widget.onRouteConfirmed(_chosenRoute!);
                        },
                  child: Text(
                    _chosenRoute == null ? 'Select a Route to Start' : 'Start Shift on ${_chosenRoute!.name}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
