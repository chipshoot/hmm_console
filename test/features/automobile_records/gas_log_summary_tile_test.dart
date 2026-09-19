// The vehicle screen's records summary gains a Gas log entry so the vehicle
// screen is complete on its own. Tapping it must do what the old vehicle
// picker did: select the vehicle, then open the gas-log list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/automobile_records/presentation/widgets/gas_log_summary_tile.dart';
import 'package:hmm_console/features/gas_log/providers/selected_automobile_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('tap selects the vehicle and opens the gas log', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/v', routes: [
      GoRoute(
          path: '/v',
          builder: (_, _) =>
              const Scaffold(body: GasLogSummaryTile(automobileId: 7))),
      GoRoute(
          path: '/gas-logs',
          builder: (_, _) => const Scaffold(body: Text('gas log list'))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Gas log'), findsOneWidget);
    await tester.tap(find.text('Gas log'));
    await tester.pumpAndSettle();

    expect(container.read(selectedAutomobileIdProvider), 7,
        reason: 'the gas-log list shows the selected vehicle');
    expect(find.text('gas log list'), findsOneWidget);
  });
}
