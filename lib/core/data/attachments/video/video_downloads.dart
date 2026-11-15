import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_mode.dart';
import '../../sync/cloud_sync_provider.dart';
import '../../sync/sync_orchestrator.dart';
import '../attachment_providers.dart';

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

  void cancel(String path) => _cancels[path]?.cancel();
}

final videoDownloadsProvider =
    NotifierProvider<VideoDownloads, Map<String, double>>(VideoDownloads.new);
