import '../core/constants.dart';

class TransitStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;

  TransitStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
  });

  factory TransitStop.fromJson(Map<String, dynamic> json) {
    return TransitStop(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Stop',
      latitude: (json['latitude'] ?? json['lat'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['lng'] ?? 0.0).toDouble(),
      description: json['description']?.toString(),
    );
  }
}

class TransitRoute {
  final String id;
  final String name;
  final String originName;
  final String destinationName;
  final String routeType; // COMBI, BUS
  final double baseFare;

  TransitRoute({
    required this.id,
    required this.name,
    required this.originName,
    required this.destinationName,
    required this.routeType,
    required this.baseFare,
  });

  factory TransitRoute.fromJson(Map<String, dynamic> json) {
    final routeType = (json['route_type']?.toString() ?? 'COMBI').toUpperCase();
    final baseFare = json['base_fare'];
    return TransitRoute(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Route',
      originName:
          json['origin_name']?.toString() ?? json['start']?.toString() ?? '',
      destinationName:
          json['destination_name']?.toString() ?? json['end']?.toString() ?? '',
      routeType: routeType,
      baseFare: switch (routeType) {
        'COMBI' => AppConstants.standardFareBWP,
        'TAXI' => AppConstants.taxiBaseFareBWP,
        'BUS' => baseFare is num ? baseFare.toDouble() : 0.0,
        _ =>
          baseFare is num ? baseFare.toDouble() : AppConstants.standardFareBWP,
      },
    );
  }
}
