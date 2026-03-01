enum DistanceUnit {
  mile,
  kilometer;

  String get apiValue => switch (this) {
        mile => 'Mile',
        kilometer => 'Kilometer',
      };

  String get label => switch (this) {
        mile => 'mi',
        kilometer => 'km',
      };

  String get displayName => apiValue;

  static DistanceUnit fromApiValue(String value) => switch (value) {
        'Mile' => mile,
        'Kilometer' || 'Kilometre' => kilometer,
        _ => mile,
      };
}

enum FuelUnit {
  gallon,
  liter;

  String get apiValue => switch (this) {
        gallon => 'Gallon',
        liter => 'Liter',
      };

  String get label => switch (this) {
        gallon => 'gal',
        liter => 'L',
      };

  String get displayName => apiValue;

  static FuelUnit fromApiValue(String value) => switch (value) {
        'Gallon' => gallon,
        'Liter' => liter,
        _ => gallon,
      };
}

enum CurrencyCode {
  cad,
  usd,
  cny;

  String get apiValue => switch (this) {
        cad => 'CAD',
        usd => 'USD',
        cny => 'CNY',
      };

  String get symbol => switch (this) {
        cad => '\$',
        usd => '\$',
        cny => '\u00a5',
      };

  String get displayName => apiValue;

  static CurrencyCode fromApiValue(String value) => switch (value) {
        'CAD' => cad,
        'USD' => usd,
        'CNY' => cny,
        _ => cad,
      };
}
