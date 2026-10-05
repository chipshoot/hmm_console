import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/local/local_hmm_note_repository.dart';
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';
import '../domain/note_piece_extractor.dart';

/// The outcome of resolving one row. The three states are distinct on purpose:
/// an *unbound* row is a card the user hasn't finished, a *missing* one points
/// at a note that is gone or hasn't synced yet, and neither is an error.
class ResolvedValue {
  const ResolvedValue({
    this.text,
    this.image,
    this.missing = false,
    this.unbound = false,
  });

  final String? text;

  /// Set instead of [text] for an image row.
  final VaultRef? image;
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

    // A soft-deleted entity (`isActivated: false`) reads as removed - for
    // every kind, image rows included, so a removed note's photo is not shown.
    if (NotePieceExtractor.isDeactivated(note.content)) {
      return const ResolvedValue(missing: true);
    }

    if (s.kind == SourceGranularity.image) {
      final image = NotePieceExtractor.image(note.attachments, s.locator ?? '');
      return image == null
          ? const ResolvedValue(missing: true)
          : ResolvedValue(image: image);
    }

    final value = switch (s.kind) {
      SourceGranularity.field =>
        NotePieceExtractor.field(note.content, s.locator ?? ''),
      SourceGranularity.section => NotePieceExtractor.section(
          note.description ?? note.content,
          s.locator ?? '',
        ),
      SourceGranularity.whole =>
        NotePieceExtractor.whole(note.content, note.description),
      SourceGranularity.image => null, // handled above
    };

    if (value == null || value.isEmpty) {
      return const ResolvedValue(missing: true);
    }
    return ResolvedValue(text: value);
  }
}
