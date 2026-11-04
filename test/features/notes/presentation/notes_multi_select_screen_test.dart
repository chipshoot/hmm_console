import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_contact_repository.dart'
    show contactCatalogName;
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/presentation/widgets/notes_bulk_bar.dart';
import 'package:hmm_console/features/notes/states/note_bulk_actions.dart';
import 'package:hmm_console/features/notes/states/note_selection.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/features/notes/states/notes_multi_select.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBulk implements NoteBulkActions {
  final calls = <String>[];
  Set<int> failIds = {};

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  BulkOutcome _split(List<int> ids) => BulkOutcome(
    succeeded: [
      for (final id in ids)
        if (!failIds.contains(id)) id,
    ],
    failed: [
      for (final id in ids)
        if (failIds.contains(id)) id,
    ],
  );

  @override
  Future<(bool, BulkOutcome)> togglePinned(
    List<int> ids,
    Map<int, bool> isPinnedById,
  ) async {
    final pin = !ids.every((id) => isPinnedById[id] ?? false);
    calls.add('pin($pin,${ids.join(',')})');
    return (pin, _split(ids));
  }

  @override
  Future<BulkOutcome> setFlag(List<int> ids, int? flagColor) async {
    calls.add('flag($flagColor,${ids.join(',')})');
    return _split(ids);
  }

  @override
  Future<BulkDeleteOutcome> delete(
    List<int> ids,
    bool Function(int id) isOrdinary,
  ) async {
    calls.add('delete(${ids.join(',')})');
    final eligible = ids.where(isOrdinary).toList();
    final o = _split(eligible);
    return BulkDeleteOutcome(
      deleted: o.succeeded,
      skipped: ids.where((id) => !isOrdinary(id)).toList(),
      failed: o.failed,
    );
  }

  @override
  Future<BulkOutcome> restore(List<int> ids) async {
    calls.add('restore(${ids.join(',')})');
    return BulkOutcome(succeeded: ids, failed: const []);
  }
}

/// Notes 1..[general] are ordinary, then [contacts] contact notes. Ids in
/// [pinned] are pinned.
class _ListState extends NotesListState {
  _ListState({this.general = 5, this.contacts = 0, this.pinned = const {}});
  final int general;
  final int contacts;
  final Set<int> pinned;

  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      for (var i = 1; i <= general + contacts; i++)
        HmmNote(
          id: i,
          uuid: 'u$i',
          subject: 'Note $i',
          authorId: 1,
          catalogId: i <= general ? 10 : 11,
          createDate: DateTime(2026, 1, 1).add(Duration(hours: i)),
        ),
    ],
    catalogsById: const {
      10: NoteCatalog(
        id: 10,
        name: kGeneralCatalogName,
        schema: '{}',
        formatType: 0,
        isDefault: false,
      ),
      11: NoteCatalog(
        id: 11,
        name: contactCatalogName,
        schema: '{}',
        formatType: 0,
        isDefault: false,
      ),
    },
    statesByUuid: {
      for (final id in pinned)
        'u$id': NoteState(
          noteUuid: 'u$id',
          isPinned: true,
          lastModifiedDate: DateTime(2026),
        ),
    },
  );
}

Widget _app(
  _FakeBulk bulk, {
  _ListState? state,
  TargetPlatform platform = TargetPlatform.android,
  List<Override> extra = const [],
  bool docked = false,
}) => ProviderScope(
  overrides: [
    notesListStateProvider.overrideWith(() => state ?? _ListState()),
    noteBulkActionsProvider.overrideWithValue(bulk),
    ...extra,
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(platform: platform, extensions: const [AppColors.light]),
    home: NotesListScreen(sidebarDocked: docked),
  ),
);

ProviderContainer _c(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(NotesListScreen)));

NotesMultiSelect _sel(WidgetTester t) => _c(t).read(notesMultiSelectProvider);

Future<void> _boot(WidgetTester t, Widget app, {Size? size}) async {
  if (size != null) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }
  await t.pumpWidget(app);
  await t.pumpAndSettle();
}

void _enter(WidgetTester t, [int? id]) {
  _c(t).read(notesMultiSelectProvider.notifier).enter(id);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('iOS Edit enters selection; tapping rows toggles; Done exits', (
    t,
  ) async {
    await _boot(t, _app(_FakeBulk(), platform: TargetPlatform.iOS));
    expect(find.text('Edit'), findsOneWidget);
    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();
    expect(_sel(t).active, isTrue);
    expect(find.text('Select notes'), findsWidgets);
    expect(find.text('Done'), findsOneWidget);

    await t.tap(find.text('Note 2'));
    await t.pumpAndSettle();
    expect(_sel(t).ids, {2});
    expect(find.text('1 selected'), findsWidgets);
    await t.tap(find.text('Note 3'));
    await t.pumpAndSettle();
    expect(_sel(t).ids, {2, 3});
    await t.tap(find.text('Note 2'));
    await t.pumpAndSettle();
    expect(_sel(t).ids, {3});

    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(_sel(t).active, isFalse);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('Android: long-press, Select enters selection with that note', (
    t,
  ) async {
    await _boot(t, _app(_FakeBulk()));
    expect(find.text('Edit'), findsNothing);
    await t.longPress(find.text('Note 2'));
    await t.pumpAndSettle();
    await t.tap(find.text('Select'));
    await t.pumpAndSettle();
    expect(_sel(t).active, isTrue);
    expect(_sel(t).ids, {2});
    expect(find.text('1 selected'), findsWidgets);
    expect(find.byTooltip('Done'), findsOneWidget);
    // The close button leaves selection.
    await t.tap(find.byTooltip('Done'));
    await t.pumpAndSettle();
    expect(_sel(t).active, isFalse);
  });

  testWidgets('rows show check circles only while selecting', (t) async {
    await _boot(t, _app(_FakeBulk()));
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    _enter(t, 1);
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
    expect(find.byType(NoteRow), findsNWidgets(5));
  });

  testWidgets('swipes and the long-press menu are off while selecting', (
    t,
  ) async {
    await _boot(t, _app(_FakeBulk()));
    expect(find.byType(Slidable), findsNWidgets(5));
    _enter(t);
    await t.pumpAndSettle();
    expect(find.byType(Slidable), findsNothing);
    await t.longPress(find.text('Note 2'));
    await t.pumpAndSettle();
    // A hold with no long-press handler is just a tap: no sheet opens.
    expect(find.text('Select'), findsNothing);
    expect(find.text('Attach to…'), findsNothing);
  });

  testWidgets('iOS: no context menu while selecting', (t) async {
    await _boot(t, _app(_FakeBulk(), platform: TargetPlatform.iOS));
    expect(find.byType(CupertinoContextMenu), findsNWidgets(5));
    _enter(t);
    await t.pumpAndSettle();
    expect(find.byType(CupertinoContextMenu), findsNothing);
  });

  testWidgets('bulk bar is disabled while nothing is selected', (t) async {
    await _boot(t, _app(_FakeBulk()));
    expect(find.byTooltip('Pin'), findsNothing);
    _enter(t);
    await t.pumpAndSettle();
    for (final tip in ['Pin', 'Flag…', 'Delete']) {
      final b = t.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tip),
          matching: find.byType(IconButton),
        ),
      );
      expect(b.onPressed, isNull, reason: tip);
    }
    final all = t.widget<TextButton>(
      find.widgetWithText(TextButton, 'Select All'),
    );
    expect(all.onPressed, isNotNull); // Select All stays usable
  });

  testWidgets('Select All selects every visible note including Pinned', (
    t,
  ) async {
    await _boot(t, _app(_FakeBulk(), state: _ListState(pinned: {1, 2})));
    _enter(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Select All'));
    await t.pumpAndSettle();
    expect(_sel(t).ids, {1, 2, 3, 4, 5});
    expect(find.text('5 selected'), findsWidgets);
  });

  testWidgets('bulk pin pins all when one is unpinned; full success exits', (
    t,
  ) async {
    final bulk = _FakeBulk();
    await _boot(t, _app(bulk, state: _ListState(pinned: {1})));
    _enter(t, 1);
    _c(t).read(notesMultiSelectProvider.notifier).toggle(2);
    await t.pumpAndSettle();
    expect(find.byTooltip('Pin'), findsOneWidget);
    await t.tap(find.byTooltip('Pin'));
    await t.pumpAndSettle();
    expect(bulk.calls, ['pin(true,1,2)']);
    expect(_sel(t).active, isFalse);
  });

  testWidgets('bulk bar offers Unpin when every selected note is pinned', (
    t,
  ) async {
    await _boot(t, _app(_FakeBulk(), state: _ListState(pinned: {1, 2})));
    _enter(t, 1);
    _c(t).read(notesMultiSelectProvider.notifier).toggle(2);
    await t.pumpAndSettle();
    expect(find.byTooltip('Unpin'), findsOneWidget);
    expect(find.byTooltip('Pin'), findsNothing);
  });

  testWidgets('bulk flag applies the colour and remembers it', (t) async {
    final bulk = _FakeBulk();
    await _boot(t, _app(bulk));
    _enter(t, 1);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Flag…'));
    await t.pumpAndSettle();
    await t.tap(find.text('Blue'));
    await t.pumpAndSettle();
    expect(bulk.calls, ['flag(4,1)']);
    expect(_sel(t).active, isFalse);
  });

  testWidgets('bulk flag partial failure keeps the failed notes selected', (
    t,
  ) async {
    final bulk = _FakeBulk()..failIds = {3, 7};
    await _boot(t, _app(bulk, state: _ListState(general: 10)));
    _enter(t);
    _c(t)
        .read(notesMultiSelectProvider.notifier)
        .selectAll(List.generate(10, (i) => i + 1));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Flag…'));
    await t.pumpAndSettle();
    await t.tap(find.text('Blue'));
    await t.pumpAndSettle();
    expect(find.text('Flagged 8 of 10 notes'), findsOneWidget);
    expect(_sel(t).ids, {3, 7});
    expect(_sel(t).active, isTrue);
  });

  testWidgets('bulk delete mixed: skips contacts, Undo restores the deleted', (
    t,
  ) async {
    final bulk = _FakeBulk();
    await _boot(t, _app(bulk, state: _ListState(general: 3, contacts: 2)));
    _enter(t);
    _c(t).read(notesMultiSelectProvider.notifier).selectAll([1, 2, 3, 4, 5]);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete'));
    await t.pumpAndSettle();
    expect(find.text('Deleted 3 · 2 skipped'), findsOneWidget);
    expect(bulk.calls, ['delete(5,4,3,2,1)']);
    expect(_sel(t).ids, {4, 5});
    expect(_sel(t).active, isTrue);

    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(bulk.calls.last, 'restore(3,2,1)');
    expect(find.text('Restored 3 notes'), findsOneWidget);
    expect(_sel(t).ids, {4, 5});
  });

  testWidgets('bulk delete of ordinary notes exits selection', (t) async {
    final bulk = _FakeBulk();
    await _boot(t, _app(bulk));
    _enter(t, 1);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete'));
    await t.pumpAndSettle();
    expect(find.text('Deleted 1 note'), findsOneWidget);
    expect(_sel(t).active, isFalse);
  });

  testWidgets('bulk delete with failures keeps them selected and says so', (
    t,
  ) async {
    final bulk = _FakeBulk()..failIds = {2};
    await _boot(t, _app(bulk));
    _enter(t, 1);
    _c(t).read(notesMultiSelectProvider.notifier).toggle(2);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete'));
    await t.pumpAndSettle();
    expect(
      find.text("Couldn't delete some notes. They stay selected."),
      findsOneWidget,
    );
    expect(_sel(t).ids, {2});
    expect(_sel(t).active, isTrue);
  });

  testWidgets('bulk delete only contacts writes nothing', (t) async {
    final bulk = _FakeBulk();
    await _boot(t, _app(bulk, state: _ListState(general: 1, contacts: 2)));
    _enter(t);
    _c(t).read(notesMultiSelectProvider.notifier).selectAll([2, 3]);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete'));
    await t.pumpAndSettle();
    expect(
      find.text('These 2 notes are managed in their own screens'),
      findsOneWidget,
    );
    expect(bulk.calls.where((c) => c.startsWith('delete')), isEmpty);
    expect(_sel(t).ids, {2, 3});
  });

  testWidgets('picking a sidebar source exits selection', (t) async {
    await _boot(t, _app(_FakeBulk()));
    _enter(t, 1);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filters and lists').first);
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Pinned')),
    );
    await t.pumpAndSettle();
    expect(_sel(t).active, isFalse);
  });

  testWidgets('wide: bulk-deleting the open note clears the selection', (
    t,
  ) async {
    final bulk = _FakeBulk();
    await _boot(t, _app(bulk, docked: true), size: const Size(1200, 900));
    _c(t).read(selectedNoteIdProvider.notifier).select(2);
    _enter(t, 2);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete'));
    await t.pumpAndSettle();
    expect(_c(t).read(selectedNoteIdProvider), isNull);
  });

  testWidgets('wide: bulk-deleting another note keeps the open one', (t) async {
    await _boot(
      t,
      _app(_FakeBulk(), docked: true),
      size: const Size(1200, 900),
    );
    _c(t).read(selectedNoteIdProvider.notifier).select(2);
    _enter(t, 3);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete'));
    await t.pumpAndSettle();
    expect(_c(t).read(selectedNoteIdProvider), 2);
  });

  testWidgets(
    'search narrows, then bulk delete touches only the visible ticks',
    (t) async {
      final bulk = _FakeBulk();
      await _boot(t, _app(bulk));
      _enter(t);
      _c(t).read(notesMultiSelectProvider.notifier).selectAll([1, 2, 3]);
      await t.pumpAndSettle();
      expect(find.text('3 selected'), findsWidgets);
      await t.enterText(find.byType(TextField), 'Note 2');
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(_sel(t).ids, {2});
      expect(find.text('1 selected'), findsWidgets);
      await t.tap(find.byTooltip('Delete'));
      await t.pumpAndSettle();
      expect(bulk.calls, ['delete(2)']);
    },
  );

  testWidgets('picking a chip exits selection', (t) async {
    await _boot(t, _app(_FakeBulk()));
    _enter(t, 1);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Pinned'));
    await t.pumpAndSettle();
    expect(_sel(t).active, isFalse);
  });

  testWidgets('picking a smart filter in the side panel exits selection', (
    t,
  ) async {
    await _boot(t, _app(_FakeBulk()));
    _enter(t, 1);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filters and lists'));
    await t.pumpAndSettle();
    final smart = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('With photos'),
    );
    await t.scrollUntilVisible(
      smart,
      200,
      scrollable: find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.tap(smart);
    await t.pumpAndSettle();
    expect(_sel(t).active, isFalse);
  });

  testWidgets('Pin (not Unpin) shows when nothing is ticked', (t) async {
    await _boot(t, _app(_FakeBulk(), state: _ListState(pinned: {1})));
    _enter(t);
    await t.pumpAndSettle();
    expect(find.byTooltip('Pin'), findsOneWidget);
    expect(find.byTooltip('Unpin'), findsNothing);
  });

  testWidgets('iOS bulk bar is a flat Cupertino bar', (t) async {
    await _boot(t, _app(_FakeBulk(), platform: TargetPlatform.iOS));
    _enter(t, 1);
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(NotesBulkBar),
        matching: find.byType(DecoratedBox),
      ),
      findsWidgets,
    );
    final materials = t
        .widgetList<Material>(
          find.descendant(
            of: find.byType(NotesBulkBar),
            matching: find.byType(Material),
          ),
        )
        .where((m) => m.elevation > 0);
    expect(materials, isEmpty);
  });
}
