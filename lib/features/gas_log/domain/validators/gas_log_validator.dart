mixin GasLogValidator {
  String? validateOdometer(String? value) {
    if (value == null || value.isEmpty) return 'Odometer is required';
    final v = double.tryParse(value);
    if (v == null || v < 0) return 'Enter a valid odometer reading';
    return null;
  }

  String? validateFuel(String? value) {
    if (value == null || value.isEmpty) return 'Fuel amount is required';
    final v = double.tryParse(value);
    if (v == null || v <= 0) return 'Enter a valid fuel amount';
    return null;
  }

  String? validatePrice(String? value) {
    if (value == null || value.isEmpty) return 'Price is required';
    final v = double.tryParse(value);
    if (v == null || v < 0) return 'Enter a valid price';
    return null;
  }

  String? validateDistance(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final v = double.tryParse(value);
    if (v == null || v < 0) return 'Enter a valid distance';
    return null;
  }

  /// For real-time logs: odometer must be >= automobile's current meterReading.
  String? validateOdometerAgainstMeter(String? value, int currentMeterReading) {
    final base = validateOdometer(value);
    if (base != null) return base;
    final v = double.parse(value!);
    if (v < currentMeterReading) {
      return 'Odometer cannot be less than current reading ($currentMeterReading)';
    }
    return null;
  }

  /// Advisory warning if odometer has a large gap from expected value.
  /// Returns warning message or null. Non-blocking — for display only.
  String? warnOdometerGap(
    String? odometerValue,
    String? distanceValue,
    int currentMeterReading, {
    double threshold = 500,
  }) {
    final odo = double.tryParse(odometerValue ?? '');
    final dist = double.tryParse(distanceValue ?? '') ?? 0;
    if (odo == null || currentMeterReading <= 0) return null;
    final expected = currentMeterReading + dist;
    final gap = (odo - expected).abs();
    if (gap > threshold) {
      return 'Large gap: odometer is ${gap.toStringAsFixed(0)} from expected (${expected.toStringAsFixed(0)})';
    }
    return null;
  }
}
