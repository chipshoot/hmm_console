// lib/features/notes/query/markdown_text.dart
import 'package:markdown/markdown.dart' as md;

const _skipped = {'img', 'table', 'input'};
const _containers = {'ul', 'ol', 'li', 'blockquote'};
const _blocks = {'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'pre', 'hr'};

/// Plain searchable text of [markdown]: block texts joined by `\n`; images,
/// tables and raw HTML omitted; link text kept, URLs dropped; task-list
/// markers dropped.
String markdownToPlainText(String markdown) {
  if (markdown.isEmpty) return '';
  final doc = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  final lines = <String>[];
  // Top-level Text nodes are raw HTML blocks.
  _collect(doc.parseLines(markdown.split('\n')), lines, root: true);
  return lines.join('\n');
}

void _collect(List<md.Node> nodes, List<String> out, {bool root = false}) {
  final buf = StringBuffer();
  void flush() {
    final t = buf.toString().trim();
    if (t.isNotEmpty) out.add(t);
    buf.clear();
  }

  for (final n in nodes) {
    if (n is md.Text) {
      if (!root) buf.write(n.text);
    } else if (n is md.Element) {
      if (_skipped.contains(n.tag)) continue;
      if (_containers.contains(n.tag)) {
        flush();
        _collect(n.children ?? const [], out);
      } else if (_blocks.contains(n.tag)) {
        flush();
        buf.write(_inline(n));
        flush();
      } else {
        buf.write(_inline(n));
      }
    }
  }
  flush();
}

String _inline(md.Node n) {
  if (n is md.Text) return n.text;
  if (n is md.Element) {
    if (_skipped.contains(n.tag)) return '';
    if (n.tag == 'br') return ' ';
    return (n.children ?? const []).map(_inline).join();
  }
  return '';
}
