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
}
