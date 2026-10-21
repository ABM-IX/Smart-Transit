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
  static const String _pendingVerificationEmailKey =
      'smarttransit_pending_verification_email';

  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _authSubscription;

  UserRole _role = UserRole.passenger;
  UserProfile? _profile;
  final String _localUserId =
      'user-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  String _userName = 'Commuter';
  String _serviceType = 'COMBI';
  String _assignedRouteId = '';
  String _vehiclePlate = '';
  bool _isLoading = false;
  bool _isSessionReady = false;
  bool _passwordRecoveryPending = false;
  bool _emailVerifiedWelcomePending = false;
  String? _pendingVerificationEmail;
  String? _authLinkError;

  AuthProvider() {
    _initAuth();
  }

  bool get isLoading => _isLoading;
  bool get isSessionReady => _isSessionReady;
  bool get passwordRecoveryPending => _passwordRecoveryPending;
  bool get emailVerifiedWelcomePending => _emailVerifiedWelcomePending;
  String? get authLinkError => _authLinkError;
  UserProfile? get profile => _profile;
  bool get isAuthenticated =>
      _profile != null || _authService.currentUser != null;

  UserRole get role => _role;
  String get userId => _profile?.id.isNotEmpty == true
      ? _profile!.id
      : (_authService.currentUser?.id ?? _localUserId);
  String get userName =>
      _profile?.fullName.isNotEmpty == true ? _profile!.fullName : _userName;
  String get userEmail => _profile?.email.isNotEmpty == true
      ? _profile!.email
      : (_authService.currentUser?.email ?? 'commuter@smarttransit.bw');
  String get phoneNumber => _profile?.phoneNumber.isNotEmpty == true
      ? _profile!.phoneNumber
      : '+267 71 234 567';
  String get serviceType => _profile?.serviceType.isNotEmpty == true
      ? _profile!.serviceType
      : _serviceType;
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
      _pendingVerificationEmail = prefs.getString(_pendingVerificationEmailKey);
      _recognizeVerifiedEmail(_authService.currentUser);
    } catch (_) {
      // Continue into the signed-out flow if local session data is unavailable.
    } finally {
      _isSessionReady = true;
      notifyListeners();
    }
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
    unawaited(loadSavedSession());

    final current = _authService.currentUser;
    if (current != null) {
      loadProfile(current.id);
    }

    _authSubscription = _authService.onAuthStateChange.listen((data) {
      final session = data.session;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecoveryPending = true;
        notifyListeners();
      }
      if (data.event == AuthChangeEvent.signedIn) {
        _recognizeVerifiedEmail(data.session?.user);
      }
      if (session != null) {
        loadProfile(session.user.id);
      } else if (data.event == AuthChangeEvent.signedOut) {
        _resetToGuest();
      }
    });
  }

  void finishPasswordRecovery() {
    if (!_passwordRecoveryPending) return;
    _passwordRecoveryPending = false;
    notifyListeners();
  }

  void beginPasswordRecovery() {
    if (_passwordRecoveryPending) return;
    _passwordRecoveryPending = true;
    _authLinkError = null;
    notifyListeners();
  }

  Future<void> markEmailVerificationPending(String email) async {
    _pendingVerificationEmail = email.trim().toLowerCase();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingVerificationEmailKey,
        _pendingVerificationEmail!,
      );
    } catch (_) {}
  }

  void _recognizeVerifiedEmail(User? user) {
    final email = user?.email?.trim().toLowerCase();
    if (email == null ||
        email.isEmpty ||
        user?.emailConfirmedAt == null ||
        email != _pendingVerificationEmail) {
      return;
    }
    _emailVerifiedWelcomePending = true;
    _pendingVerificationEmail = null;
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.remove(_pendingVerificationEmailKey),
      ),
    );
    notifyListeners();
  }

  void finishEmailVerifiedWelcome() {
    if (!_emailVerifiedWelcomePending) return;
    _emailVerifiedWelcomePending = false;
    notifyListeners();
  }

  void reportAuthLinkError(Object error) {
    _authLinkError = AuthService.formatAuthErrorMessage(error);
    notifyListeners();
  }

  void clearAuthLinkError() {
    if (_authLinkError == null) return;
    _authLinkError = null;
    notifyListeners();
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
      _userName =
          '${newRole.displayName} ${userId.substring(userId.length > 4 ? userId.length - 4 : 0)}';
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
    // Route, vehicle and service type are registration-time assignments. Keep
    // the saved driver assignment even if an old shift setup screen calls this.
    if (_profile?.isDriver == true) {
      _serviceType = _profile!.serviceType;
      _assignedRouteId = _profile!.assignedRouteId ?? '';
      _vehiclePlate = _profile!.vehiclePlate ?? '';
      notifyListeners();
      return;
    }

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

  Future<void> updatePhoneNumber(String phoneNumber) async {
    final cleanPhone = phoneNumber.trim();
    if (cleanPhone.isEmpty || _profile == null) return;
    await _authService.updatePhoneNumber(
      userId: _profile!.id,
      phoneNumber: cleanPhone,
    );
    _profile = _profile!.copyWith(phoneNumber: cleanPhone);
    await _saveSession(_profile!);
    notifyListeners();
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    if (_profile == null) return;
    final cleanName = fullName?.trim() ?? _profile!.fullName;
    await _authService.updateProfile(
      userId: _profile!.id,
      fullName: cleanName,
      avatarUrl: avatarUrl,
    );
    _profile = _profile!.copyWith(fullName: cleanName, avatarUrl: avatarUrl);
    _userName = cleanName;
    await _saveSession(_profile!);
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
