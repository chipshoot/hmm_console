/// Category of a service-record line item. Mirrors the backend
/// `LineItemType` enum (PascalCase wire names).
enum LineItemType {
  labour,
  part,
  fee;

  String get wireName => switch (this) {
        LineItemType.labour => 'Labour',
        LineItemType.part => 'Part',
        LineItemType.fee => 'Fee',
      };

  String get displayName => switch (this) {
        LineItemType.labour => 'Labour',
        LineItemType.part => 'Part',
        LineItemType.fee => 'Fee',
      };

  static LineItemType fromWire(String? value) => switch (value) {
        'Labour' => LineItemType.labour,
        'Fee' => LineItemType.fee,
        _ => LineItemType.part,
      };
}
