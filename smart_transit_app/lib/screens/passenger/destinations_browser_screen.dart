import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/route_model.dart';
import '../../providers/transit_provider.dart';
import 'passenger_dashboard.dart';

class DestinationsBrowserScreen extends StatefulWidget {
  final TransportMode mode;
  final Function(TransitRoute) onRouteSelected;

  const DestinationsBrowserScreen({
    super.key,
    required this.mode,
    required this.onRouteSelected,
  });

  @override
  State<DestinationsBrowserScreen> createState() => _DestinationsBrowserScreenState();
}

class _DestinationsBrowserScreenState extends State<DestinationsBrowserScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final transit = Provider.of<TransitProvider>(context);
    final targetType = widget.mode == TransportMode.bus ? 'BUS' : 'COMBI';
    
    final filteredRoutes = transit.routes.where((r) {
      final matchesType = r.routeType.toUpperCase() == targetType;
      final matchesQuery = _searchQuery.isEmpty ||
          r.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.originName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.destinationName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesType && matchesQuery;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search destinations or route numbers...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.black),
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
          const SizedBox(height: 18),

          Text(
            widget.mode == TransportMode.bus ? 'Intercity & Regional Routes' : 'Urban Combi Routes',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: filteredRoutes.isEmpty
                ? Center(
                    child: Text(
                      'No routes found matching "$_searchQuery"',
                      style: const TextStyle(color: AppTheme.midGrey),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredRoutes.length,
                    separatorBuilder: (context, idx) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final route = filteredRoutes[index];
                      return _buildRouteCard(route);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(TransitRoute route) {
    return Card(
      child: InkWell(
        onTap: () => widget.onRouteSelected(route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.black, width: 1.5),
                ),
                child: Icon(
                  widget.mode == TransportMode.bus ? Icons.directions_bus : Icons.airport_shuttle,
                  color: AppTheme.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${route.originName} → ${route.destinationName}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.midGrey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'P${route.baseFare.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, color: AppTheme.midGrey, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
