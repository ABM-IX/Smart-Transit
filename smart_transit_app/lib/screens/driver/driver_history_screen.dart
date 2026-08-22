import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';

class DriverHistoryScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const DriverHistoryScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final transit = Provider.of<TransitProvider>(context);

    final mockShiftHistory = [
      {
        'id': 'shift-201',
        'route': 'Route U1 – BAC to Bus Rank',
        'date': 'Today (Active Shift)',
        'trips': 6,
        'passengers': transit.passengersCarried > 0 ? transit.passengersCarried : 24,
        'revenue': 192.0,
        'vehicle': auth.vehiclePlate,
        'status': 'In Progress'
      },
      {
        'id': 'shift-200',
        'route': 'Route U1 – BAC to Bus Rank',
        'date': 'Yesterday, 21 Aug 2026',
        'trips': 14,
        'passengers': 58,
        'revenue': 464.0,
        'vehicle': auth.vehiclePlate,
        'status': 'Completed'
      },
      {
        'id': 'shift-199',
        'route': 'Gaborone → Molepolole Coach',
        'date': '20 Aug 2026',
        'trips': 4,
        'passengers': 140,
        'revenue': 4900.0,
        'vehicle': auth.vehiclePlate,
        'status': 'Completed'
      },
      {
        'id': 'shift-198',
        'route': 'Special Taxi Dispatch',
        'date': '19 Aug 2026',
        'trips': 8,
        'passengers': 12,
        'revenue': 285.0,
        'vehicle': auth.vehiclePlate,
        'status': 'Completed'
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Shift & Trip History', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.black),
                onPressed: onBack,
              )
            : null,
      ),
      body: Column(
        children: [
          // Shift Summary Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.offWhite,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('32', 'Total Shifts'),
                Container(height: 30, width: 1, color: AppTheme.lightGrey),
                _buildSummaryStat('234', 'Pax Carried'),
                Container(height: 30, width: 1, color: AppTheme.lightGrey),
                _buildSummaryStat('P5,841.00', 'Total Revenue'),
              ],
            ),
          ),

          // Shift History List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: mockShiftHistory.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final shift = mockShiftHistory[idx];
                final isInProgress = shift['status'] == 'In Progress';

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isInProgress ? AppTheme.accentGreen : AppTheme.lightGrey,
                      width: isInProgress ? 1.5 : 1.0,
                    ),
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
                            Text(
                              shift['route'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isInProgress ? AppTheme.accentGreen.withOpacity(0.15) : AppTheme.offWhite,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                shift['status'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isInProgress ? AppTheme.accentGreen : AppTheme.midGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${shift['trips']} Trips • ${shift['passengers']} Passengers',
                              style: const TextStyle(fontSize: 13, color: AppTheme.midGrey),
                            ),
                            Text(
                              'P${(shift['revenue'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppTheme.black,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppTheme.lightGrey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Vehicle: ${shift['vehicle']}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
                            ),
                            Text(
                              shift['date'] as String,
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

  Widget _buildSummaryStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.black),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.midGrey),
        ),
      ],
    );
  }
}
