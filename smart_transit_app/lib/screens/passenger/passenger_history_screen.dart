import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/status_pill.dart';

class PassengerHistoryScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PassengerHistoryScreen({super.key, this.onBack});

  @override
  State<PassengerHistoryScreen> createState() => _PassengerHistoryScreenState();
}

class _PassengerHistoryScreenState extends State<PassengerHistoryScreen> {
  String _selectedFilter = 'ALL';

  final List<Map<String, dynamic>> _mockHistory = [
    {
      'id': 'trip-101',
      'mode': 'COMBI',
      'routeName': 'Route U1 – BAC to Bus Rank',
      'origin': 'BAC Stop',
      'destination': 'Gaborone Bus Rank',
      'fare': 8.0,
      'date': 'Today, 14:15',
      'driver': 'Kabo M. (B-BW 492)',
      'status': 'Completed'
    },
    {
      'id': 'trip-102',
      'mode': 'TAXI',
      'routeName': 'Special Direct Cab',
      'origin': 'Main Mall CBD',
      'destination': 'Game City Mall',
      'fare': 25.0,
      'date': 'Yesterday, 18:30',
      'driver': 'Tuelo K. (B 123 ABC)',
      'status': 'Completed'
    },
    {
      'id': 'trip-103',
      'mode': 'BUS',
      'routeName': 'Gaborone → Molepolole Coach',
      'origin': 'Gaborone Bus Rank',
      'destination': 'Molepolole Rank',
      'fare': 35.0,
      'date': '20 Aug 2026, 09:00',
      'driver': 'Intercity Express #4',
      'status': 'Completed'
    },
    {
      'id': 'trip-104',
      'mode': 'COMBI',
      'routeName': 'Route M1 – Molepolole Central to Mafitlhakgosi',
      'origin': 'Molepolole Rank',
      'destination': 'Mafitlhakgosi',
      'fare': 8.0,
      'date': '19 Aug 2026, 16:45',
      'driver': 'Oteng P. (B-BW 881)',
      'status': 'Completed'
    },
    {
      'id': 'trip-105',
      'mode': 'TAXI',
      'routeName': 'Standard Shared Taxi',
      'origin': 'UB Main Gate',
      'destination': 'Tlokweng Border Road',
      'fare': 8.0,
      'date': '18 Aug 2026, 12:10',
      'driver': 'Thabo S. (B 774 AXZ)',
      'status': 'Completed'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredTrips = _selectedFilter == 'ALL'
        ? _mockHistory
        : _mockHistory.where((t) => t['mode'] == _selectedFilter).toList();

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
            child: filteredTrips.isEmpty
                ? const Center(
                    child: Text('No trip history found.', style: TextStyle(color: AppTheme.midGrey)),
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
                                  Text(
                                    '${item['origin']} → ${item['destination']}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.midGrey),
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: AppTheme.lightGrey),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Driver: ${item['driver']}',
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
