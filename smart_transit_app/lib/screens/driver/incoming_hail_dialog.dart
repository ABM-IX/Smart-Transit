import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/hail_request_model.dart';

class IncomingHailDialog extends StatelessWidget {
  final HailRequest hail;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingHailDialog({
    super.key,
    required this.hail,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isTaxi = hail.serviceType == 'TAXI' || hail.serviceType == 'SPECIAL' || hail.serviceType == 'STANDARD';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.black, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.offWhite,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTaxi ? Icons.local_taxi : Icons.pan_tool_alt,
                  color: AppTheme.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTaxi ? 'Incoming Taxi Request' : 'Passenger Hail Request',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.black,
                      ),
                    ),
                    Text(
                      hail.stopName != null ? 'At ${hail.stopName}' : 'Pickup along route corridor',
                      style: const TextStyle(color: AppTheme.midGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                'P${hail.fareEstimate.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Accept / Reject Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentRed,
                    side: const BorderSide(color: AppTheme.accentRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept Ride'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
