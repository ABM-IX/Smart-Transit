import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/route_model.dart';
import '../models/itinerary_model.dart';

class ApiService {
  String get baseUrl => AppConstants.defaultServerUrl;

  ApiService();

  Future<List<TransitRoute>> fetchRoutes({String? routeType, bool onlyWithRegisteredDrivers = false}) async {
    // 1. Direct Supabase Cloud Query (Primary Single Source of Truth for Real Registered Routes)
    try {
      if (onlyWithRegisteredDrivers) {
        // Query assigned_route_ids of registered drivers
        final driverUsers = await Supabase.instance.client
            .from('users')
            .select('assigned_route_id')
            .eq('role', 'DRIVER')
            .not('assigned_route_id', 'is', null);

        final Set<String> activeRouteIds = {};
        for (final row in driverUsers) {
          final id = row['assigned_route_id']?.toString();
          if (id != null && id.isNotEmpty) {
            activeRouteIds.add(id);
          }
        }

        if (activeRouteIds.isEmpty) {
          return [];
        }

        var query = Supabase.instance.client
            .from('routes')
            .select()
            .inFilter('id', activeRouteIds.toList());

        if (routeType != null) {
          query = query.eq('route_type', routeType.toUpperCase());
        }

        final List<dynamic> records = await query;
        if (records.isNotEmpty) {
          return records.map((json) => TransitRoute.fromJson(json)).toList();
        }
      } else {
        // Fetch all registered corridors from Supabase
        var query = Supabase.instance.client.from('routes').select();
        if (routeType != null) {
          query = query.eq('route_type', routeType.toUpperCase());
        }
        final List<dynamic> records = await query;
        if (records.isNotEmpty) {
          return records.map((json) => TransitRoute.fromJson(json)).toList();
        }
      }
    } catch (_) {
      // Supabase query failed, fall back to backend
    }

    // 2. Secondary Backend Server fallback
    try {
      final uri = Uri.parse('$baseUrl/api/transit/routes').replace(
        queryParameters: {
          if (routeType != null) 'route_type': routeType,
          if (onlyWithRegisteredDrivers) 'has_drivers': 'true',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Exclude any obsolete test subjects / mock dummy routes like 'route-u01', 'route-u02', etc.
          final cleanList = data.map((json) => TransitRoute.fromJson(json)).where((r) {
            final id = r.id.toLowerCase();
            final name = r.name.toLowerCase();
            return !id.startsWith('route-u0') && !name.contains('route u1') && !name.contains('route u2');
          }).toList();
          return cleanList;
        }
      }
    } catch (_) {}

    return [];
  }

  /// Fetch a specific route by its ID from Supabase
  Future<TransitRoute?> fetchRouteById(String routeId) async {
    try {
      final data = await Supabase.instance.client
          .from('routes')
          .select()
          .eq('id', routeId)
          .maybeSingle();
      if (data != null) {
        return TransitRoute.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  Future<List<TransitStop>> fetchStops({String? routeId}) async {
    // 1. Try Primary Backend Server
    try {
      final uri = Uri.parse('$baseUrl/api/transit/stops').replace(
        queryParameters: routeId != null ? {'route_id': routeId} : null,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.map((json) => TransitStop.fromJson(json)).toList();
        }
      }
    } catch (_) {
      // Backend not reached, fall through to Supabase Cloud
    }

    // 2. Direct Supabase Cloud Query
    try {
      var query = Supabase.instance.client.from('stops').select();
      if (routeId != null) {
        query = query.eq('route_id', routeId);
      }
      final List<dynamic> records = await query;
      if (records.isNotEmpty) {
        return records.map((json) => TransitStop.fromJson(json)).toList();
      }
    } catch (_) {
      // Direct query failed
    }

    // No static dummy stops — return empty if none exist in database
    return [];
  }

  Future<ItineraryModel?> planAiJourney({
    required String passengerId,
    required String originName,
    required double originLat,
    required double originLng,
    required String destName,
    required double destLat,
    required double destLng,
    String? desiredArrivalTime,
  }) async {
    final body = jsonEncode({
      'passenger_id': passengerId,
      'origin': {'name': originName, 'lat': originLat, 'lng': originLng},
      'destination': {'name': destName, 'lat': destLat, 'lng': destLng},
      'desired_arrival_time': desiredArrivalTime,
    });

    // 1. Primary Live Backend Dispatch AI
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/transit/plan-journey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return ItineraryModel.fromJson(jsonDecode(response.body));
      }
    } catch (_) {
      // Backend not reached, fall through to Edge Function
    }

    // 2. Supabase Edge Function Fallback
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/functions/v1/plan-journey'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConstants.supabasePublishableKey,
          'Authorization': 'Bearer ${AppConstants.supabasePublishableKey}',
        },
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return ItineraryModel.fromJson(jsonDecode(response.body));
      }
    } catch (_) {
      // Edge Function failed
    }

    // Return null if no live journey planner response (no static dummy fallback)
    return null;
  }
}
