import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/gaps.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../domain/gas_log_units.dart';
import '../../providers/gas_log_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gasLogSettingsProvider);

    return CommonScreenScaffold(
      title: 'Settings',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gas Log Defaults',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            GapWidgets.h16,
            DropdownButtonFormField<DistanceUnit>(
              initialValue: settings.distanceUnit,
              decoration: const InputDecoration(
                labelText: 'Distance Unit',
                border: OutlineInputBorder(),
              ),
              items: DistanceUnit.values
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(gasLogSettingsProvider.notifier)
                      .update(distanceUnit: v);
                }
              },
            ),
            GapWidgets.h16,
            DropdownButtonFormField<FuelUnit>(
              initialValue: settings.fuelUnit,
              decoration: const InputDecoration(
                labelText: 'Fuel Unit',
                border: OutlineInputBorder(),
              ),
              items: FuelUnit.values
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(gasLogSettingsProvider.notifier)
                      .update(fuelUnit: v);
                }
              },
            ),
            GapWidgets.h16,
            DropdownButtonFormField<CurrencyCode>(
              initialValue: settings.currency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: CurrencyCode.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(gasLogSettingsProvider.notifier)
                      .update(currency: v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
