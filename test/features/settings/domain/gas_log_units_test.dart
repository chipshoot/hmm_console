import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/domain/gas_log_units.dart';

void main() {
  group('DistanceUnit', () {
    test('mile has correct apiValue', () {
      expect(DistanceUnit.mile.apiValue, 'Mile');
    });

    test('kilometer has correct apiValue', () {
      expect(DistanceUnit.kilometer.apiValue, 'Kilometer');
    });

    test('mile has correct label', () {
      expect(DistanceUnit.mile.label, 'mi');
    });

    test('kilometer has correct label', () {
      expect(DistanceUnit.kilometer.label, 'km');
    });

    test('displayName matches apiValue', () {
      for (final unit in DistanceUnit.values) {
        expect(unit.displayName, unit.apiValue);
      }
    });

    test('fromApiValue returns mile for Mile', () {
      expect(DistanceUnit.fromApiValue('Mile'), DistanceUnit.mile);
    });

    test('fromApiValue returns kilometer for Kilometer', () {
      expect(DistanceUnit.fromApiValue('Kilometer'), DistanceUnit.kilometer);
    });

    test('fromApiValue defaults to mile for unknown value', () {
      expect(DistanceUnit.fromApiValue('unknown'), DistanceUnit.mile);
    });
  });

  group('FuelUnit', () {
    test('gallon has correct apiValue', () {
      expect(FuelUnit.gallon.apiValue, 'Gallon');
    });

    test('liter has correct apiValue', () {
      expect(FuelUnit.liter.apiValue, 'Liter');
    });

    test('gallon has correct label', () {
      expect(FuelUnit.gallon.label, 'gal');
    });

    test('liter has correct label', () {
      expect(FuelUnit.liter.label, 'L');
    });

    test('displayName matches apiValue', () {
      for (final unit in FuelUnit.values) {
        expect(unit.displayName, unit.apiValue);
      }
    });

    test('fromApiValue returns gallon for Gallon', () {
      expect(FuelUnit.fromApiValue('Gallon'), FuelUnit.gallon);
    });

    test('fromApiValue returns liter for Liter', () {
      expect(FuelUnit.fromApiValue('Liter'), FuelUnit.liter);
    });

    test('fromApiValue defaults to gallon for unknown value', () {
      expect(FuelUnit.fromApiValue('unknown'), FuelUnit.gallon);
    });
  });

  group('CurrencyCode', () {
    test('cad has correct apiValue', () {
      expect(CurrencyCode.cad.apiValue, 'CAD');
    });

    test('usd has correct apiValue', () {
      expect(CurrencyCode.usd.apiValue, 'USD');
    });

    test('cny has correct apiValue', () {
      expect(CurrencyCode.cny.apiValue, 'CNY');
    });

    test('cad has dollar symbol', () {
      expect(CurrencyCode.cad.symbol, '\$');
    });

    test('usd has dollar symbol', () {
      expect(CurrencyCode.usd.symbol, '\$');
    });

    test('cny has yen symbol', () {
      expect(CurrencyCode.cny.symbol, '\u00a5');
    });

    test('displayName matches apiValue', () {
      for (final code in CurrencyCode.values) {
        expect(code.displayName, code.apiValue);
      }
    });

    test('fromApiValue returns cad for CAD', () {
      expect(CurrencyCode.fromApiValue('CAD'), CurrencyCode.cad);
    });

    test('fromApiValue returns usd for USD', () {
      expect(CurrencyCode.fromApiValue('USD'), CurrencyCode.usd);
    });

    test('fromApiValue returns cny for CNY', () {
      expect(CurrencyCode.fromApiValue('CNY'), CurrencyCode.cny);
    });

    test('fromApiValue defaults to cad for unknown value', () {
      expect(CurrencyCode.fromApiValue('EUR'), CurrencyCode.cad);
    });
  });
}
