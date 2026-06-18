// The notes-list domain filter is a tap-toggle drawer (replacing the old
// horizontal chip row): a single "filter" button opens a category panel;
// picking a domain filters the list and closes the panel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

NoteCatalog _cat(int id, String name, int fmt) =>
    NoteCatalog(id: id, name: name, schema: '{}', formatType: fmt, isDefault: false);

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
          10: _cat(10, 'Hmm.AutomobileMan.GasLog', 2),
          20: _cat(20, 'Hmm.AutomobileMan.AutomobileInfo', 2),
          30: _cat(30, 'General', 3),
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('filter drawer lists DOMAINS, not individual catalogs',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Open the filter panel.
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Automobile'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'General'), findsOneWidget);
    // Individual catalog names are NOT in the domain drawer.
    expect(find.widgetWithText(ListTile, 'Gas Log'), findsNothing);
  });

  testWidgets('picking a domain in the drawer filters the list and closes it',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Fuel up'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);

    await tester.tap(find.byType(ActionChip)); // open
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Automobile')); // pick
    await tester.pumpAndSettle(); // filters + closes

    expect(find.text('Fuel up'), findsOneWidget); // automobile note kept
    expect(find.text('Shopping'), findsNothing); // general note filtered out
    // The drawer closed, so its tiles are gone.
    expect(find.widgetWithText(ListTile, 'General'), findsNothing);
    // The filter button now reflects the active domain.
    expect(find.widgetWithText(ActionChip, 'Automobile'), findsOneWidget);
  });
}
