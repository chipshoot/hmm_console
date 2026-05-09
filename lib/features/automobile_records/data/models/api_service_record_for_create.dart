import 'api_part_item.dart';

class ApiServiceRecordForCreate {
  const ApiServiceRecordForCreate({
    required this.date,
    required this.mileage,
    required this.type,
    this.description,
    this.cost,
    this.currency = 'CAD',
    this.shopName,
    this.parts = const [],
    this.notes,
  });

  final DateTime date;
  final int mileage;
  final String type;
  final String? description;
  final double? cost;
  final String currency;
  final String? shopName;
  final List<ApiPartItem> parts;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'date': date.toUtc().toIso8601String(),
        'mileage': mileage,
        'type': type,
        if (description != null) 'description': description,
        if (cost != null) 'cost': cost,
        'currency': currency,
        if (shopName != null) 'shopName': shopName,
        'parts': parts.map((p) => p.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };
}
