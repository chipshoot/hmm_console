import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/validators/gas_log_validator.dart';

class _TestValidator with GasLogValidator {}

void main() {
  late _TestValidator validator;

  setUp(() => validator = _TestValidator());

  group('validateOdometer', () {
    test('returns error for null', () {
      expect(validator.validateOdometer(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateOdometer(''), isNotNull);
    });

    test('returns error for non-numeric input', () {
      expect(validator.validateOdometer('abc'), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validateOdometer('-5'), isNotNull);
    });

    test('returns null for valid positive value', () {
      expect(validator.validateOdometer('45230'), isNull);
    });

    test('returns null for zero', () {
      expect(validator.validateOdometer('0'), isNull);
    });

    test('returns null for decimal value', () {
      expect(validator.validateOdometer('12345.5'), isNull);
    });
  });

  group('validateFuel', () {
    test('returns error for null', () {
      expect(validator.validateFuel(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateFuel(''), isNotNull);
    });

    test('returns error for zero', () {
      expect(validator.validateFuel('0'), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validateFuel('-1'), isNotNull);
    });

    test('returns null for valid positive value', () {
      expect(validator.validateFuel('42.3'), isNull);
    });
  });

  group('validatePrice', () {
    test('returns error for null', () {
      expect(validator.validatePrice(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validatePrice(''), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validatePrice('-3.89'), isNotNull);
    });

    test('returns null for zero (free gas!)', () {
      expect(validator.validatePrice('0'), isNull);
    });

    test('returns null for valid price', () {
      expect(validator.validatePrice('3.89'), isNull);
    });
  });

  group('validateDistance', () {
    test('returns null for null (optional field)', () {
      expect(validator.validateDistance(null), isNull);
    });

    test('returns null for empty string (optional field)', () {
      expect(validator.validateDistance(''), isNull);
    });

    test('returns error for non-numeric', () {
      expect(validator.validateDistance('abc'), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validateDistance('-10'), isNotNull);
    });

    test('returns null for valid distance', () {
      expect(validator.validateDistance('320.5'), isNull);
    });

    test('returns null for zero distance', () {
      expect(validator.validateDistance('0'), isNull);
    });
  });
}
