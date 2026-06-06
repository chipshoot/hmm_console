import '../../../features/notes/data/models/hmm_note.dart';

/// Produces a read-only markdown string for a note. Implementations must not
/// throw — see render_registry, which isolates failures behind the fallback.
abstract interface class NoteRenderer {
  String render(HmmNote note);
}
