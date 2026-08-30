import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_row_separator.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 1, uuid: 'u1', subject: 'Grocery list', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 2)),
          HmmNote(
              id: 2, uuid: 'u2', subject: 'Vacation', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 1)),
        ],
        catalogsById: const {},
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows note tiles and filters by search query', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notesListStateProvider.overrideWith(_StubListState.new),
      ],
      child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NotesListScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NoteListTile), findsNWidgets(2));
    expect(find.byType(AppRowSeparator), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'groc');
    await tester.pumpAndSettle();
    expect(find.byType(NoteListTile), findsOneWidget);
    expect(find.text('Grocery list'), findsOneWidget);
  });

  testWidgets('sort button opens the sort sheet', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NotesListScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    expect(find.text('Subject — A → Z'), findsOneWidget);
  });

  testWidgets('a search query left behind is still VISIBLE when you return',
      (tester) async {
    // Reported as "no notes found" while the gas log list was fine. The query
    // lives on the notifier so it survives navigation, but the TextField had
    // no controller — so coming back showed an empty search box filtering an
    // apparently empty list, with nothing on screen explaining why.
    //
    // ONE container across both mounts: rebuilding the ProviderScope would
    // create a fresh notifier and reset the query, which is exactly what the
    // app does NOT do.
    final container = ProviderContainer(overrides: [
      notesListStateProvider.overrideWith(_StubListState.new),
    ]);
    addTearDown(container.dispose);

    Widget app(Widget home) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(extensions: const [AppColors.light]),
            home: home,
          ),
        );

    await tester.pumpWidget(app(const NotesListScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    await tester.pumpAndSettle();
    expect(find.byType(NoteListTile), findsNothing);

    // Leave the screen, then come back to a freshly built one.
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(const NotesListScreen()));
    await tester.pumpAndSettle();

    // The list is still filtered — that part is by design — but now the box
    // says so instead of looking empty.
    expect(find.byType(NoteListTile), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'zzz-no-match',
        reason: 'the box must show the query that is hiding the notes');
  });

  testWidgets('the clear button appears only with a query, and empties it',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NotesListScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notesSearchClear')), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    await tester.pumpAndSettle();
    expect(find.byType(NoteListTile), findsNothing);

    await tester.tap(find.byKey(const Key('notesSearchClear')));
    await tester.pumpAndSettle();

    expect(find.byType(NoteListTile), findsNWidgets(2));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });
}
