import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/data_mode.dart';
import '../../../../core/i18n/enum_labels.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';
import '../../providers/intro_card_provider.dart';

/// First-run greeter on the dashboard. Lists the defaults that were
/// auto-picked for the user (data storage + gas log units / currency)
/// and offers a one-tap shortcut into Settings to change them. Tapping
/// "Looks good" or "Open settings" marks it as seen — it never returns
/// after that.
class DefaultsIntroCard extends ConsumerWidget {
  const DefaultsIntroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final mode = ref.watch(dataModeProvider);
    final gas = ref.watch(gasLogSettingsProvider);
    final l = AppLocalizations.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  l.dashboardWelcome,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.dashboardDefaultsBlurb,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            // Values come from the settings enums (already localized via
            // enum_labels.dart); the row labels are this feature's own copy.
            _row(l.dashboardDataStorage, mode.displayName(l)),
            _row(l.dashboardDistance, gas.distanceUnit.displayName(l)),
            _row(l.dashboardFuelVolume, gas.fuelUnit.displayName(l)),
            _row(l.dashboardCurrency, gas.currency.displayName(l)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      ref.read(introCardSeenProvider.notifier).markSeen(),
                  child: Text(l.dashboardLooksGood),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    ref.read(introCardSeenProvider.notifier).markSeen();
                    context.push('/settings');
                  },
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(l.dashboardOpenSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
