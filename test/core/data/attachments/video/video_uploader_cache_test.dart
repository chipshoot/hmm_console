import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_upload_queue.dart';
import 'package:hmm_console/core/data/attachments/video/video_uploader.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart' show VaultEntry;
import 'package:shared_preferences/shared_preferences.dart';

class _Files implements IVaultFileStore {
  _Files(this.file);
  final File file;
  Object? offloadError;
  @override
  Future<List<VaultEntry>> listOffloaded() async => const [];
  @override
  Future<void> deleteOffloaded(String p) async {}
  @override
  Future<DateTime?> offloadedModified(String p) async => null;
  @override
  Future<int> deleteStaleParts() async => 0;
  @override
  Future<File?> localFile(String p) async => file;
  @override
  Future<void> offload(String p) async {
    if (offloadError != null) throw offloadError!;
  }

  @override
  Future<void> importFile(String p, File s) async {}
  @override
  File? downloadTarget(String p) => null;
}

class _Provider extends CloudSyncProvider {
  @override
  String get providerId => 'fake';
  @override
  bool get supportsLargeFiles => true;
  @override
  Future<String> startLargeUpload(String path, int total) async => 's';
  @override
  Future<int?> largeUploadNextOffset(String h) async => null;
  @override
  Future<bool> uploadLargeChunk(
    String h,
    Uint8List chunk,
    int offset,
    int total,
  ) async => offset + chunk.length >= total;
  @override
  Future<void> cancelLargeUpload(String h) async {}
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late Directory dir;
  late _Files files;
  final offloaded = <String>[];

  VideoUploader make({bool throwInCallback = false}) => VideoUploader(
    provider: _Provider(),
    store: VideoUploadQueueStore(),
    files: files,
    unmeteredNetwork: () async => true,
    referencedPaths: () async => {'v.mp4'},
    fragmentBytes: 10,
    onOffloaded: (p) async {
      offloaded.add(p);
      if (throwInCallback) throw StateError('cache');
    },
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    offloaded.clear();
    dir = await Directory.systemTemp.createTemp('vuc');
    files = _Files(
      File('${dir.path}/v.mp4')..writeAsBytesSync(List.filled(25, 1)),
    );
  });
  tearDown(() => dir.delete(recursive: true));

  test(
    'after the last chunk and offload, onOffloaded is called with the path',
    () async {
      final u = make();
      await u.enqueue('v.mp4');
      await u.run();
      expect(offloaded, ['v.mp4']);
    },
  );

  test('a failed offload does not call onOffloaded', () async {
    files.offloadError = StateError('disk');
    final u = make();
    await u.enqueue('v.mp4');
    await u.run();
    expect(offloaded, isEmpty);
  });

  test('a throwing onOffloaded does not break the upload', () async {
    final u = make(throwInCallback: true);
    await u.enqueue('v.mp4');
    await u.run();
    expect(u.states.value, isEmpty);
    expect(await VideoUploadQueueStore().read('fake'), isEmpty);
  });
}
