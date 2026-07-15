/// Pure decision logic for the "blocked/failed safety net" prompt (Part A
/// anti-loss — see
/// `docs/superpowers/specs/2026-07-15-sync-safety-persistent-access-design.md`).
/// No Flutter/Riverpod imports so it's trivially unit-testable; the
/// widget layer (`HomeSyncOverlay`, Task 6) supplies the live values and
/// owns WHEN to call it (app-background, or a threshold crossing it
/// detects itself via `ref.listen` since that needs the previous value).
library;

/// Small pending-count threshold that, when crossed upward, is ALSO a
/// trigger for the prompt (independent of app-background) — see the
/// spec's Architecture §3: "on app-background (or when the count crosses
/// a small threshold)".
const int pendingSyncPromptThreshold = 5;

/// True when there's local data at risk (`pendingCount > 0`) AND
/// auto-sync is currently unable to reach the cloud on its own — either
/// gated by the WiFi-only network policy ([autoSyncSkippedForNetwork],
/// mirrors `SyncStatus.lastAutoTriggerSkippedForNetwork`) or the most
/// recent sync attempt failed ([lastSyncFailed], mirrors
/// `SyncStatus.lastResult != null && !SyncStatus.lastResult!.success`).
bool shouldPromptPendingSync({
  required int pendingCount,
  required bool autoSyncSkippedForNetwork,
  required bool lastSyncFailed,
}) {
  if (pendingCount <= 0) return false;
  return autoSyncSkippedForNetwork || lastSyncFailed;
}
