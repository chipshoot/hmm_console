import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_upload_queue.dart';
import 'package:hmm_console/core/data/attachments/video/video_uploader.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/data/sync/video_upload_scheduler.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart' show VaultEntry;
import 'package:shared_preferences/shared_preferences.dart';

import '../attachments/video/fake_video_platform.dart';

class _Files implements IVaultFileStore {
  @override
  Future<List<VaultEntry>> listOffloaded() async => const [];
  @override
  Future<void> deleteOffloaded(String p) async {}
  @override
  Future<DateTime?> offloadedModified(String p) async => null;
  @override
  Future<int> deleteStaleParts() async => 0;
  _Files(this.file);
  final File file;
  @override
  Future<File?> localFile(String p) async => file;
  @override
  Future<void> offload(String p) async {}
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  File? downloadTarget(String p) => null;
}

class _Provider extends CloudSyncProvider {
  int uploaded = 0;
  @override
  String get providerId => 'fake';
  @override
  bool get supportsLargeFiles => true;
  @override
  Future<String> startLargeUpload(String path, int total) async => 's1';
  @override
  Future<int?> largeUploadNextOffset(String h) async => 0;
  @override
  Future<bool> uploadLargeChunk(String h, Uint8List c, int o, int t) async {
    uploaded++;
    return o + c.length >= t;
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Runs the real uploader, then holds the run open until [gate] completes,
/// like a run that already read the queue.
class _GatedRunner implements VideoUploadRunner {
  _GatedRunner(this.inner);
  final VideoUploader inner;
  Completer<void>? gate = Completer<void>();
  @override
  Future<void> load() => inner.load();
  @override
  Future<void> run() async {
    await inner.run();
    final g = gate;
    if (g != null) await g.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an enqueue made during an in-flight run gets uploaded', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('vek');
    addTearDown(() => dir.delete(recursive: true));
    final video = File('${dir.path}/v.mp4')..writeAsBytesSync([1, 2, 3]);
    final provider = _Provider();
    final uploader = VideoUploader(
      provider: provider,
      store: VideoUploadQueueStore(),
      files: _Files(video),
      unmeteredNetwork: () async => true,
      referencedPaths: () async => {'v.mp4'},
    );
    final runner = _GatedRunner(uploader);
    final scheduler = VideoUploadScheduler(
      resolveUploader: () async => runner,
      isSyncing: () => false,
      platform: FakeVideoPlatform(),
    );

    final first = scheduler.maybeRun();
    await pumpEventQueue();
    expect(provider.uploaded, 0);

    await enqueueVideoAndKick(
      uploader: () async => uploader,
      kick: scheduler.maybeRun,
      path: 'v.mp4',
    );
    final gate = runner.gate!;
    runner.gate = null;
    gate.complete();
    await first;

    expect(provider.uploaded, 1);
  });

  test('a null uploader does not kick', () async {
    var kicks = 0;
    await enqueueVideoAndKick(
      uploader: () async => null,
      kick: () async => kicks++,
      path: 'v.mp4',
    );
    expect(kicks, 0);
  });
}
