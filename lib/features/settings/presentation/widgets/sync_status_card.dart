import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/sync/sync_controller.dart';
import '../../domain/sync_settings.dart';
import '../../providers/sync_settings_provider.dart';

/// Shows the live sync state and surfaces a manual "Sync Now" button.
/// Binds to [SyncController] (a [ChangeNotifier]) so it rebuilds whenever
/// the controller pushes a new [SyncStatus] — no Riverpod state stream
/// needed.
///
/// States rendered:
///   - Syncing… (spinner)
///   - Synced N ago (idle, success)
///   - Waiting for WiFi (auto-sync was skipped by WiFi-only policy)
///   - Last sync failed (transient banner)
///   - Sync failing — persistent badge after 3+ consecutive failures
///   - Never synced (idle, fresh app)
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(syncControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _Body(controller: controller),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.controller});

  final SyncController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = controller.status;
    final theme = Theme.of(context);

    Widget leading;
    String headline;
    Color? headlineColor;

    if (status.isSyncing) {
      leading = const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      headline = 'Syncing now…';
    } else if (status.consecutiveFailures >= 3) {
      // Persistent badge after 3 failures in a row (decision B2 in
      // task_plan.md). At this point the user should notice — a
      // transient snackbar isn't enough.
      leading = Icon(Icons.error, color: theme.colorScheme.error);
      headline = 'Sync failing — last ${status.consecutiveFailures} attempts';
      headlineColor = theme.colorScheme.error;
    } else if (status.lastAutoTriggerSkippedForNetwork) {
      // WiFi-only policy blocked the most recent auto-trigger. Stays
      // visible until the next real sync runs (manual or auto when
      // WiFi comes back).
      leading = Icon(Icons.wifi_off, color: theme.colorScheme.tertiary);
      headline = 'Waiting for WiFi to sync';
    } else if (status.lastResult != null && !status.lastResult!.success) {
      leading = Icon(Icons.warning_amber, color: theme.colorScheme.tertiary);
      headline = 'Last sync failed';
    } else if (status.lastSyncAt != null) {
      leading = Icon(Icons.cloud_done, color: theme.colorScheme.primary);
      headline = 'Synced ${_relativeTime(status.lastSyncAt!)}';
    } else {
      leading = const Icon(Icons.cloud_off);
      headline = 'Not synced yet';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: headlineColor,
                        fontWeight: FontWeight.w500,
                      )),
                  if (status.lastResult != null &&
                      !status.isSyncing &&
                      !status.lastAutoTriggerSkippedForNetwork &&
                      status.lastResult!.errors.isNotEmpty)
                    Text(
                      status.lastResult!.errors.first.message,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: status.isSyncing
                  ? null
                  : () async {
                      final proceed =
                          await confirmManualSyncIfOnCellular(context, ref);
                      if (!proceed) return;
                      await controller.triggerManualSync();
                    },
              child: const Text('Sync now'),
            ),
          ],
        ),
      ),
    );
  }

  /// Human-readable "N seconds/minutes/hours ago". Intentionally not
  /// localised yet — matches the rest of the settings screen.
  String _relativeTime(DateTime past) {
    final delta = DateTime.now().toUtc().difference(past);
    if (delta.inSeconds < 60) return 'just now';
    if (delta.inMinutes < 60) {
      final m = delta.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (delta.inHours < 24) {
      final h = delta.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    final d = delta.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
}

/// Shared confirm-dialog flow for any "manual sync" entry point. Returns
/// `true` when the caller should proceed (policy permits OR the user
/// tapped "Sync anyway"), `false` when the user cancelled.
///
/// Decision C1 in `task_plan.md`: a manual tap bypasses the WiFi-only
/// policy because the user just asked — but with a confirm dialog so a
/// fat-finger doesn't burn cellular data unexpectedly.
///
/// Lives at the top of this file (and not in `sync_controller.dart`) so
/// the controller stays UI-free; both the [SyncStatusCard]'s embedded
/// button and the standalone "Sync now" button in the Settings screen
/// route through this same helper.
Future<bool> confirmManualSyncIfOnCellular(
  BuildContext context,
  WidgetRef ref,
) async {
  final policy = ref.read(syncSettingsProvider).networkPolicy;
  if (policy == SyncNetworkPolicy.anyNetwork) return true;

  final results = await Connectivity().checkConnectivity();
  if (results.contains(ConnectivityResult.wifi)) return true;

  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sync over cellular?'),
      content: const Text(
        'Your network policy is set to "WiFi only", but you tapped Sync '
        'now. Proceeding will use cellular data.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sync anyway'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
