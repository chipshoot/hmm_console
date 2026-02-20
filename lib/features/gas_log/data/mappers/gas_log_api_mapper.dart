import '../../domain/entities/automobile.dart';
import '../../domain/entities/discount_info.dart';
import '../../domain/entities/gas_log.dart';
import '../models/api_automobile.dart';
import '../models/api_automobile_for_create.dart';
import '../models/api_automobile_for_update.dart';
import '../models/api_discount_info.dart';
import '../models/api_gas_log.dart';
import '../models/api_gas_log_for_creation.dart';
import '../models/api_gas_log_for_update.dart';

class GasLogApiMapper {
  static GasLog fromApi(ApiGasLog api) {
    return GasLog(
      id: api.id,
      date: api.date,
      automobileId: api.automobileId,
      odometer: api.odometer,
      odometerUnit: api.odometerUnit,
      distance: api.distance,
      distanceUnit: api.distanceUnit,
      fuel: api.fuel,
      fuelUnit: api.fuelUnit,
      fuelGrade: api.fuelGrade,
      isFullTank: api.isFullTank,
      isFirstFillUp: api.isFirstFillUp,
      totalPrice: api.totalPrice,
      unitPrice: api.unitPrice,
      currency: api.currency,
      totalCostAfterDiscounts: api.totalCostAfterDiscounts,
      discounts: api.discounts.map(_discountFromApi).toList(),
      stationName: api.stationName,
      location: api.location,
      cityDrivingPercentage: api.cityDrivingPercentage,
      highwayDrivingPercentage: api.highwayDrivingPercentage,
      receiptNumber: api.receiptNumber,
      fuelEfficiency: api.fuelEfficiency,
      createDate: api.createDate,
      lastModifiedDate: api.lastModifiedDate,
      comment: api.comment,
    );
  }

  static List<GasLog> fromApiList(List<ApiGasLog> apiList) {
    return apiList.map(fromApi).toList();
  }

  static ApiGasLogForCreation toCreationDto(GasLog gasLog) {
    return ApiGasLogForCreation(
      date: gasLog.date,
      automobileId: gasLog.automobileId,
      odometer: gasLog.odometer,
      odometerUnit: gasLog.odometerUnit,
      distance: gasLog.distance,
      distanceUnit: gasLog.distanceUnit,
      fuel: gasLog.fuel,
      fuelUnit: gasLog.fuelUnit,
      fuelGrade: gasLog.fuelGrade,
      isFullTank: gasLog.isFullTank,
      isFirstFillUp: gasLog.isFirstFillUp,
      totalPrice: gasLog.totalPrice,
      unitPrice: gasLog.unitPrice,
      currency: gasLog.currency,
      discountInfos: gasLog.discounts.isNotEmpty
          ? gasLog.discounts.map(_discountToApi).toList()
          : null,
      stationId: gasLog.stationId,
      location: gasLog.location,
      cityDrivingPercentage: gasLog.cityDrivingPercentage,
      highwayDrivingPercentage: gasLog.highwayDrivingPercentage,
      receiptNumber: gasLog.receiptNumber,
      comment: gasLog.comment,
    );
  }

  static ApiGasLogForUpdate toUpdateDto(GasLog gasLog) {
    return ApiGasLogForUpdate(
      date: gasLog.date,
      odometer: gasLog.odometer,
      odometerUnit: gasLog.odometerUnit,
      distance: gasLog.distance,
      distanceUnit: gasLog.distanceUnit,
      fuel: gasLog.fuel,
      fuelUnit: gasLog.fuelUnit,
      fuelGrade: gasLog.fuelGrade,
      isFullTank: gasLog.isFullTank,
      isFirstFillUp: gasLog.isFirstFillUp,
      totalPrice: gasLog.totalPrice,
      unitPrice: gasLog.unitPrice,
      currency: gasLog.currency,
      location: gasLog.location,
      cityDrivingPercentage: gasLog.cityDrivingPercentage,
      highwayDrivingPercentage: gasLog.highwayDrivingPercentage,
      receiptNumber: gasLog.receiptNumber,
      comment: gasLog.comment,
    );
  }

  static Automobile automobileFromApi(ApiAutomobile api) {
    return Automobile(
      id: api.id,
      vin: api.vin,
      maker: api.maker,
      brand: api.brand,
      model: api.model,
      trim: api.trim,
      year: api.year,
      color: api.color,
      plate: api.plate,
      engineType: api.engineType,
      fuelType: api.fuelType,
      fuelTankCapacity: api.fuelTankCapacity,
      cityMPG: api.cityMPG,
      highwayMPG: api.highwayMPG,
      combinedMPG: api.combinedMPG,
      meterReading: api.meterReading,
      purchaseMeterReading: api.purchaseMeterReading,
      purchaseDate: api.purchaseDate,
      purchasePrice: api.purchasePrice,
      ownershipStatus: api.ownershipStatus,
      isActive: api.isActive,
      soldDate: api.soldDate,
      soldMeterReading: api.soldMeterReading,
      soldPrice: api.soldPrice,
      registrationExpiryDate: api.registrationExpiryDate,
      insuranceExpiryDate: api.insuranceExpiryDate,
      insuranceProvider: api.insuranceProvider,
      insurancePolicyNumber: api.insurancePolicyNumber,
      lastServiceDate: api.lastServiceDate,
      lastServiceMeterReading: api.lastServiceMeterReading,
      nextServiceDueDate: api.nextServiceDueDate,
      nextServiceDueMeterReading: api.nextServiceDueMeterReading,
      notes: api.notes,
      createdDate: api.createdDate,
      lastModifiedDate: api.lastModifiedDate,
    );
  }

  static ApiAutomobileForCreate automobileToCreateDto(Automobile auto) {
    return ApiAutomobileForCreate(
      vin: auto.vin ?? '',
      maker: auto.maker ?? '',
      brand: auto.brand ?? '',
      model: auto.model ?? '',
      trim: auto.trim,
      year: auto.year,
      color: auto.color,
      plate: auto.plate ?? '',
      engineType: auto.engineType ?? '',
      fuelType: auto.fuelType ?? '',
      fuelTankCapacity: auto.fuelTankCapacity,
      cityMPG: auto.cityMPG,
      highwayMPG: auto.highwayMPG,
      combinedMPG: auto.combinedMPG,
      meterReading: auto.meterReading,
      purchaseMeterReading: auto.purchaseMeterReading,
      purchaseDate: auto.purchaseDate,
      purchasePrice: auto.purchasePrice,
      ownershipStatus: auto.ownershipStatus ?? 'Owned',
      registrationExpiryDate: auto.registrationExpiryDate,
      insuranceExpiryDate: auto.insuranceExpiryDate,
      insuranceProvider: auto.insuranceProvider,
      insurancePolicyNumber: auto.insurancePolicyNumber,
      notes: auto.notes,
    );
  }

  static ApiAutomobileForUpdate automobileToUpdateDto(Automobile auto) {
    return ApiAutomobileForUpdate(
      color: auto.color,
      plate: auto.plate,
      meterReading: auto.meterReading,
      ownershipStatus: auto.ownershipStatus,
      isActive: auto.isActive,
      soldDate: auto.soldDate,
      soldMeterReading: auto.soldMeterReading,
      soldPrice: auto.soldPrice,
      registrationExpiryDate: auto.registrationExpiryDate,
      insuranceExpiryDate: auto.insuranceExpiryDate,
      insuranceProvider: auto.insuranceProvider,
      insurancePolicyNumber: auto.insurancePolicyNumber,
      lastServiceDate: auto.lastServiceDate,
      lastServiceMeterReading: auto.lastServiceMeterReading,
      nextServiceDueDate: auto.nextServiceDueDate,
      nextServiceDueMeterReading: auto.nextServiceDueMeterReading,
      notes: auto.notes,
    );
  }

  static DiscountInfo _discountFromApi(ApiDiscountInfo api) {
    return DiscountInfo(discountId: api.discountId, amount: api.amount);
  }

  static ApiDiscountInfo _discountToApi(DiscountInfo info) {
    return ApiDiscountInfo(discountId: info.discountId, amount: info.amount);
  }
}
