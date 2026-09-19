import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../../../gas_log/providers/selected_automobile_provider.dart';

/// The vehicle screen's link to its gas log. The gas-log list reads the
/// SELECTED vehicle rather than taking an id, so the tile selects first and
/// navigates second — the same two steps the old vehicle picker performed.
class GasLogSummaryTile extends ConsumerWidget {
  const GasLogSummaryTile({super.key, required this.automobileId});

  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_gas_station_outlined),
        title: Text(l10n.recordsGasLog),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(selectedAutomobileIdProvider.notifier).select(automobileId);
          context.push('/gas-logs');
        },
      ),
    );
  }
}
