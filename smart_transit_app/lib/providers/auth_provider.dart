import 'package:flutter/material.dart';
import '../models/user_role.dart';

class AuthProvider extends ChangeNotifier {
  UserRole _role = UserRole.passenger;
  final String _userId = 'user-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  String _userName = 'Commuter';
  String _serviceType = 'COMBI'; // COMBI, TAXI, BUS
  String _assignedRouteId = 'route-u01';
  String _vehiclePlate = 'B-789-BW';

  UserRole get role => _role;
  String get userId => _userId;
  String get userName => _userName;
  String get serviceType => _serviceType;
  String get assignedRouteId => _assignedRouteId;
  String get vehiclePlate => _vehiclePlate;
  bool get isDriver => _role != UserRole.passenger;

  void setRole(UserRole newRole) {
    _role = newRole;
    if (_role != UserRole.passenger) {
      _userName = '${newRole.displayName} ${_userId.substring(_userId.length - 4)}';
      _serviceType = newRole.serviceType;
    } else {
      _userName = 'Commuter';
      _serviceType = 'PASSENGER';
    }
    notifyListeners();
  }

  void updateDriverConfig({
    required String serviceType,
    required String routeId,
    required String vehiclePlate,
  }) {
    _serviceType = serviceType;
    _assignedRouteId = routeId;
    _vehiclePlate = vehiclePlate;
    notifyListeners();
  }
}
