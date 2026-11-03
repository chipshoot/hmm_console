import 'dart:convert';

import 'package:flutter/cupertino.dart'
    show CupertinoActionSheet, CupertinoAlertDialog, CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_row.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/saved_search.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/features/notes/states/saved_searches_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

HmmNote _n(int id, String subject, int cat, {bool photo = false}) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
  authorId: 1,
  catalogId: cat,
  createDate: DateTime(2026, 1, 10 - id),
  attachments: photo
      ? NoteAttachments(
          primaryImage: const PhAssetRef(
            id: 'a1',
            contentType: 'image/jpeg',
            byteSize: 1,
          ),
        )
      : null,
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
      _n(1, 'Oil change', 10, photo: true),
      _n(2, 'Oil filter', 10),
      _n(3, 'Grocery list', 20, photo: true),
      _n(4, 'Vacation', 20),
    ],
    catalogsById: {
      10: _cat(10, 'Hmm.AutomobileMan.GasLog'),
      20: _cat(20, 'Hmm.General.Notes'),
    },
    catalogDomainById: const {10: 'AutomobileMan', 20: 'General'},
  );
}

class _Saved extends SavedSearchesNotifier {
  _Saved(this.initial);
  final List<SavedSearch> initial;
  @override
  List<SavedSearch> build() => initial;
}

class _FailingSaved extends SavedSearchesNotifier {
  @override
  Future<SavedSearch> add(String name, NoteQuery query) =>
      throw StateError('disk full');
}

Future<ProviderContainer> _openWith(
  WidgetTester tester,
  List<Override> overrides,
) async {
  final c = ProviderContainer(
    overrides: [notesListStateProvider.overrideWith(_State.new), ...overrides],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NotesListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

SavedSearch _s(String id, String name, int order, NoteQuery q) =>
    SavedSearch(id: id, name: name, order: order, query: q);

const _oilPhotos = NoteQuery(text: 'oil', tokens: [HasPhotoToken()]);

Future<ProviderContainer> _open(
  WidgetTester tester, {
  TargetPlatform? platform,
}) async {
  final c = ProviderContainer(
    overrides: [notesListStateProvider.overrideWith(_State.new)],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          platform: platform,
          extensions: const [AppColors.light],
        ),
        home: const NotesListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> _openDrawer(WidgetTester tester) async {
  // The side panel lists more sections now; keep its rows on screen.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.tap(find.byTooltip('Filters and lists'));
  await tester.pumpAndSettle();
}

Future<void> _saveAs(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Save search'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, name);
  await tester.pump();
  await tester.tap(find.text('Save').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('save button appears only with something to save', (
    tester,
  ) async {
    final c = await _open(tester);
    expect(find.byTooltip('Save search'), findsNothing);

    c.read(notesListStateProvider.notifier).setText('oil');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save search'), findsOneWidget);

    final n = c.read(notesListStateProvider.notifier);
    n.setQuery(const NoteQuery());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save search'), findsNothing);

    n.setTokens(const [HasPhotoToken()]);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save search'), findsOneWidget);

    n.setQuery(const NoteQuery(source: DomainSource(key: 'AutomobileMan')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save search'), findsOneWidget);
  });

  testWidgets(
    'saving stores the effective query and it opens from the drawer',
    (tester) async {
      final c = await _open(tester);
      final n = c.read(notesListStateProvider.notifier);
      n.setQuery(_oilPhotos);
      await tester.pumpAndSettle();
      expect(find.byType(NoteRow), findsOneWidget);

      await tester.tap(find.byTooltip('Save search'));
      await tester.pumpAndSettle();
      // Default name is the trimmed text.
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'oil',
      );
      await tester.enterText(find.byType(TextField).last, 'Oil photos');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Saved "Oil photos"'), findsOneWidget);

      final saved = c.read(savedSearchesProvider);
      expect(saved.single.name, 'Oil photos');
      expect(saved.single.query.text, 'oil');
      expect(saved.single.query.tokens, [const HasPhotoToken()]);

      n.setQuery(const NoteQuery());
      await tester.pumpAndSettle();
      expect(find.byType(NoteRow), findsNWidgets(4));

      await _openDrawer(tester);
      await tester.tap(find.text('Oil photos'));
      await tester.pumpAndSettle();

      expect(find.byType(NoteRow), findsOneWidget);
      expect(find.text('Oil change'), findsWidgets);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        c.read(notesListStateProvider).value!.query.source,
        isA<SmartSource>(),
      );
    },
  );

  testWidgets('the save dialog disables Save while the name is blank', (
    tester,
  ) async {
    final c = await _open(tester);
    c.read(notesListStateProvider.notifier).setText('oil');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.pump();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(find.text('Name'), findsOneWidget, reason: 'dialog stays open');
    expect(c.read(savedSearchesProvider), isEmpty);
  });

  testWidgets('saving while a saved search is open stores no SmartSource', (
    tester,
  ) async {
    final base = _s('s1', 'Oil photos', 0, _oilPhotos);
    final c = ProviderContainer(
      overrides: [
        notesListStateProvider.overrideWith(_State.new),
        savedSearchesProvider.overrideWith(() => _Saved([base])),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColors.light]),
          home: const NotesListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    c
        .read(notesListStateProvider.notifier)
        .setQuery(const NoteQuery(source: SmartSource(savedId: 's1')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save search'), findsOneWidget);

    await _saveAs(tester, 'Copy');
    final copy = c
        .read(savedSearchesProvider)
        .firstWhere((s) => s.name == 'Copy');
    expect(copy.query.source, isNot(isA<SmartSource>()));
    expect(copy.query.text, 'oil');
    expect(copy.query.tokens, [const HasPhotoToken()]);
    expect(copy.query.scope, NoteScope.currentSource);
  });

  testWidgets(
    'rename, move down and delete with undo from the long-press menu',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SyncableSettingsRepository.notesSavedSearchesKey: jsonEncode([
          _s('s1', 'Oil photos', 0, _oilPhotos).toJson(),
          _s('s2', 'Vacation', 1, const NoteQuery(text: 'vac')).toJson(),
        ]),
      });
      final c = ProviderContainer(
        overrides: [notesListStateProvider.overrideWith(_State.new)],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const NotesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openDrawer(tester);
      expect(find.text('Saved searches'), findsOneWidget);

      // Move up is hidden at the top.
      await tester.longPress(find.text('Oil photos'));
      await tester.pumpAndSettle();
      expect(find.text('Move up'), findsNothing);
      expect(find.text('Move down'), findsOneWidget);

      // Rename.
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Photos');
      await tester.pump();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(c.read(savedSearchesProvider).map((s) => s.name), [
        'Photos',
        'Vacation',
      ]);

      // Move down.
      await tester.longPress(find.text('Photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();
      expect(c.read(savedSearchesProvider).map((s) => s.name), [
        'Vacation',
        'Photos',
      ]);

      // Delete, then undo: back in the same position.
      await tester.longPress(find.text('Photos'));
      await tester.pumpAndSettle();
      expect(find.text('Move down'), findsNothing);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Deleted "Photos"'), findsOneWidget);
      expect(c.read(savedSearchesProvider).map((s) => s.name), ['Vacation']);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Restored "Photos"'), findsOneWidget);
      expect(c.read(savedSearchesProvider).map((s) => s.name), [
        'Vacation',
        'Photos',
      ]);
    },
  );

  testWidgets(
    'deleting the open saved search shows the deleted message with Show all notes',
    (tester) async {
      final c = ProviderContainer(
        overrides: [
          notesListStateProvider.overrideWith(_State.new),
          savedSearchesProvider.overrideWith(
            () => _Saved([_s('s1', 'Oil photos', 0, _oilPhotos)]),
          ),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const NotesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openDrawer(tester);
      await tester.tap(find.text('Oil photos'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteRow), findsOneWidget);

      await _openDrawer(tester);
      // The name is also in the filter bar now; press the drawer's tile.
      await tester.longPress(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Oil photos'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('This saved search was deleted'), findsOneWidget);
      await tester.tap(find.text('Show all notes'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteRow), findsNWidgets(4));
    },
  );

  testWidgets('the save dialog is Cupertino on iOS', (tester) async {
    final c = await _open(tester, platform: TargetPlatform.iOS);
    c.read(notesListStateProvider.notifier).setText('oil');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save search'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the save dialog is Material on Android', (tester) async {
    final c = await _open(tester, platform: TargetPlatform.android);
    c.read(notesListStateProvider.notifier).setText('oil');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save search'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('long-press opens a Cupertino action sheet on iOS', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [
        notesListStateProvider.overrideWith(_State.new),
        savedSearchesProvider.overrideWith(
          () => _Saved([_s('s1', 'Oil photos', 0, _oilPhotos)]),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            extensions: const [AppColors.light],
          ),
          home: const NotesListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openDrawer(tester);
    await tester.longPress(find.text('Oil photos'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
  });

  testWidgets('help lists the Search tokens and Saved searches entries', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    for (final title in ['Search tokens', 'Saved searches']) {
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: scrollable.first,
      );
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byIcon(Icons.bookmark_add_outlined), findsWidgets);
  });

  testWidgets('opening a domain saved search resets a sticky All-notes scope', (
    tester,
  ) async {
    final saved = _s(
      's1',
      'Auto photos',
      0,
      const NoteQuery(
        source: DomainSource(key: 'AutomobileMan'),
        tokens: [HasPhotoToken()],
      ),
    );
    final c = await _openWith(tester, [
      savedSearchesProvider.overrideWith(() => _Saved([saved])),
    ]);
    c.read(notesListStateProvider.notifier).setScope(NoteScope.all);
    await tester.pumpAndSettle();

    await _openDrawer(tester);
    await tester.tap(find.text('Auto photos'));
    await tester.pumpAndSettle();

    // Only the automobile photo note, not the General one.
    expect(find.byType(NoteRow), findsOneWidget);
    expect(find.text('Oil change'), findsWidgets);
    expect(find.text('Grocery list'), findsNothing);
    expect(find.byType(SegmentedButton<NoteScope>), findsOneWidget);
  });

  testWidgets('an open saved search is named in the filter bar', (
    tester,
  ) async {
    await _openWith(tester, [
      savedSearchesProvider.overrideWith(
        () => _Saved([_s('s1', 'Oil photos', 0, _oilPhotos)]),
      ),
    ]);
    await _openDrawer(tester);
    await tester.tap(find.text('Oil photos'));
    await tester.pumpAndSettle();
    expect(find.text('Oil photos'), findsOneWidget);
  });

  testWidgets('a deleted saved search offers no Save button', (tester) async {
    final c = await _openWith(tester, [
      savedSearchesProvider.overrideWith(() => _Saved(const [])),
    ]);
    c
        .read(notesListStateProvider.notifier)
        .setQuery(const NoteQuery(source: SmartSource(savedId: 'gone')));
    await tester.pumpAndSettle();
    expect(find.text('This saved search was deleted'), findsOneWidget);
    expect(find.byTooltip('Save search'), findsNothing);
  });

  testWidgets('a failing save shows the failure snackbar', (tester) async {
    final c = await _openWith(tester, [
      savedSearchesProvider.overrideWith(_FailingSaved.new),
    ]);
    c.read(notesListStateProvider.notifier).setText('oil');
    await tester.pumpAndSettle();
    await _saveAs(tester, 'Oil');
    expect(find.text("Couldn't save the search"), findsOneWidget);
    expect(find.text('Saved "Oil"'), findsNothing);
  });
}
