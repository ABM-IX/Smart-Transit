import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/itinerary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transit_provider.dart';
import '../../services/api_service.dart';

class AiPlannerScreen extends StatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  State<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends State<AiPlannerScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _originController = TextEditingController(text: 'Home (Block 8)');
  final TextEditingController _destController = TextEditingController(text: 'Francistown Central Terminal');
  final TextEditingController _timeController = TextEditingController(text: '14:00');

  bool _isLoading = false;
  ItineraryModel? _itinerary;

  Future<void> _planTrip() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final transit = Provider.of<TransitProvider>(context, listen: false);

    final result = await _api.planAiJourney(
      passengerId: auth.userId,
      originName: _originController.text,
      originLat: transit.currentLocation.latitude,
      originLng: transit.currentLocation.longitude,
      destName: _destController.text,
      destLat: -21.1661,
      destLng: 27.5144,
      desiredArrivalTime: _timeController.text,
    );

    setState(() {
      _itinerary = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('AI Multi-Modal Facilitator', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.black),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppTheme.black, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Autonomous Journey Orchestrator',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.black,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Coordinates Taxi + Combi + Bus into one seamless schedule.',
                          style: TextStyle(fontSize: 12, color: AppTheme.midGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: _originController,
              label: 'Origin / Current Location',
              icon: Icons.my_location,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _destController,
              label: 'Destination',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _timeController,
              label: 'Target Arrival Time',
              icon: Icons.access_time,
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _planTrip,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.route),
              label: Text(_isLoading ? 'Orchestrating Route...' : 'Generate Multi-Modal Plan'),
            ),
            const SizedBox(height: 24),

            if (_itinerary != null) ...[
              _buildItineraryCard(_itinerary!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppTheme.black, size: 20),
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.midGrey),
        filled: true,
        fillColor: AppTheme.offWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.lightGrey),
        ),
      ),
    );
  }

  Widget _buildItineraryCard(ItineraryModel plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Planned Itinerary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.black),
            ),
            Text(
              'Est. Total: P${plan.totalFareBWP.toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppTheme.accentGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...plan.legs.map((leg) => _buildLegCard(leg)),
      ],
    );
  }

  Widget _buildLegCard(JourneyLegModel leg) {
    IconData legIcon;
    if (leg.mode == 'TAXI') {
      legIcon = Icons.local_taxi;
    } else if (leg.mode == 'COMBI') {
      legIcon = Icons.airport_shuttle;
    } else if (leg.mode == 'BUS') {
      legIcon = Icons.directions_bus;
    } else {
      legIcon = Icons.directions_walk;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.offWhite,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(legIcon, color: AppTheme.black, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leg ${leg.legNumber}: ${leg.mode}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.black,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${leg.fromName} → ${leg.toName}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${leg.departureTime} - ${leg.arrivalTime}',
                  style: const TextStyle(color: AppTheme.midGrey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(leg.instruction, style: const TextStyle(color: AppTheme.midGrey, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${leg.durationMinutes} mins • ${(leg.distanceMeters / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(color: AppTheme.midGrey, fontSize: 12),
                ),
                Text(
                  leg.fareBWP > 0 ? 'P${leg.fareBWP.toStringAsFixed(2)}' : 'Free',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
