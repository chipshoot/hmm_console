import 'api_discount_info.dart';

class ApiGasLog {
  final int id;
  final DateTime date;
  final int automobileId;

  // Odometer & Distance
  final double odometer;
  final String odometerUnit;
  final double distance;
  final String distanceUnit;

  // Fuel Information
  final double fuel;
  final String fuelUnit;
  final String fuelGrade;
  final bool isFullTank;
  final bool isFirstFillUp;

  // Pricing
  final double totalPrice;
  final double unitPrice;
  final String currency;
  final double totalCostAfterDiscounts;
  final List<ApiDiscountInfo> discounts;

  // Station & Location
  final String? stationName;
  final String? location;

  // Driving Context
  final int? cityDrivingPercentage;
  final int? highwayDrivingPercentage;
  final String? receiptNumber;

  // Calculated
  final double fuelEfficiency;

  // Metadata
  final DateTime createDate;
  final DateTime? lastModifiedDate;
  final String? comment;

  const ApiGasLog({
    required this.id,
    required this.date,
    required this.automobileId,
    required this.odometer,
    required this.odometerUnit,
    required this.distance,
    required this.distanceUnit,
    required this.fuel,
    required this.fuelUnit,
    required this.fuelGrade,
    required this.isFullTank,
    required this.isFirstFillUp,
    required this.totalPrice,
    required this.unitPrice,
    required this.currency,
    required this.totalCostAfterDiscounts,
    required this.discounts,
    this.stationName,
    this.location,
    this.cityDrivingPercentage,
    this.highwayDrivingPercentage,
    this.receiptNumber,
    required this.fuelEfficiency,
    required this.createDate,
    this.lastModifiedDate,
    this.comment,
  });

  factory ApiGasLog.fromJson(Map<String, dynamic> json) {
    return ApiGasLog(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      automobileId: json['automobileId'] as int,
      odometer: (json['odometer'] as num).toDouble(),
      odometerUnit: json['odometerUnit'] as String? ?? 'Mile',
      distance: (json['distance'] as num).toDouble(),
      distanceUnit: json['distanceUnit'] as String? ?? 'Mile',
      fuel: (json['fuel'] as num).toDouble(),
      fuelUnit: json['fuelUnit'] as String? ?? 'Gallon',
      fuelGrade: json['fuelGrade'] as String? ?? 'Regular',
      isFullTank: json['isFullTank'] as bool? ?? true,
      isFirstFillUp: json['isFirstFillUp'] as bool? ?? false,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'CAD',
      totalCostAfterDiscounts:
          (json['totalCostAfterDiscounts'] as num?)?.toDouble() ?? 0,
      discounts: (json['discounts'] as List<dynamic>?)
              ?.map((e) =>
                  ApiDiscountInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      stationName: json['stationName'] as String?,
      location: json['location'] as String?,
      cityDrivingPercentage: json['cityDrivingPercentage'] as int?,
      highwayDrivingPercentage: json['highwayDrivingPercentage'] as int?,
      receiptNumber: json['receiptNumber'] as String?,
      fuelEfficiency: (json['fuelEfficiency'] as num?)?.toDouble() ?? 0,
      createDate: DateTime.parse(json['createDate'] as String),
      lastModifiedDate: json['lastModifiedDate'] != null
          ? DateTime.parse(json['lastModifiedDate'] as String)
          : null,
      comment: json['comment'] as String?,
    );
  }
}
