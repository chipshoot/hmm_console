import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/sync/sync_controller.dart';
import '../../../../l10n/gen/app_localizations.dart';
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
    final l = AppLocalizations.of(context);

    Widget leading;
    String headline;
    Color? headlineColor;

    if (status.isSyncing) {
      leading = const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      headline = l.syncStatusSyncing;
    } else if (status.consecutiveFailures >= 3) {
      // Persistent badge after 3 failures in a row (decision B2 in
      // task_plan.md). At this point the user should notice — a
      // transient snackbar isn't enough.
      leading = Icon(Icons.error, color: theme.colorScheme.error);
      headline = l.syncStatusFailing(status.consecutiveFailures);
      headlineColor = theme.colorScheme.error;
    } else if (status.lastAutoTriggerSkippedForNetwork) {
      // WiFi-only policy blocked the most recent auto-trigger. Stays
      // visible until the next real sync runs (manual or auto when
      // WiFi comes back).
      leading = Icon(Icons.wifi_off, color: theme.colorScheme.tertiary);
      headline = l.syncStatusWaitingWifi;
    } else if (status.lastResult != null && !status.lastResult!.success) {
      leading = Icon(Icons.warning_amber, color: theme.colorScheme.tertiary);
      headline = l.syncStatusLastFailed;
    } else if (status.lastSyncAt != null) {
      leading = Icon(Icons.cloud_done, color: theme.colorScheme.primary);
      headline = l.syncStatusSynced(_relativeTime(status.lastSyncAt!, l));
    } else {
      leading = const Icon(Icons.cloud_off);
      headline = l.syncStatusNever;
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
              child: Text(l.settingsSyncNow),
            ),
          ],
        ),
      ),
    );
  }

  /// Human-readable "N minutes/hours/days ago".
  ///
  /// Plural forms come from the ARB rather than a `s`-appending ternary:
  /// Chinese has no plural inflection, so the old approach had no correct
  /// translation at all.
  String _relativeTime(DateTime past, AppLocalizations l) {
    final delta = DateTime.now().toUtc().difference(past);
    if (delta.inSeconds < 60) return l.syncRelativeJustNow;
    if (delta.inMinutes < 60) return l.syncRelativeMinutes(delta.inMinutes);
    if (delta.inHours < 24) return l.syncRelativeHours(delta.inHours);
    return l.syncRelativeDays(delta.inDays);
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
  final l = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.syncCellularTitle),
      content: Text(l.syncCellularBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.syncAnyway),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
