import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/scanner/document_scanner.dart';

void main() {
  test('the default scanner reports itself unavailable and scans nothing',
      () async {
    // Every platform except iOS-with-VisionKit gets this one, so it must be
    // safe rather than throwing: the UI hides the scan action when
    // isAvailable() is false and never calls scan().
    const scanner = UnavailableDocumentScanner();

    expect(await scanner.isAvailable(), isFalse);
    expect(await scanner.scan(), isEmpty);
  });
}
