class HailRequest {
  final String requestId;
  final String passengerId;
  final String routeId;
  final double pickupLat;
  final double pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final String serviceType;
  final double fareEstimate;
  final String? stopName;
  final String? message;

  HailRequest({
    required this.requestId,
    required this.passengerId,
    required this.routeId,
    required this.pickupLat,
    required this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    required this.serviceType,
    required this.fareEstimate,
    this.stopName,
    this.message,
  });

  factory HailRequest.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickupLoc'] as Map<String, dynamic>? ?? json['pickup'] as Map<String, dynamic>?;
    final dest = json['destinationLoc'] as Map<String, dynamic>? ?? json['dropoff'] as Map<String, dynamic>?;

    return HailRequest(
      requestId: json['requestId']?.toString() ?? '',
      passengerId: json['passengerId']?.toString() ?? '',
      routeId: json['routeId']?.toString() ?? 'default-route',
      pickupLat: (pickup?['lat'] ?? pickup?['latitude'] ?? 0.0).toDouble(),
      pickupLng: (pickup?['lng'] ?? pickup?['longitude'] ?? 0.0).toDouble(),
      destinationLat: dest != null ? (dest['lat'] ?? dest['latitude'] ?? 0.0).toDouble() : null,
      destinationLng: dest != null ? (dest['lng'] ?? dest['longitude'] ?? 0.0).toDouble() : null,
      serviceType: json['serviceType']?.toString() ?? 'STANDARD',
      fareEstimate: (json['fareEstimate'] ?? 8.0).toDouble(),
      stopName: json['stopName']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class SpacingAdvisory {
  final String status; // SLOW DOWN, SPEED UP, MAINTAIN CURRENT SPEED
  final String aheadDisplay;
  final String behindDisplay;

  SpacingAdvisory({
    required this.status,
    required this.aheadDisplay,
    required this.behindDisplay,
  });

  factory SpacingAdvisory.fromJson(Map<String, dynamic> json) {
    return SpacingAdvisory(
      status: json['status']?.toString() ?? 'MAINTAIN CURRENT SPEED',
      aheadDisplay: json['ahead']?.toString() ?? 'N/A',
      behindDisplay: json['behind']?.toString() ?? 'N/A',
    );
  }
}
