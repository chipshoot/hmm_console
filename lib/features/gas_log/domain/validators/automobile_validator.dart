import '../../../../l10n/gen/app_localizations.dart';

/// Form validation for the vehicle create / edit screens.
///
/// Takes an [AppLocalizations] per call rather than resolving one from a
/// `BuildContext`: the mixin carries no `on State` constraint (the tests apply
/// it to a plain class), and a validator handed its inputs is easier to test
/// than one reaching for ambient state.
mixin AutomobileValidator {
  String? validateVin(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationVinRequired;
    if (value.length != 17) return l.validationVinLength;
    return null;
  }

  String? validateMaker(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationMakerRequired;
    if (value.length > 50) return l.validationMakerTooLong;
    return null;
  }

  String? validateBrand(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationBrandRequired;
    if (value.length > 50) return l.validationBrandTooLong;
    return null;
  }

  String? validateModel(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationModelRequired;
    if (value.length > 50) return l.validationModelTooLong;
    return null;
  }

  String? validatePlate(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationPlateRequired;
    if (value.length > 20) return l.validationPlateTooLong;
    return null;
  }

  String? validateYear(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return l.validationYearRequired;
    final v = int.tryParse(value);
    if (v == null || v < 1900 || v > 2100) {
      return l.validationYearRange(1900, 2100);
    }
    return null;
  }

  String? validateMeterReading(String? value, AppLocalizations l) {
    if (value == null || value.isEmpty) return null; // optional
    final v = int.tryParse(value);
    if (v == null || v < 0) return l.vehicleInvalidMeterReading;
    return null;
  }
}
