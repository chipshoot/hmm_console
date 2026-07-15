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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _maybePrompt();
    }
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
