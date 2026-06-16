import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/markdown_view.dart';

void main() {
  testWidgets('renders the note body and the ⋯ menu actions', (tester) async {
    final note = HmmNote(
        id: 5, uuid: 'u5', subject: 'My note', authorId: 1, catalogId: 1,
        content: 'Hello body', createDate: DateTime(2026, 1, 1));
    final catalog = NoteCatalog(
        id: 1, name: 'General', schema: '{}', formatType: 3, isDefault: false);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteDetailProvider(5).overrideWith(
            (ref) async => NoteDetailData(note, catalog)),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NoteDetailScreen(noteId: 5),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('My note'), findsOneWidget);
    expect(find.byType(MarkdownView), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget); // General is editable
    expect(find.text('View raw content'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
