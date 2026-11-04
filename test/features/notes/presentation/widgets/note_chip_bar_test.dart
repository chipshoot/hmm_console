import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/states/filter_usage.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
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
    all: [_n(1, 10), _n(2, 20), _n(3, 20)],
    catalogsById: {
      10: _cat(10, 'Hmm.AutomobileMan.GasLog'),
      20: _cat(20, 'Hmm.General.Notes'),
    },
    catalogDomainById: const {10: 'AutomobileMan', 20: 'General'},
  );
}

class _Usage extends FilterUsageNotifier {
  final recorded = <String>[];
  @override
  Future<Map<String, int>> build() async => {};
  @override
  Future<void> record(String domainKey) async => recorded.add(domainKey);
}

Widget _app(_Usage usage, {bool docked = false, Widget? home}) => ProviderScope(
  overrides: [
    notesListStateProvider.overrideWith(_State.new),
    filterUsageProvider.overrideWith(() => usage),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(extensions: const [AppColors.light]),
    home: home ?? NotesListScreen(sidebarDocked: docked),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The override is reset in a finally: the binding's invariant check runs
  // before addTearDown callbacks, so a teardown would fail the test itself.
  void platformTest(
    String name,
    TargetPlatform platform,
    Future<void> Function(WidgetTester) body,
  ) => testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  Future<void> pump(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  testWidgets('the bar shows All, Pinned, Flagged, the top domain and ＋', (
    tester,
  ) async {
    await pump(tester, _app(_Usage()));
    for (final t in ['All', 'Pinned', 'Flagged', 'General']) {
      expect(find.widgetWithText(ChoiceChip, t), findsOneWidget, reason: t);
    }
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
          .selected,
      isTrue,
    );
    expect(find.byTooltip('More filters'), findsOneWidget);
  });

  testWidgets(
    'tapping a domain chip filters and records usage; tapping it again '
    'returns to All',
    (tester) async {
      final usage = _Usage();
      await pump(tester, _app(usage));

      await tester.tap(find.widgetWithText(ChoiceChip, 'General'));
      await tester.pumpAndSettle();
      expect(usage.recorded, ['General']);
      expect(find.text('Note 1'), findsNothing);
      expect(find.text('Note 2'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'General'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'General'));
      await tester.pumpAndSettle();
      expect(find.text('Note 1'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
            .selected,
        isTrue,
      );
      expect(usage.recorded, ['General'], reason: 'deselecting is not a pick');
    },
  );

  testWidgets('＋ opens the side panel', (tester) async {
    await pump(tester, _app(_Usage()));
    expect(find.byType(Drawer), findsNothing);
    await tester.tap(find.byTooltip('More filters'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
  });

  testWidgets('☰ opens the side panel', (tester) async {
    await pump(tester, _app(_Usage()));
    await tester.tap(find.byTooltip('Filters and lists'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
  });

  testWidgets('docked: no ☰, no ＋ and no drawer', (tester) async {
    await pump(tester, _app(_Usage(), docked: true));
    expect(find.byTooltip('Filters and lists'), findsNothing);
    expect(find.byTooltip('More filters'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Pinned'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.drawer, isNull);
  });

  testWidgets('there is no funnel button and no sub-filter popup', (
    tester,
  ) async {
    await pump(tester, _app(_Usage()));
    expect(find.byIcon(Icons.filter_list), findsNothing);
    expect(find.byTooltip('Filter'), findsNothing);
    expect(find.byType(PopupMenuButton<int>), findsNothing);
  });

  testWidgets('an open built-in smart filter shows as a selected chip', (
    tester,
  ) async {
    await pump(tester, _app(_Usage()));
    await tester.tap(find.byTooltip('Filters and lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'With photos'));
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(ChoiceChip, 'With photos');
    expect(chip, findsOneWidget);
    expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
  });

  platformTest('iOS keeps its back button', TargetPlatform.iOS, (tester) async {
    await pump(
      tester,
      _app(
        _Usage(),
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: GestureDetector(
                key: const Key('open'),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const NotesListScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
  });

  Widget pushHome() => Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        key: const Key('open'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotesListScreen()),
        ),
        child: const Text('open'),
      ),
    ),
  );

  platformTest(
    'Android pushed: one menu icon and the back button',
    TargetPlatform.android,
    (tester) async {
      await pump(tester, _app(_Usage(), home: pushHome()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    },
  );

  platformTest(
    'Android root: one menu icon and no back button',
    TargetPlatform.android,
    (tester) async {
      await pump(tester, _app(_Usage()));
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    },
  );

  testWidgets('the help entry "Quick filters" uses Icons.add', (tester) async {
    late AppLocalizations l;
    late ScreenHelp help;
    await pump(
      tester,
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l = AppLocalizations.of(context);
            help = helpFor(HelpId.notesList, l);
            return const SizedBox();
          },
        ),
      ),
    );
    final entry = help.entries.singleWhere((e) => e.icon == Icons.add);
    expect(entry.title, 'Quick filters');
    expect(entry.body, l.helpNotesListChipsBody);
  });
}
