import 'discount_info.dart';

class GasLog {
  final int? id;
  final DateTime date;
  final int automobileId;

  final double odometer;
  final String odometerUnit;
  final double distance;
  final String distanceUnit;

  final double fuel;
  final String fuelUnit;
  final String fuelGrade;
  final bool isFullTank;
  final bool isFirstFillUp;

  final double totalPrice;
  final double unitPrice;
  final String currency;
  final double totalCostAfterDiscounts;
  final List<DiscountInfo> discounts;

  final int? stationId;
  final String? stationName;
  final String? location;
  final int? cityDrivingPercentage;
  final int? highwayDrivingPercentage;
  final String? receiptNumber;

  final double fuelEfficiency;
  final DateTime? createDate;
  final DateTime? lastModifiedDate;
  final String? comment;

  GasLog({
    this.id,
    required this.date,
    required this.automobileId,
    required this.odometer,
    this.odometerUnit = 'Mile',
    required this.distance,
    this.distanceUnit = 'Mile',
    required this.fuel,
    this.fuelUnit = 'Gallon',
    required this.fuelGrade,
    this.isFullTank = true,
    this.isFirstFillUp = false,
    required this.totalPrice,
    required this.unitPrice,
    this.currency = 'CAD',
    this.totalCostAfterDiscounts = 0,
    this.discounts = const [],
    this.stationId,
    this.stationName,
    this.location,
    this.cityDrivingPercentage,
    this.highwayDrivingPercentage,
    this.receiptNumber,
    this.fuelEfficiency = 0,
    this.createDate,
    this.lastModifiedDate,
    this.comment,
  });

  GasLog copyWith({
    int? id,
    DateTime? date,
    int? automobileId,
    double? odometer,
    String? odometerUnit,
    double? distance,
    String? distanceUnit,
    double? fuel,
    String? fuelUnit,
    String? fuelGrade,
    bool? isFullTank,
    bool? isFirstFillUp,
    double? totalPrice,
    double? unitPrice,
    String? currency,
    double? totalCostAfterDiscounts,
    List<DiscountInfo>? discounts,
    int? stationId,
    String? stationName,
    String? location,
    int? cityDrivingPercentage,
    int? highwayDrivingPercentage,
    String? receiptNumber,
    double? fuelEfficiency,
    DateTime? createDate,
    DateTime? lastModifiedDate,
    String? comment,
  }) {
    return GasLog(
      id: id ?? this.id,
      date: date ?? this.date,
      automobileId: automobileId ?? this.automobileId,
      odometer: odometer ?? this.odometer,
      odometerUnit: odometerUnit ?? this.odometerUnit,
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      fuel: fuel ?? this.fuel,
      fuelUnit: fuelUnit ?? this.fuelUnit,
      fuelGrade: fuelGrade ?? this.fuelGrade,
      isFullTank: isFullTank ?? this.isFullTank,
      isFirstFillUp: isFirstFillUp ?? this.isFirstFillUp,
      totalPrice: totalPrice ?? this.totalPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      totalCostAfterDiscounts:
          totalCostAfterDiscounts ?? this.totalCostAfterDiscounts,
      discounts: discounts ?? this.discounts,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      location: location ?? this.location,
      cityDrivingPercentage:
          cityDrivingPercentage ?? this.cityDrivingPercentage,
      highwayDrivingPercentage:
          highwayDrivingPercentage ?? this.highwayDrivingPercentage,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      fuelEfficiency: fuelEfficiency ?? this.fuelEfficiency,
      createDate: createDate ?? this.createDate,
      lastModifiedDate: lastModifiedDate ?? this.lastModifiedDate,
      comment: comment ?? this.comment,
    );
  }
}
