import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/data/models/api_automobile_for_update.dart';

void main() {
  group('ApiAutomobileForUpdate.toJson', () {
    test('serializes mutable fields', () {
      const dto = ApiAutomobileForUpdate(
        color: 'Red',
        plate: 'XYZ 789',
        meterReading: 50000,
        ownershipStatus: 'Owned',
        isActive: true,
      );

      final json = dto.toJson();

      expect(json['color'], 'Red');
      expect(json['plate'], 'XYZ 789');
      expect(json['meterReading'], 50000);
      expect(json['ownershipStatus'], 'Owned');
      expect(json['isActive'], true);
    });

    test('serializes deactivation correctly', () {
      const dto = ApiAutomobileForUpdate(
        color: 'Silver',
        plate: 'ABC 123',
        meterReading: 45230,
        isActive: false,
      );

      final json = dto.toJson();

      expect(json['isActive'], false);
    });

    test('serializes date fields as ISO 8601', () {
      final dto = ApiAutomobileForUpdate(
        meterReading: 0,
        lastServiceDate: DateTime(2026, 1, 15),
        nextServiceDueDate: DateTime(2026, 7, 15),
        insuranceExpiryDate: DateTime(2027, 1, 1),
        registrationExpiryDate: DateTime(2027, 3, 15),
      );

      final json = dto.toJson();

      expect(json['lastServiceDate'], contains('2026-01-15'));
      expect(json['nextServiceDueDate'], contains('2026-07-15'));
      expect(json['insuranceExpiryDate'], contains('2027-01-01'));
      expect(json['registrationExpiryDate'], contains('2027-03-15'));
    });

    test('omits null date fields', () {
      const dto = ApiAutomobileForUpdate(meterReading: 0);

      final json = dto.toJson();

      expect(json.containsKey('lastServiceDate'), isFalse);
      expect(json.containsKey('nextServiceDueDate'), isFalse);
      expect(json.containsKey('soldDate'), isFalse);
      expect(json.containsKey('insuranceExpiryDate'), isFalse);
      expect(json.containsKey('registrationExpiryDate'), isFalse);
    });
  });
}
