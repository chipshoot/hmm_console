import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/screen_scaffold.dart';
import '../../providers/selected_automobile_provider.dart';
import '../../states/automobiles_state.dart';
import '../widgets/automobile_list_tile.dart';

class AutomobileSelectorScreen extends ConsumerWidget {
  const AutomobileSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automobilesAsync = ref.watch(automobilesStateProvider);

    return CommonScreenScaffold(
      title: 'Select Vehicle',
      withPadding: false,
      actions: [
        TextButton.icon(
          onPressed: () => context.push('/automobiles/manage'),
          icon: const Icon(Icons.settings),
          label: const Text('Manage'),
        ),
      ],
      child: automobilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load vehicles',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(automobilesStateProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (automobiles) {
          if (automobiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No vehicles found',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Add a vehicle to get started.'),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => context.push('/automobiles/manage'),
                    child: const Text('Manage Vehicles'),
                  ),
                ],
              ),
            );
          }

          final active =
              automobiles.where((a) => a.isActive).toList();

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(automobilesStateProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: active.length,
              itemBuilder: (context, index) {
                final auto = active[index];
                return AutomobileListTile(
                  automobile: auto,
                  onTap: () {
                    ref.read(selectedAutomobileIdProvider.notifier).select(
                        auto.id);
                    context.push('/gas-logs');
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
