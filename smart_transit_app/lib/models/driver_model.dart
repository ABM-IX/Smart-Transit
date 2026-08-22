class LiveDriver {
  final String driverId;
  final String serviceType; // COMBI, TAXI, BUS
  final String status;      // ONLINE, OFFLINE
  final String? routeId;
  final String? vehicleId;
  final double latitude;
  final double longitude;
  final int occupancy;
  final double speed;
  final double heading;

  LiveDriver({
    required this.driverId,
    required this.serviceType,
    required this.status,
    this.routeId,
    this.vehicleId,
    required this.latitude,
    required this.longitude,
    this.occupancy = 0,
    this.speed = 0.0,
    this.heading = 0.0,
  });

  factory LiveDriver.fromJson(Map<String, dynamic> json) {
    final coords = json['coords'] as Map<String, dynamic>?;
    return LiveDriver(
      driverId: json['driver_id']?.toString() ?? json['driverId']?.toString() ?? '',
      serviceType: (json['service_type'] ?? json['serviceType'] ?? 'COMBI').toString().toUpperCase(),
      status: json['status']?.toString() ?? 'ONLINE',
      routeId: json['route_id']?.toString() ?? json['routeId']?.toString(),
      vehicleId: json['vehicle_id']?.toString() ?? json['vehicleId']?.toString(),
      latitude: (coords?['lat'] ?? coords?['latitude'] ?? json['latitude'] ?? 0.0).toDouble(),
      longitude: (coords?['lng'] ?? coords?['longitude'] ?? json['longitude'] ?? 0.0).toDouble(),
      occupancy: (json['occupancy'] as num?)?.toInt() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
