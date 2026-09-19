// Reported: switching the filter on the notes list navigated back to the
// main screen. The actual cause was the router provider rebuilding on a
// settings write (see test/core/navigation/router_stability_test.dart).
//
// This pins the other way that symptom could arise: the drawer/sheet tap
// handlers call setFilter() and THEN Navigator.pop(). The drawer is built
// from the list state, so setFilter() rebuilds the screen; if the pop ever
// ran against a stale context it would fall through to the route's
// Navigator and pop the notes screen itself. So the list is put on TOP of
// another route and that route must still be underneath after a filter tap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 1, uuid: 'u1', subject: 'Oil change', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 2)),
          HmmNote(
              id: 2, uuid: 'u2', subject: 'Grocery list', authorId: 1,
              catalogId: 20, createDate: DateTime(2026, 1, 1)),
        ],
        catalogsById: {
          10: const NoteCatalog(
              id: 10, name: 'Hmm.AutomobileMan.GasLog', schema: '{}',
              formatType: 0, isDefault: false),
          20: const NoteCatalog(
              id: 20, name: 'Hmm.General.Notes', schema: '{}',
              formatType: 0, isDefault: false),
        },
        catalogDomainById: const {10: 'AutomobileMan', 20: 'General'},
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('choosing a filter in the drawer does NOT pop the notes screen',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notesListStateProvider.overrideWith(_StubListState.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        // A "dashboard" underneath, then the notes list pushed on top —
        // the shape the bug needs to show itself.
        home: Builder(
          builder: (context) => Scaffold(
            key: const Key('dashboardStandIn'),
            body: Center(
              child: ElevatedButton(
                key: const Key('openNotes'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const NotesListScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('openNotes')));
    await tester.pumpAndSettle();
    expect(find.byType(NotesListScreen), findsOneWidget);

    // Open the drawer and pick a domain filter.
    final scaffold = find.descendant(
        of: find.byType(NotesListScreen), matching: find.byType(Scaffold));
    tester.firstState<ScaffoldState>(scaffold).openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Automobile').last);
    await tester.pumpAndSettle();

    // The drawer closed, the filter applied — and we are STILL on the list.
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(NotesListScreen), findsOneWidget,
        reason: 'the pop must close the drawer, not the notes screen');
    expect(find.text('Oil change'), findsOneWidget);
    expect(find.text('Grocery list'), findsNothing,
        reason: 'the filter did apply');
  });

  testWidgets('choosing a filter in the SHEET does NOT pop the notes screen',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notesListStateProvider.overrideWith(_StubListState.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('openNotes'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const NotesListScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('openNotes')));
    await tester.pumpAndSettle();

    // The toolbar filter icon opens the modal sheet.
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    // Expand the Automobile domain, then pick its catalog.
    await tester.tap(find.text('Automobile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gas Log').last);
    await tester.pumpAndSettle();

    expect(find.byType(NotesListScreen), findsOneWidget,
        reason: 'the pop must close the sheet, not the notes screen');
    expect(find.text('Oil change'), findsOneWidget);
    expect(find.text('Grocery list'), findsNothing,
        reason: 'the filter did apply');
  });
}
