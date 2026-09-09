import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class DriverHistoryScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DriverHistoryScreen({super.key, this.onBack});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _shifts = [];
  int _totalTrips = 0;
  int _totalPax = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDriverHistory();
  }

  Future<void> _loadDriverHistory() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('trips')
          .select()
          .eq('driver_id', auth.userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 4));

      final List<Map<String, dynamic>> loaded = [];
      int tripsCount = 0;
      double revenue = 0.0;

      for (final row in response) {
        DateTime? createdAt;
        if (row['created_at'] != null) {
          createdAt = DateTime.tryParse(row['created_at'].toString());
        }
        final dateStr = createdAt != null
            ? DateFormat('dd MMM yyyy, HH:mm').format(createdAt.toLocal())
            : 'Recent Shift';

        final fare = (row['fare'] as num?)?.toDouble() ?? 8.0;
        revenue += fare;
        tripsCount++;

        loaded.add({
          'id': row['id']?.toString() ?? '',
          'route': row['route_id'] ?? '${row['pickup_name'] ?? 'Origin'} → ${row['dropoff_name'] ?? 'Dropoff'}',
          'date': dateStr,
          'trips': 1,
          'passengers': 1,
          'revenue': fare,
          'vehicle': auth.vehiclePlate,
          'status': row['status'] ?? 'Completed',
        });
      }

      if (mounted) {
        setState(() {
          _shifts = loaded;
          _totalTrips = tripsCount;
          _totalPax = tripsCount;
          _totalRevenue = revenue;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _shifts = [];
          _totalTrips = 0;
          _totalPax = 0;
          _totalRevenue = 0.0;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Shift & Trip History', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.black),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.black),
            onPressed: _loadDriverHistory,
            tooltip: 'Refresh Shift History',
          ),
        ],
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
                _buildSummaryStat('$_totalTrips', 'Total Trips'),
                Container(height: 30, width: 1, color: AppTheme.lightGrey),
                _buildSummaryStat('$_totalPax', 'Pax Carried'),
                Container(height: 30, width: 1, color: AppTheme.lightGrey),
                _buildSummaryStat('P${_totalRevenue.toStringAsFixed(2)}', 'Total Revenue'),
              ],
            ),
          ),

          // Shift History List or Clean Empty State
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.black),
                  )
                : _shifts.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppTheme.offWhite,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.lightGrey),
                                ),
                                child: const Icon(Icons.history_toggle_off, size: 32, color: AppTheme.midGrey),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Completed Trips Yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'You have not completed any passenger rides yet on this account. Start your shift on the map and complete rides with commuters to record trip logs and revenue here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.midGrey,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDriverHistory,
                        color: AppTheme.black,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _shifts.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final shift = _shifts[idx];
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
                                    Expanded(
                                      child: Text(
                                        shift['route'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isInProgress
                                            ? AppTheme.accentGreen.withOpacity(0.15)
                                            : AppTheme.offWhite,
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
