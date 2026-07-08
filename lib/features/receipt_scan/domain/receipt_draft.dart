import 'dart:typed_data';

import '../../automobile_records/domain/entities/line_item_type.dart';
import '../../automobile_records/domain/entities/service_type.dart';

/// Which extractor produced (or should produce) a receipt draft. Persisted as
/// a user preference; mirrors the DataMode selection pattern.
enum ReceiptExtractorMode {
  onDevice('onDevice'),
  cloudAi('cloudAi');

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
  const ReceiptInput({required this.bytes, required this.contentType});

  final Uint8List bytes;

  /// `image/jpeg|png|heic|webp` or `application/pdf`.
  final String contentType;

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
