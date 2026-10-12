import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _sessionProfileKey = 'smarttransit_user_profile';
  static const String _sessionLoggedInKey = 'smarttransit_is_logged_in';

  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _authSubscription;

  UserRole _role = UserRole.passenger;
  UserProfile? _profile;
  final String _localUserId = 'user-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  String _userName = 'Commuter';
  String _serviceType = 'COMBI';
  String _assignedRouteId = '';
  String _vehiclePlate = '';
  bool _isLoading = false;

  AuthProvider() {
    _initAuth();
  }

  bool get isLoading => _isLoading;
  UserProfile? get profile => _profile;
  bool get isAuthenticated => _profile != null || _authService.currentUser != null;

  UserRole get role => _role;
  String get userId => _profile?.id.isNotEmpty == true 
      ? _profile!.id 
      : (_authService.currentUser?.id ?? _localUserId);
  String get userName => _profile?.fullName.isNotEmpty == true ? _profile!.fullName : _userName;
  String get userEmail => _profile?.email.isNotEmpty == true 
      ? _profile!.email 
      : (_authService.currentUser?.email ?? 'commuter@smarttransit.bw');
  String get phoneNumber => _profile?.phoneNumber.isNotEmpty == true ? _profile!.phoneNumber : '+267 71 234 567';
  String get serviceType => _profile?.serviceType.isNotEmpty == true ? _profile!.serviceType : _serviceType;
  String get assignedRouteId => _profile?.assignedRouteId ?? _assignedRouteId;
  String get vehiclePlate => _profile?.vehiclePlate ?? _vehiclePlate;
  bool get isDriver => _role != UserRole.passenger;

  Future<void> loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_sessionLoggedInKey) ?? false;
      final rawProfile = prefs.getString(_sessionProfileKey);
      if (isLoggedIn && rawProfile != null && rawProfile.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(rawProfile);
        final p = UserProfile.fromJson(data);
        _profile = p;
        _userName = p.fullName;
        _serviceType = p.serviceType;
        if (p.assignedRouteId != null && p.assignedRouteId!.isNotEmpty) {
          _assignedRouteId = p.assignedRouteId!;
        }
        if (p.vehiclePlate != null && p.vehiclePlate!.isNotEmpty) {
          _vehiclePlate = p.vehiclePlate!;
        }
        _role = UserRole.fromDatabase(p.role, p.serviceType);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveSession(UserProfile p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionLoggedInKey, true);
      await prefs.setString(_sessionProfileKey, jsonEncode(p.toJson()));
    } catch (_) {}
  }

  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionLoggedInKey);
      await prefs.remove(_sessionProfileKey);
    } catch (_) {}
  }

  void _initAuth() {
    loadSavedSession();

    final current = _authService.currentUser;
    if (current != null) {
      loadProfile(current.id);
    }

    _authSubscription = _authService.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        loadProfile(session.user.id);
      } else if (data.event == AuthChangeEvent.signedOut) {
        _resetToGuest();
      }
    });
  }

  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      final p = await _authService.fetchUserProfile(uid);
      if (p != null) {
        setProfile(p);
      }
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setProfile(UserProfile p) {
    _profile = p;
    _userName = p.fullName;
    _serviceType = p.serviceType;
    if (p.assignedRouteId != null && p.assignedRouteId!.isNotEmpty) {
      _assignedRouteId = p.assignedRouteId!;
    }
    if (p.vehiclePlate != null && p.vehiclePlate!.isNotEmpty) {
      _vehiclePlate = p.vehiclePlate!;
    }
    _role = UserRole.fromDatabase(p.role, p.serviceType);
    _saveSession(p);
    notifyListeners();
  }

  void setRole(UserRole newRole) {
    _role = newRole;
    if (_role != UserRole.passenger) {
      _userName = '${newRole.displayName} ${userId.substring(userId.length > 4 ? userId.length - 4 : 0)}';
      _serviceType = newRole.serviceType;
    } else {
      _userName = 'Commuter';
      _serviceType = 'PASSENGER';
    }
    if (_profile != null) {
      _profile = _profile!.copyWith(
        role: newRole == UserRole.passenger ? 'PASSENGER' : 'DRIVER',
        serviceType: _serviceType,
      );
      _saveSession(_profile!);
    }
    notifyListeners();
  }

  Future<void> updateDriverConfig({
    required String serviceType,
    required String routeId,
    required String vehiclePlate,
  }) async {
    _serviceType = serviceType.toUpperCase().trim();
    _assignedRouteId = routeId;
    _vehiclePlate = vehiclePlate.toUpperCase().trim();

    if (_profile != null) {
      _profile = _profile!.copyWith(
        serviceType: _serviceType,
        assignedRouteId: _assignedRouteId,
        vehiclePlate: _vehiclePlate,
      );
      _saveSession(_profile!);
      await _authService.updateDriverProfile(
        userId: _profile!.id,
        vehiclePlate: _vehiclePlate,
        assignedRouteId: _assignedRouteId,
        serviceType: _serviceType,
      );
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clearSavedSession();
    await _authService.signOut();
    _resetToGuest();
  }

  void _resetToGuest() {
    _clearSavedSession();
    _profile = null;
    _role = UserRole.passenger;
    _userName = 'Commuter';
    _serviceType = 'COMBI';
    _assignedRouteId = '';
    _vehiclePlate = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
