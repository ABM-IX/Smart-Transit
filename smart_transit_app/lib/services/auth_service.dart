import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String role; // 'PASSENGER' or 'DRIVER'
  final String serviceType; // 'PASSENGER', 'COMBI', 'BUS', 'TAXI'
  final String? vehiclePlate;
  final String? assignedRouteId;
  final String? avatarUrl;
  final double rating;
  final bool isActive;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.serviceType,
    this.vehiclePlate,
    this.assignedRouteId,
    this.avatarUrl,
    this.rating = 5.0,
    this.isActive = true,
  });

  bool get isDriver => role.toUpperCase() == 'DRIVER';
  bool get isPassenger => role.toUpperCase() == 'PASSENGER';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      role: (json['role'] as String? ?? 'PASSENGER').toUpperCase(),
      serviceType: (json['service_type'] as String? ?? 'PASSENGER')
          .toUpperCase(),
      vehiclePlate: json['vehicle_plate'] as String?,
      assignedRouteId: json['assigned_route_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'role': role,
      'service_type': serviceType,
      'vehicle_plate': vehiclePlate,
      'assigned_route_id': assignedRouteId,
      'avatar_url': avatarUrl,
      'rating': rating,
      'is_active': isActive,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? phoneNumber,
    String? role,
    String? serviceType,
    String? vehiclePlate,
    String? assignedRouteId,
    String? avatarUrl,
    double? rating,
    bool? isActive,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      serviceType: serviceType ?? this.serviceType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      assignedRouteId: assignedRouteId ?? this.assignedRouteId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      isActive: isActive ?? this.isActive,
    );
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  /// Register a new Commuter / Passenger
  Future<AuthResponse> signUpPassenger({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AppConstants.authRedirectUrl,
      data: {
        'full_name': fullName.trim(),
        'phone_number': phoneNumber.trim(),
        'role': 'PASSENGER',
        'service_type': 'PASSENGER',
      },
    );

    if (response.user != null) {
      await _ensureProfileCreated(
        userId: response.user!.id,
        email: email.trim(),
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        role: 'PASSENGER',
        serviceType: 'PASSENGER',
      );
    }

    return response;
  }

  /// Ensure the default Metropolitan Taxi Dispatch corridor exists in public.routes
  Future<void> ensureTaxiDispatchRoute() async {
    try {
      await _supabase.from('routes').upsert({
        'id': 'taxi-dispatch',
        'name': 'Metropolitan Taxi Dispatch',
        'origin_name': 'Gaborone Metro',
        'destination_name': 'On-Demand Dispatch',
        'route_type': 'TAXI',
        'base_fare': AppConstants.taxiBaseFareBWP,
        'is_active': true,
      });
    } catch (_) {}
  }

  /// Formats raw Supabase / Auth exceptions into user-friendly messages
  static String formatAuthErrorMessage(Object error) {
    final raw = error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('AuthException: ', '')
        .replaceAll('AuthRetryableFetchException: ', '');
    final message = raw.toLowerCase();

    if (message.contains('database error saving new user') ||
        message.contains('unexpected_failure')) {
      return 'We couldn’t finish setting up your account right now. Please try again in a moment.';
    }
    if (message.contains('over_email_send_rate_limit') ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return 'Too many emails have been requested recently. Please wait a few minutes and try again.';
    }
    if (message.contains('already registered') ||
        message.contains('already in use') ||
        message.contains('user already exists')) {
      return 'There’s already a SmartTransit account with this email. Try signing in instead.';
    }
    if (message.contains('password should be at least') ||
        message.contains('password must contain') ||
        message.contains('weak_password')) {
      return 'Choose a stronger password. Use at least 6 characters.';
    }
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'That email and password don’t match. Check them and try again.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please verify your email first. Open the confirmation link we sent, then sign in.';
    }
    if (message.contains('user not found') ||
        message.contains('email not found')) {
      return 'We couldn’t find an account with that email. Check the address or create an account.';
    }
    if (message.contains('invalid email') ||
        message.contains('email address is invalid')) {
      return 'Enter a valid email address, such as name@example.com.';
    }
    if (message.contains('same_password') ||
        message.contains('should be different from the old password')) {
      return 'Choose a password you haven’t used for this account before.';
    }
    if (message.contains('network') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('timed out')) {
      return 'We couldn’t connect. Check your internet connection and try again.';
    }
    if (message.contains('otp_expired') ||
        message.contains('expired') ||
        message.contains('invalid token')) {
      return 'This link has expired or was already used. Request a fresh email and try again.';
    }
    if (message.contains('code verifier could not be found')) {
      return 'Open this link on the same phone where you requested it. If it still won’t open, request a fresh email from that phone.';
    }

    return 'Something went wrong. Please try again. If the problem continues, check your connection or contact support.';
  }

  /// Dynamically create or ensure an operating corridor exists in public.routes
  Future<String> createOrGetRoute({
    required String name,
    required String originName,
    required String destinationName,
    required String routeType,
    double baseFare = AppConstants.standardFareBWP,
  }) async {
    final cleanId = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final routeId = cleanId.isNotEmpty
        ? cleanId
        : 'route-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await _supabase.from('routes').upsert({
        'id': routeId,
        'name': name.trim(),
        'origin_name': originName.trim(),
        'destination_name': destinationName.trim(),
        'route_type': routeType.toUpperCase().trim(),
        'base_fare': baseFare,
        'is_active': true,
      });
    } catch (_) {}

    return routeId;
  }

  /// Register a new Transit Driver / Operator
  Future<AuthResponse> signUpDriver({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String serviceType,
    required String vehiclePlate,
    String? assignedRouteId,
  }) async {
    final normalizedServiceType = serviceType.toUpperCase().trim();
    final normalizedPlate = vehiclePlate.toUpperCase().trim();

    // Ensure taxi dispatch route exists in public.routes if registering as a taxi
    if (normalizedServiceType == 'TAXI' || assignedRouteId == 'taxi-dispatch') {
      await ensureTaxiDispatchRoute();
    }

    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AppConstants.authRedirectUrl,
      data: {
        'full_name': fullName.trim(),
        'phone_number': phoneNumber.trim(),
        'role': 'DRIVER',
        'service_type': normalizedServiceType,
        'vehicle_plate': normalizedPlate,
        'assigned_route_id': assignedRouteId,
      },
    );

    if (response.user != null) {
      await _ensureProfileCreated(
        userId: response.user!.id,
        email: email.trim(),
        fullName: fullName.trim(),
        phoneNumber: phoneNumber.trim(),
        role: 'DRIVER',
        serviceType: normalizedServiceType,
        vehiclePlate: normalizedPlate,
        assignedRouteId: assignedRouteId,
      );
    }

    return response;
  }

  /// Ensure public.users row exists even if Postgres trigger is delayed or disabled in local test
  Future<void> _ensureProfileCreated({
    required String userId,
    required String email,
    required String fullName,
    required String phoneNumber,
    required String role,
    required String serviceType,
    String? vehiclePlate,
    String? assignedRouteId,
  }) async {
    try {
      await _supabase.from('users').upsert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'role': role,
        'service_type': serviceType,
        'vehicle_plate': vehiclePlate,
        'assigned_route_id': assignedRouteId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Ignored if RLS or network prevents direct upsert; trigger will handle it
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Request password reset email via Supabase Free Tier
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConstants.passwordRecoveryRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> updatePhoneNumber({
    required String userId,
    required String phoneNumber,
  }) async {
    await _supabase
        .from('users')
        .update({
          'phone_number': phoneNumber.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<String> uploadProfilePhoto({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path =
        '$userId/profile-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _supabase.storage
        .from('profile-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    return _supabase.storage.from('profile-photos').getPublicUrl(path);
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) async {
    final metadata = <String, dynamic>{'full_name': fullName.trim()};
    final row = <String, dynamic>{
      'full_name': fullName.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (avatarUrl != null) {
      metadata['avatar_url'] = avatarUrl;
      row['avatar_url'] = avatarUrl;
    }
    await _supabase.from('users').update(row).eq('id', userId);
    await _supabase.auth.updateUser(UserAttributes(data: metadata));
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Fetch user profile from public.users table
  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        return UserProfile.fromJson(data);
      }
    } catch (e) {
      // Return null or fallback
    }

    // Fallback using auth user metadata if database table query is empty
    final user = _supabase.auth.currentUser;
    if (user != null && user.id == userId) {
      final meta = user.userMetadata ?? {};
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: (meta['full_name'] as String?) ?? 'SmartTransit User',
        phoneNumber: (meta['phone_number'] as String?) ?? '',
        role: ((meta['role'] as String?) ?? 'PASSENGER').toUpperCase(),
        serviceType: ((meta['service_type'] as String?) ?? 'PASSENGER')
            .toUpperCase(),
        vehiclePlate: meta['vehicle_plate'] as String?,
        assignedRouteId: meta['assigned_route_id'] as String?,
        avatarUrl: meta['avatar_url'] as String?,
      );
    }
    return null;
  }

  /// Update driver's assigned route or vehicle plate
  Future<void> updateDriverProfile({
    required String userId,
    required String vehiclePlate,
    String? assignedRouteId,
    String? serviceType,
  }) async {
    final updateData = <String, dynamic>{
      'vehicle_plate': vehiclePlate.toUpperCase().trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (assignedRouteId != null) {
      updateData['assigned_route_id'] = assignedRouteId;
    }
    if (serviceType != null) {
      updateData['service_type'] = serviceType.toUpperCase().trim();
    }

    await _supabase.from('users').update(updateData).eq('id', userId);
  }
}
