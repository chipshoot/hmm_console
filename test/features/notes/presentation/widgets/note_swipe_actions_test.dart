import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/note_selection.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMutate implements MutateNote {
  final calls = <String>[];
  bool failPin = false;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<NoteState> setPinned(int id, bool pinned) async {
    if (failPin) throw StateError('boom');
    calls.add('setPinned($id,$pinned)');
    return NoteState(noteUuid: 'u$id', lastModifiedDate: DateTime(2026));
  }

  @override
  Future<NoteState> setFlagColor(int id, int? color) async {
    calls.add('setFlagColor($id,$color)');
    return NoteState(noteUuid: 'u$id', lastModifiedDate: DateTime(2026));
  }

  @override
  Future<void> delete(int id) async => calls.add('delete($id)');

  @override
  Future<HmmNote> restore(int id) async {
    calls.add('restore($id)');
    return HmmNote(
      id: id,
      uuid: 'u$id',
      subject: 's',
      authorId: 1,
      createDate: DateTime(2026),
    );
  }
}

class _ListState extends NotesListState {
  _ListState({this.catalogName, this.states = const {}});
  final String? catalogName;
  final Map<String, NoteState> states;

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
    ],
    catalogsById: {
      10: NoteCatalog(
        id: 10,
        name: catalogName ?? kGeneralCatalogName,
        schema: '{}',
        formatType: 0,
        isDefault: false,
      ),
    },
    statesByUuid: states,
  );
}

Widget _app(
  _FakeMutate mutate, {
  _ListState? state,
  List<Override> extra = const [],
  TargetPlatform? platform,
  Widget home = const NotesListScreen(),
}) => ProviderScope(
  overrides: [
    notesListStateProvider.overrideWith(() => state ?? _ListState()),
    mutateNoteProvider.overrideWithValue(mutate),
    ...extra,
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(platform: platform, extensions: const [AppColors.light]),
    home: home,
  ),
);

NoteState _state({bool pinned = false, int? flag}) => NoteState(
  noteUuid: 'u1',
  isPinned: pinned,
  flagColor: flag,
  lastModifiedDate: DateTime(2026),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('swipe right pins an unpinned note', (tester) async {
    final m = _FakeMutate();
    await tester.pumpWidget(_app(m));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NoteRow), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();

    expect(m.calls, ['setPinned(1,true)']);
  });

  testWidgets('swipe left on an ordinary note shows Flag and Delete', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeMutate()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NoteRow), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(find.text('Flag'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Manage'), findsNothing);
  });

  testWidgets('swipe left on a contact note shows Manage, not Delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeMutate(),
        state: _ListState(catalogName: 'Hmm.ContactMan.Contact'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NoteRow), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Flag'), findsOneWidget);
  });

  testWidgets('Manage on a note with no own screen says where to manage it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeMutate(), state: _ListState(catalogName: 'Hmm.Weird.Thing')),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NoteRow), const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    expect(find.text('Manage in its own screen'), findsOneWidget);
  });

  testWidgets('flag uses the last-used colour', (tester) async {
    final m = _FakeMutate();
    await tester.pumpWidget(
      _app(m, extra: [notesLastFlagColorProvider.overrideWithValue(3)]),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NoteRow), const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flag'));
    await tester.pumpAndSettle();

    expect(m.calls, ['setFlagColor(1,3)']);
  });

  testWidgets('flagged note shows Unflag, which clears the flag', (
    tester,
  ) async {
    final m = _FakeMutate();
    await tester.pumpWidget(
      _app(m, state: _ListState(states: {'u1': _state(flag: 2)})),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NoteRow), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('Flag'), findsNothing);
    await tester.tap(find.text('Unflag'));
    await tester.pumpAndSettle();

    expect(m.calls, ['setFlagColor(1,null)']);
  });

  testWidgets('swipe delete then Undo restores, even from the Pinned view', (
    tester,
  ) async {
    final m = _FakeMutate();
    await tester.pumpWidget(
      _app(m, state: _ListState(states: {'u1': _state(pinned: true)})),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(NotesListScreen)),
    ).read(notesListStateProvider.notifier).setSource(const PinnedSource());
    await tester.pumpAndSettle();
    expect(find.byType(NoteRow), findsOneWidget);

    await tester.drag(find.byType(NoteRow), const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(m.calls, ['delete(1)']);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(m.calls, ['delete(1)', 'restore(1)']);
  });

  testWidgets('wide: deleting the open note clears the selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final m = _FakeMutate();
    await tester.pumpWidget(_app(m));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotesListScreen)),
    );
    container.read(selectedNoteIdProvider.notifier).select(1);

    await tester.drag(find.byType(NoteRow), const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(m.calls, ['delete(1)']);
    expect(container.read(selectedNoteIdProvider), isNull);
  });

  testWidgets('pin failure shows the snackbar', (tester) async {
    final m = _FakeMutate()..failPin = true;
    await tester.pumpWidget(_app(m));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(NoteRow), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't pin the note"), findsOneWidget);
  });

  Future<double> pushNotes(WidgetTester tester, _FakeMutate m) async {
    await tester.pumpWidget(
      _app(
        m,
        platform: TargetPlatform.iOS,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const NotesListScreen(),
                  ),
                ),
                child: const Text('open notes'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesListScreen), findsOneWidget);
    return tester.getCenter(find.byType(NoteRow)).dy;
  }

  testWidgets('iOS: a drag from the left edge pops the route, not Pin', (
    tester,
  ) async {
    final m = _FakeMutate();
    final y = await pushNotes(tester, m);

    // A real finger takes frames to travel the touch slop, so the row has
    // rebuilt (Pin disabled) before the first move; reproduce that frame.
    final g = await tester.startGesture(Offset(5, y));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    expect(find.byType(NotesListScreen), findsNothing);
    expect(find.text('open notes'), findsOneWidget);
    expect(find.text('Pin'), findsNothing);
    expect(m.calls, isEmpty);
  });

  testWidgets('iOS: a mid-row drag opens Pin and keeps the route', (
    tester,
  ) async {
    final y = await pushNotes(tester, _FakeMutate());

    await tester.dragFrom(Offset(100, y), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget);
  });
}
