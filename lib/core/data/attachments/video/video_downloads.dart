import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_mode.dart';
import '../../sync/cloud_sync_provider.dart';
import '../../sync/sync_orchestrator.dart';
import '../attachment_providers.dart';
import 'video_cache.dart';

enum VideoFetchOutcome { ready, stillUploading, cancelled, failed }

class VideoFetchResult {
  const VideoFetchResult(this.outcome, [this.file]);

  final VideoFetchOutcome outcome;

  /// Set only when [outcome] is [VideoFetchOutcome.ready].
  final File? file;
}

/// The active cloud provider that videos are fetched from, if any. A seam for
/// tests.
final videoCloudProvider = Provider<CloudSyncProvider?>(
  (ref) => ref.watch(syncOrchestratorProvider).provider,
);

/// Whether videos move through the cloud: cloudStorage mode with a provider
/// that can transfer large files. Otherwise videos stay on the device that
/// added them.
final videoCloudEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(dataModeProvider) == DataMode.cloudStorage &&
      ref.watch(videoCloudProvider)?.supportsLargeFiles == true,
);

/// Downloads of videos that another device uploaded. State: vault path ->
/// fraction 0..1; absent means not downloading.
class VideoDownloads extends Notifier<Map<String, double>> {
  VideoDownloads({this.onReady});

  /// Called when a fetch resolves to ready; [downloaded] is true when the file
  /// was actually downloaded, false when it was already local. Best effort.
  final Future<void> Function(String path, {required bool downloaded})? onReady;

  final _cancels = <String, TransferCancel>{};

  @override
  Map<String, double> build() => const {};

  void _setProgress(String path, double? fraction) {
    final next = {...state};
    if (fraction == null) {
      next.remove(path);
    } else {
      next[path] = fraction;
    }
    state = next;
  }

  final _inFlight = <String, Future<VideoFetchResult>>{};

  /// Joins a download already running for [path] instead of starting another.
  Future<VideoFetchResult> fetch(String path) {
    final running = _inFlight[path];
    if (running != null) return running;
    final f = _fetch(path);
    _inFlight[path] = f;
    unawaited(f.whenComplete(() => _inFlight.remove(path)));
    return f;
  }

  Future<VideoFetchResult> _fetch(String path) async {
    final cancel = TransferCancel();
    _cancels[path] = cancel;
    _setProgress(path, 0);
    try {
      final store = await ref.read(vaultFileStoreProvider.future);
      final local = await store?.localFile(path);
      if (local != null) {
        await _ready(path, downloaded: false);
        return VideoFetchResult(VideoFetchOutcome.ready, local);
      }
      final provider = ref.read(videoCloudProvider);
      final target = store?.downloadTarget(path);
      if (provider == null || !provider.supportsLargeFiles || target == null) {
        return const VideoFetchResult(VideoFetchOutcome.failed);
      }
      if (!await provider.largeFileExists(path)) {
        return const VideoFetchResult(VideoFetchOutcome.stillUploading);
      }
      await provider.downloadLargeFile(
        path,
        target,
        cancel: cancel,
        onProgress: (received, total) {
          if (total > 0 && _cancels[path] == cancel) {
            _setProgress(path, (received / total).clamp(0.0, 1.0));
          }
        },
      );
      await _ready(path, downloaded: true);
      return VideoFetchResult(VideoFetchOutcome.ready, target);
    } on TransferCancelledException {
      return const VideoFetchResult(VideoFetchOutcome.cancelled);
    } catch (e) {
      // Type only: error text can carry a pre-authenticated URL.
      debugPrint('VideoDownloads: fetch failed (${e.runtimeType})');
      return const VideoFetchResult(VideoFetchOutcome.failed);
    } finally {
      _cancels.remove(path);
      if (ref.mounted) _setProgress(path, null);
    }
  }

  Future<void> _ready(String path, {required bool downloaded}) async {
    try {
      await onReady?.call(path, downloaded: downloaded);
    } catch (e) {
      debugPrint('VideoDownloads: cache hook failed (${e.runtimeType})');
    }
  }

  void cancel(String path) => _cancels[path]?.cancel();
}

final videoDownloadsProvider =
    NotifierProvider<VideoDownloads, Map<String, double>>(() {
      late final VideoDownloads notifier;
      // The notifier's own ref, read only after it is built.
      // ignore: invalid_use_of_protected_member
      Ref ref() => notifier.ref;
      notifier = VideoDownloads(
        // Not awaited: a ready video must not wait for eviction. touchVideo
        // catches its own errors.
        onReady: (path, {required downloaded}) async => unawaited(
          touchVideo(
            ref().read(videoCacheIndexProvider.future),
            path,
            cache: downloaded
                ? () => ref().read(videoCacheProvider.future)
                : null,
          ),
        ),
      );
      return notifier;
    });
