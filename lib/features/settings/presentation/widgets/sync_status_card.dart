import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/sync/sync_controller.dart';

/// Shows the live sync state and surfaces a manual "Sync Now" button.
/// Binds to [SyncController] (a [ChangeNotifier]) so it rebuilds whenever
/// the controller pushes a new [SyncStatus] — no Riverpod state stream
/// needed.
///
/// States rendered:
///   - Idle  ("Synced 3 minutes ago" / "Never synced")
///   - Syncing… (spinner)
///   - Failure (snackbar-style banner, persistent badge after 3+ in a row)
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

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final SyncController controller;

  @override
  Widget build(BuildContext context) {
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
                  : () => controller.triggerManualSync(),
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
