import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/scanner/native_document_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hmm/document_scanner');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  void mock(Future<Object?>? Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, handler);

  test('a scan becomes one PickedImageBytes per page, in order', () async {
    mock((call) async {
      if (call.method == 'scan') {
        return <Uint8List>[
          Uint8List.fromList([1]),
          Uint8List.fromList([2]),
        ];
      }
      return null;
    });

    final pages = await const NativeDocumentScanner().scan();

    expect(pages, hasLength(2));
    expect(pages[0].bytes, Uint8List.fromList([1]));
    expect(pages[1].bytes, Uint8List.fromList([2]));
    expect(pages[0].contentType, 'image/jpeg');
  });

  test('cancelling returns no pages rather than throwing', () async {
    mock((call) async => <Uint8List>[]);
    expect(await const NativeDocumentScanner().scan(), isEmpty);
  });

  test('an unavailable scanner is not an error', () async {
    // The UI hides the action on isAvailable() == false; a throw here would
    // surface a crash for a device that simply cannot scan.
    mock((call) async => throw PlatformException(code: 'unavailable'));

    expect(await const NativeDocumentScanner().isAvailable(), isFalse);
    expect(await const NativeDocumentScanner().scan(), isEmpty);
  });

  test('a second scan while one is presenting is ignored, not fatal',
      () async {
    mock((call) async => throw PlatformException(code: 'already_presenting'));
    expect(await const NativeDocumentScanner().scan(), isEmpty);
  });

  test('a real failure propagates', () async {
    mock((call) async =>
        throw PlatformException(code: 'failed', message: 'camera exploded'));

    expect(() => const NativeDocumentScanner().scan(),
        throwsA(isA<PlatformException>()));
  });

  test('a missing plugin is treated as no scanner, not a crash', () async {
    // Android and any host without the plugin registered land here.
    messenger.setMockMethodCallHandler(channel, null);

    expect(await const NativeDocumentScanner().isAvailable(), isFalse);
    expect(await const NativeDocumentScanner().scan(), isEmpty);
  });

  test('isAvailable passes the platform answer through', () async {
    mock((call) async => call.method == 'isAvailable' ? true : null);
    expect(await const NativeDocumentScanner().isAvailable(), isTrue);
  });
}
