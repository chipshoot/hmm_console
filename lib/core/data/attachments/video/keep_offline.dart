import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../local/database.dart';
import '../../vault/vault_gc.dart';
import '../attachment_providers.dart';
import 'video_cache.dart' show videoCacheIndexProvider;
import 'video_cache_index.dart';
import 'video_downloads.dart';
import 'video_uploader.dart' show videoMayUseNetworkProvider;

/// Per-device "Keep offline" for videos: a kept video is downloaded to this
/// device and never cleared by the cache. Not synced.
class KeepOffline {
  KeepOffline({
    required VideoCacheIndex index,
    required Future<VideoFetchResult> Function(String) fetch,
    required Future<bool> Function(String) isLocal,
    required Future<bool> Function() mayUseNetwork,
    required Future<Set<String>> Function() referencedPaths,
  }) : _index = index,
       _fetch = fetch,
       _isLocal = isLocal,
       _mayUseNetwork = mayUseNetwork,
       _referenced = referencedPaths;

  final VideoCacheIndex _index;
  final Future<VideoFetchResult> Function(String) _fetch;
  final Future<bool> Function(String) _isLocal;
  final Future<bool> Function() _mayUseNetwork;
  final Future<Set<String>> Function() _referenced;

  bool isKept(String path) => _index.isKept(path);

  /// Marks or unmarks [path]. Marking persists first, then starts a download
  /// when the file isn't on this device (not awaited). Unmarking never
  /// deletes the file; it just becomes cache-evictable.
  Future<void> set(String path, bool kept) async {
    await _index.setKept(path, kept);
    if (kept && !await _isLocal(path)) _start(path);
  }

  /// Starts a download for every kept video not on this device, when the
  /// network is allowed. Returns how many were started; doesn't await them.
  ///
  /// First drops the kept mark of every video no note references any more
  /// (removed from its note, or its note purged), so a deleted video is never
  /// downloaded again.
  Future<int> fetchMissing() async {
    final kept = _index.keptOffline;
    if (kept.isEmpty) return 0;
    final referenced = await _referenced();
    for (final path in kept.difference(referenced)) {
      await _index.setKept(path, false);
    }
    if (!await _mayUseNetwork()) return 0;
    var started = 0;
    for (final path in kept.intersection(referenced)) {
      if (await _isLocal(path)) continue;
      _start(path);
      started++;
    }
    return started;
  }

  void _start(String path) {
    unawaited(
      _fetch(path).then<void>(
        (_) {},
        onError: (Object e) {
          debugPrint('Keep offline fetch failed (${e.runtimeType})');
        },
      ),
    );
  }
}

/// Null unless videos move through the cloud and there is an on-disk vault.
final keepOfflineProvider = FutureProvider<KeepOffline?>((ref) async {
  if (!ref.watch(videoCloudEnabledProvider)) return null;
  final files = await ref.watch(vaultFileStoreProvider.future);
  if (files == null) return null;
  final index = await ref.watch(videoCacheIndexProvider.future);
  final downloads = ref.read(videoDownloadsProvider.notifier);
  final db = ref.watch(hmmDatabaseProvider);
  return KeepOffline(
    index: index,
    fetch: downloads.fetch,
    isLocal: (p) async => await files.localFile(p) != null,
    mayUseNetwork: ref.read(videoMayUseNetworkProvider),
    referencedPaths: () => collectReferencedVaultPaths(db),
  );
});
