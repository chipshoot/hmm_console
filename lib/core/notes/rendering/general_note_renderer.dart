import '../../../features/notes/data/models/hmm_note.dart';
import 'note_renderer.dart';

class GeneralNoteRenderer implements NoteRenderer {
  const GeneralNoteRenderer();

  @override
  String render(HmmNote note) {
    final body = note.content?.trim();
    if (body != null && body.isNotEmpty) return body;
    final desc = note.description?.trim();
    return (desc == null || desc.isEmpty) ? '_(empty note)_' : desc;
  }
}
