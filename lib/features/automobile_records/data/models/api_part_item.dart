class ApiPartItem {
  const ApiPartItem({
    required this.name,
    this.quantity = 1,
    this.unitCost,
    this.currency,
  });

  final String name;
  final int quantity;
  final double? unitCost;
  final String? currency;

  factory ApiPartItem.fromJson(Map<String, dynamic> json) {
    return ApiPartItem(
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitCost: (json['unitCost'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        if (unitCost != null) 'unitCost': unitCost,
        if (currency != null) 'currency': currency,
      };
}
