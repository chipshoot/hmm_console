import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/validators/automobile_validator.dart';

class _TestValidator with AutomobileValidator {}

void main() {
  late _TestValidator validator;

  setUp(() => validator = _TestValidator());

  group('validateVin', () {
    test('returns error for null', () {
      expect(validator.validateVin(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateVin(''), isNotNull);
    });

    test('returns error for too short', () {
      expect(validator.validateVin('1HGBH41'), isNotNull);
    });

    test('returns error for too long', () {
      expect(validator.validateVin('1HGBH41JXMN1091860'), isNotNull);
    });

    test('returns null for exactly 17 characters', () {
      expect(validator.validateVin('1HGBH41JXMN109186'), isNull);
    });
  });

  group('validateMaker', () {
    test('returns error for null', () {
      expect(validator.validateMaker(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateMaker(''), isNotNull);
    });

    test('returns error for over 50 characters', () {
      expect(validator.validateMaker('A' * 51), isNotNull);
    });

    test('returns null for valid maker', () {
      expect(validator.validateMaker('Toyota'), isNull);
    });
  });

  group('validateBrand', () {
    test('returns error for null', () {
      expect(validator.validateBrand(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateBrand(''), isNotNull);
    });

    test('returns error for over 50 characters', () {
      expect(validator.validateBrand('B' * 51), isNotNull);
    });

    test('returns null for valid brand', () {
      expect(validator.validateBrand('Toyota'), isNull);
    });
  });

  group('validateModel', () {
    test('returns error for null', () {
      expect(validator.validateModel(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateModel(''), isNotNull);
    });

    test('returns error for over 50 characters', () {
      expect(validator.validateModel('M' * 51), isNotNull);
    });

    test('returns null for valid model', () {
      expect(validator.validateModel('Camry'), isNull);
    });
  });

  group('validatePlate', () {
    test('returns error for null', () {
      expect(validator.validatePlate(null), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validatePlate(''), isNotNull);
    });

    test('returns error for over 20 characters', () {
      expect(validator.validatePlate('P' * 21), isNotNull);
    });

    test('returns null for valid plate', () {
      expect(validator.validatePlate('ABC 123'), isNull);
    });
  });

  group('validateYear', () {
    test('returns error for null (required)', () {
      expect(validator.validateYear(null), isNotNull);
    });

    test('returns error for empty string (required)', () {
      expect(validator.validateYear(''), isNotNull);
    });

    test('returns error for non-numeric', () {
      expect(validator.validateYear('abc'), isNotNull);
    });

    test('returns error for year below 1900', () {
      expect(validator.validateYear('1899'), isNotNull);
    });

    test('returns error for year above 2100', () {
      expect(validator.validateYear('2101'), isNotNull);
    });

    test('returns null for valid year', () {
      expect(validator.validateYear('2024'), isNull);
    });

    test('returns null for boundary year 1900', () {
      expect(validator.validateYear('1900'), isNull);
    });

    test('returns null for boundary year 2100', () {
      expect(validator.validateYear('2100'), isNull);
    });
  });

  group('validateMeterReading', () {
    test('returns null for null (optional)', () {
      expect(validator.validateMeterReading(null), isNull);
    });

    test('returns null for empty string (optional)', () {
      expect(validator.validateMeterReading(''), isNull);
    });

    test('returns error for non-numeric', () {
      expect(validator.validateMeterReading('abc'), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validateMeterReading('-1'), isNotNull);
    });

    test('returns null for zero', () {
      expect(validator.validateMeterReading('0'), isNull);
    });

    test('returns null for valid reading', () {
      expect(validator.validateMeterReading('45230'), isNull);
    });
  });
}
