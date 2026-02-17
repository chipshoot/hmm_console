import 'api_discount_info.dart';

class ApiGasLogForCreation {
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
  final List<ApiDiscountInfo>? discountInfos;
  final int? stationId;
  final String? location;
  final int? cityDrivingPercentage;
  final int? highwayDrivingPercentage;
  final String? receiptNumber;
  final String? comment;

  const ApiGasLogForCreation({
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
    this.discountInfos,
    this.stationId,
    this.location,
    this.cityDrivingPercentage,
    this.highwayDrivingPercentage,
    this.receiptNumber,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'date': date.toIso8601String(),
      'automobileId': automobileId,
      'odometer': odometer,
      'odometerUnit': odometerUnit,
      'distance': distance,
      'distanceUnit': distanceUnit,
      'fuel': fuel,
      'fuelUnit': fuelUnit,
      'fuelGrade': fuelGrade,
      'isFullTank': isFullTank,
      'isFirstFillUp': isFirstFillUp,
      'totalPrice': totalPrice,
      'unitPrice': unitPrice,
      'currency': currency,
    };
    if (discountInfos != null) {
      json['discountInfos'] = discountInfos!.map((d) => d.toJson()).toList();
    }
    if (stationId != null) json['stationId'] = stationId;
    if (location != null) json['location'] = location;
    if (cityDrivingPercentage != null) {
      json['cityDrivingPercentage'] = cityDrivingPercentage;
    }
    if (highwayDrivingPercentage != null) {
      json['highwayDrivingPercentage'] = highwayDrivingPercentage;
    }
    if (receiptNumber != null) json['receiptNumber'] = receiptNumber;
    if (comment != null) json['comment'] = comment;
    return json;
  }
}
