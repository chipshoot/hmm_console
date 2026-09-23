import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/data_mode.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../driver_licence/domain/driver_licence.dart';
import '../../../driver_licence/states/driver_licence_state.dart';
import '../../../gas_log/domain/entities/automobile.dart';
import '../../../gas_log/presentation/widgets/automobile_list_tile.dart';
import '../../../gas_log/providers/selected_automobile_provider.dart';
import '../../../gas_log/states/automobiles_state.dart';
import '../../../notes/states/attached_notes_state.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';

/// The automobile domain on one screen: the licence (one, it describes the
/// person) above the vehicles (many, each owns its own records). A thin
/// navigation screen — every destination already exists.
///
/// Replaces the old vehicle picker at /automobiles. The picker's one job
/// (choose a vehicle, open its gas log) is the fuel button on each row.
class AutomobileHubScreen extends ConsumerWidget {
  const AutomobileHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // The licence has no cloudApi repository — its provider throws there.
    // Same rule the dashboard tile used to apply; it lives here now.
    final showLicence = ref.watch(dataModeProvider) != DataMode.cloudApi;
    final autos = ref.watch(automobilesStateProvider);

    return CommonScreenScaffold(
      title: l.automobileHubTitle,
      withPadding: false,
      actions: [
        TextButton.icon(
          onPressed: () => context.push('/automobiles/manage'),
          icon: const Icon(Icons.settings),
          label: Text(l.vehicleManage),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(automobilesStateProvider.notifier).refresh(),
        child: ListView(
          padding: EdgeInsets.only(
              bottom: 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            if (showLicence) const _LicenceCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                l.automobileHubVehicles.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
              ),
            ),
            ...autos.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ],
              error: (e, _) => [_LoadFailed(error: e)],
              data: (all) {
                final active = all.where((a) => a.isActive).toList();
                if (active.isEmpty) return const [_NoVehicles()];
                return [
                  for (final a in active) _VehicleRow(automobile: a),
                  _AddVehicleRow(),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenceCard extends ConsumerWidget {
  const _LicenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(driverLicenceStateProvider);
    // Title only while loading: no "add yours" invitation that flips a
    // moment later into the saved card. An error reads as "none saved";
    // the licence screen shows the error itself.
    if (async.isLoading) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(l.automobileHubLicenceTitle),
        ),
      );
    }
    final licence = async.value;
    final saved = licence != null;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(saved ? l.automobileHubLicenceTitle : l.automobileHubLicenceAdd),
        subtitle: Text(saved
            ? _summary(licence, l, Localizations.localeOf(context).toString())
            : l.automobileHubLicenceAddHint),
        trailing: Icon(saved ? Icons.chevron_right : Icons.add),
        // Always the details screen, saved or not: that is what the old
        // dashboard tile opened. /licence/show is the hand-your-phone-over
        // photo view and is not the place to land from the hub.
        onTap: () => context.push('/licence'),
      ),
    );
  }

  /// "G · Ontario · expires Mar 14, 2028", each part only when present.
  static String _summary(DriverLicence licence, AppLocalizations l, String locale) {
    final parts = <String>[];
    final c = licence.licenceClass;
    if (c != null && c.isNotEmpty) parts.add(c);
    final j = licence.jurisdiction;
    if (j != null && j.isNotEmpty) parts.add(j);
    final d = licence.expiryDate;
    if (d != null) {
      parts.add(
          l.automobileHubLicenceExpires(DateFormat.yMMMd(locale).format(d)));
    }
    return parts.join(' · ');
  }
}

class _VehicleRow extends ConsumerWidget {
  const _VehicleRow({required this.automobile});
  final Automobile automobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final distLabel = ref.watch(gasLogSettingsProvider).distanceUnit.label;
    return AutomobileListTile(
      automobile: automobile,
      distanceLabel: distLabel,
      onTap: () => context.push('/automobiles/manage/${automobile.id}/edit'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NotesButton(automobile: automobile),
          IconButton.filledTonal(
            tooltip: l.automobileHubGasLogFor(automobile.displayName),
            icon: const Icon(Icons.local_gas_station_outlined),
            onPressed: () {
              // The gas-log list reads the SELECTED vehicle, so select first.
              ref
                  .read(selectedAutomobileIdProvider.notifier)
                  .select(automobile.id);
              context.push('/gas-logs');
            },
          ),
          Icon(Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// The car's notes, one tap from the hub. The badge is the count, so a car
/// with nothing written about it carries no decoration at all.
class _NotesButton extends ConsumerWidget {
  const _NotesButton({required this.automobile});
  final Automobile automobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final count =
        ref.watch(attachedNotesProvider(automobile.id)).value?.length;
    const icon = Icon(Icons.sticky_note_2_outlined);
    return IconButton.filledTonal(
      tooltip: l.automobileHubNotesFor(automobile.displayName),
      icon: count == null || count == 0
          ? icon
          : Badge(label: Text('$count'), child: icon),
      onPressed: () =>
          context.push('/automobiles/manage/${automobile.id}/notes'),
    );
  }
}

class _AddVehicleRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: TextButton.icon(
        onPressed: () => context.push('/automobiles/manage/new'),
        icon: const Icon(Icons.add),
        label: Text(l.vehicleAdd),
      ),
    );
  }
}

class _NoVehicles extends StatelessWidget {
  const _NoVehicles();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        children: [
          Icon(Icons.directions_car_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(l.automobileHubNoVehicles,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l.automobileHubNoVehiclesHint, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/automobiles/manage/new'),
            child: Text(l.vehicleAdd),
          ),
        ],
      ),
    );
  }
}

class _LoadFailed extends ConsumerWidget {
  const _LoadFailed({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(l.vehicleLoadFailed, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(error.toString(),
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () =>
                ref.read(automobilesStateProvider.notifier).refresh(),
            child: Text(l.commonRetry),
          ),
        ],
      ),
    );
  }
}
