// The screen the hub's notes button opens: it names the car, says where a
// new note will land, and leads with the one action that matters.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/vehicle_notes_screen.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _StubAutomobiles extends AutomobilesState {
  @override
  Future<List<Automobile>> build() async => [
        Automobile(
            id: 1,
            year: 2020,
            maker: 'Honda',
            model: 'Civic',
            meterReading: 100,
            isActive: true),
      ];
}

Future<void> _pump(WidgetTester tester) async {
  final router = GoRouter(initialLocation: '/v', routes: [
    GoRoute(
        path: '/v',
        builder: (_, _) => const VehicleNotesScreen(automobileId: 1)),
    GoRoute(
        path: '/notes/new',
        builder: (_, s) => Scaffold(
            body: Text('editor parent=${s.uri.queryParameters['parent']}'))),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      automobilesStateProvider.overrideWith(_StubAutomobiles.new),
      attachedNotesProvider(1).overrideWith((ref) async => <HmmNote>[]),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names the car and where a new note lands', (tester) async {
    await _pump(tester);
    expect(find.text('2020 Honda Civic'), findsOneWidget);
    expect(find.text('Automobile · 2020 Honda Civic'), findsOneWidget);
  });

  testWidgets('New note opens the editor attached to this car',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'New note'));
    await tester.pumpAndSettle();
    expect(find.text('editor parent=1'), findsOneWidget);
  });

  testWidgets('the section does not offer a second add button',
      (tester) async {
    await _pump(tester);
    // One add control on the screen: the New note button. The section's own
    // "+" is suppressed, so exactly one add icon is present.
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('vehicle notes screen hosts AttachedNotesSection for the car',
      (tester) async {
    await _pump(tester);
    expect(find.byType(AttachedNotesSection), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
  });
}
