import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_mode.dart';
import '../data/sync/pending_sync_count_provider.dart';
import '../data/sync/sync_controller.dart';
import '../navigation/router.dart';
import '../navigation/router_config.dart' show rootNavigatorKey;
import '../../features/settings/presentation/widgets/sync_status_card.dart'
    show confirmManualSyncIfOnCellular;

/// Mode-adaptive sync status chip. Part of the persistent Home+Sync
/// overlay (`HomeSyncOverlay`, Task 6).
///
/// - `local` / `cloudApi` (Phase 1): neutral/disabled — full per-tier
///   behavior lands in Phase 2 (design doc phasing).
/// - `cloudStorage`: live status (synced / syncing / N unsynced / error) —
///   tap = sync now (cellular-confirm, reusing the same helper as
///   Settings' `SyncStatusCard`); long-press = mini sheet with
///   last-synced + pending count + a jump to Settings.
class SyncPill extends ConsumerWidget {
  const SyncPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dataModeProvider);
    final cs = Theme.of(context).colorScheme;

    if (mode != DataMode.cloudStorage) {
      return _Chip(
        icon: Icons.cloud_off,
        label: mode == DataMode.local ? 'Local only' : 'Cloud (soon)',
        color: cs.onSurfaceVariant,
        onTap: () {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext == null) return;
          ScaffoldMessenger.maybeOf(navContext)?.showSnackBar(
            SnackBar(
              content: Text(
                mode == DataMode.local
                    ? 'Local mode has no cloud sync yet.'
                    : 'Cloud (API) sync is not available yet.',
              ),
            ),
          );
        },
      );
    }

    final controller = ref.watch(syncControllerProvider);
    final pendingAsync = ref.watch(pendingSyncCountProvider);
    final pending = pendingAsync.value ?? 0;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.status;
        IconData icon;
        String label;
        Color color = cs.primary;

        if (status.isSyncing) {
          icon = Icons.sync;
          label = 'Syncing…';
        } else if (status.consecutiveFailures >= 3 ||
            (status.lastResult != null && !status.lastResult!.success)) {
          icon = Icons.error_outline;
          label = pending > 0 ? '$pending unsynced · error' : 'Sync error';
          color = cs.error;
        } else if (status.lastAutoTriggerSkippedForNetwork) {
          icon = Icons.wifi_off;
          label =
              pending > 0 ? '$pending unsynced · WiFi' : 'Waiting for WiFi';
          color = cs.tertiary;
        } else if (pending > 0) {
          icon = Icons.cloud_upload_outlined;
          label = '$pending unsynced';
          color = cs.tertiary;
        } else {
          icon = Icons.cloud_done_outlined;
          label = 'Synced';
        }

        return _Chip(
          icon: icon,
          label: label,
          color: color,
          onTap: status.isSyncing
              ? null
              : () async {
                  final navContext = rootNavigatorKey.currentContext;
                  if (navContext == null) return;
                  final proceed =
                      await confirmManualSyncIfOnCellular(navContext, ref);
                  if (!proceed) return;
                  await controller.triggerManualSync();
                },
          onLongPress: () => _showMiniSheet(ref, controller, pending),
        );
      },
    );
  }

  void _showMiniSheet(WidgetRef ref, SyncController controller, int pending) {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;
    final status = controller.status;
    showModalBottomSheet<void>(
      context: navContext,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.lastSyncAt == null
                    ? 'Never synced'
                    : 'Last synced: ${status.lastSyncAt}',
              ),
              const SizedBox(height: 4),
              Text('$pending change${pending == 1 ? '' : 's'} pending'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(AppRouter.config).push('/settings');
                },
                child: const Text('Open sync settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
