/// Parameter objects for `IHmmNoteRepository.createNote` and `updateNote`.
///
/// Mirror the Hmm.ServiceApi DTOs (`ApiNoteForCreate`, `ApiNoteForUpdate`):
///
/// * [HmmNoteCreate] carries the **mutable + initial-only** fields the caller
///   provides on insert. `authorId` is **not** exposed — the repository
///   resolves it from the signed-in user (matches the server's POST flow,
///   where `CurrentUserAuthorProvider` derives the author from the JWT).
/// * [HmmNoteUpdate] carries only the fields the API allows mutating on
///   PUT/PATCH: subject, content, description. Author and catalog are
///   immutable after create on both sides; passing them in is a bug and
///   `LocalHmmNoteRepository.updateNote` throws ArgumentError.
class HmmNoteCreate {
  const HmmNoteCreate({
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

class HmmNoteUpdate {
  const HmmNoteUpdate({
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
