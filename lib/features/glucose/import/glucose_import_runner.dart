import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_mode.dart';
import '../../../core/data/sync/sync_controller.dart';
import '../../../core/data/sync/sync_orchestrator.dart';
import '../states/glucose_providers.dart';
import '../states/glucose_settings_providers.dart';
import 'glucose_importer.dart';
import 'glucose_sample_source.dart';
import 'health_glucose_sample_source.dart';

/// Runs [GlucoseImporter] automatically on start and on resume, at most once
/// per [throttle], when every gate holds: iOS, not Cloud API, import on this
/// device, the first import done, and not waiting for the first sync.
/// [importNow] skips the first-import and throttle gates only.
class GlucoseImportRunner with WidgetsBindingObserver {
  GlucoseImportRunner({
    required this.importer,
    required this.prefs,
    required this.isIOS,
    required this.isCloudApi,
    required this.importOnDevice,
    required this.waitingForFirstSync,
    this.syncEvents,
    this.isSyncing = _no,
    this.now = DateTime.now,
    this.throttle = const Duration(minutes: 15),
  });

  static bool _no() => false;

  /// Built per run, only once the gates hold (the repository throws in Cloud
  /// API mode).
  final GlucoseImporter Function() importer;
  final GlucoseImportPrefs prefs;
  final bool Function() isIOS;
  final bool Function() isCloudApi;

  /// "Import from Apple Health on this device", once its stored value is
  /// known.
  final Future<bool> Function() importOnDevice;

  /// True while cloud sync is on and no sync has finished since install.
  final bool Function() waitingForFirstSync;

  /// Notifies on sync status changes. An automatic run held back by the
  /// first sync, or by the sync lock, runs once a sync finishes.
  final Listenable? syncEvents;
  final bool Function() isSyncing;
  final DateTime Function() now;
  final Duration throttle;

  final ValueNotifier<GlucoseImportResult?> _lastResult = ValueNotifier(null);

  /// The latest run's result (automatic or manual) for the list's message.
  ValueListenable<GlucoseImportResult?> get lastResult => _lastResult;

  DateTime? _lastAutoRun;
  bool _autoRunning = false;
  bool _retryAfterSync = false;
  bool _started = false;
  bool _disposed = false;
  Future<void> _queue = Future<void>.value();

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    syncEvents?.addListener(_afterSync);
    unawaited(_auto());
  }

  void _afterSync() {
    if (!_retryAfterSync || isSyncing() || waitingForFirstSync()) return;
    _retryAfterSync = false;
    unawaited(_auto());
  }

  Future<void> _auto() async {
    if (_disposed || _autoRunning) return;
    final at = now();
    final previous = _lastAutoRun;
    if (previous != null && at.difference(previous) < throttle) return;
    _autoRunning = true;
    try {
      if (!isIOS() || isCloudApi()) return;
      if (waitingForFirstSync()) {
        _retryAfterSync = true;
        return;
      }
      if (!await importOnDevice()) return;
      if (!await prefs.importedOnce()) return;
      if (_disposed) return;
      _lastAutoRun = at;
      final result = await _run(manual: false);
      if (result.error is GlucoseImportBusy) {
        // Not a failure the owner needs to see: try again after the sync,
        // or on the next resume.
        _lastAutoRun = previous;
        _retryAfterSync = true;
        return;
      }
      if (!_disposed) _lastResult.value = result;
    } catch (e) {
      debugPrint('Glucose import skipped (${e.runtimeType})');
    } finally {
      _autoRunning = false;
    }
  }

  /// The owner's "Import now". Null when a gate other than the first-import
  /// flag or the throttle fails.
  Future<GlucoseImportResult?> importNow() async {
    if (_disposed || !isIOS() || isCloudApi() || waitingForFirstSync()) {
      return null;
    }
    if (!await importOnDevice()) return null;
    if (_disposed) return null;
    final result = await _run(manual: true);
    if (!_disposed) _lastResult.value = result;
    return result;
  }

  /// One import at a time; a second waits for the first.
  Future<GlucoseImportResult> _run({required bool manual}) {
    final next = _queue.then((_) async {
      try {
        return await importer().run(manual: manual);
      } catch (e) {
        return GlucoseImportResult(error: e);
      }
    });
    _queue = next.then((_) {});
    return next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_auto());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      syncEvents?.removeListener(_afterSync);
    }
    _lastResult.dispose();
  }
}

final glucoseSampleSourceProvider = Provider<GlucoseSampleSource>(
  (ref) => HealthGlucoseSampleSource(),
);

/// Rebuilt with the sync controller and data mode. The app root keeps it
/// alive and starts each new instance.
final glucoseImportRunnerProvider = Provider<GlucoseImportRunner>((ref) {
  final mode = ref.watch(dataModeProvider);
  final controller = ref.watch(syncControllerProvider);
  final cloudSync = ref.watch(syncOrchestratorProvider).isActive;
  final prefs = ref.watch(glucoseImportPrefsProvider);
  final cloudApi = mode == DataMode.cloudApi;
  final runner = GlucoseImportRunner(
    importer: () => GlucoseImporter(
      repo: ref.read(glucoseRepositoryProvider),
      source: ref.read(glucoseSampleSourceProvider),
      prefs: prefs,
      now: DateTime.now,
      runExclusive: controller.runExclusive,
    ),
    prefs: prefs,
    isIOS: () => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
    isCloudApi: () => cloudApi,
    importOnDevice: () async {
      ref.read(glucoseImportOnDeviceProvider);
      await ref.read(glucoseImportOnDeviceProvider.notifier).loaded;
      return ref.read(glucoseImportOnDeviceProvider);
    },
    waitingForFirstSync: () =>
        cloudSync && controller.status.lastSyncAt == null,
    syncEvents: controller,
    isSyncing: () => controller.status.isSyncing,
  );
  ref.onDispose(runner.dispose);
  return runner;
});
