// Downsize-on-copy wiring: persistToVault must run picked bytes through
// the injected ImageDownsizer and store the RESULT (bytes, content
// type, byteSize), not the original. The native downsizer itself uses
// platform codecs and is covered by manual smoke testing; here we drive
// the picker with fakes so no platform channel is touched.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_downsizer.dart';
import 'package:hmm_console/core/data/vault/local_vault_store.dart';

Uint8List _bytes(int n, [int fill = 0x42]) =>
    Uint8List.fromList(List<int>.filled(n, fill));

/// Halves the input and claims a JPEG transcode — lets us assert the
/// stored ref reflects the downsizer's output.
class _HalvingDownsizer implements ImageDownsizer {
  int calls = 0;
  String? lastContentType;

  @override
  Future<DownsizeResult> downsize(
    Uint8List bytes, {
    required String contentType,
  }) async {
    calls++;
    lastContentType = contentType;
    return DownsizeResult(
      bytes: Uint8List.fromList(bytes.sublist(0, bytes.length ~/ 2)),
      contentType: 'image/jpeg',
    );
  }
}

void main() {
  late Directory tmp;
  late LocalVaultStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hmm_downsize_test_');
    store = LocalVaultStore(rootDir: tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('persistToVault stores the downsized bytes + recomputed ref',
      () async {
    final shrinker = _HalvingDownsizer();
    final picker = VaultImageAttachmentPicker(
      vaultStore: store,
      downsizer: shrinker,
    );
    final original = _bytes(1000);

    final ref = await picker.persistToVault(
      noteId: 3,
      bytes: original,
      originalName: 'car.png', // PNG in → JPEG out after downsize
    );

    expect(shrinker.calls, 1);
    // Downsizer saw the resolved INPUT content type, not the output.
    expect(shrinker.lastContentType, 'image/png');

    // Ref reflects the DOWNSIZED result, not the original pick.
    expect(ref.contentType, 'image/jpeg');
    expect(ref.path, endsWith('.jpg'));
    expect(ref.byteSize, 500);
    expect(ref.originalName, 'car.png');

    // The bytes on disk are the halved ones.
    final stored = await store.getBytes(ref.path);
    expect(stored.length, 500);
    expect(stored, equals(original.sublist(0, 500)));
  });

  test('default picker (no downsizer) stores bytes unchanged', () async {
    // Backstop for the NoopImageDownsizer default — existing callers and
    // tests that construct the picker without a downsizer keep the
    // old copy-verbatim behaviour.
    final picker = VaultImageAttachmentPicker(vaultStore: store);
    final original = _bytes(128);

    final ref = await picker.persistToVault(
      noteId: 1,
      bytes: original,
      originalName: 'p.jpg',
    );

    expect(ref.byteSize, 128);
    expect(ref.contentType, 'image/jpeg');
    expect(await store.getBytes(ref.path), equals(original));
  });

  test('disallowed input type is rejected before downsizing', () async {
    final shrinker = _HalvingDownsizer();
    final picker = VaultImageAttachmentPicker(
      vaultStore: store,
      downsizer: shrinker,
    );

    await expectLater(
      picker.persistToVault(
        noteId: 1,
        bytes: _bytes(64),
        originalName: 'notes.gif', // gif not in the allow-list
      ),
      throwsA(isA<AttachmentPickerException>()),
    );
    expect(shrinker.calls, 0, reason: 'must not downsize a rejected type');
  });

  group('NoopImageDownsizer', () {
    test('returns bytes and content type unchanged', () async {
      final b = _bytes(50);
      final r =
          await const NoopImageDownsizer().downsize(b, contentType: 'image/png');
      expect(identical(r.bytes, b), isTrue);
      expect(r.contentType, 'image/png');
    });
  });
}
