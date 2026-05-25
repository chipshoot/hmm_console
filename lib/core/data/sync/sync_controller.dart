import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_models.dart';
import 'sync_orchestrator.dart';

/// Why a sync was kicked off. Surfaced into [SyncStatus.lastReason] so the
/// settings UI can show "Synced from background" vs "Synced periodically"
/// when useful for debugging.
enum SyncTriggerReason {
  /// User tapped the Sync Now button — bypasses the throttle window.
  manual,

  /// App returned to the foreground (debounced — see
  /// [SyncController.foregroundDebounce]).
  appForeground,

  /// App is going to the background — best-effort push of pending edits
  /// before the OS may suspend us.
  appBackground,

  /// 10-minute safety-net timer while the app is in `resumed`.
  periodic,
}

/// Snapshot of sync state that the UI binds to via [SyncController] (a
/// [ChangeNotifier]). Pure value object so widgets can rebuild reliably
/// on update.
class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastResult,
    this.lastReason,
    this.consecutiveFailures = 0,
  });

  /// True while a sync is in flight (between [SyncController._runSync]
  /// start and its `finally` block).
  final bool isSyncing;

  /// When the most recent sync **completed** (not when it started).
  /// Null if no sync has ever run in this app process.
  final DateTime? lastSyncAt;

  /// Full result of the most recent sync. Null if no sync has run.
  final SyncResult? lastResult;

  /// Trigger that fired the most recent sync.
  final SyncTriggerReason? lastReason;

  /// Number of failed syncs in a row. Resets to 0 on any success. Used
  /// by the settings UI to escalate from a transient snackbar to a
  /// persistent badge after a few failures in a row (decision B2 in
  /// task_plan.md).
  final int consecutiveFailures;

  SyncStatus _copyWith({
    bool? isSyncing,
    DateTime? lastSyncAt,
    SyncResult? lastResult,
    SyncTriggerReason? lastReason,
    int? consecutiveFailures,
  }) {
    return SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastResult: lastResult ?? this.lastResult,
      lastReason: lastReason ?? this.lastReason,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }
}

/// Function shape that [SyncController] calls when it decides to sync.
/// Production-wired to `() => orchestrator.syncNow()`; tests pass a fake
/// that returns canned [SyncResult]s and counts invocations.
typedef SyncAction = Future<SyncResult> Function();

/// Pluggable clock so tests can drive throttle + periodic timing without
/// `await Future.delayed(...)`.
typedef ClockNow = DateTime Function();

DateTime _defaultNow() => DateTime.now().toUtc();

/// Schedules automatic sync passes on top of [SyncOrchestrator]:
///
///   - On app **foreground** (`AppLifecycleState.resumed`): wait
///     [foregroundDebounce] then fire (debounce avoids double-firing on
///     rapid iOS lifecycle bounces during phone calls / notifications).
///   - On app **background** (`AppLifecycleState.paused`): fire
///     immediately — best-effort push before the OS may suspend us.
///   - Every [periodicInterval] while the app is in `resumed`: fire
///     (safety net for long-lived foreground sessions).
///   - User tap on Sync Now (route via [triggerManualSync]): fire
///     immediately, **bypassing the throttle** (the user just asked).
///
/// All auto-triggers (everything except manual) share a single
/// [throttle] window — if the previous sync started less than
/// [throttle] ago, a new auto-trigger is dropped silently. In-flight
/// syncs always short-circuit further triggers (manual or auto) until
/// done.
///
/// Failures are not exposed by throwing — they live in
/// [SyncStatus.lastResult] / [SyncStatus.consecutiveFailures] so the
/// settings UI can decide how loud to be (transient snackbar vs
/// persistent badge after 3 in a row — decision B2).
class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  SyncController({
    required SyncAction syncAction,
    this.throttle = const Duration(seconds: 30),
    this.periodicInterval = const Duration(minutes: 10),
    this.foregroundDebounce = const Duration(milliseconds: 250),
    ClockNow now = _defaultNow,
  })  : _syncAction = syncAction,
        _now = now;

  final SyncAction _syncAction;
  final Duration throttle;
  final Duration periodicInterval;
  final Duration foregroundDebounce;
  final ClockNow _now;

  Timer? _periodicTimer;
  Timer? _foregroundDebounceTimer;
  DateTime? _lastSyncStartedAt;
  SyncStatus _status = const SyncStatus();
  bool _started = false;

  SyncStatus get status => _status;

  /// Register the binding observer + start the periodic timer. Idempotent
  /// — repeat calls are no-ops. Call from the root widget's
  /// `initState()` once auth has resolved.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _restartPeriodicTimer();
  }

  /// Mirror of [start] — call from the root widget's `dispose()` and on
  /// logout. Cancels both timers + removes the binding observer.
  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _foregroundDebounceTimer?.cancel();
    _foregroundDebounceTimer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Debounce: iOS often fires resumed → inactive → resumed in
        // quick succession when a notification banner drops. Wait
        // [foregroundDebounce] so the trigger only counts the user's
        // actual return.
        _foregroundDebounceTimer?.cancel();
        _foregroundDebounceTimer = Timer(foregroundDebounce, () {
          triggerAutoSync(SyncTriggerReason.appForeground);
        });
        _restartPeriodicTimer();
        break;
      case AppLifecycleState.paused:
        // Cancel any pending foreground-debounce + the periodic timer
        // (no point running it while backgrounded). Best-effort fire
        // the background push.
        _foregroundDebounceTimer?.cancel();
        _foregroundDebounceTimer = null;
        _periodicTimer?.cancel();
        _periodicTimer = null;
        unawaited(triggerAutoSync(SyncTriggerReason.appBackground));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Don't sync on these transitions — they fire too often (phone
        // calls, control center, app switcher peek) and aren't reliable
        // signals of intent.
        break;
    }
  }

  /// Fire a sync triggered by lifecycle / timer. Drops silently if a
  /// sync is in flight OR if the throttle window hasn't elapsed.
  /// Returns the [SyncResult] when it actually ran, null when skipped.
  Future<SyncResult?> triggerAutoSync(SyncTriggerReason reason) async {
    if (_status.isSyncing) return null;
    if (_lastSyncStartedAt != null &&
        _now().difference(_lastSyncStartedAt!) < throttle) {
      return null;
    }
    return _runSync(reason);
  }

  /// User-initiated sync. Bypasses the throttle (the user just asked,
  /// it'd be confusing to silently drop it) but still respects
  /// in-flight — if a sync is already running, the manual trigger waits
  /// for it via the returned Future and the caller sees the same
  /// result.
  Future<SyncResult?> triggerManualSync() async {
    if (_status.isSyncing) return null;
    return _runSync(SyncTriggerReason.manual);
  }

  Future<SyncResult?> _runSync(SyncTriggerReason reason) async {
    _lastSyncStartedAt = _now();
    _status = _status._copyWith(isSyncing: true, lastReason: reason);
    notifyListeners();

    SyncResult? result;
    try {
      result = await _syncAction();
    } catch (e) {
      // Wrap as a SyncResult.failed so the status surface stays
      // uniform — the orchestrator already does this for its own
      // errors, but a thrown exception from a fake or from network
      // tear-down lands here.
      result = SyncResult.failed(
        at: _now(),
        error: SyncError(
          recordType: 'transport',
          recordId: '-',
          message: 'Sync threw: $e',
        ),
      );
    }

    final ok = result.success;
    _status = SyncStatus(
      isSyncing: false,
      lastSyncAt: _now(),
      lastResult: result,
      lastReason: reason,
      consecutiveFailures: ok ? 0 : _status.consecutiveFailures + 1,
    );
    notifyListeners();
    return result;
  }

  void _restartPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(periodicInterval, (_) {
      triggerAutoSync(SyncTriggerReason.periodic);
    });
  }
}

/// Singleton SyncController per app process. Stops + restarts when the
/// sync orchestrator changes (i.e. when the user switches DataMode in
/// settings — the new orchestrator might point at a different cloud
/// provider). The root widget calls `.start()` after auth resolves.
final syncControllerProvider = Provider<SyncController>((ref) {
  final orchestrator = ref.watch(syncOrchestratorProvider);
  final controller = SyncController(
    syncAction: orchestrator.syncNow,
  );
  ref.onDispose(controller.stop);
  return controller;
});
