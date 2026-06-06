import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/markdown_view.dart';

void main() {
  testWidgets('renders a MarkdownBody for the given markdown', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MarkdownView('# Title\n\nBody text')),
    ));
    expect(find.byType(MarkdownView), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });
}
