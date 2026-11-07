import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_actions_menu.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/note_sharer.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/features/notes/states/notes_multi_select.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMutate implements MutateNote {
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<NoteState> setFlagColor(int id, int? color) async {
    calls.add('setFlagColor($id,$color)');
    return NoteState(noteUuid: 'u$id', lastModifiedDate: DateTime(2026));
  }

  bool failTags = false;

  @override
  Future<void> setTags(int id, Set<int> tagIds) async {
    if (failTags) throw StateError('boom');
    calls.add('setTags($id,${(tagIds.toList()..sort())})');
  }

  @override
  Future<HmmNote> setParent(int id, int? parentId) async {
    calls.add('setParent($id,$parentId)');
    return HmmNote(
      id: id,
      uuid: 'u$id',
      subject: 's',
      authorId: 1,
      createDate: DateTime(2026),
    );
  }
}

class _FakeSharer implements NoteSharer {
  final shared = <String>[];
  final origins = <Rect?>[];
  bool fail = false;

  @override
  Future<void> shareText(String text, {Rect? origin}) async {
    if (fail) throw StateError('boom');
    shared.add(text);
    origins.add(origin);
  }
}

class _ListState extends NotesListState {
  _ListState({this.catalogName});
  final String? catalogName;

  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Grocery list',
        content: 'milk',
        authorId: 1,
        catalogId: 10,
        createDate: DateTime(2026, 1, 2),
      ),
      HmmNote(
        id: 9,
        uuid: 'u9',
        subject: 'Trip',
        authorId: 1,
        catalogId: 11,
        createDate: DateTime(2026, 1, 1),
      ),
    ],
    tagsByNoteId: const {
      1: [(id: 100, name: 'A'), (id: 101, name: 'B')],
    },
    catalogsById: {
      10: NoteCatalog(
        id: 10,
        name: catalogName ?? kGeneralCatalogName,
        schema: '{}',
        formatType: 0,
        isDefault: false,
      ),
      11: NoteCatalog(
        id: 11,
        name: kGeneralCatalogName,
        schema: '{}',
        formatType: 0,
        isDefault: false,
      ),
    },
  );
}

Widget _app(
  _FakeMutate mutate,
  _FakeSharer sharer, {
  _ListState? state,
  List<Override> extra = const [],
  TargetPlatform? platform,
}) => ProviderScope(
  overrides: [
    notesListStateProvider.overrideWith(() => state ?? _ListState()),
    mutateNoteProvider.overrideWithValue(mutate),
    noteSharerProvider.overrideWithValue(sharer),
    ...extra,
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(platform: platform, extensions: const [AppColors.light]),
    home: const NotesListScreen(),
  ),
);

/// CupertinoContextMenu opens after a long hold plus its grow animation.
Future<void> _holdRow(WidgetTester t, Finder row) async {
  final g = await t.startGesture(t.getCenter(row));
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await g.up();
  await t.pumpAndSettle();
}

List<Override> _tagOverrides() {
  final db = HmmDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return [tagRepositoryProvider.overrideWithValue(_FixedTags(db))];
}

class _FixedTags extends LocalTagRepository {
  _FixedTags(super.db);

  @override
  Stream<List<TagUsage>> watchTagUsage() => Stream.value([
    (id: 100, name: 'A', noteCount: 1),
    (id: 101, name: 'B', noteCount: 1),
    (id: 102, name: 'C', noteCount: 0),
  ]);
}

Finder get _firstRow => find.widgetWithText(NoteRow, 'Grocery list');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('noteMenuItems', () {
    test('ordinary note', () {
      final items = noteMenuItems(ordinary: true);
      expect(items.map((i) => i.action), [
        NoteMenuAction.pin,
        NoteMenuAction.flag,
        NoteMenuAction.tags,
        NoteMenuAction.attach,
        NoteMenuAction.share,
        NoteMenuAction.select,
        NoteMenuAction.delete,
      ]);
      expect(items.every((i) => i.enabled), isTrue);
    });

    test('entity note', () {
      final items = noteMenuItems(ordinary: false);
      expect(items.map((i) => i.action), [
        NoteMenuAction.pin,
        NoteMenuAction.flag,
        NoteMenuAction.tags,
        NoteMenuAction.share,
        NoteMenuAction.select,
        NoteMenuAction.manage,
      ]);
      expect(items.where((i) => !i.enabled).map((i) => i.action), [
        NoteMenuAction.share,
        NoteMenuAction.manage,
      ]);
    });
  });

  group('Android sheet', () {
    testWidgets('long-press opens the sheet with Select first', (t) async {
      await t.pumpWidget(_app(_FakeMutate(), _FakeSharer()));
      await t.pumpAndSettle();

      await t.longPress(_firstRow);
      await t.pumpAndSettle();

      final tiles = t.widgetList<ListTile>(find.byType(ListTile)).toList();
      String text(ListTile x) => (x.title! as Text).data!;
      expect(text(tiles.first), 'Select');
      expect(tiles.map(text), [
        'Select',
        'Pin',
        'Flag…',
        'Tags…',
        'Attach to…',
        'Share…',
        'Delete',
      ]);
    });

    testWidgets('Select enters multi-select with the note ticked', (t) async {
      await t.pumpWidget(_app(_FakeMutate(), _FakeSharer()));
      await t.pumpAndSettle();
      await t.longPress(_firstRow);
      await t.pumpAndSettle();

      await t.tap(find.text('Select'));
      await t.pumpAndSettle();

      final c = ProviderScope.containerOf(
        t.element(find.byType(NotesListScreen)),
      );
      final s = c.read(notesMultiSelectProvider);
      expect(s.active, isTrue);
      expect(s.ids, {1});
    });

    testWidgets('Share… hands the note text to the sharer', (t) async {
      final sharer = _FakeSharer();
      await t.pumpWidget(_app(_FakeMutate(), sharer));
      await t.pumpAndSettle();
      await t.longPress(_firstRow);
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Share…'));
      await t.pumpAndSettle();
      await t.tap(find.text('Share…'));
      await t.pumpAndSettle();

      expect(sharer.shared, ['Grocery list\n\nmilk']);
      // iPad needs a non-empty anchor for the share popover.
      expect(sharer.origins.single, isNotNull);
      expect(sharer.origins.single!.isEmpty, isFalse);
    });

    testWidgets('share failure shows the snackbar', (t) async {
      final sharer = _FakeSharer()..fail = true;
      await t.pumpWidget(_app(_FakeMutate(), sharer));
      await t.pumpAndSettle();
      await t.longPress(_firstRow);
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Share…'));
      await t.pumpAndSettle();
      await t.tap(find.text('Share…'));
      await t.pumpAndSettle();

      expect(find.text("Couldn't share the note"), findsOneWidget);
    });

    testWidgets('Flag… then Blue flags the note and remembers the colour', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final m = _FakeMutate();
      await t.pumpWidget(_app(m, _FakeSharer()));
      await t.pumpAndSettle();
      await t.longPress(_firstRow);
      await t.pumpAndSettle();

      await t.tap(find.text('Flag…'));
      await t.pumpAndSettle();
      await t.tap(find.text('Blue'));
      await t.pumpAndSettle();

      expect(m.calls, ['setFlagColor(1,4)']);
      final c = ProviderScope.containerOf(
        t.element(find.byType(NotesListScreen)),
      );
      expect(c.read(notesLastFlagColorProvider), 4);
    });

    testWidgets('Tags… writes the picked set through setTags', (t) async {
      final m = _FakeMutate();
      await t.pumpWidget(_app(m, _FakeSharer(), extra: _tagOverrides()));
      await t.pumpAndSettle();
      await t.longPress(_firstRow);
      await t.pumpAndSettle();

      await t.tap(find.text('Tags…'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(CheckboxListTile, 'A')); // remove A
      await t.tap(find.widgetWithText(CheckboxListTile, 'C')); // add C
      await t.pumpAndSettle();
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();

      expect(m.calls, ['setTags(1,[101, 102])']);
    });

    testWidgets('a failed tag write shows the failure snackbar', (t) async {
      final m = _FakeMutate()..failTags = true;
      await t.pumpWidget(_app(m, _FakeSharer(), extra: _tagOverrides()));
      await t.pumpAndSettle();
      await t.longPress(_firstRow);
      await t.pumpAndSettle();

      await t.tap(find.text('Tags…'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(CheckboxListTile, 'C'));
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();

      expect(find.text("Couldn't change the note's tags"), findsOneWidget);
    });

    testWidgets('Attach to… then Undo restores the previous parent', (t) async {
      final m = _FakeMutate();
      await t.pumpWidget(_app(m, _FakeSharer()));
      await t.pumpAndSettle();
      await t.longPress(_firstRow);
      await t.pumpAndSettle();

      await t.tap(find.text('Attach to…'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Trip'));
      await t.pumpAndSettle();

      expect(m.calls, ['setParent(1,9)']);
      expect(find.text('Attached to "Trip"'), findsOneWidget);

      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(m.calls, ['setParent(1,9)', 'setParent(1,null)']);
    });

    testWidgets('an entity note shows disabled Share from / Manage in', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          _FakeMutate(),
          _FakeSharer(),
          state: _ListState(catalogName: 'Hmm.ContactMan.Contact'),
        ),
      );
      await t.pumpAndSettle();
      await t.longPress(find.byType(NoteRow).first);
      await t.pumpAndSettle();

      expect(find.text('Share from Contacts'), findsOneWidget);
      expect(find.text('Manage in Contacts'), findsOneWidget);
      expect(find.text('Attach to…'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      final share = t.widget<ListTile>(
        find.widgetWithText(ListTile, 'Share from Contacts'),
      );
      expect(share.enabled, isFalse);
    });
  });

  group('iOS context menu', () {
    testWidgets('long-press shows a CupertinoContextMenu with Delete', (
      t,
    ) async {
      await t.pumpWidget(
        _app(_FakeMutate(), _FakeSharer(), platform: TargetPlatform.iOS),
      );
      await t.pumpAndSettle();
      expect(find.byType(CupertinoContextMenu), findsWidgets);

      await _holdRow(t, _firstRow);

      expect(find.byType(CupertinoContextMenuAction), findsWidgets);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('a contact note shows the disabled Manage / Share from', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          _FakeMutate(),
          _FakeSharer(),
          platform: TargetPlatform.iOS,
          state: _ListState(catalogName: 'Hmm.ContactMan.Contact'),
        ),
      );
      await t.pumpAndSettle();

      await _holdRow(t, find.byType(NoteRow).first);

      expect(find.text('Manage in Contacts'), findsOneWidget);
      expect(find.text('Share from Contacts'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('Share… in the context menu reaches the sharer', (t) async {
      final sharer = _FakeSharer();
      await t.pumpWidget(
        _app(_FakeMutate(), sharer, platform: TargetPlatform.iOS),
      );
      await t.pumpAndSettle();
      await _holdRow(t, _firstRow);

      await t.tap(find.text('Share…'));
      await t.pumpAndSettle();

      expect(sharer.shared, ['Grocery list\n\nmilk']);
      expect(sharer.origins.single, isNotNull);
      expect(sharer.origins.single!.isEmpty, isFalse);
    });

    testWidgets('swipes still work on iOS', (t) async {
      final m = _FakeMutate();
      await t.pumpWidget(_app(m, _FakeSharer(), platform: TargetPlatform.iOS));
      await t.pumpAndSettle();

      await t.drag(_firstRow, const Offset(-350, 0));
      await t.pumpAndSettle();
      expect(find.text('Flag'), findsOneWidget);
    });
  });
}
