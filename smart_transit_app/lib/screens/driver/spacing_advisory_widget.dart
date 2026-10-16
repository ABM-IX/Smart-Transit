import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/hail_request_model.dart';

class SpacingAdvisoryWidget extends StatelessWidget {
  final SpacingAdvisory? advisory;

  const SpacingAdvisoryWidget({super.key, this.advisory});

  @override
  Widget build(BuildContext context) {
    if (advisory == null) {
      return const SizedBox.shrink();
    }

    final String statusUpper = advisory!.status.toUpperCase();
    final Color statusColor;
    final IconData statusIcon;
    final String instructionText;

    if (statusUpper.contains('HOLD')) {
      statusColor = AppTheme.statusDanger; // Red #DC2626
      statusIcon = Icons.front_hand;
      instructionText = 'Excess crowding ahead. Pause/hold at stop.';
    } else if (statusUpper.contains('SLOW') || statusUpper.contains('DOWN')) {
      statusColor = AppTheme.statusWarning; // Amber #F59E0B
      statusIcon = Icons.arrow_downward;
      instructionText = 'Too close to vehicle ahead. Regulate gap.';
    } else if (statusUpper.contains('SPEED') || statusUpper.contains('UP')) {
      statusColor = AppTheme.statusInfo; // Blue #2563EB
      statusIcon = Icons.arrow_upward;
      instructionText = 'Lagging behind schedule corridor. Accelerate pace.';
    } else {
      // Default: MAINTAIN / MAINTAIN CURRENT SPEED / MAINTAIN PACE
      statusColor = AppTheme.statusSuccess; // Green #16A34A
      statusIcon = Icons.check_circle_outline;
      instructionText = 'Optimal headway spacing maintained.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.18),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      advisory!.status,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        fontSize: 15,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceGrey,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: Text(
                        'ANTI-BUNCHING',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  instructionText,
                  style: TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ahead: ${advisory!.aheadDisplay} • Behind: ${advisory!.behindDisplay}',
                  style: TextStyle(
                    color: AppTheme.brandNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
