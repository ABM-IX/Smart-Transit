import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'passenger_dashboard.dart';

class ModeSelectionScreen extends StatelessWidget {
  final Function(TransportMode) onModeSelected;

  const ModeSelectionScreen({super.key, required this.onModeSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your mode',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Clean, direct booking across bus, combi, and taxi.',
            style: TextStyle(fontSize: 14, color: AppTheme.midGrey),
          ),
          const SizedBox(height: 28),

          // Bus Card
          _buildModeCard(
            title: 'Bus',
            subtitle: 'Scheduled long-distance & regional trips',
            icon: Icons.directions_bus_outlined,
            fare: 'From P20',
            onTap: () => onModeSelected(TransportMode.bus),
          ),
          const SizedBox(height: 14),

          // Combi Card
          _buildModeCard(
            title: 'Combi',
            subtitle: 'Flexible urban arterial routes',
            icon: Icons.airport_shuttle_outlined,
            fare: 'P8.00',
            onTap: () => onModeSelected(TransportMode.combi),
          ),
          const SizedBox(height: 14),

          // Taxi Card
          _buildModeCard(
            title: 'Taxi',
            subtitle: 'Private & shared on-demand rides',
            icon: Icons.local_taxi_outlined,
            fare: 'From P8.00',
            onTap: () => onModeSelected(TransportMode.taxi),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String fare,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.black, width: 1.5),
                ),
                child: Icon(icon, color: AppTheme.black, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppTheme.midGrey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fare,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.midGrey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
