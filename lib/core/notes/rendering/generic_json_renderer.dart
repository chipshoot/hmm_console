import 'dart:convert';

import '../../../features/notes/data/models/hmm_note.dart';
import 'note_renderer.dart';

class GenericJsonRenderer implements NoteRenderer {
  const GenericJsonRenderer();

  @override
  String render(HmmNote note) {
    final content = note.content?.trim();
    if (content == null || content.isEmpty) {
      final desc = note.description?.trim();
      return (desc == null || desc.isEmpty) ? '_(empty note)_' : desc;
    }
    try {
      return jsonToMarkdown(jsonDecode(content)).trimRight();
    } catch (_) {
      return content; // not JSON — show as-is
    }
  }

  /// Render decoded JSON as a nested markdown bullet list.
  static String jsonToMarkdown(Object? node, {int depth = 0}) {
    final buf = StringBuffer();
    final pad = '  ' * depth;
    if (node is Map) {
      node.forEach((k, v) {
        if (v is Map || v is List) {
          buf.writeln('$pad- **$k:**');
          buf.write(jsonToMarkdown(v, depth: depth + 1));
        } else {
          buf.writeln('$pad- **$k:** $v');
        }
      });
    } else if (node is List) {
      for (final item in node) {
        if (item is Map || item is List) {
          buf.write(jsonToMarkdown(item, depth: depth));
        } else {
          buf.writeln('$pad- $item');
        }
      }
    } else {
      buf.writeln('$pad$node');
    }
    return buf.toString();
  }
}
