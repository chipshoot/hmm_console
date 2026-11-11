import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/notes_sidebar.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/note_selection.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_shell_screen.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Note one',
        authorId: 1,
        catalogId: 10,
        createDate: DateTime(2026, 1, 1),
      ),
    ],
    catalogsById: const {},
  );
}

class _DomainListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Note one',
        authorId: 1,
        catalogId: 10,
        createDate: DateTime(2026, 1, 1),
      ),
    ],
    catalogsById: const {},
  );
}

class _ManyNotesState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
    all: [
      for (var i = 1; i <= 60; i++)
        HmmNote(
          id: i,
          uuid: 'u$i',
          subject: 'Note $i',
          authorId: 1,
          catalogId: 10,
          createDate: DateTime(2026, 1, 1).add(Duration(days: i)),
        ),
    ],
    catalogsById: const {},
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('wide screen shows two panes; narrow shows one', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: ThemeData(extensions: const [AppColors.light]),
          home: const NotesShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.text('Select a note'), findsOneWidget);
  });

  testWidgets('narrow screen shows a single pane (no detail placeholder)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: ThemeData(extensions: const [AppColors.light]),
          home: const NotesShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.text('Select a note'), findsNothing);
  });

  group('layouts', () {
    void size(WidgetTester tester, double w) {
      tester.view.physicalSize = Size(w, 900);
      tester.view.devicePixelRatio = 1.0;
    }

    Future<ProviderContainer> pump(
      WidgetTester tester,
      double w, {
      bool pushed = false,
      NotesListState Function() listState = _DomainListState.new,
    }) async {
      size(tester, w);
      addTearDown(tester.view.reset);
      final note = HmmNote(
        id: 1,
        uuid: 'u1',
        subject: 'Note one',
        authorId: 1,
        catalogId: 10,
        content: 'body',
        createDate: DateTime(2026, 1, 1),
      );
      const catalog = NoteCatalog(
        id: 10,
        name: 'Hmm.AutomobileMan.GasLog',
        schema: '{}',
        formatType: 3,
        isDefault: false,
      );
      final container = ProviderContainer(
        overrides: [
          notesListStateProvider.overrideWith(listState),
          noteDetailProvider(
            1,
          ).overrideWith((ref) async => NoteDetailData(note, catalog)),
        ],
      );
      addTearDown(container.dispose);
      const shell = NotesShellScreen();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(extensions: const [AppColors.light]),
            home: pushed
                ? Builder(
                    builder: (context) => Scaffold(
                      body: ElevatedButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => shell)),
                        child: const Text('open'),
                      ),
                    ),
                  )
                : shell,
          ),
        ),
      );
      if (pushed) {
        await tester.tap(find.text('open'));
      }
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('at 1100 pt the sidebar is docked and the list has no menu', (
      tester,
    ) async {
      await pump(tester, 1100);
      expect(find.byType(NotesSidebar), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('notes-sidebar-pane'))).width,
        240,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('notes-list-pane'))).width,
        360,
      );
    });

    testWidgets('at 1100 pt the side-panel button hides and shows the panel', (
      tester,
    ) async {
      final container = await pump(tester, 1100);
      final listPane = find.byKey(const ValueKey('notes-list-pane'));
      final before = tester.state(find.byType(NotesListScreen));

      await tester.tap(find.byTooltip('Hide side panel'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesSidebar), findsNothing);
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(tester.getSize(listPane).width, 360);
      expect(tester.state(find.byType(NotesListScreen)), same(before));
      expect(
        container.read(settingsProvider).value!.notesSidebarHidden,
        isTrue,
      );

      await tester.tap(find.byTooltip('Show side panel'));
      await tester.pumpAndSettle();
      expect(find.byType(NotesSidebar), findsOneWidget);
      expect(
        container.read(settingsProvider).value!.notesSidebarHidden,
        isFalse,
      );
    });

    testWidgets('a saved hidden choice starts with the panel hidden', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'app_settings': jsonEncode({'notesSidebarHidden': true}),
      });
      await pump(tester, 1100);
      expect(find.byType(NotesSidebar), findsNothing);
      expect(find.byTooltip('Show side panel'), findsOneWidget);
    });

    testWidgets('at 800 pt there is no side-panel button', (tester) async {
      await pump(tester, 800);
      expect(find.byTooltip('Hide side panel'), findsNothing);
      expect(find.byTooltip('Show side panel'), findsNothing);
    });

    testWidgets('at 800 pt it is list and detail; menu opens the drawer', (
      tester,
    ) async {
      await pump(tester, 800);
      expect(find.byType(NotesSidebar), findsNothing);
      expect(find.text('Select a note'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(NotesSidebar), findsOneWidget);
    });

    testWidgets('at 400 pt it is the phone layout', (tester) async {
      await pump(tester, 400);
      expect(find.byType(NotesSidebar), findsNothing);
      expect(find.text('Select a note'), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('picking in the docked sidebar filters and keeps the route', (
      tester,
    ) async {
      final container = await pump(tester, 1100, pushed: true);
      final canPop = Navigator.of(
        tester.element(find.byType(NotesShellScreen)),
      ).canPop();
      expect(canPop, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byType(NotesSidebar),
          matching: find.text('Pinned'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(notesListStateProvider).value!.query.source,
        const PinnedSource(),
      );
      expect(find.byType(NotesShellScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(NotesShellScreen))).canPop(),
        canPop,
      );
    });

    testWidgets('crossing 1000 pt keeps the list pane State and scroll', (
      tester,
    ) async {
      await pump(tester, 800, listState: _ManyNotesState.new);
      final before = tester.state(find.byType(NotesListScreen));
      final scrollable = find.descendant(
        of: find.byType(NotesListScreen),
        matching: find.byType(Scrollable),
      );
      ScrollPosition position() =>
          tester.state<ScrollableState>(scrollable.first).position;
      position().jumpTo(position().maxScrollExtent);
      await tester.pumpAndSettle();
      final offset = position().pixels;
      expect(offset, greaterThan(0));

      size(tester, 1100);
      await tester.pumpAndSettle();
      expect(find.byType(NotesSidebar), findsOneWidget);
      size(tester, 800);
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(NotesListScreen)), same(before));
      expect(position().pixels, offset);
    });

    testWidgets('resizing 1100 to 800 to 1100 keeps tokens and selection', (
      tester,
    ) async {
      final container = await pump(tester, 1100);
      container.read(notesListStateProvider.notifier).setTokens(const [
        HasPhotoToken(),
      ]);
      container.read(selectedNoteIdProvider.notifier).select(1);
      await tester.pumpAndSettle();
      final chip = find.byType(InputChip);
      expect(chip, findsOneWidget);
      expect(find.byType(NoteDetailScreen), findsOneWidget);

      for (final w in [800.0, 1100.0]) {
        size(tester, w);
        await tester.pumpAndSettle();
        expect(chip, findsOneWidget);
        expect(find.byType(NoteDetailScreen), findsOneWidget);
        expect(container.read(selectedNoteIdProvider), 1);
        expect(
          find.byType(NotesSidebar),
          w >= 1000 ? findsOneWidget : findsNothing,
        );
      }
    });
  });
}
