import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_list_row.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';

HmmNote _note({String? content}) => HmmNote(
      id: 1,
      uuid: 'u1',
      subject: 'Grocery list',
      authorId: 1,
      createDate: DateTime(2026, 6, 1),
      content: content,
    );

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders subject as title and content preview as primary',
      (t) async {
    await t.pumpWidget(_host(NoteListTile(
      note: _note(content: 'Milk, eggs, coffee'),
    )));
    expect(find.byType(AppListRow), findsOneWidget);
    expect(find.text('Grocery list'), findsOneWidget);
    expect(find.text('Milk, eggs, coffee'), findsOneWidget);
  });

  testWidgets('JSON content shows no primary preview line', (t) async {
    await t.pumpWidget(_host(NoteListTile(
      note: _note(content: '{"make":"Toyota"}'),
    )));
    expect(find.text('{"make":"Toyota"}'), findsNothing);
    expect(find.text('Grocery list'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(NoteListTile(
      note: _note(content: 'hi'),
      onTap: () => tapped = true,
    )));
    await t.tap(find.byType(AppListRow));
    expect(tapped, isTrue);
  });
}
