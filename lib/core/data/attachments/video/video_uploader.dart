import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_mode.dart';
import '../../local/database.dart';
import '../../sync/cloud_sync_provider.dart';
import '../../sync/sync_orchestrator.dart';
import '../../vault/vault_file_store.dart';
import '../../vault/vault_gc.dart';
import '../attachment_providers.dart';
import '../../sync/video_upload_scheduler.dart' show VideoUploadRunner;
import 'video_cache.dart';
import 'video_upload_queue.dart';

enum VideoUploadPhase { queued, waitingForWifi, uploading, failed }

class VideoUploadState {
  const VideoUploadState(this.phase, this.sent, this.total);
  final VideoUploadPhase phase;
  final int sent;
  final int total;

  double get fraction => total <= 0 ? 0 : (sent / total).clamp(0.0, 1.0);
}

/// Uploads videos to the cloud provider in resumable chunks, one entry at a
/// time, never holding more than one chunk in memory. Entries wait for an
/// unmetered network unless the user allowed mobile data for them.
class VideoUploader implements VideoUploadRunner {
  VideoUploader({
    required CloudSyncProvider provider,
    required VideoUploadQueueStore store,
    required IVaultFileStore files,
    required Future<bool> Function() unmeteredNetwork,
    required Future<Set<String>> Function() referencedPaths,
    int fragmentBytes = kUploadFragmentBytes,
    Future<void> Function(String path)? onOffloaded,
  }) : _provider = provider,
       _store = store,
       _files = files,
       _unmetered = unmeteredNetwork,
       _referenced = referencedPaths,
       _fragment = fragmentBytes,
       _onOffloaded = onOffloaded;

  final CloudSyncProvider _provider;
  final VideoUploadQueueStore _store;
  final IVaultFileStore _files;
  final Future<bool> Function() _unmetered;
  final Future<Set<String>> Function() _referenced;
  final int _fragment;
  final Future<void> Function(String path)? _onOffloaded;

  final _states = ValueNotifier<Map<String, VideoUploadState>>(const {});
  Future<void>? _running;

  /// path -> state; absent means nothing pending.
  ValueListenable<Map<String, VideoUploadState>> get states => _states;

  String get _pid => _provider.providerId;

  void _set(String path, VideoUploadState? s) {
    final next = {..._states.value};
    if (s == null) {
      next.remove(path);
    } else {
      next[path] = s;
    }
    _states.value = next;
  }

  @override
  Future<void> load() async {
    for (final e in await _store.read(_pid)) {
      _set(e.path, VideoUploadState(VideoUploadPhase.queued, e.sent, e.total));
    }
  }

  Future<void> enqueue(String path) async {
    if ((await _store.read(_pid)).any((e) => e.path == path)) return;
    final file = await _files.localFile(path);
    if (file == null) return;
    final total = await file.length();
    await _store.put(_pid, VideoUploadEntry(path: path, total: total));
    _set(path, VideoUploadState(VideoUploadPhase.queued, 0, total));
  }

  /// Marks [path] as allowed on mobile data without running the queue; the
  /// caller then triggers a run (the scheduler, so it holds a background
  /// task).
  Future<void> setMobileOk(String path) async {
    final entry = (await _store.read(
      _pid,
    )).where((e) => e.path == path).firstOrNull;
    if (entry == null) return;
    await _store.put(_pid, entry.copyWith(mobileOk: true));
  }

  Future<void> allowMobileData(String path) async {
    await setMobileOk(path);
    final running = _running;
    if (running != null) await running;
    await run();
  }

  @override
  Future<void> run() => _running ??= _runAll().whenComplete(() {
    _running = null;
  });

  Future<void> _runAll() async {
    final referenced = await _referenced();
    for (final entry in await _store.read(_pid)) {
      if (!await _process(entry, referenced)) return;
    }
  }

  Future<void> _drop(VideoUploadEntry e) async {
    await _store.remove(_pid, e.path);
    _set(e.path, null);
  }

  /// Returns false when the run should stop (a failure).
  Future<bool> _process(VideoUploadEntry entry, Set<String> referenced) async {
    if (!referenced.contains(entry.path)) {
      final session = entry.session;
      if (session != null) {
        try {
          await _provider.cancelLargeUpload(session);
        } catch (e) {
          debugPrint('Video upload cancel failed: ${e.runtimeType}');
        }
      }
      await _drop(entry);
      return true;
    }
    final file = await _files.localFile(entry.path);
    if (file == null) {
      await _drop(entry);
      return true;
    }
    // Already in the offload root: a previous run finished the upload and was
    // killed between offload and drop. Do not upload it again.
    final offloaded = _files.downloadTarget(entry.path);
    if (offloaded != null && await offloaded.exists()) {
      await _drop(entry);
      return true;
    }
    if (!entry.mobileOk && !await _unmetered()) {
      _set(
        entry.path,
        VideoUploadState(
          VideoUploadPhase.waitingForWifi,
          entry.sent,
          entry.total,
        ),
      );
      return true;
    }
    try {
      await _upload(entry, file);
      return true;
    } catch (e) {
      debugPrint('Video upload failed: ${e.runtimeType}');
      _set(
        entry.path,
        VideoUploadState(VideoUploadPhase.failed, entry.sent, entry.total),
      );
      return false;
    }
  }

  Future<void> _upload(VideoUploadEntry entry, File file) async {
    final total = entry.total;
    if (await file.length() != total) {
      // Replaced or truncated since it was queued; the session is useless.
      await _drop(entry);
      return;
    }
    var current = entry;
    var restarted = false;

    Future<int> startSession() async {
      final session = await _provider.startLargeUpload(entry.path, total);
      current = current.copyWith(session: session, sent: 0);
      await _store.put(_pid, current);
      return 0;
    }

    var offset = 0;
    if (current.session == null) {
      offset = await startSession();
    } else {
      final next = await _provider.largeUploadNextOffset(current.session!);
      offset = next ?? await startSession();
    }

    final raf = await file.open();
    try {
      while (true) {
        final stored = (await _store.read(
          _pid,
        )).where((e) => e.path == entry.path).firstOrNull;
        if (stored == null ||
            await _files.localFile(entry.path) == null ||
            !(await _referenced()).contains(entry.path)) {
          // The note was purged (or the file removed) mid-upload: finishing
          // would leave an orphan in the cloud that nothing ever removes.
          final session = current.session;
          if (session != null) {
            try {
              await _provider.cancelLargeUpload(session);
            } catch (e) {
              debugPrint('Video upload cancel failed: ${e.runtimeType}');
            }
          }
          await _drop(entry);
          return;
        }
        if (stored.mobileOk != current.mobileOk) {
          current = current.copyWith(mobileOk: stored.mobileOk);
        }
        if (!current.mobileOk && !await _unmetered()) {
          current = current.copyWith(sent: offset);
          await _store.put(_pid, current);
          _set(
            entry.path,
            VideoUploadState(VideoUploadPhase.waitingForWifi, offset, total),
          );
          return;
        }
        final len = (total - offset) < _fragment ? total - offset : _fragment;
        if (len <= 0) throw StateError('Nothing left to read');
        await raf.setPosition(offset);
        final chunk = await raf.read(len);
        if (chunk.length != len) throw StateError('Short read');
        bool done;
        try {
          done = await _provider.uploadLargeChunk(
            current.session!,
            chunk,
            offset,
            total,
          );
        } on LargeUploadSessionGone {
          if (restarted) rethrow;
          restarted = true;
          offset = await startSession();
          continue;
        }
        offset += chunk.length;
        if (done) break;
        current = current.copyWith(sent: offset);
        await _store.put(_pid, current);
        _set(
          entry.path,
          VideoUploadState(VideoUploadPhase.uploading, offset, total),
        );
      }
    } finally {
      await raf.close();
    }
    // The upload is complete; a failed offload must not cause a re-upload.
    try {
      await _files.offload(entry.path);
      try {
        await _onOffloaded?.call(entry.path);
      } catch (e) {
        debugPrint('Video cache update failed: ${e.runtimeType}');
      }
    } catch (e) {
      debugPrint('Video offload failed: ${e.runtimeType}');
    }
    await _drop(entry);
  }
}

Future<bool> _isUnmetered() async {
  final r = await Connectivity().checkConnectivity();
  return r.contains(ConnectivityResult.wifi) ||
      r.contains(ConnectivityResult.ethernet);
}

/// Null unless the data mode is cloudStorage and the active provider can move
/// large files and there is an on-disk vault. A FutureProvider because the
/// vault file store resolves asynchronously.
final FutureProvider<VideoUploader?> videoUploaderProvider =
    FutureProvider<VideoUploader?>((ref) async {
      if (ref.watch(dataModeProvider) != DataMode.cloudStorage) return null;
      final provider = ref.watch(syncOrchestratorProvider).provider;
      if (provider == null || !provider.supportsLargeFiles) return null;
      final files = await ref.watch(vaultFileStoreProvider.future);
      if (files == null) return null;
      final db = ref.watch(hmmDatabaseProvider);
      return VideoUploader(
        provider: provider,
        store: VideoUploadQueueStore(),
        files: files,
        unmeteredNetwork: _isUnmetered,
        referencedPaths: () => collectReferencedVaultPaths(db),
        onOffloaded: (p) => touchVideo(
          ref.read(videoCacheIndexProvider.future),
          p,
          cache: () => ref.read(videoCacheProvider.future),
        ),
      );
    });
