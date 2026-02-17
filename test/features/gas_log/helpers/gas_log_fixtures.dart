import 'package:hmm_console/features/gas_log/data/models/api_automobile.dart';
import 'package:hmm_console/features/gas_log/data/models/api_discount_info.dart';
import 'package:hmm_console/features/gas_log/data/models/api_gas_log.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/domain/entities/discount_info.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';

/// Shared test fixtures for gas log tests.
class GasLogFixtures {
  static final date = DateTime(2026, 1, 15, 10, 30);
  static final createDate = DateTime(2026, 1, 15, 10, 30);
  static final lastModified = DateTime(2026, 1, 16, 8, 0);

  // --- JSON payloads ---

  static Map<String, dynamic> apiGasLogJson({int id = 1}) => {
        'id': id,
        'date': date.toIso8601String(),
        'automobileId': 42,
        'odometer': 45230.0,
        'odometerUnit': 'Mile',
        'distance': 320.5,
        'distanceUnit': 'Mile',
        'fuel': 42.3,
        'fuelUnit': 'Gallon',
        'fuelGrade': 'Regular',
        'isFullTank': true,
        'isFirstFillUp': false,
        'totalPrice': 164.55,
        'unitPrice': 3.89,
        'currency': 'CAD',
        'totalCostAfterDiscounts': 160.55,
        'discounts': [
          {'discountId': 1, 'amount': 4.0},
        ],
        'stationName': 'Shell Station',
        'location': 'Vancouver',
        'cityDrivingPercentage': 60,
        'highwayDrivingPercentage': 40,
        'receiptNumber': 'R-001',
        'fuelEfficiency': 7.58,
        'createDate': createDate.toIso8601String(),
        'lastModifiedDate': lastModified.toIso8601String(),
        'comment': 'Regular fill-up',
      };

  static Map<String, dynamic> apiGasLogJsonMinimal({int id = 2}) => {
        'id': id,
        'date': date.toIso8601String(),
        'automobileId': 42,
        'odometer': 45000.0,
        'distance': 0.0,
        'fuel': 30.0,
        'fuelGrade': 'Regular',
        'isFullTank': true,
        'isFirstFillUp': false,
        'totalPrice': 100.0,
        'unitPrice': 3.33,
        'createDate': createDate.toIso8601String(),
      };

  static Map<String, dynamic> apiAutomobileJson({
    int id = 42,
    bool isActive = true,
  }) =>
      {
        'id': id,
        'vin': '1HGBH41JXMN109186',
        'maker': 'Toyota',
        'brand': 'Toyota',
        'model': 'Camry',
        'trim': 'LE',
        'year': 2023,
        'color': 'Silver',
        'plate': 'ABC 123',
        'engineType': 'Gasoline',
        'fuelType': 'Regular',
        'fuelTankCapacity': 15.8,
        'cityMPG': 28.0,
        'highwayMPG': 39.0,
        'combinedMPG': 32.0,
        'meterReading': 45230,
        'purchaseMeterReading': 10,
        'purchaseDate': '2023-03-15T00:00:00',
        'purchasePrice': 28000.0,
        'ownershipStatus': 'Owned',
        'isActive': isActive,
        'registrationExpiryDate': '2027-03-15T00:00:00',
        'insuranceExpiryDate': '2027-01-01T00:00:00',
        'insuranceProvider': 'ICBC',
        'insurancePolicyNumber': 'POL-123456',
        'lastServiceDate': '2025-12-01T00:00:00',
        'lastServiceMeterReading': 44000,
        'nextServiceDueDate': '2026-06-01T00:00:00',
        'nextServiceDueMeterReading': 50000,
        'notes': 'Good condition',
        'createdDate': '2023-03-15T10:00:00',
        'lastModifiedDate': '2026-01-10T08:00:00',
      };

  static Map<String, dynamic> paginationHeaderJson({
    int totalCount = 2,
    int pageSize = 20,
    int currentPage = 1,
    int totalPages = 1,
  }) =>
      {
        'totalCount': totalCount,
        'pageSize': pageSize,
        'currentPage': currentPage,
        'totalPages': totalPages,
      };

  // --- Domain entities ---

  static GasLog gasLog({int? id = 1}) => GasLog(
        id: id,
        date: date,
        automobileId: 42,
        odometer: 45230,
        odometerUnit: 'Mile',
        distance: 320.5,
        distanceUnit: 'Mile',
        fuel: 42.3,
        fuelUnit: 'Gallon',
        fuelGrade: 'Regular',
        isFullTank: true,
        isFirstFillUp: false,
        totalPrice: 164.55,
        unitPrice: 3.89,
        currency: 'CAD',
        totalCostAfterDiscounts: 160.55,
        discounts: const [DiscountInfo(discountId: 1, amount: 4.0)],
        stationName: 'Shell Station',
        location: 'Vancouver',
        cityDrivingPercentage: 60,
        highwayDrivingPercentage: 40,
        receiptNumber: 'R-001',
        fuelEfficiency: 7.58,
        createDate: createDate,
        lastModifiedDate: lastModified,
        comment: 'Regular fill-up',
      );

  static Automobile automobile({int id = 42, bool isActive = true}) =>
      Automobile(
        id: id,
        vin: '1HGBH41JXMN109186',
        maker: 'Toyota',
        brand: 'Toyota',
        model: 'Camry',
        trim: 'LE',
        year: 2023,
        color: 'Silver',
        plate: 'ABC 123',
        engineType: 'Gasoline',
        fuelType: 'Regular',
        fuelTankCapacity: 15.8,
        cityMPG: 28.0,
        highwayMPG: 39.0,
        combinedMPG: 32.0,
        meterReading: 45230,
        ownershipStatus: 'Owned',
        isActive: isActive,
        notes: 'Good condition',
      );

  static Automobile automobileForCreate() => const Automobile(
        id: 0,
        vin: '1HGBH41JXMN109186',
        maker: 'Toyota',
        brand: 'Toyota',
        model: 'Camry',
        plate: 'NEW 001',
        engineType: 'Gasoline',
        fuelType: 'Regular',
        year: 2024,
        meterReading: 0,
        isActive: true,
        ownershipStatus: 'Owned',
      );

  // --- API model instances ---

  static ApiGasLog apiGasLog({int id = 1}) =>
      ApiGasLog.fromJson(apiGasLogJson(id: id));

  static ApiAutomobile apiAutomobile({int id = 42}) =>
      ApiAutomobile.fromJson(apiAutomobileJson(id: id));

  static const apiDiscountInfo =
      ApiDiscountInfo(discountId: 1, amount: 4.0);

  static const discountInfo = DiscountInfo(discountId: 1, amount: 4.0);
}
