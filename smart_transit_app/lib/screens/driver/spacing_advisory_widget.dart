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

    Color statusColor;
    IconData statusIcon;

    if (advisory!.status == 'SLOW DOWN') {
      statusColor = AppTheme.accentRed;
      statusIcon = Icons.arrow_downward;
    } else if (advisory!.status == 'SPEED UP') {
      statusColor = AppTheme.accentAmber;
      statusIcon = Icons.arrow_upward;
    } else {
      statusColor = AppTheme.accentGreen;
      statusIcon = Icons.check;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advisory!.status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ahead: ${advisory!.aheadDisplay} • Behind: ${advisory!.behindDisplay}',
                  style: const TextStyle(
                    color: AppTheme.midGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'ANTI-BUNCHING',
            style: TextStyle(
              color: AppTheme.midGrey,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
