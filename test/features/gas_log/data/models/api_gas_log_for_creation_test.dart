import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/data/models/api_discount_info.dart';
import 'package:hmm_console/features/gas_log/data/models/api_gas_log_for_creation.dart';

void main() {
  group('ApiGasLogForCreation.toJson', () {
    test('serializes all required fields', () {
      final dto = ApiGasLogForCreation(
        date: DateTime(2026, 1, 15),
        automobileId: 42,
        odometer: 45230,
        distance: 320.5,
        fuel: 42.3,
        fuelGrade: 'Regular',
        totalPrice: 164.55,
        unitPrice: 3.89,
      );

      final json = dto.toJson();

      expect(json['date'], DateTime(2026, 1, 15).toIso8601String());
      expect(json['automobileId'], 42);
      expect(json['odometer'], 45230);
      expect(json['distance'], 320.5);
      expect(json['fuel'], 42.3);
      expect(json['fuelGrade'], 'Regular');
      expect(json['totalPrice'], 164.55);
      expect(json['unitPrice'], 3.89);
      expect(json['odometerUnit'], 'Mile');
      expect(json['distanceUnit'], 'Mile');
      expect(json['fuelUnit'], 'Gallon');
      expect(json['currency'], 'CAD');
      expect(json['isFullTank'], true);
      expect(json['isFirstFillUp'], false);
    });

    test('omits null optional fields', () {
      final dto = ApiGasLogForCreation(
        date: DateTime(2026, 1, 15),
        automobileId: 42,
        odometer: 45230,
        distance: 320.5,
        fuel: 42.3,
        fuelGrade: 'Regular',
        totalPrice: 164.55,
        unitPrice: 3.89,
      );

      final json = dto.toJson();

      expect(json.containsKey('discountInfos'), false);
      expect(json.containsKey('stationId'), false);
      expect(json.containsKey('location'), false);
      expect(json.containsKey('comment'), false);
      expect(json.containsKey('receiptNumber'), false);
      expect(json.containsKey('cityDrivingPercentage'), false);
      expect(json.containsKey('highwayDrivingPercentage'), false);
    });

    test('includes optional fields when set', () {
      final dto = ApiGasLogForCreation(
        date: DateTime(2026, 1, 15),
        automobileId: 42,
        odometer: 45230,
        distance: 320.5,
        fuel: 42.3,
        fuelGrade: 'Premium',
        totalPrice: 164.55,
        unitPrice: 3.89,
        location: 'Vancouver',
        comment: 'Test',
        receiptNumber: 'R-001',
        cityDrivingPercentage: 60,
        highwayDrivingPercentage: 40,
        discountInfos: [const ApiDiscountInfo(discountId: 1, amount: 4.0)],
      );

      final json = dto.toJson();

      expect(json['location'], 'Vancouver');
      expect(json['comment'], 'Test');
      expect(json['receiptNumber'], 'R-001');
      expect(json['cityDrivingPercentage'], 60);
      expect(json['highwayDrivingPercentage'], 40);
      expect(json['discountInfos'], hasLength(1));
    });
  });
}
