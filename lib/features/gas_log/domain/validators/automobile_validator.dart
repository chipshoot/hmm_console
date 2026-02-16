mixin AutomobileValidator {
  String? validateVin(String? value) {
    if (value == null || value.isEmpty) return 'VIN is required';
    if (value.length != 17) return 'VIN must be exactly 17 characters';
    return null;
  }

  String? validateMaker(String? value) {
    if (value == null || value.isEmpty) return 'Maker is required';
    if (value.length > 50) return 'Maker must be 50 characters or less';
    return null;
  }

  String? validateBrand(String? value) {
    if (value == null || value.isEmpty) return 'Brand is required';
    if (value.length > 50) return 'Brand must be 50 characters or less';
    return null;
  }

  String? validateModel(String? value) {
    if (value == null || value.isEmpty) return 'Model is required';
    if (value.length > 50) return 'Model must be 50 characters or less';
    return null;
  }

  String? validatePlate(String? value) {
    if (value == null || value.isEmpty) return 'Plate is required';
    if (value.length > 20) return 'Plate must be 20 characters or less';
    return null;
  }

  String? validateYear(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final v = int.tryParse(value);
    if (v == null || v < 1900 || v > 2100) {
      return 'Enter a year between 1900 and 2100';
    }
    return null;
  }

  String? validateMeterReading(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final v = int.tryParse(value);
    if (v == null || v < 0) return 'Enter a valid meter reading';
    return null;
  }
}
