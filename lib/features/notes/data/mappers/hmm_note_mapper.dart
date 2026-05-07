import '../../../../core/data/local/database.dart' as drift;
import '../models/hmm_note.dart';

/// Bridges the persistence layer (Drift `Note` row) and the domain layer
/// (`HmmNote`). Lives at the feature boundary so the local repo stays the
/// only place that imports both shapes.
///
/// When Phase 4 lands the `ApiSyncProvider`, add `fromApi` and `toApi` here
/// so all HmmNote translations live in one file.
class HmmNoteMapper {
  const HmmNoteMapper._();

  static HmmNote fromDriftRow(drift.Note row) => HmmNote(
        id: row.id,
        // The Drift schema marks `uuid` nullable but pairs it with a
        // `clientDefault(generateUuid)`, so every row Drift produces has one.
        // Belt-and-braces: synthesise a fallback if a legacy row slips
        // through without a uuid (rather than throw).
        uuid: row.uuid ?? '',
        subject: row.subject,
        content: row.content,
        authorId: row.authorId,
        catalogId: row.catalogId,
        parentNoteId: row.parentNoteId,
        description: row.description,
        createDate: row.createDate,
        lastModifiedDate: row.lastModifiedDate,
        deletedAt: row.deletedAt,
        version: row.version,
      );
}
