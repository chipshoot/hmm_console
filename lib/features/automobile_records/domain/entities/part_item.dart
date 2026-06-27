import 'line_item_type.dart';

/// A part / labour / fee line on a service record. Nested JSON inside the
/// ServiceRecord note on the backend; plain value object on the client.
class PartItem {
  const PartItem({
    required this.name,
    this.type = LineItemType.part,
    this.quantity = 1,
    this.unitCost,
    this.currency = 'CAD',
  });

  final LineItemType type;
  final String name;
  final int quantity;
  final double? unitCost;
  final String currency;

  double get lineTotal => (unitCost ?? 0) * quantity;

  PartItem copyWith({
    LineItemType? type,
    String? name,
    int? quantity,
    double? unitCost,
    String? currency,
  }) {
    return PartItem(
      type: type ?? this.type,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      currency: currency ?? this.currency,
    );
  }
}
