import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache.dart';
import 'package:hmm_console/core/data/attachments/video/video_cache_index.dart';
import 'package:hmm_console/core/data/attachments/video/video_downloads.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart' show VaultEntry;
import 'package:shared_preferences/shared_preferences.dart';

class _Files implements IVaultFileStore {
  _Files(this.target);
  final File target;
  @override
  Future<List<VaultEntry>> listOffloaded() async => const [];
  @override
  Future<void> deleteOffloaded(String p) async {}
  @override
  Future<DateTime?> offloadedModified(String p) async => null;
  @override
  Future<int> deleteStaleParts() async => 0;
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
  Object? failWith;
  Completer<void>? hold;
  @override
  bool get supportsLargeFiles => true;
  @override
  Future<bool> largeFileExists(String path) async => true;
  @override
  Future<void> downloadLargeFile(
    String path,
    File target, {
    void Function(int received, int total)? onProgress,
    TransferCancel? cancel,
  }) async {
    if (hold != null) await hold!.future;
    if (cancel?.isCancelled ?? false) throw const TransferCancelledException();
    if (failWith != null) throw failWith!;
    await target.writeAsBytes([1, 2, 3]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeCache implements VideoCache {
  final calls = <Set<String>>[];
  Object? throwOnEvict;
  Completer<void>? evictGate;
  @override
  Future<List<String>> evictToFit({Set<String> protect = const {}}) async {
    calls.add(protect);
    if (evictGate != null) await evictGate!.future;
    if (throwOnEvict != null) throw throwOnEvict!;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late Directory dir;
  late File target;
  late _Provider provider;
  late _FakeCache cache;
  late VideoCacheIndex index;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    index = VideoCacheIndex(await SharedPreferences.getInstance());
    dir = Directory.systemTemp.createTempSync('vdc');
    target = File('${dir.path}/v.mov');
    provider = _Provider();
    cache = _FakeCache();
    c = ProviderContainer(
      overrides: [
        vaultFileStoreProvider.overrideWith((ref) async => _Files(target)),
        videoCloudProvider.overrideWithValue(provider),
        videoCacheIndexProvider.overrideWith((ref) async => index),
        videoCacheProvider.overrideWith((ref) async => cache),
      ],
    );
    addTearDown(() {
      c.dispose();
      dir.deleteSync(recursive: true);
    });
  });

  test(
    'a finished download touches the path and evicts with it protected',
    () async {
      final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
      expect(r.outcome, VideoFetchOutcome.ready);
      await pumpEventQueue();
      expect(index.lastUsed('p'), isNotNull);
      expect(cache.calls, [
        {'p'},
      ]);
    },
  );

  test('an already-local file only touches', () async {
    target.writeAsBytesSync([9]);
    await c.read(videoDownloadsProvider.notifier).fetch('p');
    await pumpEventQueue();
    expect(index.lastUsed('p'), isNotNull);
    expect(cache.calls, isEmpty);
  });

  test('a cancelled or failed download does not evict', () async {
    provider.failWith = StateError('x');
    final failed = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(failed.outcome, VideoFetchOutcome.failed);
    await pumpEventQueue();

    provider.failWith = null;
    provider.hold = Completer<void>();
    final n = c.read(videoDownloadsProvider.notifier);
    final f = n.fetch('q');
    await pumpEventQueue();
    n.cancel('q');
    provider.hold!.complete();
    final cancelled = await f;
    expect(cancelled.outcome, VideoFetchOutcome.cancelled);
    await pumpEventQueue();
    expect(cache.calls, isEmpty);
    expect(index.lastUsed('p'), isNull);
    expect(index.lastUsed('q'), isNull);
  });

  test('a cache failure never breaks the download', () async {
    cache.throwOnEvict = StateError('delete failed');
    final r = await c.read(videoDownloadsProvider.notifier).fetch('p');
    expect(r.outcome, VideoFetchOutcome.ready);
  });

  test('ready does not wait for eviction', () async {
    cache.evictGate = Completer<void>();
    final r = await c
        .read(videoDownloadsProvider.notifier)
        .fetch('p')
        .timeout(const Duration(seconds: 1));
    expect(r.outcome, VideoFetchOutcome.ready);
    cache.evictGate!.complete();
    await pumpEventQueue();
    expect(cache.calls, [
      {'p'},
    ]);
  });
}
