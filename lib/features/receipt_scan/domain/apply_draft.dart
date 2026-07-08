import '../../automobile_records/domain/entities/part_item.dart';
import '../../automobile_records/domain/entities/service_type.dart';
import 'receipt_draft.dart';
import 'reconcile_line_items.dart';

/// Snapshot of the scalar + line-item fields a receipt scan can fill. The form
/// maps its controllers to/from this value object.
class ScanFormValues {
  const ScanFormValues({
    this.shopName,
    this.date,
    this.mileage,
    this.type,
    this.tax,
    this.currency,
    this.items = const [],
  });

  factory ScanFormValues.empty() => const ScanFormValues();

  final String? shopName;
  final DateTime? date;
  final int? mileage;
  final ServiceType? type;
  final double? tax;
  final String? currency;
  final List<PartItem> items;

  ScanFormValues copyWith({
    String? shopName,
    DateTime? date,
    int? mileage,
    ServiceType? type,
    double? tax,
    String? currency,
    List<PartItem>? items,
  }) =>
      ScanFormValues(
        shopName: shopName ?? this.shopName,
        date: date ?? this.date,
        mileage: mileage ?? this.mileage,
        type: type ?? this.type,
        tax: tax ?? this.tax,
        currency: currency ?? this.currency,
        items: items ?? this.items,
      );
}

/// Outcome of [applyDraft] — the merged values plus what changed, so the UI can
/// report it and warn on a totals mismatch.
class ApplyDraftResult {
  const ApplyDraftResult({
    required this.values,
    required this.filledScalarCount,
    required this.appendedItemCount,
    required this.adjustedItemCount,
    required this.totalsMismatch,
  });

  final ScanFormValues values;
  final int filledScalarCount;
  final int appendedItemCount;
  final int adjustedItemCount;
  final bool totalsMismatch;
}

/// Pure, least-surprise merge: fills only currently-empty scalar fields (never
/// overwrites what the user already typed), appends the draft's line items to
/// any existing rows, and flags a soft totals mismatch.
ApplyDraftResult applyDraft(ScanFormValues form, ReceiptDraft draft) {
  var filled = 0;
  bool isBlank(Object? v) => v == null || (v is String && v.trim().isEmpty);

  var shopName = form.shopName;
  if (isBlank(shopName) && !isBlank(draft.shopName)) {
    shopName = draft.shopName;
    filled++;
  }
  var date = form.date;
  if (date == null && draft.date != null) {
    date = draft.date;
    filled++;
  }
  var mileage = form.mileage;
  if (mileage == null && draft.odometer != null) {
    mileage = draft.odometer;
    filled++;
  }
  var type = form.type;
  if (type == null && draft.serviceType != null) {
    type = draft.serviceType;
    filled++;
  }
  var tax = form.tax;
  if (tax == null && draft.tax != null) {
    tax = draft.tax;
    filled++;
  }
  var currency = form.currency;
  if (isBlank(currency) && !isBlank(draft.currency)) {
    currency = draft.currency;
    filled++;
  }

  // Skip line items identical to ones already on the form (same type, name,
  // quantity, unit cost) so re-scanning the same receipt doesn't stack
  // duplicate rows. Dedup is only against the pre-scan items, so legitimate
  // repeats within a single receipt are preserved.
  bool alreadyOnForm(ReceiptLineItem li) => form.items.any((p) =>
      p.type == li.type &&
      p.name.trim().toLowerCase() == li.name.trim().toLowerCase() &&
      p.quantity == li.quantity &&
      p.unitCost == li.unitCost);

  // Reconcile each line from its printed amount BEFORE the dedup check, so a
  // re-scan of the same receipt (raw qty 1 -> reconciled qty 7) matches the
  // already-appended reconciled row and is skipped rather than duplicated.
  var adjusted = 0;
  final appended = <PartItem>[];
  for (final li in draft.lineItems) {
    final rec = reconcileLineItem(li);
    if (alreadyOnForm(rec.item)) continue;
    if (rec.adjusted) adjusted++;
    appended.add(PartItem(
      type: rec.item.type,
      name: rec.item.name,
      quantity: rec.item.quantity,
      unitCost: rec.item.unitCost,
      currency: currency ?? form.currency ?? 'CAD',
    ));
  }
  final items = [...form.items, ...appended];

  // Totals mismatch: compare the draft's stated total against the computed
  // subtotal (sum of the appended items) + tax. Only meaningful when items were
  // actually itemized — a bare total with no line items (the on-device case)
  // would otherwise always "mismatch" (subtotal 0).
  var mismatch = false;
  if (draft.total != null && appended.isNotEmpty) {
    final subtotal = appended.fold<double>(0, (s, p) => s + p.lineTotal);
    final computed = subtotal + (tax ?? 0);
    mismatch = (computed - draft.total!).abs() > 0.01;
  }

  return ApplyDraftResult(
    values: form.copyWith(
      shopName: shopName,
      date: date,
      mileage: mileage,
      type: type,
      tax: tax,
      currency: currency,
      items: items,
    ),
    filledScalarCount: filled,
    appendedItemCount: appended.length,
    adjustedItemCount: adjusted,
    totalsMismatch: mismatch,
  );
}
