import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/screen_scaffold.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';
import '../../domain/entities/automobile.dart';
import '../../states/automobiles_state.dart';
import '../../states/deactivate_automobile_state.dart';
import '../../states/update_automobile_state.dart';
import '../widgets/manageable_automobile_tile.dart';

class AutomobileManagementScreen extends ConsumerWidget {
  const AutomobileManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final automobilesAsync = ref.watch(automobilesStateProvider);

    ref.listen<AsyncValue<void>>(deactivateAutomobileStateProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      if (next.hasValue && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle status updated')),
        );
      }
    });

    ref.listen<AsyncValue<void>>(updateAutomobileStateProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return CommonScreenScaffold(
      title: 'Manage Vehicles',
      withPadding: false,
      child: Stack(
        children: [
          automobilesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error),
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
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('No vehicles yet',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('Tap + to add your first vehicle.'),
                    ],
                  ),
                );
              }

              final active =
                  automobiles.where((a) => a.isActive).toList();
              final inactive =
                  automobiles.where((a) => !a.isActive).toList();

              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(automobilesStateProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  children: [
                    if (active.isNotEmpty) ...[
                      _SectionHeader(title: 'Active (${active.length})'),
                      ...active.map((auto) => _buildTile(context, ref, auto)),
                    ],
                    if (inactive.isNotEmpty) ...[
                      _SectionHeader(title: 'Inactive (${inactive.length})'),
                      ...inactive
                          .map((auto) => _buildTile(context, ref, auto)),
                    ],
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => context.push('/automobiles/manage/new'),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, WidgetRef ref, Automobile auto) {
    final distLabel = ref.watch(gasLogSettingsProvider).distanceUnit.label;
    return ManageableAutomobileTile(
      automobile: auto,
      distanceLabel: distLabel,
      onEdit: () => context.push('/automobiles/manage/${auto.id}/edit'),
      onToggleActive: () => _confirmToggleActive(context, ref, auto),
    );
  }

  void _confirmToggleActive(
      BuildContext context, WidgetRef ref, Automobile auto) {
    final action = auto.isActive ? 'deactivate' : 'reactivate';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} vehicle?'),
        content: Text(
          'Are you sure you want to $action ${auto.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (auto.isActive) {
                ref
                    .read(deactivateAutomobileStateProvider.notifier)
                    .deactivate(auto.id);
              } else {
                // Reactivate: update with isActive = true
                final reactivated = Automobile(
                  id: auto.id,
                  vin: auto.vin,
                  maker: auto.maker,
                  brand: auto.brand,
                  model: auto.model,
                  trim: auto.trim,
                  year: auto.year,
                  color: auto.color,
                  plate: auto.plate,
                  engineType: auto.engineType,
                  fuelType: auto.fuelType,
                  fuelTankCapacity: auto.fuelTankCapacity,
                  cityMPG: auto.cityMPG,
                  highwayMPG: auto.highwayMPG,
                  combinedMPG: auto.combinedMPG,
                  meterReading: auto.meterReading,
                  purchaseMeterReading: auto.purchaseMeterReading,
                  purchaseDate: auto.purchaseDate,
                  purchasePrice: auto.purchasePrice,
                  ownershipStatus: auto.ownershipStatus,
                  isActive: true,
                  soldDate: auto.soldDate,
                  soldMeterReading: auto.soldMeterReading,
                  soldPrice: auto.soldPrice,
                  registrationExpiryDate: auto.registrationExpiryDate,
                  insuranceExpiryDate: auto.insuranceExpiryDate,
                  insuranceProvider: auto.insuranceProvider,
                  insurancePolicyNumber: auto.insurancePolicyNumber,
                  lastServiceDate: auto.lastServiceDate,
                  lastServiceMeterReading: auto.lastServiceMeterReading,
                  nextServiceDueDate: auto.nextServiceDueDate,
                  nextServiceDueMeterReading: auto.nextServiceDueMeterReading,
                  notes: auto.notes,
                );
                ref
                    .read(updateAutomobileStateProvider.notifier)
                    .updateAutomobile(auto.id, reactivated);
              }
            },
            child: Text(action[0].toUpperCase() + action.substring(1)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
