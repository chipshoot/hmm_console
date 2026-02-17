import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/data/models/api_gas_log.dart';

import '../../helpers/gas_log_fixtures.dart';

void main() {
  group('ApiGasLog.fromJson', () {
    test('parses full JSON correctly', () {
      final json = GasLogFixtures.apiGasLogJson();
      final gasLog = ApiGasLog.fromJson(json);

      expect(gasLog.id, 1);
      expect(gasLog.date, GasLogFixtures.date);
      expect(gasLog.automobileId, 42);
      expect(gasLog.odometer, 45230.0);
      expect(gasLog.odometerUnit, 'Mile');
      expect(gasLog.distance, 320.5);
      expect(gasLog.distanceUnit, 'Mile');
      expect(gasLog.fuel, 42.3);
      expect(gasLog.fuelUnit, 'Gallon');
      expect(gasLog.fuelGrade, 'Regular');
      expect(gasLog.isFullTank, true);
      expect(gasLog.isFirstFillUp, false);
      expect(gasLog.totalPrice, 164.55);
      expect(gasLog.unitPrice, 3.89);
      expect(gasLog.currency, 'CAD');
      expect(gasLog.totalCostAfterDiscounts, 160.55);
      expect(gasLog.discounts, hasLength(1));
      expect(gasLog.discounts.first.discountId, 1);
      expect(gasLog.discounts.first.amount, 4.0);
      expect(gasLog.stationName, 'Shell Station');
      expect(gasLog.location, 'Vancouver');
      expect(gasLog.cityDrivingPercentage, 60);
      expect(gasLog.highwayDrivingPercentage, 40);
      expect(gasLog.receiptNumber, 'R-001');
      expect(gasLog.fuelEfficiency, 7.58);
      expect(gasLog.createDate, GasLogFixtures.createDate);
      expect(gasLog.lastModifiedDate, GasLogFixtures.lastModified);
      expect(gasLog.comment, 'Regular fill-up');
    });

    test('parses minimal JSON with defaults', () {
      final json = GasLogFixtures.apiGasLogJsonMinimal();
      final gasLog = ApiGasLog.fromJson(json);

      expect(gasLog.id, 2);
      expect(gasLog.odometerUnit, 'Mile');
      expect(gasLog.distanceUnit, 'Mile');
      expect(gasLog.fuelUnit, 'Gallon');
      expect(gasLog.currency, 'CAD');
      expect(gasLog.totalCostAfterDiscounts, 0);
      expect(gasLog.discounts, isEmpty);
      expect(gasLog.stationName, isNull);
      expect(gasLog.location, isNull);
      expect(gasLog.cityDrivingPercentage, isNull);
      expect(gasLog.highwayDrivingPercentage, isNull);
      expect(gasLog.receiptNumber, isNull);
      expect(gasLog.fuelEfficiency, 0);
      expect(gasLog.lastModifiedDate, isNull);
      expect(gasLog.comment, isNull);
    });

    test('handles null discounts list', () {
      final json = GasLogFixtures.apiGasLogJson()..['discounts'] = null;
      final gasLog = ApiGasLog.fromJson(json);
      expect(gasLog.discounts, isEmpty);
    });
  });
}
