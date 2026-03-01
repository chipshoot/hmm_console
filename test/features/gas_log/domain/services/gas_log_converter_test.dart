import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/domain/services/gas_log_converter.dart';
import 'package:hmm_console/features/settings/domain/gas_log_settings.dart';
import 'package:hmm_console/features/settings/domain/gas_log_units.dart';

void main() {
  group('GasLogConversion', () {
    final baseGasLog = GasLog(
      id: 1,
      date: DateTime(2025, 6, 15),
      automobileId: 10,
      odometer: 10000,
      odometerUnit: 'Mile',
      distance: 300,
      distanceUnit: 'Mile',
      fuel: 10,
      fuelUnit: 'Gallon',
      fuelGrade: 'Regular',
      totalPrice: 50.0,
      unitPrice: 5.0,
      currency: 'CAD',
      fuelEfficiency: 30.0,
      stationName: 'Shell',
    );

    test('same units returns values unchanged', () {
      const settings = GasLogSettings(
        distanceUnit: DistanceUnit.mile,
        fuelUnit: FuelUnit.gallon,
        currency: CurrencyCode.cad,
      );

      final dm = baseGasLog.toDisplayModel(settings);

      expect(dm.odometer, 10000);
      expect(dm.distance, 300);
      expect(dm.fuel, 10);
      expect(dm.totalPrice, 50.0);
      expect(dm.unitPrice, 5.0);
      expect(dm.fuelEfficiency, 30.0);
      expect(dm.distanceLabel, 'mi');
      expect(dm.fuelLabel, 'gal');
      expect(dm.currencySymbol, r'$');
      expect(dm.stationName, 'Shell');
      expect(dm.original, same(baseGasLog));
    });

    test('miles to kilometers converts distance fields', () {
      const settings = GasLogSettings(
        distanceUnit: DistanceUnit.kilometer,
        fuelUnit: FuelUnit.gallon,
        currency: CurrencyCode.cad,
      );

      final dm = baseGasLog.toDisplayModel(settings);

      expect(dm.odometer, closeTo(16093.44, 0.01));
      expect(dm.distance, closeTo(482.80, 0.01));
      expect(dm.fuel, 10); // unchanged — same fuel unit
      expect(dm.distanceLabel, 'km');
    });

    test('gallons to liters converts fuel', () {
      const settings = GasLogSettings(
        distanceUnit: DistanceUnit.mile,
        fuelUnit: FuelUnit.liter,
        currency: CurrencyCode.cad,
      );

      final dm = baseGasLog.toDisplayModel(settings);

      expect(dm.fuel, closeTo(37.854, 0.001));
      expect(dm.odometer, 10000); // unchanged
      expect(dm.fuelLabel, 'L');
    });

    test('exchange rate applied to price fields', () {
      const settings = GasLogSettings(
        distanceUnit: DistanceUnit.mile,
        fuelUnit: FuelUnit.gallon,
        currency: CurrencyCode.usd,
      );

      final dm = baseGasLog.toDisplayModel(settings, exchangeRate: 0.75);

      expect(dm.totalPrice, closeTo(37.50, 0.01));
      expect(dm.unitPrice, closeTo(3.75, 0.01));
    });

    test('full conversion: miles/gallons/CAD to km/L/CNY', () {
      const settings = GasLogSettings(
        distanceUnit: DistanceUnit.kilometer,
        fuelUnit: FuelUnit.liter,
        currency: CurrencyCode.cny,
      );

      final dm = baseGasLog.toDisplayModel(settings, exchangeRate: 5.2);

      expect(dm.odometer, closeTo(16093.44, 0.01));
      expect(dm.distance, closeTo(482.80, 0.01));
      expect(dm.fuel, closeTo(37.854, 0.001));
      expect(dm.totalPrice, closeTo(260.0, 0.01));
      expect(dm.unitPrice, closeTo(26.0, 0.01));
      expect(dm.fuelEfficiency, closeTo(12.754, 0.01));
      expect(dm.distanceLabel, 'km');
      expect(dm.fuelLabel, 'L');
      expect(dm.currencySymbol, '\u00a5');
    });

    test('retains original gas log reference', () {
      const settings = GasLogSettings();
      final dm = baseGasLog.toDisplayModel(settings);
      expect(dm.original.id, 1);
      expect(dm.date, DateTime(2025, 6, 15));
    });
  });
}
