import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_error_message.dart';
import '../../states/_records_automobile_id_provider.dart';
import '../../states/insurance_policies_state.dart';
import '../../states/scheduled_services_state.dart';
import '../../states/service_records_state.dart';

/// Three at-a-glance cards for an automobile's insurance, last service,
/// and soonest scheduled-service. Each card renders a one-line summary
/// of the source-of-truth data fetched from the backend (not the
/// snapshot inline fields) and a "Manage" button that deep-links to
/// the dedicated history/list screen.
///
/// Drop into any automobile-context screen below the vehicle title.
/// Sets `recordsAutomobileIdProvider` on init so the underlying async
/// notifiers load data for the right vehicle.
class AutomobileRecordsSummary extends ConsumerStatefulWidget {
  const AutomobileRecordsSummary({super.key, required this.automobileId});

  final int automobileId;

  @override
  ConsumerState<AutomobileRecordsSummary> createState() =>
      _AutomobileRecordsSummaryState();
}

class _AutomobileRecordsSummaryState
    extends ConsumerState<AutomobileRecordsSummary> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsuranceSummaryCard(automobileId: widget.automobileId),
        const SizedBox(height: 8),
        _ServiceSummaryCard(automobileId: widget.automobileId),
        const SizedBox(height: 8),
        _ScheduleSummaryCard(automobileId: widget.automobileId),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: const Text('Notes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('/automobiles/manage/${widget.automobileId}/notes'),
          ),
        ),
      ],
    );
  }
}

class _InsuranceSummaryCard extends ConsumerWidget {
  const _InsuranceSummaryCard({required this.automobileId});
  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeInsurancePolicyStateProvider);
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat.yMMMd();

    final l10n = AppLocalizations.of(context);
    return _SummaryCard(
      icon: Icons.shield_outlined,
      iconColor: cs.primary,
      title: l10n.automobileRecordsInsurance,
      action: l10n.automobileRecordsManage,
      onAction: () =>
          context.push('/automobiles/manage/$automobileId/insurance'),
      child: activeAsync.when(
        loading: () => const _Loading(),
        error: (e, _) => _Subtle('Could not load: ${dioErrorMessage(e)}'),
        data: (policy) {
          if (policy == null) {
            return _Subtle(l10n.automobileRecordsNoActivePolicy);
          }
          final daysToExpiry =
              policy.expiryDate.difference(DateTime.now()).inDays;
          final cs = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                policy.provider,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('Policy ${policy.policyNumber}'),
              Text(
                'Expires ${df.format(policy.expiryDate)} '
                '($daysToExpiry day${daysToExpiry == 1 ? '' : 's'})',
                style: TextStyle(
                  color: daysToExpiry < 30 ? cs.error : null,
                  fontWeight: daysToExpiry < 30 ? FontWeight.w600 : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceSummaryCard extends ConsumerWidget {
  const _ServiceSummaryCard({required this.automobileId});
  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(serviceRecordsStateProvider);
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat.yMMMd();

    final l10n = AppLocalizations.of(context);
    return _SummaryCard(
      icon: Icons.build_outlined,
      iconColor: cs.tertiary,
      title: l10n.automobileRecordsServiceHistory,
      action: l10n.automobileRecordsViewHistory,
      onAction: () =>
          context.push('/automobiles/manage/$automobileId/services'),
      child: recordsAsync.when(
        loading: () => const _Loading(),
        error: (e, _) => _Subtle('Could not load: ${dioErrorMessage(e)}'),
        data: (records) {
          if (records.isEmpty) {
            return _Subtle(l10n.automobileRecordsNoServiceRecords);
          }
          final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
          final latest = sorted.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last: ${latest.types.map((t) => t.displayName).join(', ')}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                  '${df.format(latest.date)} • ${latest.mileage} mi'),
              Text('${records.length} record${records.length == 1 ? '' : 's'} on file'),
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleSummaryCard extends ConsumerWidget {
  const _ScheduleSummaryCard({required this.automobileId});
  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soonestAsync = ref.watch(soonestScheduledServiceStateProvider);
    final allAsync = ref.watch(scheduledServicesStateProvider);
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat.yMMMd();

    final l10n = AppLocalizations.of(context);
    return _SummaryCard(
      icon: Icons.event_repeat_outlined,
      iconColor: cs.secondary,
      title: l10n.automobileRecordsScheduledService,
      action: l10n.automobileRecordsManage,
      onAction: () => context
          .push('/automobiles/manage/$automobileId/scheduled-services'),
      child: soonestAsync.when(
        loading: () => const _Loading(),
        error: (e, _) => _Subtle('Could not load: ${dioErrorMessage(e)}'),
        data: (soonest) {
          final total = allAsync.value?.length ?? 0;
          if (soonest == null) {
            return _Subtle(
              total == 0
                  ? l10n.automobileRecordsNoSchedules
                  : '$total schedule${total == 1 ? '' : 's'}, none with a due date',
            );
          }
          final due = soonest.nextDueDate!;
          final days = due.difference(DateTime.now()).inDays;
          final overdue = days < 0;
          final cs = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next: ${soonest.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                overdue
                    ? 'Overdue since ${df.format(due)} (${-days}d)'
                    : 'Due ${df.format(due)} (in ${days}d)',
                style: TextStyle(
                  color: overdue ? cs.error : null,
                  fontWeight: overdue ? FontWeight.w600 : null,
                ),
              ),
              if (total > 1)
                Text('$total active schedules'),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.action,
    required this.onAction,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String action;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton(onPressed: onAction, child: Text(action)),
              ],
            ),
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium ??
                  const TextStyle(),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _Subtle extends StatelessWidget {
  const _Subtle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
