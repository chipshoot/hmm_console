import 'dart:typed_data';

import '../../automobile_records/domain/entities/line_item_type.dart';
import '../../automobile_records/domain/entities/service_type.dart';

/// Which extractor produced (or should produce) a receipt draft. Persisted as
/// a user preference; mirrors the DataMode selection pattern.
enum ReceiptExtractorMode {
  onDevice('onDevice'),
  cloudAi('cloudAi'),
  provider('provider');

  const ReceiptExtractorMode(this.wire);

  /// Stable value used in persistence and on the wire.
  final String wire;

  /// Inverse of [wire]; tolerant — unknown/null falls back to [onDevice].
  static ReceiptExtractorMode fromWire(String? s) =>
      ReceiptExtractorMode.values.firstWhere(
        (m) => m.wire == s,
        orElse: () => ReceiptExtractorMode.onDevice,
      );
}

/// The raw receipt handed to an extractor.
class ReceiptInput {
  const ReceiptInput({
    required this.bytes,
    required this.contentType,
    this.sensitive = false,
  });

  final Uint8List bytes;

  /// `image/jpeg|png|heic|webp` or `application/pdf`.
  final String contentType;

  final bool sensitive;

  bool get isPdf => contentType == 'application/pdf';
}

/// One extracted line item — maps 1:1 to a service-record [PartItem].
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.type,
    required this.name,
    this.quantity = 1,
    this.unitCost,
    this.amount,
  });

  final LineItemType type;
  final String name;
  final int quantity;
  final double? unitCost;

  /// Printed line total from the receipt; the authoritative signal used to
  /// reconcile [quantity] / [unitCost]. Null when the receipt doesn't show it.
  final double? amount;
}

/// Extractor-agnostic result. Every field is optional — an extractor fills what
/// it can find; anything unfound stays null and the form field is left for the
/// user.
class ReceiptDraft {
  const ReceiptDraft({
    required this.source,
    this.shopName,
    this.date,
    this.odometer,
    this.serviceType,
    this.lineItems = const [],
    this.tax,
    this.total,
    this.currency,
    this.rawText,
  });

  final ReceiptExtractorMode source;
  final String? shopName;
  final DateTime? date;

  /// Odometer reading if present on the receipt; maps to ServiceRecord.mileage.
  final int? odometer;
  final ServiceType? serviceType;
  final List<ReceiptLineItem> lineItems;
  final double? tax;

  /// Grand total, used only to cross-check the itemized total — not stored.
  final double? total;
  final String? currency;

  /// OCR text / model notes, for debugging and the on-device fallback.
  final String? rawText;
}

/// Thrown by an extractor when it cannot produce a draft (network, no text,
/// model error). The UI surfaces this; the user enters the record manually.
class ReceiptExtractionException implements Exception {
  const ReceiptExtractionException(this.message);
  final String message;

  @override
  String toString() => 'ReceiptExtractionException: $message';
}

/// Maps an extractor's JSON (server or AI provider) to a [ReceiptDraft].
///
/// Deliberately tolerant — a mistyped or missing field degrades to null rather
/// than discarding the whole draft. Keys fall back from camelCase to
/// PascalCase so a serializer-config regression can't silently blank the
/// extracted fields (the bug that once shipped).
ReceiptDraft receiptDraftFromJson(
  Map<String, dynamic> j,
  ReceiptExtractorMode source,
) {
  final rawItems = _get(j, 'lineItems');
  final items = rawItems is List ? rawItems : const [];
  final date = _asString(_get(j, 'date'));
  return ReceiptDraft(
    source: source,
    shopName: _asString(_get(j, 'shopName')),
    date: date != null ? DateTime.tryParse(date) : null,
    odometer: _asNum(_get(j, 'odometer'))?.toInt(),
    tax: _asNum(_get(j, 'tax'))?.toDouble(),
    total: _asNum(_get(j, 'total'))?.toDouble(),
    currency: _asString(_get(j, 'currency')),
    lineItems: [
      for (final it in items)
        if (it is Map)
          ReceiptLineItem(
            type: LineItemType.fromWire(_asString(_get(it, 'type'))),
            name: _asString(_get(it, 'name')) ?? '',
            quantity: _asNum(_get(it, 'quantity'))?.toInt() ?? 1,
            unitCost: _asNum(_get(it, 'unitCost'))?.toDouble(),
            amount: _asNum(_get(it, 'amount'))?.toDouble(),
          ),
    ],
  );
}

dynamic _get(Map<dynamic, dynamic> j, String camel) {
  if (j.containsKey(camel)) return j[camel];
  final pascal = camel[0].toUpperCase() + camel.substring(1);
  return j[pascal];
}

String? _asString(dynamic v) => v is String ? v : null;

num? _asNum(dynamic v) => v is num ? v : null;
