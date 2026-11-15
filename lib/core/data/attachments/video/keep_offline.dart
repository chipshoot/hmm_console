import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachment_providers.dart';
import 'video_cache.dart' show videoCacheIndexProvider;
import 'video_cache_index.dart';
import 'video_downloads.dart';
import 'video_uploader.dart' show isUnmeteredNetwork;

/// Per-device "Keep offline" for videos: a kept video is downloaded to this
/// device and never cleared by the cache. Not synced.
class KeepOffline {
  KeepOffline({
    required VideoCacheIndex index,
    required Future<VideoFetchResult> Function(String) fetch,
    required Future<bool> Function(String) isLocal,
    required Future<bool> Function() mayUseNetwork,
  }) : _index = index,
       _fetch = fetch,
       _isLocal = isLocal,
       _mayUseNetwork = mayUseNetwork;

  final VideoCacheIndex _index;
  final Future<VideoFetchResult> Function(String) _fetch;
  final Future<bool> Function(String) _isLocal;
  final Future<bool> Function() _mayUseNetwork;

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
  Future<int> fetchMissing() async {
    if (!await _mayUseNetwork()) return 0;
    var started = 0;
    for (final path in _index.keptOffline) {
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
  return KeepOffline(
    index: index,
    fetch: downloads.fetch,
    isLocal: (p) async => await files.localFile(p) != null,
    // Task 4 ORs the "Upload on mobile data" setting in here.
    mayUseNetwork: isUnmeteredNetwork,
  );
});
