import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_transit_app/providers/transit_provider.dart';
import 'package:smart_transit_app/services/place_name_service.dart';

void main() {
  group('PlaceNameService locality & generic name handling', () {
    test('rejects generic pickup strings like Current location', () {
      expect(PlaceNameService.isGenericLocationName('Current location'), isTrue);
      expect(PlaceNameService.isGenericLocationName('current location'), isTrue);
      expect(PlaceNameService.isGenericLocationName('Pickup Point'), isTrue);
      expect(PlaceNameService.isGenericLocationName('Tlokweng'), isFalse);
      expect(
        PlaceNameService.sanitizeLocationName('Current location'),
        isNull,
      );
      expect(
        PlaceNameService.sanitizeLocationName('Tlokweng'),
        equals('Tlokweng'),
      );
    });

    test('resolves Tlokweng coordinates to Tlokweng instead of Current location', () async {
      const tlokwengCoords = LatLng(-24.6685, 25.9750);
      final resolved = await PlaceNameService.resolvePlaceName(
        tlokwengCoords,
        preferredName: 'Current location',
      );
      expect(resolved.toLowerCase(), contains('tlokweng'));
      expect(
        PlaceNameService.isGenericLocationName(resolved),
        isFalse,
      );
    });
  });

  group('TransitProvider trip lifecycle & session reset', () {
    test('resetPassengerTrip clears session state and increments tripResetVersion', () {
      final provider = TransitProvider();
      final initialResetVersion = provider.tripResetVersion;

      provider.resetPassengerTrip();

      expect(provider.passengerStatus, equals(PassengerTripStatus.idle));
      expect(provider.assignedDriverId, isNull);
      expect(provider.etaSeconds, isNull);
      expect(provider.etaDistanceMeters, isNull);
      expect(provider.taxiPickupName, isNull);
      expect(provider.taxiDestinationName, isNull);
      expect(provider.tripResetVersion, equals(initialResetVersion + 1));
    });
  });
}
