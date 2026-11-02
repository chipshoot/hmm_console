import 'package:flutter/cupertino.dart' show CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/note_selection.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/features/notes/states/recent_searches.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

HmmNote _n(int id, String subject, int cat) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
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
    all: [
      _n(1, 'Oil change', 10),
      _n(2, 'Tyres', 10),
      _n(3, 'Grocery list', 20),
      _n(4, 'Vacation', 20),
    ],
    catalogsById: {
      10: _cat(10, 'Hmm.AutomobileMan.GasLog'),
      20: _cat(20, 'Hmm.General.Notes'),
    },
    catalogDomainById: const {10: 'AutomobileMan', 20: 'General'},
    tagsByNoteId: const {
      1: [(id: 5, name: 'car')],
      2: [(id: 5, name: 'car')],
      3: [(id: 6, name: 'home')],
    },
    liveTagNames: const {5: 'car', 6: 'home'},
  );
}

Widget _app(
  Widget home, {
  TargetPlatform? platform,
  ProviderContainer? container,
}) {
  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(platform: platform, extensions: const [AppColors.light]),
    home: home,
  );
  return container != null
      ? UncontrolledProviderScope(container: container, child: app)
      : ProviderScope(
          overrides: [notesListStateProvider.overrideWith(_State.new)],
          child: app,
        );
}

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [notesListStateProvider.overrideWith(_State.new)],
  );
  addTearDown(c.dispose);
  return c;
}

NotesListState _notifier(WidgetTester t) => ProviderScope.containerOf(
  t.element(find.byType(NotesListScreen)),
).read(notesListStateProvider.notifier);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_app(const NotesListScreen()));
  await tester.pumpAndSettle();
}

final _chip = find.byWidgetPredicate((w) => w is Chip || w is InputChip);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'typing shows suggestions and tapping one adds a chip and filters',
    (tester) async {
      await _open(tester);
      await _type(tester, 'car');
      expect(find.text('Suggestions'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, '#car'));
      await tester.pumpAndSettle();

      expect(_chip, findsOneWidget);
      expect(
        find.descendant(of: _chip, matching: find.text('#car')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byType(NoteRow), findsNWidgets(2));
      expect(find.text('Oil change'), findsOneWidget);
      expect(find.text('Grocery list'), findsNothing);
      // The notifier's text is empty too: the box must not look empty while
      // still filtering.
      final q = ProviderScope.containerOf(
        tester.element(find.byType(NotesListScreen)),
      ).read(notesListStateProvider).value!.query;
      expect(q.text, '');
      expect(q.tokens, [const TagToken(5)]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(NoteRow),
        findsNWidgets(2),
        reason: 'no late text undoes it',
      );
    },
  );

  testWidgets('removing a chip restores the list', (tester) async {
    await _open(tester);
    _notifier(tester).setTokens(const [TagToken(5)]);
    await tester.pumpAndSettle();
    expect(find.byType(NoteRow), findsNWidgets(2));

    await tester.tap(find.byTooltip('Remove #car'));
    await tester.pumpAndSettle();
    expect(_chip, findsNothing);
    expect(find.byType(NoteRow), findsNWidgets(4));
  });

  testWidgets("a removed tag's chip is struck out and ignored", (tester) async {
    await _open(tester);
    _notifier(tester).setTokens(const [TagToken(99)]);
    await tester.pumpAndSettle();

    final label = find.textContaining('(removed)');
    expect(label, findsOneWidget);
    expect(
      tester.widget<Text>(label).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(find.byType(NoteRow), findsNWidgets(4));
  });

  testWidgets('tokens and scope are still shown after leaving and returning', (
    tester,
  ) async {
    final c = _container();
    await tester.pumpWidget(_app(const NotesListScreen(), container: c));
    await tester.pumpAndSettle();
    c.read(notesListStateProvider.notifier)
      ..setSource(const DomainSource(key: 'AutomobileMan'))
      ..setTokens(const [TagToken(5)])
      ..setScope(NoteScope.all);
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(const SizedBox(), container: c));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(const NotesListScreen(), container: c));
    await tester.pumpAndSettle();

    expect(_chip, findsOneWidget);
    final seg = tester.widget<SegmentedButton<NoteScope>>(
      find.byType(SegmentedButton<NoteScope>),
    );
    expect(seg.selected, {NoteScope.all});
  });

  testWidgets('the scope toggle appears only while searching inside a filter', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(SegmentedButton<NoteScope>), findsNothing);

    _notifier(tester).setSource(const DomainSource(key: 'AutomobileMan'));
    await tester.pumpAndSettle();
    expect(
      find.byType(SegmentedButton<NoteScope>),
      findsNothing,
      reason: 'not searching',
    );

    await _type(tester, 'list');
    expect(find.byType(SegmentedButton<NoteScope>), findsOneWidget);
    expect(find.text('In Automobile'), findsOneWidget);
    expect(find.text('Grocery list'), findsNothing);

    await tester.tap(find.text('All notes').last);
    await tester.pumpAndSettle();
    expect(find.text('Grocery list'), findsOneWidget);

    // All notes + no source filter: nothing to choose between.
    _notifier(tester).setSource(const AllSource());
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<NoteScope>), findsNothing);
  });

  testWidgets(
    'focusing the empty box shows recent searches; tapping one applies it',
    (tester) async {
      final c = _container();
      await tester.pumpWidget(_app(const NotesListScreen(), container: c));
      await tester.pumpAndSettle();
      await c
          .read(recentSearchesProvider.notifier)
          .record(const NoteQuery(text: 'oil', tokens: [TagToken(5)]));
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsNothing, reason: 'not focused');

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Clear'), findsOneWidget);

      await tester.tap(find.text('oil · #car'));
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'oil',
      );
      expect(_chip, findsOneWidget);
      expect(find.byType(NoteRow), findsOneWidget);

      // Clear empties the list.
      await tester.tap(find.byKey(const Key('notesSearchClear')));
      await tester.pumpAndSettle();
      _notifier(tester).setTokens(const []);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsNothing);
    },
  );

  testWidgets('opening a note from a search records a recent search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _container();
    await tester.pumpWidget(_app(const NotesListScreen(), container: c));
    await tester.pumpAndSettle();
    await _type(tester, 'oil');

    await tester.tap(find.byType(NoteRow));
    await tester.pumpAndSettle();
    expect(c.read(selectedNoteIdProvider), 1);
    final recents = await c.read(recentSearchesProvider.future);
    expect(recents.map((r) => r.text), ['oil']);
  });

  testWidgets('submitting records a recent search', (tester) async {
    final c = _container();
    await tester.pumpWidget(_app(const NotesListScreen(), container: c));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tyres');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final recents = await c.read(recentSearchesProvider.future);
    expect(recents.map((r) => r.text), ['tyres']);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('chips and scope toggle render on $platform', (tester) async {
      await tester.pumpWidget(
        _app(const NotesListScreen(), platform: platform),
      );
      await tester.pumpAndSettle();
      _notifier(tester)
        ..setSource(const DomainSource(key: 'AutomobileMan'))
        ..setTokens(const [TagToken(5)]);
      await tester.pumpAndSettle();
      expect(_chip, findsOneWidget);
      expect(
        find.byType(
          platform == TargetPlatform.iOS
              ? CupertinoSlidingSegmentedControl<NoteScope>
              : SegmentedButton<NoteScope>,
        ),
        findsOneWidget,
      );
    });
  }
}
