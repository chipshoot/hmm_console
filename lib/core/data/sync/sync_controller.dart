import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/domain/sync_settings.dart';
import '../../../features/settings/providers/sync_settings_provider.dart';
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
    this.lastAutoTriggerSkippedForNetwork = false,
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

  /// True if the most recent auto-trigger was suppressed by the
  /// WiFi-only network policy (device is on cellular / no network).
  /// Drives the "Waiting for WiFi" state of [SyncStatusCard]. Cleared
  /// to false whenever a sync actually runs (success or failure) —
  /// it's a transient banner, not a sticky error.
  final bool lastAutoTriggerSkippedForNetwork;

  SyncStatus _copyWith({
    bool? isSyncing,
    DateTime? lastSyncAt,
    SyncResult? lastResult,
    SyncTriggerReason? lastReason,
    int? consecutiveFailures,
    bool? lastAutoTriggerSkippedForNetwork,
  }) {
    return SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastResult: lastResult ?? this.lastResult,
      lastReason: lastReason ?? this.lastReason,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastAutoTriggerSkippedForNetwork: lastAutoTriggerSkippedForNetwork ??
          this.lastAutoTriggerSkippedForNetwork,
    );
  }
}

/// Function shape that [SyncController] calls when it decides to sync.
/// Production-wired to `() => orchestrator.syncNow()`; tests pass a fake
/// that returns canned [SyncResult]s and counts invocations.
typedef SyncAction = Future<SyncResult> Function();

/// Returns `true` when an auto-trigger is allowed to fire right now.
/// Production wiring composes WiFi-only network policy + connectivity
/// probe (Phase C); the default `(() async => true)` opts every controller
/// into "always allowed", which keeps tests + non-network-aware callers
/// simple.
typedef CanAutoSyncCheck = Future<bool> Function();

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
    CanAutoSyncCheck? canAutoSync,
    this.throttle = const Duration(seconds: 30),
    this.periodicInterval = const Duration(minutes: 10),
    this.foregroundDebounce = const Duration(milliseconds: 250),
    ClockNow now = _defaultNow,
  })  : _syncAction = syncAction,
        _canAutoSync = canAutoSync ?? _alwaysAllow,
        _now = now;

  final SyncAction _syncAction;
  final CanAutoSyncCheck _canAutoSync;
  final Duration throttle;
  final Duration periodicInterval;
  final Duration foregroundDebounce;
  final ClockNow _now;

  static Future<bool> _alwaysAllow() async => true;

  Timer? _periodicTimer;
  Timer? _foregroundDebounceTimer;
  DateTime? _lastSyncStartedAt;
  SyncStatus _status = const SyncStatus();
  bool _started = false;

  SyncStatus get status => _status;

  /// Whether [start] has registered the lifecycle observer + periodic
  /// timer for this instance. Exposed so the wiring that re-starts a
  /// recreated controller (root widget) can be regression-tested.
  bool get isStarted => _started;

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

  /// Fire a sync triggered by lifecycle / timer. Drops silently when:
  ///   - a sync is already in flight
  ///   - the 30-s throttle window hasn't elapsed
  ///   - the injected [CanAutoSyncCheck] returns false (production wires
  ///     this to "WiFi-only policy is on AND device is on cellular")
  /// Returns the [SyncResult] when it actually ran, null when skipped.
  /// When the network policy was the reason for the skip, sets
  /// [SyncStatus.lastAutoTriggerSkippedForNetwork] so the UI can show
  /// "Waiting for WiFi". Throttle / in-flight skips don't touch that
  /// flag — they're invisible to the UI.
  Future<SyncResult?> triggerAutoSync(SyncTriggerReason reason) async {
    if (_status.isSyncing) return null;
    if (_lastSyncStartedAt != null &&
        _now().difference(_lastSyncStartedAt!) < throttle) {
      return null;
    }
    // Claim the in-flight slot synchronously, BEFORE awaiting the gate.
    // Otherwise a manual-or-auto trigger that fires while we're paused
    // at `await _canAutoSync()` would see `isSyncing == false` and
    // double-run the sync. We don't notify yet — the UI shouldn't
    // flicker "Syncing…" when the gate is about to reject.
    _status = _status._copyWith(isSyncing: true, lastReason: reason);
    return _executeWithGate(reason);
  }

  /// User-initiated sync. Bypasses the throttle and the auto-sync gate
  /// (the user just asked — see decision C1 in `task_plan.md`; the
  /// settings UI handles the cellular-warn confirm dialog before calling
  /// us). Still respects in-flight: if a sync is already running, this
  /// returns null immediately.
  Future<SyncResult?> triggerManualSync() async {
    if (_status.isSyncing) return null;
    _lastSyncStartedAt = _now();
    _status = _status._copyWith(
      isSyncing: true,
      lastReason: SyncTriggerReason.manual,
    );
    notifyListeners();
    return _executeAction(SyncTriggerReason.manual);
  }

  /// Auto-sync's two-phase tail after the synchronous claim: first
  /// award the network gate, then either skip with the "Waiting for
  /// WiFi" flag or proceed to the action.
  Future<SyncResult?> _executeWithGate(SyncTriggerReason reason) async {
    final allowed = await _canAutoSync();
    if (!allowed) {
      final wasAlreadyFlagged = _status.lastAutoTriggerSkippedForNetwork;
      _status = _status._copyWith(
        isSyncing: false,
        lastAutoTriggerSkippedForNetwork: true,
      );
      // Only notify if the flag actually changed — avoids per-tick
      // rebuild storms when periodic timers keep firing while
      // cellular-only.
      if (!wasAlreadyFlagged) notifyListeners();
      return null;
    }
    _lastSyncStartedAt = _now();
    notifyListeners(); // Now the UI shows the spinner.
    return _executeAction(reason);
  }

  /// Calls the injected [SyncAction] and wires the result back into
  /// [SyncStatus]. Assumes the caller has already claimed `isSyncing`
  /// and called `notifyListeners()` (or chose not to — for skip paths).
  Future<SyncResult> _executeAction(SyncTriggerReason reason) async {
    SyncResult result;
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
      // A real sync just ran — any prior "Waiting for WiFi" banner is
      // stale, clear it.
      lastAutoTriggerSkippedForNetwork: false,
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
///
/// The `canAutoSync` callback re-reads the current `SyncSettings` on every
/// invocation via `ref.read` — that way a user flipping the radio in
/// Settings → Sync over takes effect on the very next auto-trigger
/// without rebuilding the controller.
final syncControllerProvider = Provider<SyncController>((ref) {
  final orchestrator = ref.watch(syncOrchestratorProvider);
  final connectivity = Connectivity();
  final controller = SyncController(
    syncAction: orchestrator.syncNow,
    canAutoSync: () async {
      final policy = ref.read(syncSettingsProvider).networkPolicy;
      if (policy == SyncNetworkPolicy.anyNetwork) return true;
      // WiFi-only policy: only allow when the device reports WiFi in
      // its list of active connections. Cellular / none / VPN-on-cell
      // all block.
      final results = await connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.wifi);
    },
  );
  ref.onDispose(controller.stop);
  return controller;
});
