import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/pending_sync_count_provider.dart';
import '../data/sync/pending_sync_prompt.dart';
import '../data/sync/sync_controller.dart';
import '../navigation/router_config.dart' show rootNavigatorKey;
import '../settings/settings_controller.dart' show settingsProvider;
import '../../features/settings/presentation/widgets/sync_status_card.dart'
    show confirmManualSyncIfOnCellular;
import 'quick_panel/quick_access_panel.dart';
import 'quick_panel/quick_panel_coach_mark.dart';
import 'quick_panel/quick_panel_settings.dart';

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

  /// Whether the Quick Access Panel is currently revealed. Toggled by the
  /// bottom-right long-press hot-zone (open) and the outside-tap dismiss
  /// barrier / a panel action's onDismiss (close).
  bool _panelOpen = false;

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

  void _openPanel() => setState(() => _panelOpen = true);

  void _closePanel() {
    if (_panelOpen) setState(() => _panelOpen = false);
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

    final enabled = ref.watch(quickPanelEnabledProvider);
    final pending = ref.watch(pendingSyncCountProvider).value ?? 0;
    // Final-review fix: don't show the coach mark's full-screen scrim
    // until `settingsProvider` has actually resolved — `quickPanelHintShown`
    // reads `?? false` while settings are still loading on cold start, so a
    // RETURNING user (persisted hint == true) could otherwise see a flash
    // of the scrim before the real value arrives.
    // TODO(quick-panel): also gate coach to authenticated/main route. The
    // router's own signal (`routerAuthStateProvider`,
    // lib/core/navigation/auth_change_provider.dart) is the obvious
    // candidate — it's exactly what `router_config.dart`'s redirect uses —
    // but it transitively resolves through `TokenStorage` /
    // `FlutterSecureStorage` platform channels that aren't mocked by
    // default in widget tests (see test/helpers/mock_token_storage.dart),
    // so watching it here would make this overlay's tests depend on
    // per-test secure-storage plugin overrides rather than a clean signal.
    // Left unwired pending a lighter-weight auth signal or test-harness
    // support.
    final showCoach = enabled &&
        !_panelOpen &&
        !ref.watch(quickPanelHintShownProvider) &&
        ref.watch(settingsProvider).hasValue;

    // Positioned.fill so we can host corner children; a bare Stack does not
    // absorb pointer events in empty regions, so taps outside the hot-zone /
    // open panel fall through to content behind.
    return Positioned.fill(
      child: Stack(
        children: [
          if (_panelOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePanel,
              ),
            ),
          if (enabled && !_panelOpen)
            Positioned(
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(right: 8, bottom: 8),
                // Final-review fix: this hot-zone must react to long-press
                // ONLY — a plain tap has to pass through to whatever's
                // behind it (e.g. a FAB or bottom-nav control). `Semantics
                // .onTap` registers an assistive-tech activation action
                // (screen reader "double-tap to activate") WITHOUT making
                // the zone a pointer-tap target for sighted users, so
                // accessibility is preserved while the GestureDetector
                // below drops `onTap` and switches to `translucent` so it
                // no longer consumes/hit-tests plain taps.
                child: Semantics(
                  button: true,
                  label: 'Home and sync quick actions',
                  onTap: _openPanel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPress: _openPanel,
                    child: const SizedBox(width: 56, height: 56),
                  ),
                ),
              ),
            ),
          if (enabled && !_panelOpen)
            Positioned(
              right: 0,
              bottom: 0,
              child: SafeArea(
                // Finding 1 dropped the hot-zone's tap-to-open, so this dot
                // is now the ONLY tap-to-open affordance while data is at
                // risk — its hit target must be >=48dp. The SizedBox below
                // grows the tap target to 48x48 while the visual dot stays
                // 12x12 (centered), so the minimum inset here is trimmed
                // from the old 12/12 to keep the visible dot roughly where
                // it was in the corner rather than shifting further inward.
                minimum: EdgeInsets.zero,
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final status = _controller.status;
                    final atRisk = shouldPromptPendingSync(
                      pendingCount: pending,
                      autoSyncSkippedForNetwork:
                          status.lastAutoTriggerSkippedForNetwork,
                      lastSyncFailed: status.lastResult != null &&
                          !status.lastResult!.success,
                    );
                    if (!atRisk) return const SizedBox.shrink();
                    return GestureDetector(
                      key: const Key('quickPanelAtRiskDot'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _openPanel,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: _AtRiskDotVisual(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_panelOpen)
            Positioned(
              right: 12,
              bottom: 12,
              child: SafeArea(
                minimum: const EdgeInsets.only(right: 8, bottom: 8),
                // `Positioned(right: ..., bottom: ...)` with no matching
                // `left`/`top` leaves the child's width unbounded (Stack
                // only tightens an axis when BOTH edges on it are set) —
                // QuickAccessPanel's Column(crossAxisAlignment: stretch)
                // needs a bounded width to stretch into, so size this
                // anchor to the panel's own intrinsic width instead of
                // touching QuickAccessPanel itself.
                child: IntrinsicWidth(
                  child: QuickAccessPanel(onDismiss: _closePanel),
                ),
              ),
            ),
          if (showCoach)
            QuickPanelCoachMark(
              onDismiss: () =>
                  ref.read(quickPanelHintShownProvider.notifier).markShown(),
            ),
        ],
      ),
    );
  }
}

/// The visible 12x12 dot for the at-risk indicator. Kept as its own tiny
/// widget so the enclosing `GestureDetector`/`SizedBox` can enlarge the
/// TAP TARGET to 48x48 (Finding 2) without inflating the dot's own visual
/// footprint.
class _AtRiskDotVisual extends StatelessWidget {
  const _AtRiskDotVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}
