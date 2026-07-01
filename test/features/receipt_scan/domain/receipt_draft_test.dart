import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

void main() {
  test('empty draft has null scalars and no line items', () {
    const d = ReceiptDraft(source: ReceiptExtractorMode.onDevice);
    expect(d.shopName, isNull);
    expect(d.lineItems, isEmpty);
  });

  test('ReceiptExtractorMode round-trips through its wire value', () {
    expect(ReceiptExtractorMode.fromWire('cloudAi'), ReceiptExtractorMode.cloudAi);
    expect(ReceiptExtractorMode.onDevice.wire, 'onDevice');
    expect(ReceiptExtractorMode.fromWire('nonsense'), ReceiptExtractorMode.onDevice);
  });

  test('ReceiptInput.isPdf reflects the content type', () {
    final img =
        ReceiptInput(bytes: Uint8List(1), contentType: 'image/jpeg');
    final pdf =
        ReceiptInput(bytes: Uint8List(1), contentType: 'application/pdf');
    expect(img.isPdf, isFalse);
    expect(pdf.isPdf, isTrue);
  });
}
