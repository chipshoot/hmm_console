/// Service categories that mirror the backend `ServiceType` enum.
enum ServiceType {
  oilChange,
  tireRotation,
  brake,
  inspection,
  repair,
  other;

  /// Backend wire value (PascalCase, matches C# enum names).
  String get wireValue => switch (this) {
        ServiceType.oilChange => 'OilChange',
        ServiceType.tireRotation => 'TireRotation',
        ServiceType.brake => 'Brake',
        ServiceType.inspection => 'Inspection',
        ServiceType.repair => 'Repair',
        ServiceType.other => 'Other',
      };

  /// English name used in **stored data**, not on screen.
  ///
  /// `LocalServiceRecordRepository._subjectFor` composes this into a note
  /// subject that is persisted and synced, so it must stay stable and
  /// untranslated — otherwise the same record would carry a different subject
  /// depending on the device's language.
  ///
  /// For anything a user reads, use `ServiceTypeLabels.label(l)` from
  /// `presentation/record_labels.dart`.
  String get displayName => switch (this) {
        ServiceType.oilChange => 'Oil change',
        ServiceType.tireRotation => 'Tire rotation',
        ServiceType.brake => 'Brake',
        ServiceType.inspection => 'Inspection',
        ServiceType.repair => 'Repair',
        ServiceType.other => 'Other',
      };

  static ServiceType fromWire(String? value) {
    return switch (value) {
      'OilChange' => ServiceType.oilChange,
      'TireRotation' => ServiceType.tireRotation,
      'Brake' => ServiceType.brake,
      'Inspection' => ServiceType.inspection,
      'Repair' => ServiceType.repair,
      _ => ServiceType.other,
    };
  }
}
