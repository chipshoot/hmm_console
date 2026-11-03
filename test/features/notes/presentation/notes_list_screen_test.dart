import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_row_separator.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Grocery list',
        authorId: 1,
        catalogId: 10,
        createDate: DateTime(2026, 1, 2),
      ),
      HmmNote(
        id: 2,
        uuid: 'u2',
        subject: 'Vacation',
        authorId: 1,
        catalogId: 10,
        createDate: DateTime(2026, 1, 1),
      ),
    ],
    catalogsById: const {},
  );
}

class _FailingListState extends NotesListState {
  int refreshes = 0;

  @override
  Future<NotesListData> build() async => throw StateError('disk on fire');

  @override
  Future<void> refresh() async => refreshes++;
}

class _DomainListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Oil change',
        authorId: 1,
        catalogId: 10,
        createDate: DateTime(2026, 1, 3),
      ),
      HmmNote(
        id: 2,
        uuid: 'u2',
        subject: 'Insurance renewal',
        authorId: 1,
        catalogId: 11,
        createDate: DateTime(2026, 1, 2),
      ),
      HmmNote(
        id: 3,
        uuid: 'u3',
        subject: 'Grocery list',
        authorId: 1,
        catalogId: 20,
        createDate: DateTime(2026, 1, 1),
      ),
    ],
    catalogsById: const {
      10: NoteCatalog(
        id: 10,
        name: 'Hmm.AutomobileMan.GasLog',
        schema: '{}',
        formatType: 0,
        isDefault: false,
      ),
      11: NoteCatalog(
        id: 11,
        name: 'Hmm.AutomobileMan.AutoInsurancePolicy',
        schema: '{}',
        formatType: 0,
        isDefault: false,
      ),
      20: NoteCatalog(
        id: 20,
        name: 'Hmm.General.Notes',
        schema: '{}',
        formatType: 0,
        isDefault: false,
      ),
    },
    catalogDomainById: const {
      10: 'AutomobileMan',
      11: 'AutomobileMan',
      20: 'General',
    },
  );
}

Widget _app({
  NotesListState Function() state = _StubListState.new,
  List<Override> extra = const [],
  TargetPlatform? platform,
}) => ProviderScope(
  overrides: [notesListStateProvider.overrideWith(state), ...extra],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(platform: platform, extensions: const [AppColors.light]),
    home: const NotesListScreen(),
  ),
);

/// Types into the search box and waits out its debounce.
Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows note tiles and filters by search query', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NoteRow), findsNWidgets(2));
    expect(find.byType(AppRowSeparator), findsOneWidget);

    await _search(tester, 'groc');
    expect(find.byType(NoteRow), findsOneWidget);
    expect(find.text('Grocery list'), findsOneWidget);
  });

  testWidgets('a search query left behind is still VISIBLE when you return', (
    tester,
  ) async {
    // Reported as "no notes found" while the gas log list was fine. The query
    // lives on the notifier so it survives navigation, but the TextField had
    // no controller — so coming back showed an empty search box filtering an
    // apparently empty list, with nothing on screen explaining why.
    //
    // ONE container across both mounts: rebuilding the ProviderScope would
    // create a fresh notifier and reset the query, which is exactly what the
    // app does NOT do.
    final container = ProviderContainer(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
    );
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

    await _search(tester, 'zzz-no-match');
    expect(find.byType(NoteRow), findsNothing);

    // Leave the screen, then come back to a freshly built one.
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(const NotesListScreen()));
    await tester.pumpAndSettle();

    // The list is still filtered — that part is by design — but now the box
    // says so instead of looking empty.
    expect(find.byType(NoteRow), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.controller?.text,
      'zzz-no-match',
      reason: 'the box must show the query that is hiding the notes',
    );
  });

  testWidgets('the clear button appears only with a query, and empties it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notesSearchClear')), findsNothing);

    await _search(tester, 'zzz-no-match');
    expect(find.byType(NoteRow), findsNothing);

    await tester.tap(find.byKey(const Key('notesSearchClear')));
    await tester.pumpAndSettle();

    expect(find.byType(NoteRow), findsNWidgets(2));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('no matches shows Clear search, which restores the list', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _search(tester, 'zzz');
    expect(find.text('No notes match “zzz”'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Clear search'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteRow), findsNWidgets(2));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
      reason: 'the box follows the cleared query',
    );
  });

  testWidgets('an empty view without a search says so', (tester) async {
    await tester.pumpWidget(_app(state: _DomainListState.new));
    await tester.pumpAndSettle();

    // A domain with no notes in it (only reachable programmatically today).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotesListScreen)),
    );
    container
        .read(notesListStateProvider.notifier)
        .setSource(const DomainSource(key: 'Health'));
    await tester.pumpAndSettle();

    expect(find.text('No notes here'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Clear search'), findsNothing);
  });

  testWidgets('no notes at all shows the first-run message', (tester) async {
    await tester.pumpWidget(_app(state: _EmptyListState.new));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets('load failure shows a generic message and Retry', (tester) async {
    final logs = <String?>[];
    final old = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m);
    late _FailingListState state;
    await tester.pumpWidget(_app(state: () => state = _FailingListState()));
    await tester.pumpAndSettle();
    debugPrint = old; // restored before the binding checks its invariants

    expect(find.text("Couldn't load your notes"), findsOneWidget);
    expect(find.textContaining('disk on fire'), findsNothing);
    expect(logs.where((m) => m!.contains('StateError')), isNotEmpty);
    expect(logs.where((m) => m!.contains('disk on fire')), isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(state.refreshes, 1);
  });

  testWidgets('pull to refresh triggers a manual sync', (tester) async {
    var syncs = 0;
    final controller = SyncController(
      syncAction: () async {
        syncs++;
        return SyncResult(
          pulledNotes: 0,
          pulledAttachments: 0,
          pushedNotes: 0,
          pushedAttachments: 0,
          completedAt: DateTime.now().toUtc(),
        );
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(extra: [syncControllerProvider.overrideWithValue(controller)]),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.byType(NoteRow).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(syncs, 1);
  });

  testWidgets('iOS pull to refresh triggers a manual sync once', (
    tester,
  ) async {
    var syncs = 0;
    final controller = SyncController(
      syncAction: () async {
        syncs++;
        return SyncResult(
          pulledNotes: 0,
          pulledAttachments: 0,
          pushedNotes: 0,
          pushedAttachments: 0,
          completedAt: DateTime.now().toUtc(),
        );
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        platform: TargetPlatform.iOS,
        extra: [syncControllerProvider.overrideWithValue(controller)],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      findsOneWidget,
    );

    // Past the control's 100 px trigger distance.
    await tester.drag(find.byType(NoteRow).first, const Offset(0, 300));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(syncs, 1);
  });

  testWidgets('the search hint covers more than subjects', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Search notes'), findsOneWidget);
  });

  testWidgets('a long parent title is cut on characters, not code units', (
    tester,
  ) async {
    await tester.pumpWidget(_app(state: _ParentEmojiListState.new));
    await tester.pumpAndSettle();
    final shown = '${'a' * 19}\u{1F600}…';
    expect(find.textContaining(shown, findRichText: true), findsOneWidget);
  });

  testWidgets('drawer and filter sheet still select a domain and its catalog', (
    tester,
  ) async {
    await tester.pumpWidget(_app(state: _DomainListState.new));
    await tester.pumpAndSettle();
    expect(find.byType(NoteRow), findsNWidgets(3));

    // Drawer: a whole domain.
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Automobile'));
    await tester.pumpAndSettle();
    expect(find.text('Oil change'), findsOneWidget);
    expect(find.text('Insurance renewal'), findsOneWidget);
    expect(find.text('Grocery list'), findsNothing);

    // Sheet: one catalog of that domain.
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automobile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gas Log').last);
    await tester.pumpAndSettle();
    expect(find.text('Oil change'), findsOneWidget);
    expect(find.text('Insurance renewal'), findsNothing);
    expect(find.text('Grocery list'), findsNothing);

    // Sheet: back to all notes.
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteRow), findsNWidgets(3));
  });

  testWidgets('help button opens Notes list help', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.helpNotesListSummary), findsOneWidget);
    expect(find.text(l.helpNotesListViewTitle), findsOneWidget);
  });

  testWidgets('top bar buttons have localized tooltips', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    for (final t in ['View', 'Filter', 'Subsystems', 'Help']) {
      expect(find.byTooltip(t), findsOneWidget, reason: t);
    }
  });
}

class _EmptyListState extends NotesListState {
  @override
  Future<NotesListData> build() async =>
      const NotesListData(all: [], catalogsById: {});
}

class _ParentEmojiListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: '${'a' * 19}\u{1F600}tail',
        authorId: 1,
        createDate: DateTime(2026, 1, 1),
      ),
      HmmNote(
        id: 2,
        uuid: 'u2',
        subject: 'Child',
        authorId: 1,
        parentNoteId: 1,
        createDate: DateTime(2026, 1, 2),
      ),
    ],
    catalogsById: const {},
  );
}
