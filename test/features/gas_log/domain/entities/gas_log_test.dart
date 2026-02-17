import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/entities/discount_info.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';

import '../../helpers/gas_log_fixtures.dart';

void main() {
  group('GasLog', () {
    test('constructs with required fields and defaults', () {
      final log = GasLog(
        date: GasLogFixtures.date,
        automobileId: 42,
        odometer: 45230,
        distance: 320.5,
        fuel: 42.3,
        fuelGrade: 'Regular',
        totalPrice: 164.55,
        unitPrice: 3.89,
      );

      expect(log.id, isNull);
      expect(log.odometerUnit, 'Mile');
      expect(log.distanceUnit, 'Mile');
      expect(log.fuelUnit, 'Gallon');
      expect(log.currency, 'CAD');
      expect(log.isFullTank, true);
      expect(log.isFirstFillUp, false);
      expect(log.totalCostAfterDiscounts, 0);
      expect(log.discounts, isEmpty);
      expect(log.fuelEfficiency, 0);
      expect(log.createDate, isNull);
      expect(log.lastModifiedDate, isNull);
    });

    test('copyWith creates new instance with overridden fields', () {
      final original = GasLogFixtures.gasLog();
      final copy = original.copyWith(
        id: 99,
        odometer: 50000,
        fuel: 50.0,
        comment: 'New comment',
      );

      expect(copy.id, 99);
      expect(copy.odometer, 50000);
      expect(copy.fuel, 50.0);
      expect(copy.comment, 'New comment');
      // Unchanged fields
      expect(copy.date, original.date);
      expect(copy.automobileId, original.automobileId);
      expect(copy.totalPrice, original.totalPrice);
      expect(copy.stationName, original.stationName);
    });

    test('copyWith preserves all fields when no overrides', () {
      final original = GasLogFixtures.gasLog();
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.date, original.date);
      expect(copy.automobileId, original.automobileId);
      expect(copy.odometer, original.odometer);
      expect(copy.odometerUnit, original.odometerUnit);
      expect(copy.distance, original.distance);
      expect(copy.distanceUnit, original.distanceUnit);
      expect(copy.fuel, original.fuel);
      expect(copy.fuelUnit, original.fuelUnit);
      expect(copy.fuelGrade, original.fuelGrade);
      expect(copy.isFullTank, original.isFullTank);
      expect(copy.isFirstFillUp, original.isFirstFillUp);
      expect(copy.totalPrice, original.totalPrice);
      expect(copy.unitPrice, original.unitPrice);
      expect(copy.currency, original.currency);
      expect(copy.totalCostAfterDiscounts, original.totalCostAfterDiscounts);
      expect(copy.discounts, original.discounts);
      expect(copy.stationName, original.stationName);
      expect(copy.location, original.location);
      expect(copy.cityDrivingPercentage, original.cityDrivingPercentage);
      expect(copy.highwayDrivingPercentage, original.highwayDrivingPercentage);
      expect(copy.receiptNumber, original.receiptNumber);
      expect(copy.fuelEfficiency, original.fuelEfficiency);
      expect(copy.createDate, original.createDate);
      expect(copy.lastModifiedDate, original.lastModifiedDate);
      expect(copy.comment, original.comment);
    });

    test('copyWith can override discounts list', () {
      final original = GasLogFixtures.gasLog();
      final copy = original.copyWith(
        discounts: const [DiscountInfo(discountId: 5, amount: 10.0)],
      );

      expect(copy.discounts, hasLength(1));
      expect(copy.discounts.first.discountId, 5);
    });
  });
}
