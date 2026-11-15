import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// The note was deleted on another device (and that delete synced here)
/// while this device had it open in the editor.
class _FakeNotes implements IHmmNoteRepository {
  bool deleted = false;
  @override
  Future<HmmNote?> getNoteById(int id) async => HmmNote(
    id: id,
    uuid: 'u$id',
    subject: 'My note',
    authorId: 1,
    createDate: DateTime(2026, 1, 1),
    content: 'body',
    deletedAt: deleted ? DateTime(2026, 1, 2) : null,
  );
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTags implements ITagRepository {
  @override
  Stream<Map<int, List<NoteTagLabel>>> watchNoteTags() =>
      Stream.value(const {});
  @override
  Stream<Map<int, String>> watchLiveTagNames() => Stream.value(const {});
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeMutate implements MutateNote {
  _FakeMutate(this.notes);
  final _FakeNotes notes;
  final calls = <String>[];
  @override
  Future<HmmNote> updateGeneral(
    int id, {
    String? subject,
    String? markdownBody,
    DateTime? noteDate,
    NoteLocation? location,
  }) async {
    calls.add('update:$markdownBody');
    return (await notes.getNoteById(id))!;
  }

  @override
  Future<HmmNote> restore(int id) async {
    calls.add('restore');
    notes.deleted = false;
    return (await notes.getNoteById(id))!;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _FakeNotes notes;
  late _FakeMutate mutate;

  setUp(() {
    notes = _FakeNotes();
    mutate = _FakeMutate(notes);
  });

  Future<void> open(WidgetTester t) async {
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (_, _) => const NoteEditorScreen(noteId: 3),
            ),
          ],
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          hmmNoteRepositoryProvider.overrideWithValue(notes),
          tagRepositoryProvider.overrideWithValue(_FakeTags()),
          mutateNoteProvider.overrideWithValue(mutate),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColors.light]),
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  final bodyField = find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == 'body',
  );

  Future<void> editBodyAndSave(WidgetTester t) async {
    await t.enterText(bodyField, 'edited');
    notes.deleted = true; // the other device's delete arrives by sync
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
  }

  testWidgets('edited: Restore and save restores, then saves the changes', (
    t,
  ) async {
    await open(t);
    await editBodyAndSave(t);

    expect(find.text('Deleted on another device'), findsOneWidget);
    await t.tap(find.text('Restore and save'));
    await t.pumpAndSettle();

    expect(mutate.calls, ['restore', 'update:edited']);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('edited: Discard changes saves nothing and leaves it deleted', (
    t,
  ) async {
    await open(t);
    await editBodyAndSave(t);

    await t.tap(find.text('Discard changes'));
    await t.pumpAndSettle();

    expect(mutate.calls, isEmpty);
    expect(notes.deleted, isTrue);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('unchanged: Save just closes, with no prompt and no write', (
    t,
  ) async {
    await open(t);
    notes.deleted = true;
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(find.text('Deleted on another device'), findsNothing);
    expect(mutate.calls, isEmpty);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a live note saves as before, with no prompt', (t) async {
    await open(t);
    await t.enterText(bodyField, 'edited');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(find.text('Deleted on another device'), findsNothing);
    expect(mutate.calls, ['update:edited']);
  });
}
