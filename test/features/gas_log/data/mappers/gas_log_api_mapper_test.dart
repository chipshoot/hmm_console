import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/data/mappers/gas_log_api_mapper.dart';
import 'package:hmm_console/features/gas_log/data/models/api_gas_log.dart';

import '../../helpers/gas_log_fixtures.dart';

void main() {
  group('GasLogApiMapper.fromApi', () {
    test('maps all fields from ApiGasLog to GasLog', () {
      final api = GasLogFixtures.apiGasLog();
      final domain = GasLogApiMapper.fromApi(api);

      expect(domain.id, api.id);
      expect(domain.date, api.date);
      expect(domain.automobileId, api.automobileId);
      expect(domain.odometer, api.odometer);
      expect(domain.odometerUnit, api.odometerUnit);
      expect(domain.distance, api.distance);
      expect(domain.distanceUnit, api.distanceUnit);
      expect(domain.fuel, api.fuel);
      expect(domain.fuelUnit, api.fuelUnit);
      expect(domain.fuelGrade, api.fuelGrade);
      expect(domain.isFullTank, api.isFullTank);
      expect(domain.isFirstFillUp, api.isFirstFillUp);
      expect(domain.totalPrice, api.totalPrice);
      expect(domain.unitPrice, api.unitPrice);
      expect(domain.currency, api.currency);
      expect(domain.totalCostAfterDiscounts, api.totalCostAfterDiscounts);
      expect(domain.discounts, hasLength(1));
      expect(domain.discounts.first.discountId, 1);
      expect(domain.discounts.first.amount, 4.0);
      expect(domain.stationName, api.stationName);
      expect(domain.location, api.location);
      expect(domain.cityDrivingPercentage, api.cityDrivingPercentage);
      expect(domain.highwayDrivingPercentage, api.highwayDrivingPercentage);
      expect(domain.receiptNumber, api.receiptNumber);
      expect(domain.fuelEfficiency, api.fuelEfficiency);
      expect(domain.createDate, api.createDate);
      expect(domain.lastModifiedDate, api.lastModifiedDate);
      expect(domain.comment, api.comment);
    });
  });

  group('GasLogApiMapper.fromApiList', () {
    test('maps list of ApiGasLog to list of GasLog', () {
      final apiList = [
        GasLogFixtures.apiGasLog(id: 1),
        GasLogFixtures.apiGasLog(id: 2),
      ];
      final domainList = GasLogApiMapper.fromApiList(apiList);

      expect(domainList, hasLength(2));
      expect(domainList[0].id, 1);
      expect(domainList[1].id, 2);
    });

    test('empty list produces empty list', () {
      expect(GasLogApiMapper.fromApiList([]), isEmpty);
    });
  });

  group('GasLogApiMapper.toCreationDto', () {
    test('maps GasLog to ApiGasLogForCreation', () {
      final gasLog = GasLogFixtures.gasLog();
      final dto = GasLogApiMapper.toCreationDto(gasLog);

      expect(dto.date, gasLog.date);
      expect(dto.automobileId, gasLog.automobileId);
      expect(dto.odometer, gasLog.odometer);
      expect(dto.odometerUnit, gasLog.odometerUnit);
      expect(dto.distance, gasLog.distance);
      expect(dto.distanceUnit, gasLog.distanceUnit);
      expect(dto.fuel, gasLog.fuel);
      expect(dto.fuelUnit, gasLog.fuelUnit);
      expect(dto.fuelGrade, gasLog.fuelGrade);
      expect(dto.isFullTank, gasLog.isFullTank);
      expect(dto.isFirstFillUp, gasLog.isFirstFillUp);
      expect(dto.totalPrice, gasLog.totalPrice);
      expect(dto.unitPrice, gasLog.unitPrice);
      expect(dto.currency, gasLog.currency);
      expect(dto.discountInfos, hasLength(1));
      expect(dto.discountInfos!.first.discountId, 1);
      expect(dto.location, gasLog.location);
      expect(dto.comment, gasLog.comment);
    });

    test('discountInfos is null when discounts is empty', () {
      final gasLog = GasLogFixtures.gasLog().copyWith(discounts: []);
      final dto = GasLogApiMapper.toCreationDto(gasLog);
      expect(dto.discountInfos, isNull);
    });
  });

  group('GasLogApiMapper.toUpdateDto', () {
    test('maps GasLog to ApiGasLogForUpdate', () {
      final gasLog = GasLogFixtures.gasLog();
      final dto = GasLogApiMapper.toUpdateDto(gasLog);

      expect(dto.date, gasLog.date);
      expect(dto.odometer, gasLog.odometer);
      expect(dto.odometerUnit, gasLog.odometerUnit);
      expect(dto.distance, gasLog.distance);
      expect(dto.fuel, gasLog.fuel);
      expect(dto.fuelGrade, gasLog.fuelGrade);
      expect(dto.totalPrice, gasLog.totalPrice);
      expect(dto.unitPrice, gasLog.unitPrice);
      expect(dto.currency, gasLog.currency);
      expect(dto.location, gasLog.location);
      expect(dto.comment, gasLog.comment);
    });
  });

  group('GasLogApiMapper.automobileFromApi', () {
    test('maps ApiAutomobile to Automobile', () {
      final api = GasLogFixtures.apiAutomobile();
      final domain = GasLogApiMapper.automobileFromApi(api);

      expect(domain.id, api.id);
      expect(domain.maker, api.maker);
      expect(domain.brand, api.brand);
      expect(domain.model, api.model);
      expect(domain.year, api.year);
      expect(domain.color, api.color);
      expect(domain.plate, api.plate);
      expect(domain.meterReading, api.meterReading);
      expect(domain.isActive, api.isActive);
    });
  });
}
