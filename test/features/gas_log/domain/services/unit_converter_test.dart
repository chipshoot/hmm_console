import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/services/unit_converter.dart';

void main() {
  group('UnitConverter', () {
    group('convertDistance', () {
      test('same unit returns value unchanged', () {
        expect(UnitConverter.convertDistance(100, 'Mile', 'Mile'), 100);
        expect(UnitConverter.convertDistance(100, 'Kilometer', 'Kilometer'), 100);
      });

      test('miles to kilometers', () {
        final result = UnitConverter.convertDistance(100, 'Mile', 'Kilometer');
        expect(result, closeTo(160.9344, 0.0001));
      });

      test('kilometers to miles', () {
        final result = UnitConverter.convertDistance(100, 'Kilometer', 'Mile');
        expect(result, closeTo(62.1371, 0.0001));
      });

      test('handles Kilometre spelling', () {
        final result = UnitConverter.convertDistance(100, 'Mile', 'Kilometre');
        expect(result, closeTo(160.9344, 0.0001));
      });
    });

    group('convertVolume', () {
      test('same unit returns value unchanged', () {
        expect(UnitConverter.convertVolume(10, 'Gallon', 'Gallon'), 10);
        expect(UnitConverter.convertVolume(10, 'Liter', 'Liter'), 10);
      });

      test('gallons to liters', () {
        final result = UnitConverter.convertVolume(10, 'Gallon', 'Liter');
        expect(result, closeTo(37.8541, 0.0001));
      });

      test('liters to gallons', () {
        final result = UnitConverter.convertVolume(10, 'Liter', 'Gallon');
        expect(result, closeTo(2.6417, 0.0001));
      });
    });

    group('convertFuelEfficiency', () {
      test('same units returns value unchanged', () {
        final result = UnitConverter.convertFuelEfficiency(
          30, 'Mile', 'Mile', 'Gallon', 'Gallon',
        );
        expect(result, 30);
      });

      test('mi/gal to km/L', () {
        // 30 mpg = 30 * (1.609344 / 3.785411784) km/L ≈ 12.754
        final result = UnitConverter.convertFuelEfficiency(
          30, 'Mile', 'Kilometer', 'Gallon', 'Liter',
        );
        expect(result, closeTo(12.754, 0.001));
      });

      test('km/L to mi/gal', () {
        // 12.754 km/L back to mpg ≈ 30
        final result = UnitConverter.convertFuelEfficiency(
          12.754, 'Kilometer', 'Mile', 'Liter', 'Gallon',
        );
        expect(result, closeTo(30, 0.01));
      });
    });

    group('convertCurrency', () {
      test('applies exchange rate', () {
        expect(UnitConverter.convertCurrency(100, 1.5), 150);
      });

      test('rate of 1.0 returns value unchanged', () {
        expect(UnitConverter.convertCurrency(42.50, 1.0), 42.50);
      });
    });
  });
}
