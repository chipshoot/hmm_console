import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/screen_scaffold.dart';
import '../../domain/entities/gas_station.dart';
import '../../states/gas_stations_state.dart';
import '../widgets/gas_station_form_dialog.dart';
import '../widgets/manageable_gas_station_tile.dart';

class GasStationManagementScreen extends ConsumerWidget {
  const GasStationManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(gasStationsStateProvider);

    return CommonScreenScaffold(
      title: 'Gas Stations',
      withPadding: false,
      child: Stack(
        children: [
          stationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Failed to load gas stations',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(gasStationsStateProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (stations) {
              if (stations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_gas_station_outlined,
                          size: 64,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('No gas stations yet',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('Tap + to add your first gas station.'),
                    ],
                  ),
                );
              }

              final active =
                  stations.where((s) => s.isActive).toList()
                    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              final inactive =
                  stations.where((s) => !s.isActive).toList()
                    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.read(gasStationsStateProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  children: [
                    if (active.isNotEmpty) ...[
                      _SectionHeader(title: 'Active (${active.length})'),
                      ...active.map((s) => _buildTile(context, ref, s)),
                    ],
                    if (inactive.isNotEmpty) ...[
                      _SectionHeader(title: 'Inactive (${inactive.length})'),
                      ...inactive.map((s) => _buildTile(context, ref, s)),
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
              onPressed: () => _showFormDialog(context),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, WidgetRef ref, GasStation station) {
    return ManageableGasStationTile(
      station: station,
      onEdit: () => _showFormDialog(context, station: station),
      onToggleActive: () => _confirmToggleActive(context, ref, station),
    );
  }

  Future<void> _showFormDialog(BuildContext context,
      {GasStation? station}) async {
    await showDialog<GasStation>(
      context: context,
      builder: (_) => GasStationFormDialog(station: station),
    );
  }

  void _confirmToggleActive(
      BuildContext context, WidgetRef ref, GasStation station) {
    final action = station.isActive ? 'deactivate' : 'reactivate';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text('${action[0].toUpperCase()}${action.substring(1)} station?'),
        content: Text(
          'Are you sure you want to $action "${station.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (station.isActive) {
                ref
                    .read(gasStationsStateProvider.notifier)
                    .deleteStation(station.id!);
              } else {
                ref
                    .read(gasStationsStateProvider.notifier)
                    .updateStation(
                      station.id!,
                      station.copyWith(isActive: true),
                    );
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
