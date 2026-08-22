import '../../../../l10n/gen/app_localizations.dart';

/// Form validation for the gas-log entry screen.
///
/// Every method takes an [AppLocalizations] because the messages are read by a
/// person and must follow the app's language. The mixin is applied to `State`
/// subclasses, which do have a `BuildContext`, but the localizations are passed
/// in rather than resolved from a context here: the mixin carries no `on State`
/// constraint (the tests apply it to a plain class), and a validator handed its
/// inputs is easier to test than one reaching for ambient state.
mixin GasLogValidator {
  String? validateOdometer(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationOdometerRequired;
    final v = double.tryParse(value);
    if (v == null || v < 0) return l.validationOdometerInvalid;
    return null;
  }

  String? validateFuel(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationFuelRequired;
    final v = double.tryParse(value);
    if (v == null || v <= 0) return l.validationFuelInvalid;
    return null;
  }

  String? validatePrice(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationPriceRequired;
    final v = double.tryParse(value);
    if (v == null || v < 0) return l.validationPriceInvalid;
    return null;
  }

  String? validateDistance(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return null; // optional
    final v = double.tryParse(value);
    if (v == null || v < 0) return l.validationDistanceInvalid;
    return null;
  }

  /// For real-time logs: odometer must be >= automobile's current meterReading.
  String? validateOdometerAgainstMeter(
    String? value,
    int currentMeterReading,
    AppLocalizations l,
  ) {
    final base = validateOdometer(value, l);
    if (base != null) return base;
    final v = double.parse(value!);
    if (v < currentMeterReading) {
      return l.validationOdometerBelowCurrent('$currentMeterReading');
    }
    return null;
  }

  /// Advisory warning if odometer has a large gap from expected value.
  /// Returns warning message or null. Non-blocking — for display only.
  String? warnOdometerGap(
    String? odometerValue,
    String? distanceValue,
    int currentMeterReading,
    AppLocalizations l, {
    double threshold = 500,
  }) {
    final odo = double.tryParse(odometerValue ?? '');
    final dist = double.tryParse(distanceValue ?? '') ?? 0;
    if (odo == null || currentMeterReading <= 0) return null;
    final expected = currentMeterReading + dist;
    final gap = (odo - expected).abs();
    if (gap > threshold) {
      return l.validationOdometerLargeGap(
        gap.toStringAsFixed(0),
        expected.toStringAsFixed(0),
      );
    }
    return null;
  }
}
