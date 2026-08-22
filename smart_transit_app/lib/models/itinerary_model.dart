class JourneyLegModel {
  final int legNumber;
  final String mode; // WALK, TAXI, COMBI, BUS
  final String fromName;
  final String toName;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final String? routeName;
  final String departureTime;
  final String arrivalTime;
  final int durationMinutes;
  final double distanceMeters;
  final double fareBWP;
  final String instruction;
  final bool autoHailReady;

  JourneyLegModel({
    required this.legNumber,
    required this.mode,
    required this.fromName,
    required this.toName,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    this.routeName,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.distanceMeters,
    required this.fareBWP,
    required this.instruction,
    required this.autoHailReady,
  });

  factory JourneyLegModel.fromJson(Map<String, dynamic> json) {
    final fromCoords = json['from_coords'] as Map<String, dynamic>?;
    final toCoords = json['to_coords'] as Map<String, dynamic>?;

    return JourneyLegModel(
      legNumber: (json['leg_number'] ?? 1) as int,
      mode: json['mode']?.toString() ?? 'WALK',
      fromName: json['from_name']?.toString() ?? '',
      toName: json['to_name']?.toString() ?? '',
      fromLat: (fromCoords?['lat'] ?? 0.0).toDouble(),
      fromLng: (fromCoords?['lng'] ?? 0.0).toDouble(),
      toLat: (toCoords?['lat'] ?? 0.0).toDouble(),
      toLng: (toCoords?['lng'] ?? 0.0).toDouble(),
      routeName: json['route_name']?.toString(),
      departureTime: json['departure_time']?.toString() ?? '',
      arrivalTime: json['arrival_time']?.toString() ?? '',
      durationMinutes: (json['duration_minutes'] ?? 0) as int,
      distanceMeters: (json['distance_meters'] ?? 0.0).toDouble(),
      fareBWP: (json['fare_bwp'] ?? 0.0).toDouble(),
      instruction: json['instruction']?.toString() ?? '',
      autoHailReady: (json['auto_hail_ready'] ?? false) as bool,
    );
  }
}

class ItineraryModel {
  final String planId;
  final String originName;
  final String destinationName;
  final String summary;
  final int totalDurationMinutes;
  final double totalFareBWP;
  final double totalDistanceKm;
  final String departureTime;
  final String estimatedArrivalTime;
  final List<JourneyLegModel> legs;

  ItineraryModel({
    required this.planId,
    required this.originName,
    required this.destinationName,
    required this.summary,
    required this.totalDurationMinutes,
    required this.totalFareBWP,
    required this.totalDistanceKm,
    required this.departureTime,
    required this.estimatedArrivalTime,
    required this.legs,
  });

  factory ItineraryModel.fromJson(Map<String, dynamic> json) {
    final legsList = (json['legs'] as List<dynamic>?)
            ?.map((leg) => JourneyLegModel.fromJson(leg as Map<String, dynamic>))
            .toList() ??
        [];

    return ItineraryModel(
      planId: json['plan_id']?.toString() ?? '',
      originName: json['origin_name']?.toString() ?? '',
      destinationName: json['destination_name']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      totalDurationMinutes: (json['total_duration_minutes'] ?? 0) as int,
      totalFareBWP: (json['total_fare_bwp'] ?? 0.0).toDouble(),
      totalDistanceKm: (json['total_distance_km'] ?? 0.0).toDouble(),
      departureTime: json['departure_time']?.toString() ?? '',
      estimatedArrivalTime: json['estimated_arrival_time']?.toString() ?? '',
      legs: legsList,
    );
  }
}
