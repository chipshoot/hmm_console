import '../../../l10n/gen/app_localizations.dart';
import '../domain/entities/line_item_type.dart';
import '../domain/entities/service_type.dart';

/// UI labels for the service-record enums.
///
/// These enums already separate their wire values ([ServiceType.wireValue],
/// [LineItemType.wireName]) from display text, so unlike the gas-log dropdowns
/// there is no risk here of translating something that gets sent to the API.
///
/// There *is* a subtler hazard, and it is why `ServiceType.displayName` is
/// still English and still exists: `LocalServiceRecordRepository._subjectFor`
/// builds a note **subject** from it —
///
///     '${r.primaryType.displayName} • $d • ${r.mileage} mi'
///
/// and that subject is persisted in the Notes table and synced. Localizing
/// `displayName` in place would give a record created on a Chinese device a
/// different stored subject from the identical record created in English, and
/// the two would stop lining up across a user's own devices.
///
/// So the split here is by *audience*, not by layer:
///
/// * `ServiceType.displayName` — goes into stored data. Stays English.
/// * [ServiceTypeLabels.label] — goes on screen. Translated.
///
/// Anything user-visible should use `.label(l)`. Reaching for `.displayName`
/// in a widget is the bug this file exists to prevent.
extension ServiceTypeLabels on ServiceType {
  String label(AppLocalizations l) => switch (this) {
        ServiceType.oilChange => l.serviceTypeOilChange,
        ServiceType.tireRotation => l.serviceTypeTireRotation,
        ServiceType.brake => l.serviceTypeBrake,
        ServiceType.inspection => l.serviceTypeInspection,
        ServiceType.repair => l.serviceTypeRepair,
        ServiceType.other => l.serviceTypeOther,
      };
}

extension LineItemTypeLabels on LineItemType {
  String label(AppLocalizations l) => switch (this) {
        LineItemType.labour => l.lineItemLabour,
        LineItemType.part => l.lineItemPart,
        LineItemType.fee => l.lineItemFee,
      };
}
