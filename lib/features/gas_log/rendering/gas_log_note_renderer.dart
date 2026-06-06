import 'dart:convert';

import '../../../core/notes/rendering/generic_json_renderer.dart';
import '../../../core/notes/rendering/note_renderer.dart';
import '../../notes/data/models/hmm_note.dart';

class GasLogNoteRenderer implements NoteRenderer {
  const GasLogNoteRenderer();

  static const String catalogName = 'Hmm.AutomobileMan.GasLog';

  @override
  String render(HmmNote note) {
    final content = note.content;
    if (content != null) {
      try {
        final json = jsonDecode(content) as Map<String, dynamic>;
        final gasLog = json['note']?['content']?['GasLog'];
        if (gasLog is Map<String, dynamic>) {
          return '### Gas Log\n\n${GenericJsonRenderer.jsonToMarkdown(gasLog).trimRight()}';
        }
      } catch (_) {/* fall through to generic */}
    }
    return const GenericJsonRenderer().render(note);
  }
}
