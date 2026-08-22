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
    return TransitRoute(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Route',
      originName: json['origin_name']?.toString() ?? json['start']?.toString() ?? '',
      destinationName: json['destination_name']?.toString() ?? json['end']?.toString() ?? '',
      routeType: json['route_type']?.toString() ?? 'COMBI',
      baseFare: (json['base_fare'] ?? 8.0).toDouble(),
    );
  }
}
