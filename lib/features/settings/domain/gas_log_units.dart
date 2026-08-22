/// Units for the gas log.
///
/// Note what is NOT here: a `displayName`. These enums used to expose
/// `String get displayName => apiValue`, so the text rendered in a settings
/// dropdown was the very string persisted and sent to the API. Localizing the
/// UI would then have written a translated word into storage and onto the wire,
/// and [DistanceUnit.fromApiValue] would have stopped recognising it — silent
/// data corruption dressed up as a translation.
///
/// Display copy now lives in `core/i18n/enum_labels.dart`. Everything in this
/// file is the persistence contract: literal, stable, never translated.
enum DistanceUnit {
  mile,
  kilometer;

  /// Persisted in settings and sent to the API. Never shown to a user, and
  /// never translated.
  String get apiValue => switch (this) {
        mile => 'Mile',
        kilometer => 'Kilometer',
      };

  /// Symbol shown beside a number ("120 km"). Unit symbols read the same in
  /// English and Chinese, so this needs no translation.
  String get label => switch (this) {
        mile => 'mi',
        kilometer => 'km',
      };

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

  static CurrencyCode fromApiValue(String value) => switch (value) {
        'CAD' => cad,
        'USD' => usd,
        'CNY' => cny,
        _ => cad,
      };
}
