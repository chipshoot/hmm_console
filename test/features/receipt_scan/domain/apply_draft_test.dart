import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/receipt_scan/domain/apply_draft.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

ReceiptDraft _draft() => ReceiptDraft(
      source: ReceiptExtractorMode.cloudAi,
      shopName: 'Bob Auto',
      date: DateTime(2026, 3, 2),
      odometer: 45000,
      tax: 3.5,
      total: 53.5,
      currency: 'CAD',
      lineItems: const [
        ReceiptLineItem(
            type: LineItemType.labour, name: 'Oil change', unitCost: 40),
        ReceiptLineItem(type: LineItemType.part, name: 'Filter', unitCost: 10),
      ],
    );

void main() {
  test('fills empty scalars and appends line items', () {
    final before = ScanFormValues.empty();
    final r = applyDraft(before, _draft());
    expect(r.values.shopName, 'Bob Auto');
    expect(r.values.mileage, 45000);
    expect(r.values.tax, 3.5);
    expect(r.values.currency, 'CAD');
    expect(r.values.items, hasLength(2));
    expect(r.filledScalarCount, greaterThan(0));
    expect(r.appendedItemCount, 2);
    expect(r.totalsMismatch, isFalse);
  });

  test('never overwrites a filled scalar', () {
    final before = ScanFormValues.empty().copyWith(shopName: 'My Shop');
    final r = applyDraft(before, _draft());
    expect(r.values.shopName, 'My Shop');
  });

  test('appends items onto existing ones', () {
    final before = ScanFormValues.empty().copyWith(
      items: const [
        PartItem(type: LineItemType.fee, name: 'Shop fee', unitCost: 5)
      ],
    );
    final r = applyDraft(before, _draft());
    expect(r.values.items, hasLength(3));
  });

  test('flags a totals mismatch', () {
    final mismatch = ReceiptDraft(
      source: ReceiptExtractorMode.cloudAi,
      total: 999,
      tax: 3.5,
      lineItems: const [
        ReceiptLineItem(type: LineItemType.labour, name: 'x', unitCost: 40),
      ],
    );
    final r = applyDraft(ScanFormValues.empty(), mismatch);
    expect(r.totalsMismatch, isTrue);
  });
}
