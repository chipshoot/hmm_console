/// Parameter objects for `INoteRepository.createNote` and `updateNote`.
///
/// Mirrors the Hmm.ServiceApi DTOs (`ApiNoteForCreate`, `ApiNoteForUpdate`):
///
/// * `NoteCreate` carries the **mutable + initial-only** fields the caller
///   provides on insert. `authorId` is **not** exposed — the repository
///   resolves it from the signed-in user (matches the API's POST flow,
///   where the server validates against the JWT). Once Phase 4 is in
///   place, the `authorId: 0` placeholder hack the call sites currently
///   use is gone.
/// * `NoteUpdate` carries only the fields the API allows mutating on PUT/
///   PATCH: `subject`, `content`, `description`. Author and catalog are
///   immutable after create on both sides; passing them in is a bug and
///   `LocalNoteRepository.updateNote` throws ArgumentError.
class NoteCreate {
  const NoteCreate({
    required this.subject,
    required this.catalogId,
    this.content,
    this.parentNoteId,
    this.description,
  });

  final String subject;
  final int catalogId;
  final String? content;
  final int? parentNoteId;
  final String? description;
}

class NoteUpdate {
  const NoteUpdate({
    this.subject,
    this.content,
    this.description,
  });

  final String? subject;
  final String? content;
  final String? description;

  bool get isEmpty =>
      subject == null && content == null && description == null;
}
