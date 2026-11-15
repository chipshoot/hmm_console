import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../sync/sync_orchestrator.dart';
import '../../vault/vault_file_store.dart';
import '../attachment_providers.dart';
import 'video_cache_index.dart';
import 'video_upload_queue.dart';

const kVideoCacheLimitBytes = 2 * 1024 * 1024 * 1024;

class VideoCacheUsage {
  const VideoCacheUsage({
    required this.downloadedBytes,
    required this.keptCount,
    required this.keptBytes,
  });

  final int downloadedBytes;
  final int keptCount;
  final int keptBytes;
}

/// Keeps downloaded (offloaded) videos under a size limit, clearing the
/// least recently used first. Kept-offline videos, videos still queued for
/// upload and protected paths are never cleared.
class VideoCache {
  VideoCache({
    required IVaultFileStore files,
    required VideoCacheIndex index,
    required Future<Set<String>> Function() pendingUploads,
    int limitBytes = kVideoCacheLimitBytes,
  }) : _files = files,
       _index = index,
       _pendingUploads = pendingUploads,
       _limit = limitBytes;

  final IVaultFileStore _files;
  final VideoCacheIndex _index;
  final Future<Set<String>> Function() _pendingUploads;
  final int _limit;

  Future<VideoCacheUsage> usage() async {
    final kept = _index.keptOffline;
    var downloaded = 0;
    var keptCount = 0;
    var keptBytes = 0;
    for (final e in await _files.listOffloaded()) {
      if (kept.contains(e.relativePath)) {
        keptCount++;
        keptBytes += e.byteSize;
      } else {
        downloaded += e.byteSize;
      }
    }
    return VideoCacheUsage(
      downloadedBytes: downloaded,
      keptCount: keptCount,
      keptBytes: keptBytes,
    );
  }

  /// Deletes least-recently-used downloads until the non-kept total is within
  /// the limit. Returns the evicted paths.
  Future<List<String>> evictToFit({Set<String> protect = const {}}) async {
    final kept = _index.keptOffline;
    final pending = await _pendingUploads();
    final all = (await _files.listOffloaded())
        .where((e) => !kept.contains(e.relativePath))
        .toList();
    var total = all.fold<int>(0, (a, e) => a + e.byteSize);
    if (total <= _limit) return const [];

    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final candidates = <(String, int, DateTime)>[];
    for (final e in all) {
      final path = e.relativePath;
      if (pending.contains(path) || protect.contains(path)) continue;
      final used =
          _index.lastUsed(path) ??
          await _files.offloadedModified(path) ??
          epoch;
      candidates.add((path, e.byteSize, used));
    }
    candidates.sort((a, b) => a.$3.compareTo(b.$3));

    final evicted = <String>[];
    for (final c in candidates) {
      if (total <= _limit) break;
      await _files.deleteOffloaded(c.$1);
      await _index.forget(c.$1);
      total -= c.$2;
      evicted.add(c.$1);
    }
    return evicted;
  }

  /// Deletes every non-kept, non-pending download. Returns the bytes freed.
  Future<int> clearDownloaded() async {
    final kept = _index.keptOffline;
    final pending = await _pendingUploads();
    var freed = 0;
    for (final e in await _files.listOffloaded()) {
      if (kept.contains(e.relativePath) || pending.contains(e.relativePath)) {
        continue;
      }
      await _files.deleteOffloaded(e.relativePath);
      await _index.forget(e.relativePath);
      freed += e.byteSize;
    }
    return freed;
  }

  Future<int> sweepStaleParts() => _files.deleteStaleParts();
}

final videoCacheIndexProvider = FutureProvider<VideoCacheIndex>((ref) async {
  return VideoCacheIndex(await SharedPreferences.getInstance());
});

/// Null when there is no on-disk vault file store.
final videoCacheProvider = FutureProvider<VideoCache?>((ref) async {
  final files = await ref.watch(vaultFileStoreProvider.future);
  if (files == null) return null;
  final index = await ref.watch(videoCacheIndexProvider.future);
  final orchestrator = ref.read(syncOrchestratorProvider);
  return VideoCache(
    files: files,
    index: index,
    pendingUploads: () async {
      final provider = orchestrator.provider;
      if (provider == null) return <String>{};
      final entries = await VideoUploadQueueStore().read(provider.providerId);
      return {for (final e in entries) e.path};
    },
  );
});
