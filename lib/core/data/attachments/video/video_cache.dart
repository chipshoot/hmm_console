import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data_mode.dart';
import '../../local/database.dart';
import '../../sync/sync_orchestrator.dart';
import '../../vault/vault_file_store.dart';
import '../../vault/vault_gc.dart';
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
/// upload and protected paths are never cleared. A kept mark only counts
/// while some note still references the video; otherwise it is an ordinary
/// download.
class VideoCache {
  VideoCache({
    required IVaultFileStore files,
    required VideoCacheIndex index,
    required Future<Set<String>> Function() pendingUploads,
    required Future<Set<String>> Function() referencedPaths,
    int limitBytes = kVideoCacheLimitBytes,
  }) : _files = files,
       _index = index,
       _pendingUploads = pendingUploads,
       _referenced = referencedPaths,
       _limit = limitBytes;

  final IVaultFileStore _files;
  final VideoCacheIndex _index;
  final Future<Set<String>> Function() _pendingUploads;
  final Future<Set<String>> Function() _referenced;
  final int _limit;

  /// Kept paths that a note still references.
  Future<Set<String>> _kept() async {
    final kept = _index.keptOffline;
    if (kept.isEmpty) return kept;
    return kept.intersection(await _referenced());
  }

  Future<VideoCacheUsage> usage() async {
    final kept = await _kept();
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
    final kept = await _kept();
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
    final kept = await _kept();
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

/// Null unless the data mode is cloudStorage (only there can a cleared video
/// be downloaded again) and there is an on-disk vault file store. Not gated on
/// the cloud provider being signed in: eviction must still work while it
/// isn't.
final videoCacheProvider = FutureProvider<VideoCache?>((ref) async {
  if (ref.watch(dataModeProvider) != DataMode.cloudStorage) return null;
  final files = await ref.watch(vaultFileStoreProvider.future);
  if (files == null) return null;
  final index = await ref.watch(videoCacheIndexProvider.future);
  final orchestrator = ref.watch(syncOrchestratorProvider);
  final db = ref.watch(hmmDatabaseProvider);
  return VideoCache(
    files: files,
    index: index,
    referencedPaths: () => collectReferencedVaultPaths(db),
    pendingUploads: () async {
      final provider = orchestrator.provider;
      if (provider == null) return <String>{};
      final entries = await VideoUploadQueueStore().read(provider.providerId);
      return {for (final e in entries) e.path};
    },
  );
});

/// Records that [path] was just used and, when [cache] is given, trims the
/// cache with [path] protected. Best effort: a cache failure never reaches
/// callers.
Future<void> touchVideo(
  Future<VideoCacheIndex> index,
  String path, {
  Future<VideoCache?> Function()? cache,
}) async {
  try {
    (await index).touch(path);
    if (cache == null) return;
    await (await cache())?.evictToFit(protect: {path});
  } catch (e) {
    debugPrint('Video cache update failed (${e.runtimeType})');
  }
}
