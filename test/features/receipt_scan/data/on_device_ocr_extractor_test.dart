import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/data/on_device_ocr_extractor.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

void main() {
  test('delegates recognized text to the parser and sets rawText', () async {
    final ex = OnDeviceOcrExtractor(recognize: (_) async => 'SHOP\nTOTAL 10.00');
    final d = await ex.extract(
      ReceiptInput(bytes: Uint8List.fromList([1]), contentType: 'image/jpeg'),
    );
    expect(d.total, 10.0);
    expect(d.rawText, 'SHOP\nTOTAL 10.00');
    expect(d.source, ReceiptExtractorMode.onDevice);
  });

  test('throws when no text is recognized', () async {
    final ex = OnDeviceOcrExtractor(recognize: (_) async => '   ');
    expect(
      () => ex.extract(
          ReceiptInput(bytes: Uint8List(1), contentType: 'image/jpeg')),
      throwsA(isA<ReceiptExtractionException>()),
    );
  });

  test('rejects PDF input on-device', () async {
    final ex = OnDeviceOcrExtractor(recognize: (_) async => 'whatever');
    expect(
      () => ex.extract(
          ReceiptInput(bytes: Uint8List(0), contentType: 'application/pdf')),
      throwsA(isA<ReceiptExtractionException>()),
    );
  });
}
