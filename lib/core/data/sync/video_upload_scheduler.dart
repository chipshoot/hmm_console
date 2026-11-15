import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/video/keep_offline.dart';
import '../attachments/video/video_cache.dart';
import '../attachments/video/video_platform.dart';
import '../attachments/video/video_uploader.dart';
import 'sync_controller.dart';

/// What the scheduler needs from an uploader; [VideoUploader] implements it.
abstract interface class VideoUploadRunner {
  Future<void> load();
  Future<void> run();
}

/// Kicks the video upload queue: after each finished sync, when the uploader
/// is (re)built, on app resume and when Wi-Fi/ethernet returns. Never while a
/// sync is running, and it holds an iOS background task for the length of a
/// run so a backgrounded upload gets the grace period.
class VideoUploadScheduler with WidgetsBindingObserver {
  VideoUploadScheduler({
    required Future<VideoUploadRunner?> Function() resolveUploader,
    required bool Function() isSyncing,
    required VideoPlatform platform,
    Stream<List<ConnectivityResult>>? connectivity,
    Future<void> Function()? onAttach,
    Future<void> Function()? fetchMissing,
  }) : _resolve = resolveUploader,
       _isSyncing = isSyncing,
       _platform = platform,
       _connectivity = connectivity,
       _onAttach = onAttach,
       _fetchMissing = fetchMissing;

  final Future<VideoUploadRunner?> Function() _resolve;
  final bool Function() _isSyncing;
  final VideoPlatform _platform;
  final Stream<List<ConnectivityResult>>? _connectivity;
  final Future<void> Function()? _onAttach;
  final Future<void> Function()? _fetchMissing;
  bool _onAttachRan = false;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  VideoUploadRunner? _loaded;
  Future<void>? _inFlight;
  bool _rerun = false;
  bool _attached = false;

  /// Start listening for resume and connectivity changes.
  void attach() {
    if (_attached) return;
    _attached = true;
    if (!_onAttachRan) {
      _onAttachRan = true;
      unawaited(_runOnAttach());
    }
    WidgetsBinding.instance.addObserver(this);
    _sub = _connectivity?.listen((results) {
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        unawaited(maybeRun());
      }
    });
  }

  Future<void> _runOnAttach() async {
    try {
      await _onAttach?.call();
    } catch (e) {
      debugPrint(
        'VideoUploadScheduler: launch sweep failed (${e.runtimeType})',
      );
    }
  }

  /// Best effort: starts downloads of kept-offline videos; never fails the run.
  Future<void> _runFetchMissing() async {
    try {
      await _fetchMissing?.call();
    } catch (e) {
      debugPrint(
        'VideoUploadScheduler: keep-offline fetch failed (${e.runtimeType})',
      );
    }
  }

  void dispose() {
    if (_attached) WidgetsBinding.instance.removeObserver(this);
    _attached = false;
    unawaited(_sub?.cancel());
    _sub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(maybeRun());
  }

  /// Run the queue once unless a sync or another run is in progress.
  ///
  /// A trigger that lands mid-run is remembered and answered with exactly one
  /// more run afterwards, so work queued during a run is not stranded. The
  /// returned future covers the re-run too.
  Future<void> maybeRun() {
    if (_isSyncing()) return Future.value();
    if (_inFlight != null) {
      _rerun = true;
      return _inFlight!;
    }
    return _inFlight = _loop().whenComplete(() => _inFlight = null);
  }

  Future<void> _loop() async {
    do {
      _rerun = false;
      await _run();
    } while (_rerun && !_isSyncing());
  }

  Future<void> _run() async {
    int? task;
    try {
      final uploader = await _resolve();
      if (uploader == null) return;
      if (_isSyncing()) return;
      if (!identical(_loaded, uploader)) {
        await uploader.load();
        _loaded = uploader;
      }
      task = await _platform.beginBackgroundTask();
      try {
        await uploader.run();
      } finally {
        // Kept-offline downloads don't depend on the upload run succeeding.
        await _runFetchMissing();
      }
    } catch (e) {
      // Type only: a DioException's text can carry a pre-authenticated URL.
      debugPrint('VideoUploadScheduler: run failed (${e.runtimeType})');
    } finally {
      if (task != null) {
        try {
          await _platform.endBackgroundTask(task);
        } catch (e) {
          debugPrint(
            'VideoUploadScheduler: end task failed (${e.runtimeType})',
          );
        }
      }
    }
  }
}

final Provider<VideoUploadScheduler> videoUploadSchedulerProvider =
    Provider<VideoUploadScheduler>((ref) {
      final controller = ref.watch(syncControllerProvider);
      final scheduler = VideoUploadScheduler(
        resolveUploader: () async => ref.read(videoUploaderProvider.future),
        isSyncing: () => controller.status.isSyncing,
        platform: ref.watch(videoPlatformProvider),
        connectivity: Connectivity().onConnectivityChanged,
        onAttach: () async {
          final cache = await ref.read(videoCacheProvider.future);
          await cache?.sweepStaleParts();
          await cache?.evictToFit();
        },
        fetchMissing: () async {
          await (await ref.read(keepOfflineProvider.future))?.fetchMissing();
        },
      )..attach();
      void afterSync() => unawaited(scheduler.maybeRun());
      (controller as Listenable).addListener(afterSync);
      // A new uploader (data-mode or provider switch) gets its first run here.
      ref.listen<AsyncValue<VideoUploader?>>(videoUploaderProvider, (_, next) {
        if (next.hasValue) afterSync();
      });
      ref.onDispose(() {
        controller.removeListener(afterSync);
        scheduler.dispose();
      });
      return scheduler;
    });
