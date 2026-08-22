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
}
