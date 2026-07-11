import 'api_part_item.dart';

class ApiServiceRecordForUpdate {
  const ApiServiceRecordForUpdate({
    this.date,
    this.mileage,
    this.type,
    this.types,
    this.name,
    this.referenceNumber,
    this.description,
    this.cost,
    this.tax,
    this.currency,
    this.shopName,
    this.parts,
    this.notes,
  });

  final DateTime? date;
  final int? mileage;

  /// Legacy scalar category, still sent for one release for older backends.
  final String? type;

  /// Multi-select category tags. The current backend reads these.
  final List<String>? types;
  final String? name;
  final String? referenceNumber;
  final String? description;
  final double? cost;
  final double? tax;
  final String? currency;
  final String? shopName;
  final List<ApiPartItem>? parts;
  final String? notes;

  Map<String, dynamic> toJson() => {
        if (date != null) 'date': date!.toUtc().toIso8601String(),
        if (mileage != null) 'mileage': mileage,
        if (type != null) 'type': type,
        if (types != null) 'types': types,
        if (name != null) 'name': name,
        if (referenceNumber != null) 'referenceNumber': referenceNumber,
        if (description != null) 'description': description,
        if (cost != null) 'cost': cost,
        if (tax != null) 'tax': tax,
        if (currency != null) 'currency': currency,
        if (shopName != null) 'shopName': shopName,
        if (parts != null) 'parts': parts!.map((p) => p.toJson()).toList(),
        if (notes != null) 'notes': notes,
      };
}
