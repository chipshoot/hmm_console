import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';

void main() {
  testWidgets('lists attached notes; empty state otherwise', (tester) async {
    final note = HmmNote(
        id: 1, uuid: 'u1', subject: 'Oil change receipt', authorId: 1,
        catalogId: 1, createDate: DateTime(2026, 1, 1));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(7).overrideWith((ref) async => [note]),
      ],
      child: const MaterialApp(
          home: Scaffold(body: AttachedNotesSection(parentId: 7))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Oil change receipt'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
  });

  testWidgets('shows empty state when no attached notes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(7).overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(
          home: Scaffold(body: AttachedNotesSection(parentId: 7))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);
  });
}
