import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// The single place the markdown rendering package is referenced. Swap the
/// package here without touching call sites.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) =>
      MarkdownBody(data: data, selectable: true);
}
