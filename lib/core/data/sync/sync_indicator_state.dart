import '../data_mode.dart';
import 'sync_controller.dart';

/// What the dashboard dot shows. Five states, deliberately kept apart:
/// collapsing "waiting" into "failed", or "never synced" into "synced", is
/// the mistake that produced four bug reports on the licence screens.
enum SyncIndicatorState {
  /// Last run succeeded.
  synced,

  /// A run is in flight right now.
  syncing,

  /// Nothing is wrong, but nothing has happened either: held for Wi-Fi by
  /// the network policy, or cloud is configured and no run has occurred.
  waiting,

  /// The last run failed, or three or more in a row have.
  failed,

  /// Local data mode: there is no cloud, so there is no dot. Absence is the
  /// signal — a grey dot would claim a state about nothing.
  none,
}

SyncIndicatorState syncIndicatorStateFor(SyncStatus status, DataMode mode) {
  if (mode == DataMode.local) return SyncIndicatorState.none;
  // Order matters and mirrors SyncStatusCard: in-flight beats a stale
  // failure, a failure streak beats a Wi-Fi hold, and a hold beats a stale
  // single result — the policy is doing its job, nothing is broken.
  if (status.isSyncing) return SyncIndicatorState.syncing;
  if (status.consecutiveFailures >= 3) return SyncIndicatorState.failed;
  if (status.lastAutoTriggerSkippedForNetwork) {
    return SyncIndicatorState.waiting;
  }
  final last = status.lastResult;
  if (last != null && !last.success) return SyncIndicatorState.failed;
  if (status.lastSyncAt != null) return SyncIndicatorState.synced;
  return SyncIndicatorState.waiting;
}

/// Whether the most recent failure was a sign-in problem, so the sheet can
/// offer "Sign in again" rather than a retry that would fail the same way.
bool isAuthFailure(SyncStatus status) =>
    status.lastResult?.errors.any((e) => e.recordType == 'auth') ?? false;
