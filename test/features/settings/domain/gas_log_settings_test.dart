import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/domain/gas_log_settings.dart';
import 'package:hmm_console/features/settings/domain/gas_log_units.dart';

void main() {
  group('GasLogSettings', () {
    test('default constructor uses imperial + CAD', () {
      const settings = GasLogSettings();

      expect(settings.distanceUnit, DistanceUnit.mile);
      expect(settings.fuelUnit, FuelUnit.gallon);
      expect(settings.currency, CurrencyCode.cad);
    });

    test('constructor accepts custom values', () {
      const settings = GasLogSettings(
        distanceUnit: DistanceUnit.kilometer,
        fuelUnit: FuelUnit.liter,
        currency: CurrencyCode.cny,
      );

      expect(settings.distanceUnit, DistanceUnit.kilometer);
      expect(settings.fuelUnit, FuelUnit.liter);
      expect(settings.currency, CurrencyCode.cny);
    });

    group('copyWith', () {
      test('returns new instance with updated distanceUnit', () {
        const original = GasLogSettings();
        final updated = original.copyWith(distanceUnit: DistanceUnit.kilometer);

        expect(updated.distanceUnit, DistanceUnit.kilometer);
        expect(updated.fuelUnit, FuelUnit.gallon);
        expect(updated.currency, CurrencyCode.cad);
      });

      test('returns new instance with updated fuelUnit', () {
        const original = GasLogSettings();
        final updated = original.copyWith(fuelUnit: FuelUnit.liter);

        expect(updated.distanceUnit, DistanceUnit.mile);
        expect(updated.fuelUnit, FuelUnit.liter);
        expect(updated.currency, CurrencyCode.cad);
      });

      test('returns new instance with updated currency', () {
        const original = GasLogSettings();
        final updated = original.copyWith(currency: CurrencyCode.usd);

        expect(updated.distanceUnit, DistanceUnit.mile);
        expect(updated.fuelUnit, FuelUnit.gallon);
        expect(updated.currency, CurrencyCode.usd);
      });

      test('returns identical when no arguments passed', () {
        const original = GasLogSettings(
          distanceUnit: DistanceUnit.kilometer,
          fuelUnit: FuelUnit.liter,
          currency: CurrencyCode.cny,
        );
        final copy = original.copyWith();

        expect(copy.distanceUnit, original.distanceUnit);
        expect(copy.fuelUnit, original.fuelUnit);
        expect(copy.currency, original.currency);
      });
    });

    group('JSON serialization', () {
      test('toJson produces correct map', () {
        const settings = GasLogSettings(
          distanceUnit: DistanceUnit.kilometer,
          fuelUnit: FuelUnit.liter,
          currency: CurrencyCode.cny,
        );

        expect(settings.toJson(), {
          'distanceUnit': 'Kilometer',
          'fuelUnit': 'Liter',
          'currency': 'CNY',
        });
      });

      test('fromJson restores settings', () {
        final json = {
          'distanceUnit': 'Kilometer',
          'fuelUnit': 'Liter',
          'currency': 'USD',
        };

        final settings = GasLogSettings.fromJson(json);

        expect(settings.distanceUnit, DistanceUnit.kilometer);
        expect(settings.fuelUnit, FuelUnit.liter);
        expect(settings.currency, CurrencyCode.usd);
      });

      test('toJson/fromJson round-trip preserves values', () {
        const original = GasLogSettings(
          distanceUnit: DistanceUnit.kilometer,
          fuelUnit: FuelUnit.liter,
          currency: CurrencyCode.cny,
        );

        final restored = GasLogSettings.fromJson(original.toJson());

        expect(restored.distanceUnit, original.distanceUnit);
        expect(restored.fuelUnit, original.fuelUnit);
        expect(restored.currency, original.currency);
      });

      test('toJsonString produces valid JSON', () {
        const settings = GasLogSettings();
        final jsonStr = settings.toJsonString();
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

        expect(decoded['distanceUnit'], 'Mile');
        expect(decoded['fuelUnit'], 'Gallon');
        expect(decoded['currency'], 'CAD');
      });

      test('fromJsonString restores settings', () {
        final jsonStr = jsonEncode({
          'distanceUnit': 'Mile',
          'fuelUnit': 'Gallon',
          'currency': 'CAD',
        });

        final settings = GasLogSettings.fromJsonString(jsonStr);

        expect(settings.distanceUnit, DistanceUnit.mile);
        expect(settings.fuelUnit, FuelUnit.gallon);
        expect(settings.currency, CurrencyCode.cad);
      });

      test('toJsonString/fromJsonString round-trip preserves values', () {
        const original = GasLogSettings(
          distanceUnit: DistanceUnit.mile,
          fuelUnit: FuelUnit.liter,
          currency: CurrencyCode.usd,
        );

        final restored = GasLogSettings.fromJsonString(original.toJsonString());

        expect(restored.distanceUnit, original.distanceUnit);
        expect(restored.fuelUnit, original.fuelUnit);
        expect(restored.currency, original.currency);
      });
    });
  });
}
