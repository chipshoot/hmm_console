import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final automobilesAsync = ref.watch(automobilesStateProvider);

    ref.listen<AsyncValue<void>>(deactivateAutomobileStateProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.commonError('${next.error}')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      if (next.hasValue && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.vehicleStatusUpdated)),
        );
      }
    });

    ref.listen<AsyncValue<void>>(updateAutomobileStateProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.commonError('${next.error}')),
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
      title: l.vehicleManageTitle,
      withPadding: false,
      actions: [
        if (isApple)
          IconButton(
            key: const Key('addVehicleAction'),
            icon: const Icon(Icons.add),
            tooltip: l.vehicleAdd,
            onPressed: () => context.push('/automobiles/manage/new'),
          ),
      ],
      child: Stack(
        children: [
          automobilesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(l.vehicleLoadFailed,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(automobilesStateProvider.notifier).refresh(),
                    child: Text(l.commonRetry),
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
                      Text(l.vehicleEmpty,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(l.vehicleEmptyHint),
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
                      _SectionHeader(title: l.vehicleActiveCount(active.length)),
                      ...active.map((auto) => _buildTile(context, ref, auto)),
                    ],
                    if (inactive.isNotEmpty) ...[
                      _SectionHeader(title: l.vehicleInactiveCount(inactive.length)),
                      ...inactive
                          .map((auto) => _buildTile(context, ref, auto)),
                    ],
                  ],
                ),
              );
            },
          ),
          if (!isApple)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: () => context.push('/automobiles/manage/new'),
                tooltip: l.vehicleAdd,
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
    final l = AppLocalizations.of(context);
    // Whole sentences per action rather than a capitalized English verb
    // interpolated into one — that construction has no correct translation.
    final title =
        auto.isActive ? l.vehicleDeactivateTitle : l.vehicleReactivateTitle;
    final body = auto.isActive
        ? l.vehicleDeactivateBody(auto.displayName)
        : l.vehicleReactivateBody(auto.displayName);
    final isApple = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    void performAction() {
      if (auto.isActive) {
        ref
            .read(deactivateAutomobileStateProvider.notifier)
            .deactivate(auto.id);
      } else {
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
    }

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
                  isDestructiveAction: auto.isActive,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    performAction();
                  },
                  child: Text(auto.isActive ? l.vehicleDeactivate : l.vehicleReactivate),
                )
              : FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    performAction();
                  },
                  child: Text(auto.isActive ? l.vehicleDeactivate : l.vehicleReactivate),
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
