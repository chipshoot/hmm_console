import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/onedrive_sync_provider.dart';

import 'onedrive_graph_upload_session_test.dart'
    show RecordingAdapter, Reply, makeClient;
import 'onedrive_test_fakes.dart';

OneDriveSyncProvider make(RecordingAdapter a) => OneDriveSyncProvider(
  FakeOneDriveAuth(),
  makeClient(a),
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('large'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('supportsLargeFiles is true', () {
    expect(make(RecordingAdapter([])).supportsLargeFiles, isTrue);
  });

  test('download writes the bytes to the file and reports progress', () async {
    final bytes = List<int>.generate(1000, (i) => i % 251);
    final a = RecordingAdapter([Reply(200, null, bytes)]);
    final target = File('${tmp.path}/sub/dir/v.mov');
    final seen = <int>[];
    await make(a).downloadLargeFile(
      'attachments/n/v.mov',
      target,
      onProgress: (r, t) => seen.add(r),
    );
    expect(target.readAsBytesSync(), bytes);
    expect(File('${target.path}.part').existsSync(), isFalse);
    expect(seen, isNotEmpty);
    expect(seen.last, 1000);
  });

  test('cancel stops it with TransferCancelledException', () async {
    final a = RecordingAdapter([Reply(200, null, List.filled(1000, 1))]);
    final target = File('${tmp.path}/v.mov');
    final cancel = TransferCancel();
    await expectLater(
      make(a).downloadLargeFile(
        'attachments/n/v.mov',
        target,
        onProgress: (r, t) => cancel.cancel(),
        cancel: cancel,
      ),
      throwsA(isA<TransferCancelledException>()),
    );
    expect(target.existsSync(), isFalse);
    expect(File('${target.path}.part').existsSync(), isFalse);
  });

  test('failed download deletes the partial file and rethrows', () async {
    final a = RecordingAdapter([Reply(500)]);
    final target = File('${tmp.path}/v.mov');
    await expectLater(
      make(a).downloadLargeFile('attachments/n/v.mov', target),
      throwsA(anything),
    );
    expect(target.existsSync(), isFalse);
    expect(File('${target.path}.part').existsSync(), isFalse);
  });

  test(
    'upload operations map onto the client with the url as handle',
    () async {
      const url = 'https://upload.example/s';
      final a = RecordingAdapter([
        Reply(200, {'uploadUrl': url}),
        Reply(200, {
          'nextExpectedRanges': ['5-'],
        }),
        Reply(201),
        Reply(204),
        Reply(404),
      ]);
      final p = make(a);
      final h = await p.startLargeUpload('attachments/n/v.mov', 10);
      expect(h, url);
      expect(await p.largeUploadNextOffset(h), 5);
      expect(
        await p.uploadLargeChunk(h, Uint8List.fromList([1, 2, 3, 4, 5]), 5, 10),
        isTrue,
      );
      await p.cancelLargeUpload(h);
      expect(await p.largeFileExists('attachments/n/v.mov'), isFalse);
    },
  );
}
