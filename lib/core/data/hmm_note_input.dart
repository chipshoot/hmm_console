import 'attachments/attachment_ref.dart';
import 'note_location.dart';

/// Parameter objects for `IHmmNoteRepository.createNote` and `updateNote`.
///
/// Mirror the Hmm.ServiceApi DTOs (`ApiNoteForCreate`, `ApiNoteForUpdate`):
///
/// * [HmmNoteCreate] carries the **mutable + initial-only** fields the caller
///   provides on insert. `authorId` is **not** exposed — the repository
///   resolves it from the signed-in user (matches the server's POST flow,
///   where `CurrentUserAuthorProvider` derives the author from the JWT).
/// * [HmmNoteUpdate] carries only the fields the API allows mutating on
///   PUT/PATCH: subject, content, description, attachments. Author and
///   catalog are immutable after create on both sides; passing them in is a
///   bug and `LocalHmmNoteRepository.updateNote` throws ArgumentError.
class HmmNoteCreate {
  const HmmNoteCreate({
    required this.subject,
    required this.catalogId,
    this.content,
    this.parentNoteId,
    this.description,
    this.attachments,
    this.uuid,
    this.noteDate,
    this.location,
  });

  final String subject;
  final int catalogId;
  final String? content;
  final int? parentNoteId;
  final String? description;

  /// Optional initial note date. Null ⇒ repository stamps now.
  final DateTime? noteDate;

  /// Optional initial location. Null or [NoteLocation.empty] ⇒ no location.
  final NoteLocation? location;

  /// Optional explicit stable uuid. When null, the DB assigns a v4 uuid via
  /// the column's clientDefault. Used to seed records with a deterministic id
  /// (e.g. subsystem anchors).
  final String? uuid;

  /// Optional initial attachments payload. `null` (the default) and
  /// [NoteAttachments.empty] both produce a SQL-NULL column.
  final NoteAttachments? attachments;
}

class HmmNoteUpdate {
  const HmmNoteUpdate({
    this.subject,
    this.content,
    this.description,
    this.attachments,
    this.noteDate,
    this.location,
  });

  final String? subject;
  final String? content;
  final String? description;

  /// Replacement note date. Null ⇒ don't touch the column.
  final DateTime? noteDate;

  /// Patch semantics: null = don't touch; [NoteLocation.empty] = clear
  /// (write SQL NULL ×3); populated = set.
  final NoteLocation? location;

  /// Patch semantics:
  /// * `null`                  — don't touch the attachments column.
  /// * [NoteAttachments.empty] — clear (write SQL NULL).
  /// * any non-empty value     — replace.
  final NoteAttachments? attachments;

  bool get isEmpty =>
      subject == null &&
      content == null &&
      description == null &&
      attachments == null &&
      noteDate == null &&
      location == null;
}
