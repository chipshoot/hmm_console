import '../domain/apply_draft.dart';
import '../domain/receipt_draft.dart';
import '../domain/receipt_extractor.dart';

/// Outcome of a scan: either the draft applied to the form, or a failure with a
/// user-facing message. Never thrown — the form always continues to manual
/// entry.
sealed class ScanResult {
  const ScanResult();
}

class ScanSuccess extends ScanResult {
  const ScanSuccess(this.applied);
  final ApplyDraftResult applied;
}

class ScanFailure extends ScanResult {
  const ScanFailure(this.message);
  final String message;
}

/// Run the extractor on [input] and merge the resulting draft into [current].
///
/// Keeping the receipt as an attachment is the caller's concern (the form
/// reuses its pending-pick machinery); this helper is pure orchestration over
/// the extractor + [applyDraft], so it stays trivially testable.
Future<ScanResult> scanReceipt({
  required ReceiptExtractor extractor,
  required ReceiptInput input,
  required ScanFormValues current,
}) async {
  try {
    final draft = await extractor.extract(input);
    return ScanSuccess(applyDraft(current, draft));
  } on ReceiptExtractionException catch (e) {
    return ScanFailure(e.message);
  } catch (e) {
    return ScanFailure('Could not scan the receipt: $e');
  }
}
