// On-device (simulator) verification of the notes-list two-level filter.
// Runs the real NotesListScreen on the device's Flutter engine with real touch
// dispatch + iOS rendering (drawer, popup menu), using a stub list state so it
// doesn't need login/DB.
//
// Run: flutter test integration_test/notes_filter_test.dart -d <simulator-id>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

NoteCatalog _cat(int id, String name) =>
    NoteCatalog(id: id, name: name, schema: '{}', formatType: 2, isDefault: false);

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 1, uuid: 'u1', subject: 'Fuel up', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 3)),
          HmmNote(
              id: 2, uuid: 'u2', subject: 'Shopping', authorId: 1,
              catalogId: 30, createDate: DateTime(2026, 1, 2)),
        ],
        catalogsById: {
          10: _cat(10, 'Hmm.AutomobileMan.GasLog'),
          20: _cat(20, 'Hmm.AutomobileMan.AutoInsurancePolicy'),
          30: _cat(30, 'General'),
        },
      );
}

Widget _app() => ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NotesListScreen(),
      ),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('two-level filter drives correctly on device', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Both notes visible under "All".
    expect(find.text('Fuel up'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);

    // Open the filter drawer; it lists DOMAINS, not catalogs.
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Automobile'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'General'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Gas Log'), findsNothing);

    // Pick Automobile → filters, closes, main label updates, sub appears.
    await tester.tap(find.widgetWithText(ListTile, 'Automobile'));
    await tester.pumpAndSettle();
    expect(find.text('Fuel up'), findsOneWidget);
    expect(find.text('Shopping'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Automobile'), findsOneWidget);
    expect(find.text('All Automobile'), findsOneWidget); // sub-filter default

    // Open the sub-filter and narrow to Insurance (no notes) → list empties.
    await tester.tap(find.text('All Automobile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insurance').last);
    await tester.pumpAndSettle();
    expect(find.text('Fuel up'), findsNothing);

    // Back to All via the drawer → both notes return, sub disappears.
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Fuel up'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('All Automobile'), findsNothing);
  });
}
