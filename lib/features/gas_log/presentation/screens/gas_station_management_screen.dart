import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final stationsAsync = ref.watch(gasStationsStateProvider);

    return CommonScreenScaffold(
      title: l.stationTitle,
      withPadding: false,
      child: Stack(
        children: [
          stationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(l.stationLoadFailed,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(gasStationsStateProvider.notifier).refresh(),
                    child: Text(l.commonRetry),
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
                      Text(l.stationEmpty,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(l.stationEmptyHint),
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
                      _SectionHeader(title: l.vehicleActiveCount(active.length)),
                      ...active.map((s) => _buildTile(context, ref, s)),
                    ],
                    if (inactive.isNotEmpty) ...[
                      _SectionHeader(title: l.vehicleInactiveCount(inactive.length)),
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
    final l = AppLocalizations.of(context);
    final title =
        station.isActive ? l.stationDeactivateTitle : l.stationReactivateTitle;
    final body = station.isActive
        ? l.stationDeactivateBody(station.name)
        : l.stationReactivateBody(station.name);
    final isApple = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text(title),
        content: Text(body),
        actions: [
          isApple
              ? CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l.commonCancel),
                )
              : TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l.commonCancel),
                ),
          isApple
              ? CupertinoDialogAction(
                  isDestructiveAction: station.isActive,
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
                  child: Text(station.isActive ? l.vehicleDeactivate : l.vehicleReactivate),
                )
              : FilledButton(
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
                  child: Text(station.isActive ? l.vehicleDeactivate : l.vehicleReactivate),
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
