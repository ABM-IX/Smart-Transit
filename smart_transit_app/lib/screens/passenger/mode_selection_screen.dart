import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'passenger_dashboard.dart';

class ModeSelectionScreen extends StatelessWidget {
  final Function(TransportMode) onModeSelected;

  const ModeSelectionScreen({super.key, required this.onModeSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your mode',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppTheme.brandNavy,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select your preferred transit modality in Gaborone & Southern Africa.',
            style: TextStyle(fontSize: 14, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 24),

          // Combi Card (Electric Royal Blue from logo S-circuit)
          _buildModeCard(
            title: 'Combi',
            subtitle: 'Flexible urban arterial routes & local network',
            badgeText: 'URBAN CORRIDOR',
            icon: Icons.airport_shuttle_outlined,
            fare: 'P${AppConstants.standardFareBWP.toStringAsFixed(2)}',
            modeColor: AppTheme.combiColor,
            isDarkTheme: Theme.of(context).brightness == Brightness.dark,
            onTap: () => onModeSelected(TransportMode.combi),
          ),
          const SizedBox(height: 14),

          // Bus Card (Deep Midnight Navy from logo SMART text)
          _buildModeCard(
            title: 'Bus / Coach',
            subtitle: 'Scheduled long-distance & regional intercity routes',
            badgeText: 'INTERCITY',
            icon: Icons.directions_bus_outlined,
            fare: 'Varies by route',
            modeColor: AppTheme.busColor,
            isDarkTheme: Theme.of(context).brightness == Brightness.dark,
            onTap: () => onModeSelected(TransportMode.bus),
          ),
          const SizedBox(height: 14),

          // Taxi Card (Cyan / Sky Blue from logo TRANSIT text)
          _buildModeCard(
            title: 'Taxi / Cab',
            subtitle: 'Private special or shared on-demand direct hail',
            badgeText: 'ON-DEMAND',
            icon: Icons.local_taxi_outlined,
            fare: 'From P${AppConstants.taxiBaseFareBWP.toStringAsFixed(2)}',
            modeColor: AppTheme.taxiColor,
            isDarkTheme: Theme.of(context).brightness == Brightness.dark,
            onTap: () => onModeSelected(TransportMode.taxi),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required String fare,
    required Color modeColor,
    required bool isDarkTheme,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderGrey, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left colored accent indicator stripe
                  Container(width: 5, color: modeColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
                      ),
                      child: Row(
                        children: [
                          // Colored Icon container
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: modeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: isDarkTheme ? Colors.white : Colors.black,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.brandNavy,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: modeColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: modeColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.secondaryText,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 104,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  fare,
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.brandNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 13,
                                  color: modeColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
