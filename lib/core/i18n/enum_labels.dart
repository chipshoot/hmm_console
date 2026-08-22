import '../../features/settings/domain/gas_log_units.dart';
import '../../l10n/gen/app_localizations.dart';
import '../data/data_mode.dart';

/// Localized display copy for the settings enums.
///
/// These labels used to live on the enums themselves as
/// `String get displayName => apiValue`, which made the text in a dropdown the
/// *same string* that gets persisted and sent to the API. Translating it there
/// would have written "公里" into the saved settings and onto the wire, and
/// `fromApiValue` would no longer have recognised it — a corrupted setting
/// rather than a cosmetic bug.
///
/// So the split is deliberate and load-bearing:
///
/// * `apiValue` / `fromApiValue` — the persistence contract. Literal, stable,
///   never translated, never shown to anyone.
/// * these extensions — what a person reads. Translated freely; nothing
///   downstream parses them.
///
/// Lives in `core/i18n` rather than the settings feature because the
/// dashboard's defaults card renders the same enums.
///
/// The accessor is `displayName(l)` and deliberately **not** `label(l)`:
/// [DistanceUnit] and [FuelUnit] already carry a `label` getter for the unit
/// symbol ("mi", "L"), and an instance getter shadows an extension method of
/// the same name. `u.label(l)` would therefore resolve to the getter and try to
/// call a String — it fails to compile here, but the same clash on a getter
/// returning a function type would compile and silently do the wrong thing.
extension DataModeLabels on DataMode {
  String displayName(AppLocalizations l) => switch (this) {
        DataMode.local => l.dataModeLocal,
        DataMode.cloudStorage => l.dataModeCloudStorage,
        DataMode.cloudApi => l.dataModeCloudApi,
      };

  String describe(AppLocalizations l) => switch (this) {
        DataMode.local => l.dataModeLocalDescription,
        DataMode.cloudStorage => l.dataModeCloudStorageDescription,
        DataMode.cloudApi => l.dataModeCloudApiDescription,
      };
}

extension CloudProviderLabels on CloudProvider {
  /// OneDrive is a brand name, so it reads the same in every locale. It stays a
  /// lookup rather than a bare literal so a second provider cannot be added
  /// without someone deciding what to call it.
  String displayName(AppLocalizations l) => switch (this) {
        CloudProvider.onedrive => 'OneDrive',
      };
}

extension DistanceUnitLabels on DistanceUnit {
  String displayName(AppLocalizations l) => switch (this) {
        DistanceUnit.mile => l.unitMile,
        DistanceUnit.kilometer => l.unitKilometer,
      };
}

extension FuelUnitLabels on FuelUnit {
  String displayName(AppLocalizations l) => switch (this) {
        FuelUnit.gallon => l.unitGallon,
        FuelUnit.liter => l.unitLiter,
      };
}

extension CurrencyCodeLabels on CurrencyCode {
  /// ISO 4217 codes are not translated — CAD is CAD in every locale, and a
  /// translated code would be unreadable beside an amount. Routed through here
  /// anyway so every enum on this screen is labelled the same way, and so the
  /// choice is written down rather than implied by a bare `apiValue` at the
  /// call site.
  String displayName(AppLocalizations l) => apiValue;
}
