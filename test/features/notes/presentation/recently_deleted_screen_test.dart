import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/local/note_purge_service.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/recently_deleted_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/notes_sidebar.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/note_selection.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:hmm_console/features/notes/states/recently_deleted_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Purge implements NotePurgeService {
  final calls = <int>[];
  final outcomes = <int, PurgeOutcome>{};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<PurgeOutcome> purgeNow(int id) async {
    calls.add(id);
    return outcomes[id] ?? PurgeOutcome.purged;
  }
}

class _Mutate implements MutateNote {
  final restored = <int>[];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<HmmNote> restore(int id) async {
    restored.add(id);
    return _note(id);
  }
}

HmmNote _note(int id) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: 'Note $id',
  authorId: 1,
  createDate: DateTime(2026),
);

List<DeletedNoteItem> _items(int n) => [
  for (var i = 1; i <= n; i++) DeletedNoteItem(note: _note(i), daysLeft: 30),
];

Future<({_Purge purge, _Mutate mutate, ProviderContainer c})> _pump(
  WidgetTester t,
  List<DeletedNoteItem> items, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final purge = _Purge();
  final mutate = _Mutate();
  final c = ProviderContainer(
    overrides: [
      recentlyDeletedProvider.overrideWith((ref) => Stream.value(items)),
      notePurgeServiceProvider.overrideWithValue(purge),
      mutateNoteProvider.overrideWithValue(mutate),
    ],
  );
  addTearDown(c.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const RecentlyDeletedScreen(),
        routes: [
          GoRoute(
            path: 'notes/:id',
            builder: (_, s) => Text('detail ${s.pathParameters['id']}'),
          ),
        ],
      ),
    ],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          platform: platform,
          extensions: const [AppColors.light],
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (purge: purge, mutate: mutate, c: c);
}

Future<void> _swipe(WidgetTester t, String title, Offset by) async {
  await t.drag(find.text(title), by);
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rows show the days left', (t) async {
    await _pump(t, _items(2));
    expect(find.text('Note 1'), findsOneWidget);
    expect(find.text('Deletes in 30 days'), findsNWidgets(2));
  });

  testWidgets('swipe right + Restore restores and says so', (t) async {
    final r = await _pump(t, _items(2));
    await _swipe(t, 'Note 1', const Offset(300, 0));
    await t.tap(find.text('Restore'));
    await t.pumpAndSettle();
    expect(r.mutate.restored, [1]);
    expect(find.text('Note restored'), findsOneWidget);
  });

  testWidgets('Delete Now then Cancel does nothing', (t) async {
    final r = await _pump(t, _items(1));
    await _swipe(t, 'Note 1', const Offset(-300, 0));
    await t.tap(find.text('Delete Now'));
    await t.pumpAndSettle();
    expect(find.text('Delete this note now?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(r.purge.calls, isEmpty);
    expect(find.text('Note deleted for good'), findsNothing);
  });

  testWidgets('Delete Now then confirm purges and says so', (t) async {
    final r = await _pump(t, _items(1));
    await _swipe(t, 'Note 1', const Offset(-300, 0));
    await t.tap(find.text('Delete Now'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete Now'),
      ),
    );
    await t.pumpAndSettle();
    expect(r.purge.calls, [1]);
    expect(find.text('Note deleted for good'), findsOneWidget);
  });

  testWidgets('keptLiveOnServer shows the kept message', (t) async {
    final r = await _pump(t, _items(1));
    r.purge.outcomes[1] = PurgeOutcome.keptLiveOnServer;
    await _swipe(t, 'Note 1', const Offset(-300, 0));
    await t.tap(find.text('Delete Now'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete Now'),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text('This note was restored on another device, so it was kept'),
      findsOneWidget,
    );
  });

  testWidgets('a purged note open in the detail pane clears the selection', (
    t,
  ) async {
    final r = await _pump(t, _items(1));
    r.c.read(selectedNoteIdProvider.notifier).select(1);
    await _swipe(t, 'Note 1', const Offset(-300, 0));
    await t.tap(find.text('Delete Now'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete Now'),
      ),
    );
    await t.pumpAndSettle();
    expect(r.c.read(selectedNoteIdProvider), isNull);
  });

  testWidgets('Empty… with one failure reports a partial result', (t) async {
    final r = await _pump(t, _items(3));
    r.purge.outcomes[2] = PurgeOutcome.failed;
    await t.tap(find.text('Empty…'));
    await t.pumpAndSettle();
    expect(find.text('Delete 3 notes now?'), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete Now'),
      ),
    );
    await t.pumpAndSettle();
    expect(r.purge.calls, [1, 2, 3]);
    expect(find.text('Deleted 2 of 3 notes for good'), findsOneWidget);
  });

  testWidgets('Empty… with all purged reports the count', (t) async {
    await _pump(t, _items(2));
    await t.tap(find.text('Empty…'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete Now'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Deleted 2 notes for good'), findsOneWidget);
  });

  testWidgets('empty list shows the empty state and disables Empty…', (
    t,
  ) async {
    await _pump(t, const []);
    expect(find.text('No recently deleted notes'), findsOneWidget);
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Empty…')).onPressed,
      isNull,
    );
  });

  testWidgets('tapping a row opens the note', (t) async {
    await _pump(t, _items(1));
    await t.tap(find.text('Note 1'));
    await t.pumpAndSettle();
    expect(find.text('detail 1'), findsOneWidget);
  });

  testWidgets('iOS uses a Cupertino confirmation', (t) async {
    await _pump(t, _items(1), platform: TargetPlatform.iOS);
    await t.tap(find.text('Empty…'));
    await t.pumpAndSettle();
    expect(find.text('Delete 1 note now?'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the help button opens the Recently Deleted help', (t) async {
    await _pump(t, _items(1));
    await t.tap(find.byTooltip('Help'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Notes you delete stay here for 30 days, then are removed for good.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'sidebar Recently Deleted row shows the count and pushes the route',
    (t) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var picked = 0;
      final c = ProviderContainer(
        overrides: [
          recentlyDeletedProvider.overrideWith(
            (ref) => Stream.value(_items(2)),
          ),
        ],
      );
      addTearDown(c.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: NotesSidebar(
                data: const NotesListData(all: [], catalogsById: {}),
                onPicked: () => picked++,
              ),
            ),
          ),
          GoRoute(
            path: '/notes/deleted',
            builder: (_, _) => const Text('deleted screen'),
          ),
          GoRoute(
            path: '/notes/:id',
            builder: (_, s) => Text('note ${s.pathParameters['id']}'),
          ),
        ],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(extensions: const [AppColors.light]),
          ),
        ),
      );
      await t.pumpAndSettle();
      final tile = find.widgetWithText(ListTile, 'Recently Deleted');
      expect(
        find.descendant(of: tile, matching: find.text('2')),
        findsOneWidget,
      );
      await t.ensureVisible(tile);
      await t.tap(tile);
      await t.pumpAndSettle();
      expect(picked, 1);
      expect(find.text('deleted screen'), findsOneWidget);
      expect(find.text('note deleted'), findsNothing);
    },
  );
}
