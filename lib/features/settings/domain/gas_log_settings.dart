import 'dart:convert';

import 'gas_log_units.dart';

class GasLogSettings {
  final DistanceUnit distanceUnit;
  final FuelUnit fuelUnit;
  final CurrencyCode currency;

  /// Whether the Registration card appears on the vehicle screen.
  /// Default on. Useful to turn off in jurisdictions where vehicle
  /// registration doesn't need annual renewal (e.g. Ontario, Canada
  /// retired the renewal sticker requirement in 2022 — users there
  /// can disable this card so the screen stops nagging them about a
  /// date that doesn't matter).
  final bool showRegistration;

  const GasLogSettings({
    this.distanceUnit = DistanceUnit.mile,
    this.fuelUnit = FuelUnit.gallon,
    this.currency = CurrencyCode.cad,
    this.showRegistration = true,
  });

  GasLogSettings copyWith({
    DistanceUnit? distanceUnit,
    FuelUnit? fuelUnit,
    CurrencyCode? currency,
    bool? showRegistration,
  }) {
    return GasLogSettings(
      distanceUnit: distanceUnit ?? this.distanceUnit,
      fuelUnit: fuelUnit ?? this.fuelUnit,
      currency: currency ?? this.currency,
      showRegistration: showRegistration ?? this.showRegistration,
    );
  }

  Map<String, dynamic> toJson() => {
        'distanceUnit': distanceUnit.apiValue,
        'fuelUnit': fuelUnit.apiValue,
        'currency': currency.apiValue,
        'showRegistration': showRegistration,
      };

  factory GasLogSettings.fromJson(Map<String, dynamic> json) {
    // Tolerate missing keys: the settings bundle is stored opaquely on
    // the server and synced across client versions, so a partial or
    // older payload must default each field rather than crash the whole
    // settings sync (an unguarded `as String` on a null value used to
    // throw "Null is not a subtype of String"). Falls back to the
    // const-constructor defaults.
    const defaults = GasLogSettings();
    final distanceRaw = json['distanceUnit'] as String?;
    final fuelRaw = json['fuelUnit'] as String?;
    final currencyRaw = json['currency'] as String?;
    return GasLogSettings(
      distanceUnit: distanceRaw != null
          ? DistanceUnit.fromApiValue(distanceRaw)
          : defaults.distanceUnit,
      fuelUnit: fuelRaw != null
          ? FuelUnit.fromApiValue(fuelRaw)
          : defaults.fuelUnit,
      currency: currencyRaw != null
          ? CurrencyCode.fromApiValue(currencyRaw)
          : defaults.currency,
      // Older payloads (pre-2026-05-18) won't have this key; default
      // to true so existing installs don't silently lose the card.
      showRegistration: json['showRegistration'] as bool? ?? true,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory GasLogSettings.fromJsonString(String jsonString) {
    return GasLogSettings.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
