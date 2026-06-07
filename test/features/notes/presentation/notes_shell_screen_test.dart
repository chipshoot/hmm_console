import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_shell_screen.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 1, uuid: 'u1', subject: 'Note one', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 1)),
        ],
        catalogsById: const {},
      );
}

void main() {
  testWidgets('wide screen shows two panes; narrow shows one', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: const MaterialApp(home: NotesShellScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.text('Select a note'), findsOneWidget);
  });

  testWidgets('narrow screen shows a single pane (no detail placeholder)',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: const MaterialApp(home: NotesShellScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NotesListScreen), findsOneWidget);
    expect(find.text('Select a note'), findsNothing);
  });
}
