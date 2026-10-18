import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class _LocalityEntry {
  final String name;
  final LatLng center;
  final double radiusKm;

  const _LocalityEntry(this.name, this.center, this.radiusKm);
}

class PlaceNameService {
  static final Map<String, String> _cache = {};

  static const Set<String> _genericNames = {
    'current location',
    'my location',
    'pickup point',
    'pickup stop',
    'passenger pickup',
    'finding place…',
    'finding place...',
    'unnamed road',
    'unknown',
    'location',
  };

  /// Known Greater Gaborone & surrounding Botswana localities so that even when
  /// a user is in an area without a specific street/landmark (e.g. Tlokweng)
  /// or Nominatim is slow/unreachable, we resolve to the true locality name.
  static const List<_LocalityEntry> _knownLocalities = [
    _LocalityEntry('Tlokweng Border Gate', LatLng(-24.6753, 26.0172), 1.8),
    _LocalityEntry('Tlokweng', LatLng(-24.6685, 25.9750), 6.5),
    _LocalityEntry('Riverwalk', LatLng(-24.6746, 25.9482), 1.2),
    _LocalityEntry('Village', LatLng(-24.6650, 25.9420), 1.5),
    _LocalityEntry('Main Mall', LatLng(-24.6581, 25.9122), 1.2),
    _LocalityEntry('Gaborone Station', LatLng(-24.6633, 25.9044), 1.2),
    _LocalityEntry('Bontleng', LatLng(-24.6720, 25.9140), 1.2),
    _LocalityEntry('Old Naledi', LatLng(-24.6880, 25.9080), 1.8),
    _LocalityEntry('Extension 9', LatLng(-24.6520, 25.9250), 1.2),
    _LocalityEntry('Extension 12', LatLng(-24.6460, 25.9220), 1.2),
    _LocalityEntry('Maruapula', LatLng(-24.6400, 25.9320), 1.5),
    _LocalityEntry('Broadhurst', LatLng(-24.6267, 25.9231), 2.5),
    _LocalityEntry('Tsholofelo', LatLng(-24.6220, 25.9380), 1.8),
    _LocalityEntry('Game City', LatLng(-24.6897, 25.8808), 1.8),
    _LocalityEntry('Gaborone West', LatLng(-24.6675, 25.8850), 2.5),
    _LocalityEntry('Phase 2', LatLng(-24.6480, 25.9010), 1.3),
    _LocalityEntry('Phase 4', LatLng(-24.6620, 25.8720), 1.5),
    _LocalityEntry('Block 3', LatLng(-24.6390, 25.9010), 1.5),
    _LocalityEntry('Block 6', LatLng(-24.6250, 25.8930), 1.8),
    _LocalityEntry('Block 7', LatLng(-24.6420, 25.8820), 1.5),
    _LocalityEntry('Block 8', LatLng(-24.6150, 25.8880), 1.8),
    _LocalityEntry('Block 9', LatLng(-24.6520, 25.8750), 1.5),
    _LocalityEntry('Block 10', LatLng(-24.6020, 25.9150), 1.8),
    _LocalityEntry('Mogoditshane', LatLng(-24.6269, 25.8656), 4.5),
    _LocalityEntry('Phakalane', LatLng(-24.5670, 25.9720), 4.0),
    _LocalityEntry('Gabane', LatLng(-24.6667, 25.7833), 4.0),
    _LocalityEntry('Mmopane', LatLng(-24.5667, 25.8667), 4.0),
    _LocalityEntry('Metsimotlhabe', LatLng(-24.5550, 25.8150), 3.5),
    _LocalityEntry('Oodi', LatLng(-24.5680, 26.0350), 4.0),
    _LocalityEntry('Ramotswa', LatLng(-24.8719, 25.8699), 5.0),
    _LocalityEntry('Gaborone', LatLng(-24.6541, 25.9087), 15.0),
  ];

  static bool isGenericLocationName(String? value) {
    if (value == null) return true;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return _genericNames.contains(normalized);
  }

  static String? sanitizeLocationName(String? value) {
    if (isGenericLocationName(value)) return null;
    return value!.trim();
  }

  static String? _nearestLocalityFallback(LatLng point) {
    const distance = Distance();
    _LocalityEntry? bestMatch;
    double bestRatio = double.infinity;

    for (final entry in _knownLocalities) {
      final km = distance.as(LengthUnit.Kilometer, point, entry.center);
      if (km <= entry.radiusKm) {
        final ratio = km / entry.radiusKm;
        if (ratio < bestRatio) {
          bestRatio = ratio;
          bestMatch = entry;
        }
      }
    }
    return bestMatch?.name;
  }

  static Future<String> resolvePlaceName(
    LatLng point, {
    String? preferredName,
  }) async {
    final cleanPreferred = sanitizeLocationName(preferredName);
    if (cleanPreferred != null) return cleanPreferred;
    final resolved = await reverseGeocode(point);
    if (resolved != null && !isGenericLocationName(resolved)) {
      return resolved;
    }
    return _nearestLocalityFallback(point) ?? 'Gaborone';
  }

  static Future<String?> reverseGeocode(LatLng point) async {
    final cacheKey =
        '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
    final cached = _cache[cacheKey];
    if (cached != null && !isGenericLocationName(cached)) {
      return cached;
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': 'SmartTransit-Botswana-App/1.0'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        String? landmark;
        String? locality;

        if (address != null) {
          for (final key in [
            'amenity',
            'shop',
            'tourism',
            'building',
            'office',
            'leisure',
          ]) {
            final val = sanitizeLocationName(address[key]?.toString());
            if (val != null) {
              landmark = val;
              break;
            }
          }

          for (final key in [
            'suburb',
            'village',
            'neighbourhood',
            'locality',
            'hamlet',
            'city_district',
            'town',
            'municipality',
            'city',
            'district',
            'state_district',
            'county',
          ]) {
            final val = sanitizeLocationName(address[key]?.toString());
            if (val != null &&
                !val.toLowerCase().contains('district') &&
                val.toLowerCase() != 'botswana') {
              locality = val;
              break;
            }
          }
        }

        String? result;
        if (landmark != null && locality != null && landmark != locality) {
          result = '$landmark, $locality';
        } else if (locality != null) {
          result = locality;
        } else if (landmark != null) {
          result = landmark;
        } else {
          final rawName = sanitizeLocationName(data['name']?.toString());
          if (rawName != null) {
            result = rawName;
          } else {
            final displayName = data['display_name']?.toString();
            final firstPart =
                sanitizeLocationName(displayName?.split(',').first);
            if (firstPart != null &&
                !firstPart.toLowerCase().contains('district')) {
              result = firstPart;
            }
          }
        }

        if (result != null && !isGenericLocationName(result)) {
          _cache[cacheKey] = result;
          return result;
        }
      }
    } catch (_) {
      // Fall through to local locality lookup
    }

    final fallback = _nearestLocalityFallback(point);
    if (fallback != null) {
      _cache[cacheKey] = fallback;
      return fallback;
    }
    return null;
  }
}

