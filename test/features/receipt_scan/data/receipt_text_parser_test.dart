import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/data/receipt_text_parser.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

const _sample = '''
BOB'S AUTO SERVICE
123 Main St
Date: 2026-03-02
Oil Change        40.00
Oil Filter        10.00
GST               3.50
TOTAL            53.50
''';

const _usDate = '''
QUICK LUBE
Invoice 03/02/2026
Subtotal 50.00
Sales Tax 3.50
Balance Due 53.50
''';

void main() {
  const parser = ReceiptTextParser();

  test('pulls shop, date, tax, total from typical text', () {
    final d = parser.parse(_sample);
    expect(d.shopName, "BOB'S AUTO SERVICE");
    expect(d.date, DateTime(2026, 3, 2));
    expect(d.tax, 3.50);
    expect(d.total, 53.50);
    expect(d.lineItems, isEmpty);
    expect(d.rawText, _sample);
    expect(d.source, ReceiptExtractorMode.onDevice);
  });

  test('handles US-style date and "balance due" total, ignores subtotal', () {
    final d = parser.parse(_usDate);
    expect(d.shopName, 'QUICK LUBE');
    expect(d.date, DateTime(2026, 3, 2));
    expect(d.tax, 3.50);
    expect(d.total, 53.50); // "Balance Due", not the 50.00 subtotal
  });

  test('returns nulls (never throws) on empty/garbage', () {
    final d = parser.parse('   \n  ');
    expect(d.total, isNull);
    expect(d.shopName, isNull);
    expect(d.date, isNull);
    expect(d.tax, isNull);
  });
}
