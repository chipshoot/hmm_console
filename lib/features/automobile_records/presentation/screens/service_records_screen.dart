import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_error_message.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../gas_log/states/automobiles_state.dart';
import '../../domain/entities/service_record.dart';
import '../../states/_records_automobile_id_provider.dart';
import '../../states/mutate_service_record_state.dart';
import '../../states/service_records_state.dart';

class ServiceRecordsScreen extends ConsumerStatefulWidget {
  const ServiceRecordsScreen({super.key, required this.automobileId});

  final int automobileId;

  @override
  ConsumerState<ServiceRecordsScreen> createState() =>
      _ServiceRecordsScreenState();
}

class _ServiceRecordsScreenState
    extends ConsumerState<ServiceRecordsScreen> {
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
    final recordsAsync = ref.watch(serviceRecordsStateProvider);
    final autosAsync = ref.watch(automobilesStateProvider);
    final auto = autosAsync.value
        ?.where((a) => a.id == widget.automobileId)
        .firstOrNull;
    final title = auto != null
        ? '${auto.displayName} • Service history'
        : 'Service history';

    ref.listen<AsyncValue<void>>(mutateServiceRecordStateProvider, (_, next) {
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
          recordsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive())
,
            error: (e, _) => _ErrorState(
              error: e,
              onRetry: () =>
                  ref.read(serviceRecordsStateProvider.notifier).refresh(),
            ),
            data: (records) {
              if (records.isEmpty) return _EmptyState(onAdd: _addRecord);
              final sorted = [...records]
                ..sort((a, b) => b.date.compareTo(a.date));
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(serviceRecordsStateProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ServiceTile(
                    record: sorted[i],
                    onTap: () => _editRecord(sorted[i]),
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
              onPressed: _addRecord,
              tooltip: 'Add service record',
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _addRecord() {
    context.push('/automobiles/manage/${widget.automobileId}/services/new');
  }

  void _editRecord(ServiceRecord r) {
    context.push(
        '/automobiles/manage/${widget.automobileId}/services/${r.id}/edit');
  }

  Future<void> _confirmDelete(ServiceRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete service record?'),
        content: Text(
            'Delete ${r.type.displayName} on ${DateFormat.yMMMd().format(r.date)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(mutateServiceRecordStateProvider.notifier)
        .delete(widget.automobileId, r.id);
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final ServiceRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.build_outlined),
        title: Text(
          (record.name != null && record.name!.isNotEmpty)
              ? record.name!
              : record.type.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${df.format(record.date)} • ${record.mileage} mi'),
            if (record.shopName != null && record.shopName!.isNotEmpty)
              Text(record.shopName!),
            Text('${record.currency} '
                '${record.effectiveTotal.toStringAsFixed(2)}'),
            if (record.parts.isNotEmpty)
              Text('${record.parts.length} items',
                  style: Theme.of(context).textTheme.bodySmall),
            if (record.attachments.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${record.attachments.images.length + record.attachments.files.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build_outlined, size: 64),
          const SizedBox(height: 16),
          Text('No service records yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Tap + to log this vehicle\'s first service.'),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onAdd, child: const Text('Add record')),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Failed to load service records',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(dioErrorMessage(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
