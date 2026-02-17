class ApiGasLogForUpdate {
  final DateTime? date;
  final double? odometer;
  final String? odometerUnit;
  final double? distance;
  final String? distanceUnit;
  final double? fuel;
  final String? fuelUnit;
  final String? fuelGrade;
  final bool? isFullTank;
  final bool? isFirstFillUp;
  final double? totalPrice;
  final double? unitPrice;
  final String? currency;
  final int? stationId;
  final String? location;
  final int? cityDrivingPercentage;
  final int? highwayDrivingPercentage;
  final String? receiptNumber;
  final String? comment;

  const ApiGasLogForUpdate({
    this.date,
    this.odometer,
    this.odometerUnit,
    this.distance,
    this.distanceUnit,
    this.fuel,
    this.fuelUnit,
    this.fuelGrade,
    this.isFullTank,
    this.isFirstFillUp,
    this.totalPrice,
    this.unitPrice,
    this.currency,
    this.stationId,
    this.location,
    this.cityDrivingPercentage,
    this.highwayDrivingPercentage,
    this.receiptNumber,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (date != null) json['date'] = date!.toIso8601String();
    if (odometer != null) json['odometer'] = odometer;
    if (odometerUnit != null) json['odometerUnit'] = odometerUnit;
    if (distance != null) json['distance'] = distance;
    if (distanceUnit != null) json['distanceUnit'] = distanceUnit;
    if (fuel != null) json['fuel'] = fuel;
    if (fuelUnit != null) json['fuelUnit'] = fuelUnit;
    if (fuelGrade != null) json['fuelGrade'] = fuelGrade;
    if (isFullTank != null) json['isFullTank'] = isFullTank;
    if (isFirstFillUp != null) json['isFirstFillUp'] = isFirstFillUp;
    if (totalPrice != null) json['totalPrice'] = totalPrice;
    if (unitPrice != null) json['unitPrice'] = unitPrice;
    if (currency != null) json['currency'] = currency;
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
