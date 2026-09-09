enum UserRole {
  passenger,
  driverBus,
  driverCombi,
  driverTaxi;

  String get displayName {
    switch (this) {
      case UserRole.passenger:
        return 'Passenger';
      case UserRole.driverBus:
        return 'Bus Driver';
      case UserRole.driverCombi:
        return 'Combi Driver';
      case UserRole.driverTaxi:
        return 'Taxi Driver';
    }
  }

  String get serviceType {
    switch (this) {
      case UserRole.driverBus:
        return 'BUS';
      case UserRole.driverCombi:
        return 'COMBI';
      case UserRole.driverTaxi:
        return 'TAXI';
      default:
        return 'PASSENGER';
    }
  }

  static UserRole fromDatabase(String? role, String? serviceType) {
    final r = role?.toUpperCase();
    final st = serviceType?.toUpperCase();
    if (r == 'DRIVER') {
      if (st == 'BUS') return UserRole.driverBus;
      if (st == 'TAXI') return UserRole.driverTaxi;
      return UserRole.driverCombi;
    }
    return UserRole.passenger;
  }
}
