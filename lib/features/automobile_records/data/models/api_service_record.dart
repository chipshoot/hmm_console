import 'api_part_item.dart';

class ApiServiceRecord {
  const ApiServiceRecord({
    required this.id,
    required this.automobileId,
    required this.date,
    this.mileage = 0,
    this.type = 'Other',
    this.types = const [],
    this.name,
    this.referenceNumber,
    this.description,
    this.cost,
    this.tax,
    this.currency,
    this.shopName,
    this.parts = const [],
    this.notes,
    this.createdDate,
  });

  final int id;
  final int automobileId;
  final DateTime date;
  final int mileage;

  /// Legacy scalar category, read from older backends as a fallback when
  /// [types] is absent.
  final String type;

  /// Multi-select category tags. Empty when reading a legacy payload.
  final List<String> types;
  final String? name;
  final String? referenceNumber;
  final String? description;
  final double? cost;
  final double? tax;
  final String? currency;
  final String? shopName;
  final List<ApiPartItem> parts;
  final String? notes;
  final DateTime? createdDate;

  factory ApiServiceRecord.fromJson(Map<String, dynamic> json) {
    return ApiServiceRecord(
      id: json['id'] as int,
      automobileId: json['automobileId'] as int? ?? 0,
      date: DateTime.parse(json['date'] as String),
      mileage: json['mileage'] as int? ?? 0,
      type: json['type'] as String? ?? 'Other',
      types: (json['types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      name: json['name'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      description: json['description'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      shopName: json['shopName'] as String?,
      parts: (json['parts'] as List<dynamic>?)
              ?.map((e) => ApiPartItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      notes: json['notes'] as String?,
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'] as String)
          : null,
    );
  }
}
