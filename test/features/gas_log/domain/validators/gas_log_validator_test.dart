import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/features/gas_log/domain/validators/gas_log_validator.dart';

class _TestValidator with GasLogValidator {}

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

  group('validateOdometer', () {
    test('returns error for null', () {
      expect(validator.validateOdometer(null, l), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateOdometer('', l), isNotNull);
    });

    test('returns error for non-numeric input', () {
      expect(validator.validateOdometer('abc', l), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validateOdometer('-5', l), isNotNull);
    });

    test('returns null for valid positive value', () {
      expect(validator.validateOdometer('45230', l), isNull);
    });

    test('returns null for zero', () {
      expect(validator.validateOdometer('0', l), isNull);
    });

    test('returns null for decimal value', () {
      expect(validator.validateOdometer('12345.5', l), isNull);
    });
  });

  group('validateFuel', () {
    test('returns error for null', () {
      expect(validator.validateFuel(null, l), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validateFuel('', l), isNotNull);
    });

    test('returns error for zero', () {
      expect(validator.validateFuel('0', l), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validateFuel('-1', l), isNotNull);
    });

    test('returns null for valid positive value', () {
      expect(validator.validateFuel('42.3', l), isNull);
    });
  });

  group('validatePrice', () {
    test('returns error for null', () {
      expect(validator.validatePrice(null, l), isNotNull);
    });

    test('returns error for empty string', () {
      expect(validator.validatePrice('', l), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validatePrice('-3.89', l), isNotNull);
    });

    test('returns null for zero (free gas!)', () {
      expect(validator.validatePrice('0', l), isNull);
    });

    test('returns null for valid price', () {
      expect(validator.validatePrice('3.89', l), isNull);
    });
  });

  group('validateDistance', () {
    test('returns null for null (optional field)', () {
      expect(validator.validateDistance(null, l), isNull);
    });

    test('returns null for empty string (optional field)', () {
      expect(validator.validateDistance('', l), isNull);
    });

    test('returns error for non-numeric', () {
      expect(validator.validateDistance('abc', l), isNotNull);
    });

    test('returns error for negative value', () {
      expect(validator.validateDistance('-10', l), isNotNull);
    });

    test('returns null for valid distance', () {
      expect(validator.validateDistance('320.5', l), isNull);
    });

    test('returns null for zero distance', () {
      expect(validator.validateDistance('0', l), isNull);
    });
  });
}
