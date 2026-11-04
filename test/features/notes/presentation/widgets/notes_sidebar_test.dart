import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/notes_sidebar.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_results.dart';
import 'package:hmm_console/features/notes/query/saved_search.dart';
import 'package:hmm_console/features/notes/states/filter_usage.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/features/notes/states/notes_results_provider.dart';
import 'package:hmm_console/features/notes/states/saved_searches_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

HmmNote _n(int id, int cat) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: 'Note $id',
  authorId: 1,
  catalogId: cat,
  createDate: DateTime(2026, 1, 10 - id),
);

NoteCatalog _cat(int id, String name) => NoteCatalog(
  id: id,
  name: name,
  schema: '{}',
  formatType: 0,
  isDefault: false,
);

class _State extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [_n(1, 10), _n(2, 20)],
    catalogsById: {
      10: _cat(10, 'Hmm.AutomobileMan.GasLog'),
      20: _cat(20, 'Hmm.General.Notes'),
    },
    catalogDomainById: const {10: 'AutomobileMan', 20: 'General'},
    liveTagNames: const {7: 'Zebra', 8: 'apple', 9: 'Unused'},
  );
}

class _Saved extends SavedSearchesNotifier {
  _Saved(this.initial);
  final List<SavedSearch> initial;
  @override
  List<SavedSearch> build() => initial;
}

class _Usage extends FilterUsageNotifier {
  final recorded = <String>[];
  @override
  Future<Map<String, int>> build() async => {};
  @override
  Future<void> record(String domainKey) async => recorded.add(domainKey);
}

const _counts = NoteCounts(
  all: 12,
  pinned: 3,
  byDomain: {'AutomobileMan': 5, 'General': 7},
  byTag: {7: 2, 8: 4, 9: 0},
  byFlag: {0: 1, 4: 2, 3: 0},
);

Future<({ProviderContainer c, _Usage usage, List<int> picked})> _pump(
  WidgetTester tester, {
  AsyncValue<NoteResults> results = const AsyncData(
    NoteResults(groups: [], counts: _counts, total: 12),
  ),
  List<SavedSearch> saved = const [],
  SavedSearchesNotifier Function()? savedNotifier,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final usage = _Usage();
  final picked = <int>[];
  final c = ProviderContainer(
    overrides: [
      notesListStateProvider.overrideWith(_State.new),
      notesResultsProvider.overrideWithValue(results),
      savedSearchesProvider.overrideWith(savedNotifier ?? () => _Saved(saved)),
      filterUsageProvider.overrideWith(() => usage),
    ],
  );
  addTearDown(c.dispose);
  final data = await c.read(notesListStateProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => NotesSidebar(
              data: ref.watch(notesListStateProvider).value ?? data,
              onPicked: () => picked.add(picked.length),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (c: c, usage: usage, picked: picked);
}

NoteSource _source(ProviderContainer c) =>
    c.read(notesListStateProvider).value!.query.source;

String _countOf(WidgetTester tester, String title) {
  final tile = find.widgetWithText(ListTile, title);
  final trailing = tester.widget<ListTile>(tile).trailing;
  expect(trailing, isNotNull, reason: '$title has a trailing count');
  final texts = find.descendant(
    of: find.byWidget(trailing!),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(texts.first).data!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lists the sections in order with counts', (tester) async {
    await _pump(
      tester,
      saved: const [
        SavedSearch(
          id: 's1',
          name: 'Mine',
          order: 0,
          query: NoteQuery(text: 'oil'),
        ),
      ],
    );

    double y(String text) => tester.getTopLeft(find.text(text).first).dy;
    final order = [
      'All',
      'Pinned',
      'Flagged',
      'Today',
      'Domains',
      'Automobile',
      'General',
      'Tags',
      'apple',
      'Zebra',
      'Smart filters',
      'With photos',
      'With place',
      'Last 7 days',
      'Saved searches',
      'Mine',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(y(order[i]), greaterThan(y(order[i - 1])), reason: order[i]);
    }
    expect(find.text('Unused'), findsNothing, reason: 'zero-count tag hidden');

    expect(_countOf(tester, 'All'), '12');
    expect(_countOf(tester, 'Pinned'), '3');
    expect(_countOf(tester, 'Flagged'), '3');
    expect(_countOf(tester, 'Automobile'), '5');
    expect(_countOf(tester, 'General'), '7');
    expect(_countOf(tester, 'apple'), '4');
    expect(_countOf(tester, 'Zebra'), '2');
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Today')).trailing,
      isNull,
    );
  });

  testWidgets('flag sub-rows show only colours in use, by name', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.widgetWithText(ListTile, 'Red'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Blue'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Green'), findsNothing);
    expect(_countOf(tester, 'Blue'), '2');
  });

  testWidgets('picking a flag colour sets FlaggedSource(color)', (
    tester,
  ) async {
    final r = await _pump(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Blue'));
    await tester.pumpAndSettle();
    expect(_source(r.c), const FlaggedSource(color: 4));
    expect(r.picked, hasLength(1));
    expect(r.usage.recorded, isEmpty);
  });

  testWidgets('counts are hidden while results load', (tester) async {
    await _pump(tester, results: const AsyncLoading());
    for (final t in ['All', 'Pinned', 'Flagged', 'Automobile']) {
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, t)).trailing,
        t == 'All' ? isA<Row>() : isNull,
        reason: t, // All is selected, so it only shows the check
      );
    }
    expect(find.text('0'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Red'), findsNothing);
  });

  testWidgets(
    'picking a tag sets TagSource, records tag:<id> usage and calls onPicked once',
    (tester) async {
      final r = await _pump(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Zebra'));
      await tester.pumpAndSettle();
      expect(_source(r.c), const TagSource(tagId: 7));
      expect(r.usage.recorded, ['tag:7']);
      expect(r.picked, hasLength(1));
    },
  );

  testWidgets('picking a domain records the domain key', (tester) async {
    final r = await _pump(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Automobile'));
    await tester.pumpAndSettle();
    expect(_source(r.c), const DomainSource(key: 'AutomobileMan'));
    expect(r.usage.recorded, ['AutomobileMan']);
    expect(r.picked, hasLength(1));
  });

  testWidgets('Pinned, Today and All set their sources without usage', (
    tester,
  ) async {
    final r = await _pump(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Pinned'));
    await tester.pumpAndSettle();
    expect(_source(r.c), const PinnedSource());
    await tester.tap(find.widgetWithText(ListTile, 'Today'));
    await tester.pumpAndSettle();
    expect(_source(r.c), const TodaySource());
    await tester.tap(find.widgetWithText(ListTile, 'Flagged'));
    await tester.pumpAndSettle();
    expect(_source(r.c), const FlaggedSource());
    await tester.tap(find.widgetWithText(ListTile, 'All'));
    await tester.pumpAndSettle();
    expect(_source(r.c), const AllSource());
    expect(r.picked, hasLength(4));
    expect(r.usage.recorded, isEmpty);
  });

  testWidgets('a built-in smart filter opens; long-press does nothing', (
    tester,
  ) async {
    final r = await _pump(tester);
    await tester.longPress(find.text('With photos'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(r.picked, isEmpty);

    await tester.tap(find.text('With photos'));
    await tester.pumpAndSettle();
    expect(_source(r.c), const SmartSource(savedId: 'builtin.withPhotos'));
    expect(r.picked, hasLength(1));
  });

  testWidgets('saved-search rename / move / delete with undo still work', (
    tester,
  ) async {
    final ops = <String>[];
    final r = await _pump(tester, savedNotifier: () => _Recording(ops));
    await tester.longPress(find.text('Oil photos'));
    await tester.pumpAndSettle();
    expect(find.text('Move up'), findsNothing);
    expect(find.text('Move down'), findsOneWidget);
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    expect(ops, ['move s1 1']);
    expect(r.picked, isEmpty, reason: 'move keeps the panel open');

    await tester.longPress(find.text('Oil photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Photos');
    await tester.pump();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(ops.last, 'rename s1 Photos');

    // Delete closes the panel through onPicked, then offers Undo.
    await tester.longPress(find.text('Oil photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(ops.last, 'remove s1');
    expect(r.picked, hasLength(1));
    expect(find.text('Deleted "Oil photos"'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(ops.last, 'restore s1');
  });

  testWidgets('the help entry shows "Side panel" with the menu icon', (
    tester,
  ) async {
    late ScreenHelp help;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            help = helpFor(HelpId.notesList, AppLocalizations.of(context));
            return const SizedBox();
          },
        ),
      ),
    );
    final e = help.entries.firstWhere((e) => e.title == 'Side panel');
    expect(e.icon, Icons.menu);
  });

  testWidgets('the tokens help body mentions kinds of note', (tester) async {
    late ScreenHelp help;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            help = helpFor(HelpId.notesList, AppLocalizations.of(context));
            return const SizedBox();
          },
        ),
      ),
    );
    expect(help.entries.any((e) => e.body.contains('kinds of note')), isTrue);
  });
}

class _Recording extends SavedSearchesNotifier {
  _Recording(this.ops);
  final List<String> ops;
  @override
  List<SavedSearch> build() => const [
    SavedSearch(
      id: 's1',
      name: 'Oil photos',
      order: 0,
      query: NoteQuery(text: 'oil'),
    ),
    SavedSearch(
      id: 's2',
      name: 'Vacation',
      order: 1,
      query: NoteQuery(text: 'trip'),
    ),
  ];
  @override
  Future<void> rename(String id, String name) async =>
      ops.add('rename $id $name');
  @override
  Future<void> move(String id, int delta) async => ops.add('move $id $delta');
  @override
  Future<void> remove(String id) async => ops.add('remove $id');
  @override
  Future<void> restore(SavedSearch s) async => ops.add('restore ${s.id}');
}
