import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/features/gas_log/domain/validators/automobile_validator.dart';

class _TestValidator with AutomobileValidator {}

void main() {
  late _TestValidator validator;

  late AppLocalizations l;

  setUp(() async {
    validator = _TestValidator();
    // A real AppLocalizations, not a stub: these assertions only check
    // that a message is returned, so a stub returning '' would let an
    // empty or missing translation pass silently.
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('validateVin', () {
    test('returns error for null', () {
      expect(validator.validateVin(null, l), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateVin('', l), isNotNull);
    });

    test('returns error for too short', () {
      expect(validator.validateVin('1HGBH41', l), isNotNull);
    });

    test('returns error for too long', () {
      expect(validator.validateVin('1HGBH41JXMN1091860', l), isNotNull);
    });

    test('returns null for exactly 17 characters', () {
      expect(validator.validateVin('1HGBH41JXMN109186', l), isNull);
    });
  });

  group('validateMaker', () {
    test('returns error for null', () {
      expect(validator.validateMaker(null, l), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateMaker('', l), isNotNull);
    });

    test('returns error for over 50 characters', () {
      expect(validator.validateMaker('A' * 51, l), isNotNull);
    });

    test('returns null for valid maker', () {
      expect(validator.validateMaker('Toyota', l), isNull);
    });
  });

  group('validateBrand', () {
    test('returns error for null', () {
      expect(validator.validateBrand(null, l), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateBrand('', l), isNotNull);
    });

    test('returns error for over 50 characters', () {
      expect(validator.validateBrand('B' * 51, l), isNotNull);
    });

    test('returns null for valid brand', () {
      expect(validator.validateBrand('Toyota', l), isNull);
    });
  });

  group('validateModel', () {
    test('returns error for null', () {
      expect(validator.validateModel(null, l), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateModel('', l), isNotNull);
    });

    test('returns error for over 50 characters', () {
      expect(validator.validateModel('M' * 51, l), isNotNull);
    });

    test('returns null for valid model', () {
      expect(validator.validateModel('Camry', l), isNull);
    });
  });

  group('validatePlate', () {
    test('returns error for null', () {
      expect(validator.validatePlate(null, l), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validatePlate('', l), isNotNull);
    });

    test('returns error for over 20 characters', () {
      expect(validator.validatePlate('P' * 21, l), isNotNull);
    });

    test('returns null for valid plate', () {
      expect(validator.validatePlate('ABC 123', l), isNull);
    });
  });

  group('validateYear', () {
    test('returns error for null (required)', () {
      expect(validator.validateYear(null, l), isNotNull);
    });

    test('returns error for empty string (required)', () {
      expect(validator.validateYear('', l), isNotNull);
    });

    test('returns error for non-numeric', () {
      expect(validator.validateYear('abc', l), isNotNull);
    });

    test('returns error for year below 1900', () {
      expect(validator.validateYear('1899', l), isNotNull);
    });

    test('returns error for year above 2100', () {
      expect(validator.validateYear('2101', l), isNotNull);
    });

    test('returns null for valid year', () {
      expect(validator.validateYear('2024', l), isNull);
    });

    test('returns null for boundary year 1900', () {
      expect(validator.validateYear('1900', l), isNull);
    });

    test('returns null for boundary year 2100', () {
      expect(validator.validateYear('2100', l), isNull);
    });
  });

  group('validateMeterReading', () {
    test('returns null for null (optional)', () {
      expect(validator.validateMeterReading(null, l), isNull);
    });

    test('returns null for empty string (optional)', () {
      expect(validator.validateMeterReading('', l), isNull);
    });

    test('returns error for non-numeric', () {
      expect(validator.validateMeterReading('abc', l), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validateMeterReading('-1', l), isNotNull);
    });

    test('returns null for zero', () {
      expect(validator.validateMeterReading('0', l), isNull);
    });

    test('returns null for valid reading', () {
      expect(validator.validateMeterReading('45230', l), isNull);
    });
  });
}
