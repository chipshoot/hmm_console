import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/pending_sync_count_provider.dart';
import '../data/sync/pending_sync_prompt.dart';
import '../data/sync/sync_controller.dart';
import '../navigation/router_config.dart' show rootNavigatorKey;
import '../../features/settings/presentation/widgets/sync_status_card.dart'
    show confirmManualSyncIfOnCellular;
import 'home_button.dart';
import 'sync_pill.dart';

/// Persistent Home + Sync control cluster, mounted ONCE above the router
/// (`lib/main.dart`'s `MaterialApp.router(builder: ...)`) so it appears on
/// every screen with zero per-screen edits — including the Dashboard's raw
/// `Scaffold` (`dashboard_screen.dart:91`). Bottom-trailing, inside
/// `SafeArea`, small enough to clear bottom nav bars / FABs / the note
/// editor's media toolbar.
///
/// Also owns the "blocked/failed safety net" prompt (spec Architecture
/// §3): watches [pendingSyncCountProvider] for a threshold crossing and
/// listens for app-background, showing a one-tap "Sync now / Wait for
/// WiFi" prompt when [shouldPromptPendingSync] says the data is at risk.
class HomeSyncOverlay extends ConsumerStatefulWidget {
  const HomeSyncOverlay({super.key});

  @override
  ConsumerState<HomeSyncOverlay> createState() => _HomeSyncOverlayState();
}

class _HomeSyncOverlayState extends ConsumerState<HomeSyncOverlay>
    with WidgetsBindingObserver {
  bool _promptShowing = false;

  /// True from the moment we background until either a prompt actually
  /// shows or pending drops to 0. See the class doc + the "Final-review
  /// fix" note below for why this exists: `SyncController` only sets
  /// `lastAutoTriggerSkippedForNetwork` AFTER an awaited connectivity
  /// probe (`_executeWithGate` in `sync_controller.dart`), so reading the
  /// flag synchronously on `paused` misses the first background on
  /// cellular. Staying armed until the controller's next `notifyListeners`
  /// (when the gate resolves) — rather than disarming on `resumed` — also
  /// survives the OS suspending the isolate before the gate finishes.
  bool _armedForBackgroundPrompt = false;

  /// Mutable (not `late final`) because [syncControllerProvider] can be
  /// rebuilt into a brand-new [SyncController] instance at runtime — it
  /// watches the sync orchestrator, which watches `dataModeProvider`, so
  /// switching DataMode (Settings → Data Mode) swaps the live controller
  /// out from under us. `main.dart`'s `_MainAppState.build` handles the
  /// same hazard for `start()`/`stop()` via `ref.listen`; this widget
  /// mirrors that pattern in [build] to keep `_onControllerChanged`
  /// attached to whichever controller is actually live, instead of going
  /// silently stale on the orphaned old instance (which is only
  /// `stop()`ed via `ref.onDispose`, never notified again).
  late SyncController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial bind — `ref.listen` (in `build`) only fires on CHANGE, not
    // for the provider's current value, so the first instance must be
    // wired up here.
    _controller = ref.read(syncControllerProvider);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _armedForBackgroundPrompt = true;
      // Covers the sticky/fast path: the blocked/failed flag may already
      // be set from a prior cycle, in which case this fires immediately.
      _maybePrompt();
    }
  }

  /// Fires when [SyncController] notifies — in particular when its gated
  /// auto-sync resolves (`_executeWithGate` sets
  /// `lastAutoTriggerSkippedForNetwork` and notifies). Only acts while
  /// armed, so it's a no-op outside the background-prompt window.
  void _onControllerChanged() {
    if (_armedForBackgroundPrompt) _maybePrompt();
  }

  void _maybePrompt() {
    final pending = ref.read(pendingSyncCountProvider).value ?? 0;
    final status = ref.read(syncControllerProvider).status;
    final shouldPrompt = shouldPromptPendingSync(
      pendingCount: pending,
      autoSyncSkippedForNetwork: status.lastAutoTriggerSkippedForNetwork,
      lastSyncFailed:
          status.lastResult != null && !status.lastResult!.success,
    );
    if (!shouldPrompt || _promptShowing) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;
    _promptShowing = true;
    // We're committing to showing the prompt — disarm so a later
    // controller notification (e.g. the eventual sync outcome) doesn't
    // try to show a second one.
    _armedForBackgroundPrompt = false;
    showDialog<void>(
      context: navContext,
      builder: (ctx) => AlertDialog(
        title: Text(
          '$pending change${pending == 1 ? '' : 's'} '
          "haven't reached your cloud",
        ),
        content: const Text(
          'Sync now may use cellular data, or wait for WiFi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Wait for WiFi'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final proceed =
                  await confirmManualSyncIfOnCellular(navContext, ref);
              if (proceed) {
                await ref.read(syncControllerProvider).triggerManualSync();
              }
            },
            child: const Text('Sync now'),
          ),
        ],
      ),
    ).then((_) => _promptShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Re-bind the listener whenever `syncControllerProvider` produces a
    // new instance (DataMode switch — see the `_controller` doc comment).
    // Without this, `_controller` would stay pointed at the orphaned old
    // instance and `_onControllerChanged` would never fire again for the
    // rest of the session, silently killing the gate-resolution prompt
    // path in the new mode.
    ref.listen<SyncController>(syncControllerProvider, (prev, next) {
      prev?.removeListener(_onControllerChanged);
      next.addListener(_onControllerChanged);
      _controller = next;
    });

    // Threshold-crossing trigger: fire the same prompt when pending count
    // jumps from below to at/above pendingSyncPromptThreshold, independent
    // of app-background.
    ref.listen<AsyncValue<int>>(pendingSyncCountProvider, (prev, next) {
      final prevCount = prev?.value ?? 0;
      final nextCount = next.value ?? 0;
      if (prevCount < pendingSyncPromptThreshold &&
          nextCount >= pendingSyncPromptThreshold) {
        _maybePrompt();
      }
      if (nextCount == 0) {
        // Nothing left at risk — a background-armed prompt that hasn't
        // fired yet (gate still resolving, or the OS never re-notified
        // us) is now moot.
        _armedForBackgroundPrompt = false;
      }
    });

    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            HomeButton(),
            SizedBox(width: 8),
            SyncPill(),
          ],
        ),
      ),
    );
  }
}
