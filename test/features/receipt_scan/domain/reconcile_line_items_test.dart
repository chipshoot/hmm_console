import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:hmm_console/features/receipt_scan/domain/reconcile_line_items.dart';

ReceiptLineItem _li({int quantity = 1, double? unitCost, double? amount}) =>
    ReceiptLineItem(
        type: LineItemType.part,
        name: 'x',
        quantity: quantity,
        unitCost: unitCost,
        amount: amount);

void main() {
  test('fixes quantity from amount / unitCost (the Shp case)', () {
    final r = reconcileLineItem(_li(quantity: 1, unitCost: 17.95, amount: 125.65));
    expect(r.item.quantity, 7);
    expect(r.adjusted, isTrue);
  });

  test('fills a missing unit price from amount / quantity', () {
    final r = reconcileLineItem(_li(quantity: 4, unitCost: null, amount: 32));
    expect(r.item.unitCost, 8);
    expect(r.adjusted, isTrue);
  });

  test('leaves an already-consistent line unchanged', () {
    final r = reconcileLineItem(_li(quantity: 1, unitCost: 40, amount: 40));
    expect(r.item.quantity, 1);
    expect(r.adjusted, isFalse);
  });

  test('does not fabricate a quantity when the ratio is not a clean integer', () {
    final r = reconcileLineItem(_li(quantity: 1, unitCost: 3, amount: 10));
    expect(r.item.quantity, 1);
    expect(r.adjusted, isFalse);
  });

  test('skips when amount is missing, zero, or negative', () {
    expect(reconcileLineItem(_li(quantity: 1, unitCost: 5, amount: null)).adjusted,
        isFalse);
    expect(reconcileLineItem(_li(quantity: 1, unitCost: 5, amount: 0)).adjusted,
        isFalse);
    expect(reconcileLineItem(_li(quantity: 1, unitCost: 5, amount: -5)).adjusted,
        isFalse);
  });

  test('skips quantity fix when unitCost is zero', () {
    final r = reconcileLineItem(_li(quantity: 2, unitCost: 0, amount: 10));
    expect(r.item.unitCost, 5); // falls through to unit-price fill
    expect(r.adjusted, isTrue);
  });

  test('passes through when derived quantity would be < 1 (amount < unitCost)', () {
    final r = reconcileLineItem(_li(quantity: 1, unitCost: 40, amount: 10));
    expect(r.item.quantity, 1);
    expect(r.adjusted, isFalse);
  });

  test('accepts a small discrepancy within the relative tolerance', () {
    // 10000.40 / 2000 -> 5; 5*2000=10000, diff 0.40 <= 1% of amount (100).
    final r = reconcileLineItem(_li(quantity: 1, unitCost: 2000, amount: 10000.40));
    expect(r.item.quantity, 5);
    expect(r.adjusted, isTrue);
  });

  test('does not mutate the input line item', () {
    final input = _li(quantity: 1, unitCost: 17.95, amount: 125.65);
    final r = reconcileLineItem(input);
    expect(input.quantity, 1);
    expect(identical(r.item, input), isFalse);
  });

  test('is total on a non-finite unit price (recovers, does not throw)', () {
    final r = reconcileLineItem(
        _li(quantity: 2, unitCost: double.infinity, amount: 100));
    expect(r.item.unitCost, 50); // unusable unit price -> filled from amount/qty
    expect(r.adjusted, isTrue);
  });
}
