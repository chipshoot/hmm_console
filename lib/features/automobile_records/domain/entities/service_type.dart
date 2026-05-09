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
