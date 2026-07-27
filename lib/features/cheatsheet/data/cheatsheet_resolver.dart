import '../../../core/data/local/local_hmm_note_repository.dart';
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';
import '../domain/note_piece_extractor.dart';

/// The outcome of resolving one row. The three states are distinct on purpose:
/// an *unbound* row is a card the user hasn't finished, a *missing* one points
/// at a note that is gone or hasn't synced yet, and neither is an error.
class ResolvedValue {
  const ResolvedValue({this.text, this.missing = false, this.unbound = false});

  final String? text;
  final bool missing;
  final bool unbound;
}

/// Reads a row's referenced note by **uuid** — the cross-device stable
/// identity — and extracts the referenced piece.
class CheatsheetResolver {
  CheatsheetResolver(this._notes);

  final IHmmNoteRepository _notes;

  Future<ResolvedValue> resolve(CheatsheetRow row) async {
    final s = row.source;
    if (s == null) return const ResolvedValue(unbound: true);

    final note = await _notes.getNoteByUuid(s.noteUuid);
    if (note == null) return const ResolvedValue(missing: true);

    final value = switch (s.kind) {
      SourceGranularity.field =>
        NotePieceExtractor.field(note.content, s.locator ?? ''),
      SourceGranularity.section => NotePieceExtractor.section(
          note.description ?? note.content,
          s.locator ?? '',
        ),
      SourceGranularity.whole =>
        NotePieceExtractor.whole(note.content, note.description),
    };

    if (value == null || value.isEmpty) {
      return const ResolvedValue(missing: true);
    }
    return ResolvedValue(text: value);
  }
}
