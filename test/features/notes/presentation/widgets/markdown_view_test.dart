import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/markdown_view.dart';

void main() {
  testWidgets('renders a MarkdownBody for the given markdown', (tester) async {
    // MarkdownView is a ConsumerWidget (it resolves inline attachment images),
    // so it needs a ProviderScope ancestor.
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: MarkdownView('# Title\n\nBody text')),
      ),
    ));
    await tester.pump();
    expect(find.byType(MarkdownView), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });
}
