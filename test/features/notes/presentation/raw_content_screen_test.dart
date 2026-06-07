import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/raw_content_screen.dart';

void main() {
  test('prettyContent indents JSON and passes non-JSON through', () {
    expect(prettyContent('{"a":1}'), '{\n  "a": 1\n}');
    expect(prettyContent('plain'), 'plain');
    expect(prettyContent(null), '(no content)');
  });

  testWidgets('shows formatted content + metadata', (tester) async {
    final note = HmmNote(
        id: 3, uuid: 'abc', subject: 's', authorId: 1, catalogId: 1,
        content: '{"x":1}', createDate: DateTime(2026, 1, 1));
    final catalog = NoteCatalog(
        id: 1, name: 'General', schema: '{}', formatType: 3, isDefault: false);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteDetailProvider(3)
            .overrideWith((ref) async => NoteDetailData(note, catalog)),
      ],
      child: const MaterialApp(home: RawContentScreen(noteId: 3)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('"x": 1'), findsOneWidget);
    expect(find.textContaining('uuid: abc'), findsOneWidget);
  });
}
