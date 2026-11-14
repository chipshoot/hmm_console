import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/video/video_downloads.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';

class _Files implements IVaultFileStore {
  _Files(this.target);
  final File target;
  @override
  Future<File?> localFile(String p) async =>
      target.existsSync() ? target : null;
  @override
  File? downloadTarget(String p) => target;
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  Future<void> offload(String p) async {}
}

class _Provider extends CloudSyncProvider {
  bool exists = true;
  int downloads = 0;
  Object? failWith;
  Future<void> Function(File target, TransferCancel? cancel)? body;

  @override
  Future<bool> largeFileExists(String path) async => exists;

  @override
  Future<void> downloadLargeFile(
    String path,
    File target, {
    void Function(int received, int total)? onProgress,
    TransferCancel? cancel,
  }) async {
    downloads++;
    if (failWith != null) throw failWith!;
    onProgress?.call(50, 100);
    if (body != null) return body!(target, cancel);
    await target.writeAsBytes([1, 2, 3]);
    onProgress?.call(100, 100);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late Directory dir;
  late File target;
  late _Provider provider;
  late ProviderContainer c;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vd');
    target = File('${dir.path}/v.mov');
    provider = _Provider();
    c = ProviderContainer(
      overrides: [
        vaultFileStoreProvider.overrideWith((ref) async => _Files(target)),
        videoCloudProvider.overrideWithValue(provider),
      ],
    );
    addTearDown(() {
      c.dispose();
      dir.deleteSync(recursive: true);
    });
  });

  test('fetch downloads to the offload target and reports progress', () async {
    final seen = <double>[];
    c.listen(videoDownloadsProvider, (_, n) {
      final v = n['p'];
      if (v != null) seen.add(v);
    });
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.ready);
    expect(r.file!.path, target.path);
    expect(target.existsSync(), isTrue);
    expect(seen, contains(0.5));
    expect(c.read(videoDownloadsProvider), isEmpty);
  });

  test('fetch returns still-uploading when the cloud lacks it', () async {
    provider.exists = false;
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.stillUploading);
    expect(r.file, isNull);
    expect(provider.downloads, 0);
  });

  test('a local file is returned without a download', () async {
    await target.writeAsBytes([9]);
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.ready);
    expect(provider.downloads, 0);
  });

  test('other errors are failed', () async {
    provider.failWith = StateError('https://secret');
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.failed);
    expect(c.read(videoDownloadsProvider), isEmpty);
  });

  test('cancelled download leaves no file', () async {
    provider.body = (t, cancel) async {
      await File('${t.path}.part').writeAsBytes([1]);
      c.read(videoDownloadsProvider.notifier).cancel('p');
      expect(cancel!.isCancelled, isTrue);
      await File('${t.path}.part').delete();
      throw const TransferCancelledException();
    };
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.cancelled);
    expect(target.existsSync(), isFalse);
    expect(File('${target.path}.part').existsSync(), isFalse);
    expect(c.read(videoDownloadsProvider), isEmpty);
  });
}
