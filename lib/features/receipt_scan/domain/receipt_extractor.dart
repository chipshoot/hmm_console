import 'receipt_draft.dart';

/// Extracts a [ReceiptDraft] from a receipt image/PDF. Implementations fill
/// what they can; unfound fields stay null. Throws
/// [ReceiptExtractionException] on failure.
abstract interface class ReceiptExtractor {
  Future<ReceiptDraft> extract(ReceiptInput input);
}
