import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_shell_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/note_selection.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 1, uuid: 'u1', subject: 'Note one', authorId: 1,
              catalogId: 1, createDate: DateTime(2026, 1, 1)),
        ],
        catalogsById: const {},
      );
}

class _FakeMutate implements MutateNote {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<void> delete(int id) async {}
}

void main() {
  testWidgets('wide-mode delete clears the detail pane (no stale error)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final note = HmmNote(
        id: 1, uuid: 'u1', subject: 'Note one', authorId: 1, catalogId: 1,
        content: 'body', createDate: DateTime(2026, 1, 1));
    final catalog = NoteCatalog(
        id: 1, name: 'General', schema: '{}', formatType: 3, isDefault: false);

    final container = ProviderContainer(overrides: [
      notesListStateProvider.overrideWith(_StubListState.new),
      mutateNoteProvider.overrideWithValue(_FakeMutate()),
      noteDetailProvider(1).overrideWith((ref) async => NoteDetailData(note, catalog)),
    ]);
    addTearDown(container.dispose);
    // Pre-select note 1 so the wide detail pane is showing it.
    container.read(selectedNoteIdProvider.notifier).select(1);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NotesShellScreen()),
    ));
    await tester.pumpAndSettle();

    // Detail pane shows the note.
    expect(find.text('Note one'), findsWidgets);

    // Open the detail ⋯ menu and delete.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Pane reverts to the placeholder; no StateError text.
    expect(find.text('Select a note'), findsOneWidget);
    expect(find.textContaining('not found'), findsNothing);
  });
}
