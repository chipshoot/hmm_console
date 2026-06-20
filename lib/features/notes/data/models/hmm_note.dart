import 'dart:typed_data';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/note_location.dart';

/// Domain entity for HmmNote — matches the server-side
/// `Hmm.Core.HmmNote` shape. See Phase 3.5 in
/// `docs/data-layer-unification-plan.md`.
///
/// Distinct from:
/// * `Note` (Drift-generated row in `lib/core/data/local/database.dart`)
///   — the persistence shape, internal to the local repository.
/// * Future `ApiNote` JSON — wire format used by the API sync provider.
///
/// Mappers live at `lib/features/notes/data/mappers/hmm_note_mapper.dart`.
class HmmNote {
  const HmmNote({
    required this.id,
    required this.uuid,
    required this.subject,
    required this.authorId,
    required this.createDate,
    this.catalogId,
    this.noteDate,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.lastModifiedDate,
    this.content,
    this.parentNoteId,
    this.description,
    this.deletedAt,
    this.version,
    this.attachments,
  });

  /// Local int primary key. Per-device — never crosses the wire.
  final int id;

  /// Stable cross-device identity. Used by sync providers to correlate the
  /// local row with the server-side record.
  final String uuid;

  final String subject;

  /// JSON blob carrying the serialized domain payload (Automobile, GasLog,
  /// GasStation, etc.). Schema is determined by the parent NoteCatalog.
  final String? content;

  final int authorId;

  /// Nullable in the Drift schema. In practice every record we create
  /// supplies one (`HmmNoteCreate.catalogId` is required), but
  /// historically-imported or legacy rows may not have it.
  final int? catalogId;

  /// Self-reference for note hierarchies (e.g. GasLog notes carry the
  /// Automobile note's id as their parent).
  final int? parentNoteId;

  final String? description;

  final DateTime createDate;

  /// User-editable note date. Null on legacy rows pre-dating the v7
  /// migration; use [effectiveNoteDate] which falls back to [createDate].
  final DateTime? noteDate;

  /// The date to display/sort by: the editable note date, falling back to
  /// the immutable created-at when unset.
  DateTime get effectiveNoteDate => noteDate ?? createDate;

  final double? latitude;
  final double? longitude;
  final String? locationLabel;

  /// Convenience: the note's location, or null when none is set.
  NoteLocation? get location => (latitude == null && longitude == null)
      ? null
      : NoteLocation(
          latitude: latitude, longitude: longitude, label: locationLabel);

  final DateTime? lastModifiedDate;

  /// Soft-delete tombstone. Server-side equivalent: `HmmNote.IsDeleted`.
  final DateTime? deletedAt;
  bool get isDeleted => deletedAt != null;

  /// Optimistic-concurrency token. Server-side equivalent:
  /// `VersionedEntity.Version` (SQL Server ROWVERSION).
  final Uint8List? version;

  /// Note-level attachments (primary image + gallery). `null` means
  /// the `Notes.attachments` column is SQL NULL — i.e. no
  /// attachments. Treat `null` and [NoteAttachments.empty] as
  /// equivalent on read; use [effectiveAttachments] to skip the
  /// null check.
  final NoteAttachments? attachments;

  /// Convenience accessor that collapses `null` to
  /// [NoteAttachments.empty].
  NoteAttachments get effectiveAttachments =>
      attachments ?? NoteAttachments.empty;
}
