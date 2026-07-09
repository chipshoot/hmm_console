import 'api_part_item.dart';

class ApiServiceRecordForCreate {
  const ApiServiceRecordForCreate({
    required this.date,
    required this.mileage,
    required this.type,
    this.types = const [],
    this.name,
    this.referenceNumber,
    this.description,
    this.cost,
    this.tax,
    this.currency = 'CAD',
    this.shopName,
    this.parts = const [],
    this.notes,
  });

  final DateTime date;
  final int mileage;

  /// Legacy scalar category, still sent for one release so an older backend
  /// that only reads `type` keeps working.
  final String type;

  /// Multi-select category tags. The current backend reads these.
  final List<String> types;
  final String? name;
  final String? referenceNumber;
  final String? description;
  final double? cost;
  final double? tax;
  final String currency;
  final String? shopName;
  final List<ApiPartItem> parts;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'date': date.toUtc().toIso8601String(),
        'mileage': mileage,
        'type': type,
        'types': types,
        if (name != null) 'name': name,
        if (referenceNumber != null) 'referenceNumber': referenceNumber,
        if (description != null) 'description': description,
        if (cost != null) 'cost': cost,
        if (tax != null) 'tax': tax,
        'currency': currency,
        if (shopName != null) 'shopName': shopName,
        'parts': parts.map((p) => p.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };
}
