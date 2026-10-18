import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceNameService {
  static Future<String?> reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'zoom': '16',
        'addressdetails': '1',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': 'SmartTransit-App'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address != null) {
        for (final key in [
          'neighbourhood',
          'suburb',
          'village',
          'town',
          'city',
          'municipality',
          'county',
        ]) {
          final value = address[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      }
      final displayName = data['display_name']?.toString();
      return displayName?.split(',').first.trim();
    } catch (_) {
      return null;
    }
  }
}
