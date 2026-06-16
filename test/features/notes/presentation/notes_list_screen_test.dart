import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubListState extends NotesListState {
  @override
  Future<NotesListData> build() async => NotesListData(
        all: [
          HmmNote(
              id: 1, uuid: 'u1', subject: 'Grocery list', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 2)),
          HmmNote(
              id: 2, uuid: 'u2', subject: 'Vacation', authorId: 1,
              catalogId: 10, createDate: DateTime(2026, 1, 1)),
        ],
        catalogsById: const {},
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows note tiles and filters by search query', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notesListStateProvider.overrideWith(_StubListState.new),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NotesListScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NoteListTile), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'groc');
    await tester.pumpAndSettle();
    expect(find.byType(NoteListTile), findsOneWidget);
    expect(find.text('Grocery list'), findsOneWidget);
  });

  testWidgets('sort button opens the sort sheet', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [notesListStateProvider.overrideWith(_StubListState.new)],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NotesListScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    expect(find.text('Subject — A → Z'), findsOneWidget);
  });
}
