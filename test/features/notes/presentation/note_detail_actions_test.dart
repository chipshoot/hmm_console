import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _RecordingMutate implements MutateNote {
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  HmmNote _n(int id) => HmmNote(
    id: id,
    uuid: 'u$id',
    subject: 'My note',
    authorId: 1,
    createDate: DateTime(2026),
  );

  @override
  Future<void> delete(int id) async => calls.add('delete $id');
  @override
  Future<HmmNote> restore(int id) async {
    calls.add('restore $id');
    return _n(id);
  }

  @override
  Future<NoteState> setPinned(int id, bool pinned) async {
    calls.add('pin $id $pinned');
    return NoteState(
      noteUuid: 'u$id',
      isPinned: pinned,
      lastModifiedDate: DateTime.utc(2026),
    );
  }

  @override
  Future<NoteState> setFlagColor(int id, int? flagColor) async {
    calls.add('flag $id $flagColor');
    return NoteState(
      noteUuid: 'u$id',
      flagColor: flagColor,
      lastModifiedDate: DateTime.utc(2026),
    );
  }
}

NoteCatalog _catalog(String name) => NoteCatalog(
  id: 1,
  name: name,
  schema: '{}',
  formatType: 3,
  isDefault: false,
);

Future<_RecordingMutate> _pump(
  WidgetTester tester, {
  String catalog = 'General',
  bool pinned = false,
  int? flag,
  bool deleted = false,
  TargetPlatform? platform,
}) async {
  final mutate = _RecordingMutate();
  final note = HmmNote(
    id: 5,
    uuid: 'u5',
    subject: 'My note',
    authorId: 1,
    catalogId: 1,
    content: 'Hello body',
    createDate: DateTime(2026, 1, 1),
    deletedAt: deleted ? DateTime.utc(2026, 2, 1) : null,
  );
  final state = NoteState(
    noteUuid: 'u5',
    isPinned: pinned,
    flagColor: flag,
    lastModifiedDate: DateTime.utc(2026),
  );
  // A fresh key per pump: a second pump in one test gets a new scope with
  // its own overrides instead of updating the old one.
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        mutateNoteProvider.overrideWithValue(mutate),
        noteDetailProvider(5).overrideWith(
          (ref) async => NoteDetailData(note, _catalog(catalog), state),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          platform: platform,
          extensions: const [AppColors.light],
        ),
        home: const NoteDetailScreen(noteId: 5),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return mutate;
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Show menu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the menu offers Pin, Flag… and Delete for an ordinary note', (
    tester,
  ) async {
    await _pump(tester);
    await _openMenu(tester);

    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Flag…'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.textContaining('Manage in'), findsNothing);
  });

  testWidgets('Pin calls setPinned(true); a pinned note offers Unpin', (
    tester,
  ) async {
    final mutate = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(mutate.calls, ['pin 5 true']);

    final pinnedMutate = await _pump(tester, pinned: true);
    expect(
      find.byIcon(Icons.push_pin),
      findsOneWidget,
      reason: 'pin shown by the title',
    );
    await _openMenu(tester);
    await tester.tap(find.text('Unpin'));
    await tester.pumpAndSettle();
    expect(pinnedMutate.calls, ['pin 5 false']);
  });

  testWidgets('Flag… stores the chosen colour; Clear flag stores null', (
    tester,
  ) async {
    final mutate = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Flag…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue'));
    await tester.pumpAndSettle();
    expect(mutate.calls, ['flag 5 4']);

    final flagged = await _pump(tester, flag: 1);
    await _openMenu(tester);
    await tester.tap(find.text('Flag…'));
    await tester.pumpAndSettle();
    // The sheet scrolls on a short viewport; Clear flag is the last row.
    await tester.ensureVisible(find.text('Clear flag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear flag'));
    await tester.pumpAndSettle();
    expect(flagged.calls, ['flag 5 null']);
  });

  testWidgets('Delete shows Note deleted with Undo; Undo restores', (
    tester,
  ) async {
    final mutate = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(mutate.calls, ['delete 5']);
    expect(find.text('Note deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(mutate.calls, ['delete 5', 'restore 5']);
    expect(find.text('Note restored'), findsOneWidget);
  });

  testWidgets('an entity note shows Manage in Automobile instead of Delete', (
    tester,
  ) async {
    final mutate = await _pump(tester, catalog: 'Hmm.AutomobileMan.GasLog');
    await _openMenu(tester);

    expect(find.text('Delete'), findsNothing);
    expect(find.text('Manage in Automobile'), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget, reason: 'pin works on every note');
    await tester.tap(find.text('Manage in Automobile'));
    await tester.pumpAndSettle();
    expect(mutate.calls, isEmpty);
  });

  testWidgets('the help button explains the menu', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Read a note and use the ⋯ menu to pin, flag, edit or delete it.',
      ),
      findsOneWidget,
    );
  });

  for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('detail of a deleted note shows the banner and Restore ($p)', (
      tester,
    ) async {
      await _pump(tester, deleted: true, platform: p);
      expect(
        find.text('This note was moved to Recently Deleted'),
        findsOneWidget,
      );
      expect(find.text('Restore'), findsOneWidget);
    });
  }

  testWidgets('an ordinary note shows no banner', (tester) async {
    await _pump(tester);
    expect(find.text('This note was moved to Recently Deleted'), findsNothing);
  });

  testWidgets('Restore calls restore(id) and confirms with a snackbar', (
    tester,
  ) async {
    final mutate = await _pump(tester, deleted: true);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(mutate.calls, ['restore 5']);
    expect(find.text('Note restored'), findsOneWidget);
  });

  testWidgets('detail menu of a deleted note offers Restore, not Delete', (
    tester,
  ) async {
    await _pump(tester, deleted: true);
    await _openMenu(tester);
    expect(find.text('Restore'), findsNWidgets(2)); // banner + menu
    expect(find.text('View raw content'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Pin'), findsNothing);
    expect(find.text('Flag…'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });
}
