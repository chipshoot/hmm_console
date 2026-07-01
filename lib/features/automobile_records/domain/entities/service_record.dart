import '../../../../core/data/attachments/attachment_ref.dart';
import 'line_item_type.dart';
import 'part_item.dart';
import 'service_type.dart';

/// Append-only service-history record for a vehicle. One record per
/// service event. Mirrors the backend `ServiceRecord` note served from
/// `/v1/automobiles/{autoId}/services`.
class ServiceRecord {
  ServiceRecord({
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
    NoteAttachments? attachments,
  }) : attachments = attachments ?? NoteAttachments.empty;

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

  /// Read-through projection of the owning note's attachments column
  /// (images + PDF files). Empty when the record has none.
  final NoteAttachments attachments;

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

  ServiceRecord copyWith({
    int? id,
    int? automobileId,
    DateTime? date,
    int? mileage,
    ServiceType? type,
    String? description,
    double? cost,
    String? currency,
    String? shopName,
    List<PartItem>? parts,
    double? tax,
    String? notes,
    DateTime? createdDate,
    NoteAttachments? attachments,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      automobileId: automobileId ?? this.automobileId,
      date: date ?? this.date,
      mileage: mileage ?? this.mileage,
      type: type ?? this.type,
      description: description ?? this.description,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      shopName: shopName ?? this.shopName,
      parts: parts ?? this.parts,
      tax: tax ?? this.tax,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
      attachments: attachments ?? this.attachments,
    );
  }
}
