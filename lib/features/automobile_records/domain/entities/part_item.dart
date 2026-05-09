/// A part / labour line on a service record. Nested JSON inside the
/// ServiceRecord note on the backend; plain value object on the client.
class PartItem {
  const PartItem({
    required this.name,
    this.quantity = 1,
    this.unitCost,
    this.currency = 'CAD',
  });

  final String name;
  final int quantity;
  final double? unitCost;
  final String currency;

  double get lineTotal => (unitCost ?? 0) * quantity;

  PartItem copyWith({
    String? name,
    int? quantity,
    double? unitCost,
    String? currency,
  }) {
    return PartItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      currency: currency ?? this.currency,
    );
  }
}
