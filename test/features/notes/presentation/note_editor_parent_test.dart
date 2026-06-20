// Regression tests for the editor's subsystem-attachment handling.
// Bug: editing a note and changing its subsystem (e.g. None -> Automobile)
// appeared to "lose" the change — the editor never loaded the note's current
// parent (dropdown always showed "None"), and save only ever attached (never
// detached/changed). These cover load + save round-trip.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

/// Minimal repo that only answers getNoteById (used by _loadExisting).
class _FakeRepo implements IHmmNoteRepository {
  _FakeRepo(this.note);
  final HmmNote note;
  @override
  Future<HmmNote?> getNoteById(int id) async => note;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Records the parent the editor asks to persist.
class _FakeMutate implements MutateNote {
  bool setParentCalled = false;
  int? lastParentId;
  @override
  Future<HmmNote> updateGeneral(int id,
      {String? subject, String? markdownBody, DateTime? noteDate, NoteLocation? location}) async {
    return HmmNote(
        id: id, uuid: 'u', subject: subject ?? '', authorId: 1,
        createDate: DateTime(2026, 1, 1));
  }

  @override
  Future<HmmNote> setParent(int id, int? parentNoteId) async {
    setParentCalled = true;
    lastParentId = parentNoteId;
    return HmmNote(
        id: id, uuid: 'u', subject: 's', authorId: 1,
        createDate: DateTime(2026, 1, 1), parentNoteId: parentNoteId);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

HmmNote _note({int? parent}) => HmmNote(
      id: 1, uuid: 'n1', subject: 'My note', authorId: 1,
      createDate: DateTime(2026, 1, 1), content: 'body', parentNoteId: parent);

final _automobileAnchor = HmmNote(
    id: 7, uuid: 'auto', subject: 'Automobile', authorId: 1,
    createDate: DateTime(2026, 1, 1));

void main() {
  testWidgets('editor reflects the note\'s existing subsystem on open',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hmmNoteRepositoryProvider
            .overrideWith((ref) => _FakeRepo(_note(parent: 7))),
        subsystemAnchorsProvider.overrideWith((ref) async => [_automobileAnchor]),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NoteEditorScreen(noteId: 1),
      ),
    ));
    await tester.pumpAndSettle();
    // The attached subsystem must show in the dropdown — not "None".
    expect(find.text('Automobile'), findsOneWidget);
  });

  testWidgets('changing None -> Automobile persists via setParent',
      (tester) async {
    final fake = _FakeMutate();
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => const Scaffold(body: Text('Home')),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (ctx, state) => const NoteEditorScreen(noteId: 1),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hmmNoteRepositoryProvider
            .overrideWith((ref) => _FakeRepo(_note(parent: null))),
        subsystemAnchorsProvider.overrideWith((ref) async => [_automobileAnchor]),
        mutateNoteProvider.overrideWithValue(fake),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [AppColors.light]),
      ),
    ));
    await tester.pumpAndSettle();

    // Open the dropdown (currently shows "None") and pick Automobile.
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automobile').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(fake.setParentCalled, isTrue);
    expect(fake.lastParentId, 7);
  });
}
