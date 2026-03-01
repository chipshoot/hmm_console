import 'dart:convert';

import 'gas_log_units.dart';

class GasLogSettings {
  final DistanceUnit distanceUnit;
  final FuelUnit fuelUnit;
  final CurrencyCode currency;

  const GasLogSettings({
    this.distanceUnit = DistanceUnit.mile,
    this.fuelUnit = FuelUnit.gallon,
    this.currency = CurrencyCode.cad,
  });

  GasLogSettings copyWith({
    DistanceUnit? distanceUnit,
    FuelUnit? fuelUnit,
    CurrencyCode? currency,
  }) {
    return GasLogSettings(
      distanceUnit: distanceUnit ?? this.distanceUnit,
      fuelUnit: fuelUnit ?? this.fuelUnit,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() => {
        'distanceUnit': distanceUnit.apiValue,
        'fuelUnit': fuelUnit.apiValue,
        'currency': currency.apiValue,
      };

  factory GasLogSettings.fromJson(Map<String, dynamic> json) {
    return GasLogSettings(
      distanceUnit: DistanceUnit.fromApiValue(json['distanceUnit'] as String),
      fuelUnit: FuelUnit.fromApiValue(json['fuelUnit'] as String),
      currency: CurrencyCode.fromApiValue(json['currency'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory GasLogSettings.fromJsonString(String jsonString) {
    return GasLogSettings.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
