import '../../automobile_records/domain/entities/part_item.dart';
import '../../automobile_records/domain/entities/service_type.dart';
import 'receipt_draft.dart';

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
    required this.totalsMismatch,
  });

  final ScanFormValues values;
  final int filledScalarCount;
  final int appendedItemCount;
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

  final appended = [
    for (final li in draft.lineItems)
      PartItem(
        type: li.type,
        name: li.name,
        quantity: li.quantity,
        unitCost: li.unitCost,
        currency: currency ?? form.currency ?? 'CAD',
      ),
  ];
  final items = [...form.items, ...appended];

  // Totals mismatch: compare the draft's stated total against the computed
  // subtotal (sum of the appended items) + tax, when a total is present.
  var mismatch = false;
  if (draft.total != null) {
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
    totalsMismatch: mismatch,
  );
}
