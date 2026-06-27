import 'line_item_type.dart';
import 'part_item.dart';
import 'service_type.dart';

/// Append-only service-history record for a vehicle. One record per
/// service event. Mirrors the backend `ServiceRecord` note served from
/// `/v1/automobiles/{autoId}/services`.
class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.automobileId,
    required this.date,
    required this.mileage,
    required this.type,
    this.description,
    this.cost,
    this.currency = 'CAD',
    this.shopName,
    this.parts = const [],
    this.tax,
    this.notes,
    this.createdDate,
  });

  final int id;
  final int automobileId;
  final DateTime date;
  final int mileage;
  final ServiceType type;
  final String? description;
  final double? cost;
  final String currency;
  final String? shopName;
  final List<PartItem> parts;
  final double? tax;
  final String? notes;
  final DateTime? createdDate;

  double _totalFor(LineItemType t) =>
      parts.where((p) => p.type == t).fold(0.0, (s, p) => s + p.lineTotal);

  double get labourTotal => _totalFor(LineItemType.labour);
  double get partsTotal => _totalFor(LineItemType.part);
  double get feesTotal => _totalFor(LineItemType.fee);
  double get subtotal => labourTotal + partsTotal + feesTotal;
  double get grandTotal => subtotal + (tax ?? 0);

  /// Total to show: the computed grand total when itemized, else the legacy
  /// flat cost (0 when neither exists).
  double get effectiveTotal => parts.isNotEmpty ? grandTotal : (cost ?? 0);
}
