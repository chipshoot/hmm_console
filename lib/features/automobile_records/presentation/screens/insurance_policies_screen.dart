import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/contact_block/contact_info.dart';
import '../../../../core/network/dio_error_message.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../gas_log/states/automobiles_state.dart';
import '../../domain/entities/auto_insurance_policy.dart';
import '../../states/_records_automobile_id_provider.dart';
import '../../states/insurance_policies_state.dart';
import '../../states/mutate_insurance_policy_state.dart';

class InsurancePoliciesScreen extends ConsumerStatefulWidget {
  const InsurancePoliciesScreen({super.key, required this.automobileId});

  final int automobileId;

  @override
  ConsumerState<InsurancePoliciesScreen> createState() =>
      _InsurancePoliciesScreenState();
}

class _InsurancePoliciesScreenState
    extends ConsumerState<InsurancePoliciesScreen> {
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
    final policiesAsync = ref.watch(insurancePoliciesStateProvider);
    final autosAsync = ref.watch(automobilesStateProvider);
    final auto = autosAsync.value
        ?.where((a) => a.id == widget.automobileId)
        .firstOrNull;
    final title = auto != null ? '${auto.displayName} • Insurance' : 'Insurance';

    ref.listen<AsyncValue<void>>(mutateInsurancePolicyStateProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dioErrorMessage(next.error!)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return CommonScreenScaffold(
      title: title,
      withPadding: false,
      child: Stack(
        children: [
          policiesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => _ErrorState(
              error: e,
              onRetry: () =>
                  ref.read(insurancePoliciesStateProvider.notifier).refresh(),
            ),
            data: (policies) {
              if (policies.isEmpty) {
                return _EmptyState(onAdd: _addPolicy);
              }
              final sorted = [...policies]
                ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(insurancePoliciesStateProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _PolicyTile(
                    policy: sorted[i],
                    onTap: () => _editPolicy(sorted[i]),
                    onDelete: () => _confirmDelete(sorted[i]),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _addPolicy,
              tooltip: 'Add policy',
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _addPolicy() {
    context.push(
      '/automobiles/manage/${widget.automobileId}/insurance/new',
    );
  }

  void _editPolicy(AutoInsurancePolicy p) {
    context.push(
      '/automobiles/manage/${widget.automobileId}/insurance/${p.id}/edit',
    );
  }

  Future<void> _confirmDelete(AutoInsurancePolicy p) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.recordsDeletePolicyTitle),
        content: Text(l.recordsDeletePolicyBody(p.policyNumber, p.provider)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(mutateInsurancePolicyStateProvider.notifier)
        .delete(widget.automobileId, p.id);
  }
}

class _PolicyTile extends StatelessWidget {
  const _PolicyTile({
    required this.policy,
    required this.onTap,
    required this.onDelete,
  });

  final AutoInsurancePolicy policy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final df = DateFormat.yMMMd();
    final cs = Theme.of(context).colorScheme;
    final active = policy.isCurrentlyActive;
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.shield_outlined,
          color: active ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                policy.provider,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (active)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.recordsPolicyNumber(policy.policyNumber)),
            Text(
                '${df.format(policy.effectiveDate)} – ${df.format(policy.expiryDate)}'),
            Text(
                '${policy.currency} ${policy.premium.toStringAsFixed(2)} premium'),
            // Guarded on non-empty: without the role there is no longer a
            // guaranteed first part, so a contact carrying only an address
            // would otherwise render a blank line.
            if (policy.contacts.isNotEmpty &&
                _contactSummary(policy.contacts.first).isNotEmpty)
              Text(
                key: const Key('policyContactSummary'),
                _contactSummary(policy.contacts.first),
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
          const Icon(Icons.shield_outlined, size: 64),
          const SizedBox(height: 16),
          Text(l.recordsNoPolicies,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l.recordsNoPoliciesHint),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onAdd, child: Text(l.recordsAddPolicy)),
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
          Text(l.recordsPoliciesLoadFailed,
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

/// The primary contact as one line, so the agent's number is readable from
/// the list rather than only inside the edit form.
String _contactSummary(ContactInfo c) => [
      if (c.displayName.isNotEmpty) c.displayName,
      if ((c.phone ?? '').isNotEmpty) c.phone!,
    ].join(' · ');
