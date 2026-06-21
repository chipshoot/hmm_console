import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_file_card.dart';

void main() {
  testWidgets('shows filename + size, fires onOpen and onRemove', (t) async {
    var opened = false, removed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteFileCard(
          name: 'report.pdf',
          byteSize: 240 * 1024,
          onOpen: () => opened = true,
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.textContaining('KB'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
    await t.tap(find.text('report.pdf'));
    expect(opened, isTrue);
  });

  testWidgets('read-only hides the remove button', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteFileCard(name: 'a.pdf', byteSize: 10, readOnly: true),
      ),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
