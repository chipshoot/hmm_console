import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/data/models/api_automobile_for_create.dart';

void main() {
  group('ApiAutomobileForCreate.toJson', () {
    test('serializes all required fields', () {
      const dto = ApiAutomobileForCreate(
        vin: '1HGBH41JXMN109186',
        maker: 'Toyota',
        brand: 'Toyota',
        model: 'Camry',
        plate: 'ABC 123',
        engineType: 'Gasoline',
        fuelType: 'Regular',
      );

      final json = dto.toJson();

      expect(json['vin'], '1HGBH41JXMN109186');
      expect(json['maker'], 'Toyota');
      expect(json['brand'], 'Toyota');
      expect(json['model'], 'Camry');
      expect(json['plate'], 'ABC 123');
      expect(json['engineType'], 'Gasoline');
      expect(json['fuelType'], 'Regular');
      expect(json['year'], 0);
      expect(json['meterReading'], 0);
      expect(json['ownershipStatus'], 'Owned');
    });

    test('omits null optional fields', () {
      const dto = ApiAutomobileForCreate(
        vin: '1HGBH41JXMN109186',
        maker: 'Toyota',
        brand: 'Toyota',
        model: 'Camry',
        plate: 'ABC 123',
        engineType: 'Gasoline',
        fuelType: 'Regular',
      );

      final json = dto.toJson();

      expect(json.containsKey('trim'), isFalse);
      expect(json.containsKey('color'), isFalse);
      expect(json.containsKey('purchaseDate'), isFalse);
      expect(json.containsKey('purchasePrice'), isFalse);
      expect(json.containsKey('notes'), isFalse);
    });

    test('includes optional fields when set', () {
      final dto = ApiAutomobileForCreate(
        vin: '1HGBH41JXMN109186',
        maker: 'Toyota',
        brand: 'Toyota',
        model: 'Camry',
        plate: 'ABC 123',
        engineType: 'Gasoline',
        fuelType: 'Regular',
        trim: 'LE',
        color: 'Silver',
        year: 2024,
        purchaseDate: DateTime(2024, 1, 15),
        purchasePrice: 28000.0,
        notes: 'New car',
      );

      final json = dto.toJson();

      expect(json['trim'], 'LE');
      expect(json['color'], 'Silver');
      expect(json['year'], 2024);
      expect(json['purchaseDate'], contains('2024-01-15'));
      expect(json['purchasePrice'], 28000.0);
      expect(json['notes'], 'New car');
    });
  });
}
