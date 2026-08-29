import 'package:flutter/material.dart';

import '../record_labels.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_error_message.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../gas_log/states/automobiles_state.dart';
import '../../domain/entities/auto_scheduled_service.dart';
import '../../states/_records_automobile_id_provider.dart';
import '../../states/mutate_scheduled_service_state.dart';
import '../../states/scheduled_services_state.dart';

class ScheduledServicesScreen extends ConsumerStatefulWidget {
  const ScheduledServicesScreen({super.key, required this.automobileId});

  final int automobileId;

  @override
  ConsumerState<ScheduledServicesScreen> createState() =>
      _ScheduledServicesScreenState();
}

class _ScheduledServicesScreenState
    extends ConsumerState<ScheduledServicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(recordsAutomobileIdProvider.notifier)
          .set(widget.automobileId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final schedulesAsync = ref.watch(scheduledServicesStateProvider);
    final autosAsync = ref.watch(automobilesStateProvider);
    final auto = autosAsync.value
        ?.where((a) => a.id == widget.automobileId)
        .firstOrNull;
    final title = auto != null
        ? '${auto.displayName} • Scheduled service'
        : 'Scheduled service';

    ref.listen<AsyncValue<void>>(mutateScheduledServiceStateProvider,
        (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dioErrorMessage(next.error!)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    // The project's platform rules put a primary action in the navigation bar
    // on iOS and on a FAB on Android, so the add appears in exactly one place
    // per platform rather than both.
    final isApple = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    return CommonScreenScaffold(
      title: title,
      withPadding: false,
      actions: [
        if (isApple)
          IconButton(
            key: const Key('addScheduleAction'),
            icon: const Icon(Icons.add),
            tooltip: l.recordsAddSchedule,
            onPressed: _addSchedule,
          ),
      ],
      child: Stack(
        children: [
          schedulesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive())
,
            error: (e, _) => _ErrorState(
              error: e,
              onRetry: () => ref
                  .read(scheduledServicesStateProvider.notifier)
                  .refresh(),
            ),
            data: (schedules) {
              if (schedules.isEmpty) return _EmptyState(onAdd: _addSchedule);
              final sorted = [...schedules]
                ..sort((a, b) {
                  final ad = a.nextDueDate;
                  final bd = b.nextDueDate;
                  if (ad == null && bd == null) return 0;
                  if (ad == null) return 1;
                  if (bd == null) return -1;
                  return ad.compareTo(bd);
                });
              return RefreshIndicator(
                onRefresh: () => ref
                    .read(scheduledServicesStateProvider.notifier)
                    .refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ScheduleTile(
                    schedule: sorted[i],
                    onTap: () => _editSchedule(sorted[i]),
                    onDelete: () => _confirmDelete(sorted[i]),
                  ),
                ),
              );
            },
          ),
          if (!isApple)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _addSchedule,
                tooltip: l.recordsAddSchedule,
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  void _addSchedule() {
    context.push(
        '/automobiles/manage/${widget.automobileId}/scheduled-services/new');
  }

  void _editSchedule(AutoScheduledService s) {
    context.push(
        '/automobiles/manage/${widget.automobileId}/scheduled-services/${s.id}/edit');
  }

  Future<void> _confirmDelete(AutoScheduledService s) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.recordsDeleteScheduleTitle),
        content: Text(l.recordsDeleteScheduleBody(s.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.commonDelete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(mutateScheduledServiceStateProvider.notifier)
        .delete(widget.automobileId, s.id);
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onTap,
    required this.onDelete,
  });

  final AutoScheduledService schedule;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final df = DateFormat.yMMMd();
    final cs = Theme.of(context).colorScheme;
    final overdue = schedule.nextDueDate != null &&
        schedule.nextDueDate!.isBefore(DateTime.now());
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.event_repeat_outlined,
          color: schedule.isActive
              ? (overdue ? cs.error : cs.primary)
              : cs.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                schedule.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (overdue && schedule.isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Overdue',
                  style: TextStyle(fontSize: 11, color: cs.onErrorContainer),
                ),
              ),
            if (!schedule.isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Inactive',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schedule.type.label(l)),
            if (schedule.nextDueDate != null)
              Text(l.recordsNextDueDate(df.format(schedule.nextDueDate!)))
            else if (schedule.nextDueMileage != null)
              Text(l.recordsNextDueMileage('${schedule.nextDueMileage}', 'mi')),
            Text(_intervalLabel(schedule)),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }

  String _intervalLabel(AutoScheduledService s) {
    final parts = <String>[];
    if (s.intervalDays != null) parts.add('${s.intervalDays}d');
    if (s.intervalMileage != null) parts.add('${s.intervalMileage}mi');
    return parts.isEmpty ? 'No interval set' : 'Every ${parts.join(' / ')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_repeat_outlined, size: 64),
          const SizedBox(height: 16),
          Text(l.recordsNoSchedules,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l.recordsNoSchedulesHint),
          const SizedBox(height: 16),
          FilledButton.tonal(
              onPressed: onAdd, child: Text(l.recordsAddSchedule)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(l.recordsSchedulesLoadFailed,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(dioErrorMessage(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      ),
    );
  }
}
