import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class PassengerHistoryScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PassengerHistoryScreen({super.key, this.onBack});

  @override
  State<PassengerHistoryScreen> createState() => _PassengerHistoryScreenState();
}

class _PassengerHistoryScreenState extends State<PassengerHistoryScreen> {
  String _selectedFilter = 'ALL';
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserTrips();
  }

  Future<void> _loadUserTrips() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('trips')
          .select()
          .eq('passenger_id', auth.userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 4));

      final List<Map<String, dynamic>> loaded = [];
      for (final row in response) {
        DateTime? createdAt;
        if (row['created_at'] != null) {
          createdAt = DateTime.tryParse(row['created_at'].toString());
        }
        final dateStr = createdAt != null
            ? DateFormat('dd MMM yyyy, HH:mm').format(createdAt.toLocal())
            : 'Recent Trip';

        loaded.add({
          'id': row['id']?.toString() ?? '',
          'mode': (row['service_type'] as String? ?? 'COMBI').toUpperCase(),
          'routeName': row['route_id'] ?? '${row['pickup_name'] ?? 'Origin'} → ${row['dropoff_name'] ?? 'Destination'}',
          'origin': row['pickup_name'] ?? 'Pickup Point',
          'destination': row['dropoff_name'] ?? 'Destination',
          'fare': (row['fare'] as num?)?.toDouble() ?? 8.0,
          'date': dateStr,
          'driver': row['driver_id'] != null ? 'Driver: ${row['driver_id']}' : 'SmartTransit Operator',
          'status': row['status'] ?? 'Completed',
        });
      }

      if (mounted) {
        setState(() {
          _trips = loaded;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _trips = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTrips = _selectedFilter == 'ALL'
        ? _trips
        : _trips.where((t) => t['mode'] == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Trip History', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.black),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.black),
            onPressed: _loadUserTrips,
            tooltip: 'Refresh Trips',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.offWhite,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Modes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('COMBI', 'Combi Rides'),
                  const SizedBox(width: 8),
                  _buildFilterChip('BUS', 'Bus Routes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('TAXI', 'Taxi Cabs'),
                ],
              ),
            ),
          ),

          // History List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.black),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUserTrips,
                    color: AppTheme.black,
                    child: filteredTrips.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.directions_transit_outlined, size: 56, color: AppTheme.lightGrey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Trip History Yet',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.black),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Your completed combi rides, bus trips, and taxi bookings will appear here automatically.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppTheme.midGrey, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredTrips.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final item = filteredTrips[idx];
                              final mode = item['mode'] as String;

                              IconData iconData = Icons.airport_shuttle;
                              Color modeColor = AppTheme.accentBlue;
                              if (mode == 'BUS') {
                                iconData = Icons.directions_bus;
                                modeColor = Colors.purple;
                              } else if (mode == 'TAXI') {
                                iconData = Icons.local_taxi;
                                modeColor = AppTheme.accentGreen;
                              }

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppTheme.lightGrey),
                                ),
                                color: AppTheme.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: modeColor.withOpacity(0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(iconData, color: modeColor, size: 20),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                mode,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  color: modeColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'P${(item['fare'] as double).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                              color: AppTheme.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        item['routeName'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.my_location, size: 14, color: AppTheme.midGrey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${item['origin']} → ${item['destination']}',
                                              style: const TextStyle(fontSize: 12, color: AppTheme.midGrey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20, color: AppTheme.lightGrey),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item['driver'] as String,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
                                          ),
                                          Text(
                                            item['date'] as String,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.black,
      backgroundColor: AppTheme.white,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.white : AppTheme.black,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }
}
