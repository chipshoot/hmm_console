import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/screen_scaffold.dart';
import '../../domain/entities/gas_log.dart';
import '../../domain/services/gas_log_converter.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';
import '../../providers/exchange_rate_provider.dart';
import '../../providers/selected_automobile_provider.dart';
import '../../states/delete_gas_log_state.dart';
import '../../states/gas_logs_state.dart';
import '../widgets/gas_log_list_tile.dart';

class GasLogListScreen extends ConsumerWidget {
  const GasLogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gasLogsAsync = ref.watch(gasLogsStateProvider);
    final autoId = ref.watch(selectedAutomobileIdProvider);
    final settings = ref.watch(gasLogSettingsProvider);

    final rateAsync = ref.watch(exchangeRateProvider((
      from: _dominantCurrency(gasLogsAsync, settings.currency.apiValue),
      to: settings.currency.apiValue,
    )));
    final exchangeRate = rateAsync.hasValue ? rateAsync.value! : 1.0;

    ref.listen<AsyncValue<bool>>(deleteGasLogStateProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return CommonScreenScaffold(
      title: 'Gas Logs',
      withPadding: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () =>
              ref.read(gasLogsStateProvider.notifier).refresh(),
        ),
      ],
      child: Stack(
        children: [
          gasLogsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Failed to load gas logs',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(gasLogsStateProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (data) {
              if (data.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_gas_station_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('No gas logs yet',
                          style:
                              Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                          'Tap + to add your first gas log.'),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(gasLogsStateProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 8, bottom: 80),
                  itemCount:
                      data.items.length + (data.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == data.items.length) {
                      return _LoadMoreButton(
                        onPressed: () => ref
                            .read(gasLogsStateProvider.notifier)
                            .loadNextPage(),
                      );
                    }
                    final log = data.items[index];
                    final displayModel = log.toDisplayModel(
                      settings,
                      exchangeRate: exchangeRate,
                    );
                    return GasLogListTile(
                      displayModel: displayModel,
                      onTap: () =>
                          context.push('/gas-logs/${log.id}/edit'),
                      onDelete: () => _confirmDelete(
                          context, ref, autoId!, log),
                    );
                  },
                ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => context.push('/gas-logs/new'),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the currency of the first gas log, or the target currency
  /// if there are no logs yet (which short-circuits to rate=1.0).
  String _dominantCurrency(
    AsyncValue<GasLogsData> gasLogsAsync,
    String targetCurrency,
  ) {
    final data = gasLogsAsync.hasValue ? gasLogsAsync.value : null;
    if (data == null || data.items.isEmpty) return targetCurrency;
    return data.items.first.currency;
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int autoId,
    GasLog gasLog,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Gas Log'),
        content:
            const Text('Are you sure you want to delete this gas log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(deleteGasLogStateProvider.notifier)
                  .delete(autoId, gasLog.id!);
            },
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LoadMoreButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: FilledButton.tonal(
          onPressed: onPressed,
          child: const Text('Load More'),
        ),
      ),
    );
  }
}
