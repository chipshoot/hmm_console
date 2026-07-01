import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/receipt_scan/domain/apply_draft.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_extractor.dart';
import 'package:hmm_console/features/receipt_scan/presentation/scan_receipt_flow.dart';

class _FixedExtractor implements ReceiptExtractor {
  _FixedExtractor(this.draft);
  final ReceiptDraft draft;
  @override
  Future<ReceiptDraft> extract(ReceiptInput input) async => draft;
}

class _FailingExtractor implements ReceiptExtractor {
  @override
  Future<ReceiptDraft> extract(ReceiptInput input) async =>
      throw const ReceiptExtractionException('boom');
}

ReceiptInput _input() =>
    ReceiptInput(bytes: Uint8List(1), contentType: 'image/jpeg');

void main() {
  test('success applies the draft to the current form values', () async {
    final draft = ReceiptDraft(
      source: ReceiptExtractorMode.onDevice,
      shopName: 'Bob Auto',
      lineItems: const [
        ReceiptLineItem(type: LineItemType.part, name: 'Filter', unitCost: 10),
      ],
    );
    final r = await scanReceipt(
      extractor: _FixedExtractor(draft),
      input: _input(),
      current: ScanFormValues.empty(),
    );
    expect(r, isA<ScanSuccess>());
    final applied = (r as ScanSuccess).applied;
    expect(applied.values.shopName, 'Bob Auto');
    expect(applied.values.items, hasLength(1));
  });

  test('failure surfaces the message and does not throw', () async {
    final r = await scanReceipt(
      extractor: _FailingExtractor(),
      input: _input(),
      current: ScanFormValues.empty(),
    );
    expect(r, isA<ScanFailure>());
    expect((r as ScanFailure).message, 'boom');
  });
}
