import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_upload_queue.dart';
import 'package:hmm_console/core/data/attachments/video/video_uploader.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart' show VaultEntry;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFiles implements IVaultFileStore {
  @override
  Future<List<VaultEntry>> listOffloaded() async => const [];
  @override
  Future<void> deleteOffloaded(String p) async {}
  @override
  Future<DateTime?> offloadedModified(String p) async => null;
  @override
  Future<int> deleteStaleParts() async => 0;
  _FakeFiles(this.file);
  final File? file;
  final offloaded = <String>[];
  Object? offloadError;
  File? target;
  @override
  Future<File?> localFile(String p) async =>
      (file?.existsSync() ?? false) ? file : null;
  @override
  Future<void> offload(String p) async {
    if (offloadError != null) throw offloadError!;
    offloaded.add(p);
  }

  @override
  Future<void> importFile(String p, File s) async {}
  @override
  File? downloadTarget(String p) => target;
}

class _FakeProvider extends CloudSyncProvider {
  final chunks = <(String, int, int)>[]; // handle, offset, length
  final cancelled = <String>[];
  int started = 0;
  int? nextOffset;
  bool gone = false; // next chunk throws once
  Object? failWith;
  Duration delay = Duration.zero;
  void Function()? afterChunk;

  @override
  String get providerId => 'fake';
  @override
  bool get supportsLargeFiles => true;
  @override
  Future<String> startLargeUpload(String path, int total) async =>
      's${++started}';
  @override
  Future<int?> largeUploadNextOffset(String h) async => nextOffset;
  @override
  Future<bool> uploadLargeChunk(
    String h,
    Uint8List chunk,
    int offset,
    int total,
  ) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failWith != null) throw failWith!;
    if (gone) {
      gone = false;
      throw const LargeUploadSessionGone();
    }
    chunks.add((h, offset, chunk.length));
    afterChunk?.call();
    return offset + chunk.length >= total;
  }

  @override
  Future<void> cancelLargeUpload(String h) async => cancelled.add(h);

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late Directory dir;
  late File video;
  late _FakeProvider provider;
  late _FakeFiles files;
  late VideoUploadQueueStore store;
  var unmetered = true;
  var referenced = <String>{'v.mp4'};

  VideoUploader make() => VideoUploader(
    provider: provider,
    store: store,
    files: files,
    unmeteredNetwork: () async => unmetered,
    referencedPaths: () async => referenced,
    fragmentBytes: 10,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('vu');
    video = File('${dir.path}/v.mp4')
      ..writeAsBytesSync(List.generate(25, (i) => i));
    provider = _FakeProvider();
    files = _FakeFiles(video);
    store = VideoUploadQueueStore();
    unmetered = true;
    referenced = {'v.mp4'};
  });
  tearDown(() => dir.delete(recursive: true));

  test('uploads in fragment-sized chunks and offloads when done', () async {
    final u = make();
    await u.enqueue('v.mp4');
    await u.run();
    expect(provider.chunks.map((c) => (c.$2, c.$3)), [
      (0, 10),
      (10, 10),
      (20, 5),
    ]);
    expect(provider.chunks.every((c) => c.$3 <= 10), isTrue);
    expect(files.offloaded, ['v.mp4']);
    expect(await store.read('fake'), isEmpty);
    expect(u.states.value, isEmpty);
  });

  test('resumes from the server offset', () async {
    await store.put(
      'fake',
      const VideoUploadEntry(path: 'v.mp4', total: 25, session: 's1', sent: 10),
    );
    provider.nextOffset = 20;
    final u = make();
    await u.load();
    expect(u.states.value['v.mp4']!.phase, VideoUploadPhase.queued);
    await u.run();
    expect(provider.chunks.map((c) => (c.$1, c.$2)), [('s1', 20)]);
    expect(files.offloaded, ['v.mp4']);
  });

  test('restarts when the session is gone', () async {
    await store.put(
      'fake',
      const VideoUploadEntry(path: 'v.mp4', total: 25, session: 's1', sent: 10),
    );
    provider.nextOffset = null;
    final u = make();
    await u.load();
    await u.run();
    expect(provider.started, 1);
    expect(provider.chunks.map((c) => (c.$1, c.$2)), [
      ('s1', 0),
      ('s1', 10),
      ('s1', 20),
    ]);
  });

  test('restarts once when the session vanishes mid-upload', () async {
    final u = make();
    await u.enqueue('v.mp4');
    provider.gone = true;
    await u.run();
    expect(provider.started, 2);
    expect(provider.chunks.first.$1, 's2');
    expect(files.offloaded, ['v.mp4']);
  });

  test('drops entries no note references', () async {
    await store.put(
      'fake',
      const VideoUploadEntry(path: 'v.mp4', total: 25, session: 's1'),
    );
    referenced = {};
    final u = make();
    await u.load();
    await u.run();
    expect(provider.chunks, isEmpty);
    expect(provider.cancelled, ['s1']);
    expect(await store.read('fake'), isEmpty);
    expect(u.states.value, isEmpty);
  });

  test('waits for Wi-Fi unless mobile data was allowed', () async {
    unmetered = false;
    final u = make();
    await u.enqueue('v.mp4');
    await u.run();
    expect(provider.chunks, isEmpty);
    expect(u.states.value['v.mp4']!.phase, VideoUploadPhase.waitingForWifi);
    await u.allowMobileData('v.mp4');
    expect(provider.chunks, hasLength(3));
    expect(await store.read('fake'), isEmpty);
  });

  test('an error marks failed and keeps the entry', () async {
    provider.failWith = StateError('boom');
    final u = make();
    await u.enqueue('v.mp4');
    await u.run();
    expect(u.states.value['v.mp4']!.phase, VideoUploadPhase.failed);
    expect(await store.read('fake'), hasLength(1));
    expect(files.offloaded, isEmpty);
  });

  test('a second run() while running does not upload twice', () async {
    provider.delay = const Duration(milliseconds: 5);
    final u = make();
    await u.enqueue('v.mp4');
    final a = u.run();
    final b = u.run();
    expect(identical(a, b), isTrue);
    await a;
    await b;
    expect(provider.chunks, hasLength(3));
  });

  test('a failing offload after a complete upload drops the entry', () async {
    files.offloadError = StateError('no offload root');
    final u = make();
    await u.enqueue('v.mp4');
    await u.run();
    expect(provider.chunks, hasLength(3));
    expect(await store.read('fake'), isEmpty);
    expect(u.states.value, isEmpty);
    await u.run();
    expect(provider.chunks, hasLength(3));
    expect(provider.started, 1);
  });

  test('a file truncated mid-upload fails without an empty chunk', () async {
    final u = make();
    await u.enqueue('v.mp4');
    provider.afterChunk = () => video.writeAsBytesSync(List.filled(10, 1));
    await u.run();
    expect(provider.chunks.every((c) => c.$3 > 0), isTrue);
    expect(provider.chunks, hasLength(1));
    expect(u.states.value['v.mp4']!.phase, VideoUploadPhase.failed);
    expect(await store.read('fake'), hasLength(1));
  });

  test('a file whose length changed since enqueue is not uploaded', () async {
    final u = make();
    await u.enqueue('v.mp4');
    video.writeAsBytesSync(List.filled(10, 1));
    await u.run();
    expect(provider.chunks, isEmpty);
    expect(provider.started, 0);
    expect(await store.read('fake'), isEmpty);
    expect(u.states.value, isEmpty);
  });

  test('stops mid-upload when the network turns metered', () async {
    final u = make();
    await u.enqueue('v.mp4');
    provider.afterChunk = () => unmetered = false;
    await u.run();
    expect(provider.chunks, hasLength(1));
    final st = u.states.value['v.mp4']!;
    expect(st.phase, VideoUploadPhase.waitingForWifi);
    expect(st.sent, 10);
    expect((await store.read('fake')).single.sent, 10);
  });

  test('a file deleted between chunks cancels the session and drops', () async {
    final u = make();
    await u.enqueue('v.mp4');
    provider.afterChunk = () => video.deleteSync();
    await u.run();
    expect(provider.chunks, hasLength(1));
    expect(provider.cancelled, ['s1']);
    expect(await store.read('fake'), isEmpty);
    expect(u.states.value, isEmpty);
    expect(files.offloaded, isEmpty);
  });

  test('a path unreferenced between chunks cancels and drops', () async {
    final u = make();
    await u.enqueue('v.mp4');
    provider.afterChunk = () => referenced = {};
    await u.run();
    expect(provider.chunks, hasLength(1));
    expect(provider.cancelled, ['s1']);
    expect(await store.read('fake'), isEmpty);
    expect(u.states.value, isEmpty);
  });

  test('an already offloaded file is dropped without uploading', () async {
    final offRoot = File('${dir.path}/off.mp4')..writeAsBytesSync([1, 2, 3]);
    files.target = offRoot;
    final u = make();
    await u.enqueue('v.mp4');
    await u.run();
    expect(provider.started, 0);
    expect(provider.chunks, isEmpty);
    expect(files.offloaded, isEmpty);
    expect(await store.read('fake'), isEmpty);
    expect(u.states.value, isEmpty);
  });

  test('setMobileOk only sets the flag and does not run', () async {
    unmetered = false;
    final u = make();
    await u.enqueue('v.mp4');
    await u.setMobileOk('v.mp4');
    expect(provider.chunks, isEmpty);
    expect((await store.read('fake')).single.mobileOk, isTrue);
  });
}
