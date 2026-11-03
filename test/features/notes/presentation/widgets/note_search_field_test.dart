import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_search_field.dart';

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.sent,
    this.initial = '',
    this.chips = const [],
    this.removed,
    this.submitted,
    this.fieldKey,
  });
  final List<String> sent;
  final String initial;
  final List<Widget> chips;
  final List<int>? removed;
  final List<String>? submitted;
  final GlobalKey<NoteSearchFieldState>? fieldKey;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String text = widget.initial;

  void setText(String t) => setState(() => text = t);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: NoteSearchField(
        key: widget.fieldKey,
        text: text,
        chips: widget.chips,
        hintText: 'Search notes',
        clearTooltip: 'Clear search',
        onTextChanged: widget.sent.add,
        onRemoveLastToken: () => widget.removed?.add(1),
        onSubmitted: widget.submitted?.add,
      ),
    ),
  );
}

void main() {
  testWidgets('sends text 150 ms after the last keystroke, not before', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(_Harness(sent: sent));
    await tester.enterText(find.byType(TextField), 'oil');
    await tester.pump(const Duration(milliseconds: 149));
    expect(sent, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    expect(sent, ['oil']);
  });

  testWidgets('the clear button appears only with text, and empties it', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(_Harness(sent: sent));
    expect(find.byKey(const Key('notesSearchClear')), findsNothing);

    await tester.enterText(find.byType(TextField), 'oil');
    await tester.pump();
    await tester.tap(find.byKey(const Key('notesSearchClear')));
    await tester.pump();

    expect(sent.last, '');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byKey(const Key('notesSearchClear')), findsNothing);
  });

  testWidgets('shows the applied text on first build', (tester) async {
    await tester.pumpWidget(_Harness(sent: [], initial: 'zzz'));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'zzz',
    );
  });

  testWidgets('an outside change is copied into the box', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, sent: [], initial: 'zzz'));
    key.currentState!.setText('');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('an echo of what was sent does not move the caret', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, sent: []));
    await tester.enterText(find.byType(TextField), 'oil');
    await tester.pump(const Duration(milliseconds: 200));
    // The user keeps typing while the echo arrives.
    await tester.enterText(find.byType(TextField), 'oily');
    key.currentState!.setText('oil');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'oily',
    );
  });

  testWidgets('hardware backspace on empty text removes the last token', (
    tester,
  ) async {
    final removed = <int>[];
    await tester.pumpWidget(_Harness(sent: [], removed: removed));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(removed, hasLength(1));
  });

  testWidgets('backspace with text present does not remove a token', (
    tester,
  ) async {
    final removed = <int>[];
    await tester.pumpWidget(_Harness(sent: [], initial: 'a', removed: removed));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(removed, isEmpty);
  });

  testWidgets('clearAndCancel drops a pending keystroke', (tester) async {
    final sent = <String>[];
    final key = GlobalKey<NoteSearchFieldState>();
    await tester.pumpWidget(_Harness(sent: sent, fieldKey: key));
    await tester.enterText(find.byType(TextField), 'oil');
    await tester.pump(const Duration(milliseconds: 50));
    key.currentState!.clearAndCancel();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sent, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('renders the chips under the field', (tester) async {
    await tester.pumpWidget(
      _Harness(sent: [], chips: const [Text('chip-a'), Text('chip-b')]),
    );
    final field = tester.getBottomLeft(find.byType(TextField)).dy;
    expect(
      tester.getTopLeft(find.text('chip-a')).dy,
      greaterThanOrEqualTo(field),
    );
    expect(find.text('chip-b'), findsOneWidget);
  });

  testWidgets('submit sends immediately', (tester) async {
    final sent = <String>[];
    final submitted = <String>[];
    await tester.pumpWidget(_Harness(sent: sent, submitted: submitted));
    await tester.enterText(find.byType(TextField), 'oil');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, ['oil']);
    expect(sent, ['oil']);
  });
}
