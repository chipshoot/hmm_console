import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_link_picker.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:hmm_console/features/notes/rendering/note_display.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'note_display_fixtures.dart';

List<HmmNote> _notes() => [
  contactNote(zhangWei()),
  cheatsheetNote(vehicleCard()),
  HmmNote(
    id: 1,
    uuid: 'g',
    subject: 'Grocery list',
    authorId: 1,
    catalogId: 1,
    createDate: DateTime(2026, 1, 1),
  ),
];

class _ListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: _notes(),
    catalogsById: {1: generalCatalog, 2: contactCatalog, 3: cheatsheetCatalog},
  );
}

final _overrides = [
  notesListStateProvider.overrideWith(_ListState.new),
  noteCatalogNamesProvider.overrideWith(
    (ref) async => {
      1: 'General',
      2: contactCatalog.name,
      3: cheatsheetCatalog.name,
    },
  ),
];

Widget _app(
  Widget home, {
  List<Override> overrides = const [],
  NotesListState Function()? listState,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/contacts/:id',
        name: RouterNames.contactDetail.name,
        builder: (_, s) => Text('contact-detail:${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/cheatsheets/:id',
        name: RouterNames.cheatsheetDetail.name,
        builder: (_, s) => Text('sheet-detail:${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/notes/:id',
        builder: (_, s) => Text('note-detail:${s.pathParameters['id']}'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      if (listState == null)
        _overrides[0]
      else
        notesListStateProvider.overrideWith(listState),
      _overrides[1],
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(extensions: const [AppColors.light]),
    ),
  );
}

void _noRawSubjects() {
  expect(find.textContaining('Contact:'), findsNothing);
  expect(find.textContaining('Cheatsheet:'), findsNothing);
  expect(find.textContaining('{"note"'), findsNothing);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Narrow, so a row tap navigates instead of selecting in a split pane.
  void narrow(WidgetTester t) {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('notes list shows human titles and previews, not ids or JSON', (
    t,
  ) async {
    narrow(t);
    narrow(t);
    await t.pumpWidget(_app(const NotesListScreen()));
    await t.pumpAndSettle();
    expect(find.text('张伟'), findsOneWidget);
    expect(find.text('Doctor · +1 555 0100'), findsOneWidget);
    expect(find.text('Civic'), findsOneWidget);
    expect(find.text('Vehicle · 9 rows'), findsOneWidget);
    _noRawSubjects();
  });

  testWidgets('notes list search matches the display title', (t) async {
    narrow(t);
    await t.pumpWidget(_app(const NotesListScreen()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '张伟');
    await t.pumpAndSettle();
    expect(find.byType(NoteListTile), findsOneWidget);
    expect(
      find.descendant(of: find.byType(NoteListTile), matching: find.text('张伟')),
      findsOneWidget,
    );
    expect(find.text('Civic'), findsNothing);
    expect(find.text('Grocery list'), findsNothing);
    await t.enterText(find.byType(TextField), 'c-1');
    await t.pumpAndSettle();
    expect(find.text('张伟'), findsNothing);
    _noRawSubjects();
  });

  testWidgets('tapping a contact row opens contact detail', (t) async {
    narrow(t);
    await t.pumpWidget(_app(const NotesListScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('张伟'));
    await t.pumpAndSettle();
    expect(find.text('contact-detail:c-1'), findsOneWidget);
  });

  testWidgets('tapping a cheatsheet row opens cheatsheet detail', (t) async {
    narrow(t);
    await t.pumpWidget(_app(const NotesListScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Civic'));
    await t.pumpAndSettle();
    expect(find.text('sheet-detail:card-1'), findsOneWidget);
  });

  testWidgets('tapping a general row still opens the note', (t) async {
    narrow(t);
    await t.pumpWidget(_app(const NotesListScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Grocery list'));
    await t.pumpAndSettle();
    expect(find.text('note-detail:1'), findsOneWidget);
  });

  Widget pickerHost() => Consumer(
    builder: (context, ref, _) => Scaffold(
      body: ElevatedButton(
        onPressed: () => showNoteLinkPicker(context, ref),
        child: const Text('Open picker'),
      ),
    ),
  );

  testWidgets('link picker shows and filters by display title', (t) async {
    narrow(t);
    await t.pumpWidget(_app(pickerHost()));
    await t.pumpAndSettle();
    await t.tap(find.text('Open picker'));
    await t.pumpAndSettle();
    expect(find.text('张伟'), findsOneWidget);
    expect(find.text('Civic'), findsOneWidget);
    _noRawSubjects();
    await t.enterText(find.byType(TextField), '张伟');
    await t.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.widgetWithText(ListTile, '张伟'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'c-1');
    await t.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('attached notes shows the display title and routes by catalog', (
    t,
  ) async {
    narrow(t);
    narrow(t);
    await t.pumpWidget(
      _app(
        const Scaffold(body: AttachedNotesSection(parentId: 7)),
        overrides: [
          attachedNotesProvider(
            7,
          ).overrideWith((ref) async => [contactNote(zhangWei())]),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('张伟'), findsOneWidget);
    _noRawSubjects();
    await t.tap(find.text('张伟'));
    await t.pumpAndSettle();
    expect(find.text('contact-detail:c-1'), findsOneWidget);
  });

  testWidgets('note detail header shows the display title', (t) async {
    narrow(t);
    await t.pumpWidget(
      _app(
        const NoteDetailScreen(noteId: 20),
        overrides: [
          noteDetailProvider(20).overrideWith(
            (ref) async =>
                NoteDetailData(contactNote(zhangWei()), contactCatalog),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('张伟'), findsOneWidget);
    // The body is the generic renderer's (this screen is only reached by a
    // deep link; taps route to the contact screen), so only the header is
    // asserted: it must not be the id subject.
    expect(find.text('Contact:c-1'), findsNothing);
  });

  testWidgets('a note attached to a contact names the contact, not the id', (
    t,
  ) async {
    narrow(t);
    final child = HmmNote(
      id: 50,
      uuid: 'child',
      subject: 'Called about results',
      authorId: 1,
      catalogId: 1,
      parentNoteId: 20,
      createDate: DateTime(2026, 1, 1),
    );
    await t.pumpWidget(
      _app(const NotesListScreen(), listState: () => _AttachedState(child)),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('张伟'), findsWidgets);
    expect(find.textContaining('(张伟)'), findsOneWidget);
    _noRawSubjects();
    await t.enterText(find.byType(TextField), '张伟');
    await t.pumpAndSettle();
    expect(find.text('Called about results'), findsOneWidget);
  });
}

class _AttachedState extends NotesListState {
  _AttachedState(this.child);
  final HmmNote child;
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [contactNote(zhangWei()), child],
    catalogsById: {1: generalCatalog, 2: contactCatalog},
    catalogDomainById: const {1: 'General', 2: 'ContactMan'},
    targetsById: {20: (domain: 'ContactMan', subject: 'Contact:c-1')},
  );
}
