import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../util/uuid.dart';

part 'database.g.dart';

class Authors extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountName => text().withLength(min: 1, max: 256)();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();
  IntColumn get role => integer().withDefault(const Constant(0))();
  BoolColumn get isActivated => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [{accountName}];
}

class NoteCatalogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get schema => text()();
  TextColumn get render => text().nullable()();
  IntColumn get formatType => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{name}];
}

@TableIndex(name: 'idx_notes_last_modified', columns: {#lastModifiedDate})
@TableIndex(name: 'idx_notes_catalog', columns: {#catalogId})
@TableIndex(name: 'idx_notes_parent', columns: {#parentNoteId})
@TableIndex(name: 'idx_notes_uuid', columns: {#uuid}, unique: true)
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Stable cross-device identity used by the sync layer. Nullable in the
  // schema only to allow ADD COLUMN during the v2→v3 migration; fresh inserts
  // always populate via [clientDefault].
  TextColumn get uuid => text().nullable().clientDefault(generateUuid)();
  TextColumn get subject => text().withLength(min: 1, max: 1000)();
  TextColumn get content => text().nullable()();
  IntColumn get authorId => integer().references(Authors, #id)();
  IntColumn get catalogId => integer().nullable().references(NoteCatalogs, #id)();
  // Self-referential parent note (e.g. gas_log note → its automobile note).
  IntColumn get parentNoteId =>
      integer().nullable().references(Notes, #id)();
  // Soft-delete timestamp (tombstone). NULL → live row.
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BlobColumn get version => blob().nullable()();
  DateTimeColumn get createDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastModifiedDate => dateTime().nullable()();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();

  // Note-level attachments — JSON value matching the NoteAttachments
  // wrapper schema. NULL = no attachments. See
  // docs/attachments-design.md in the Hmm repo. The old per-row
  // `Attachments` child table was retired in schema v5 (Phase 11.5);
  // attachment refs now ride in this column and the bytes live in
  // the vault directory.
  TextColumn get attachments => text().nullable()();
}

// The `Attachments` child table was retired in schema v5 (Phase 11.5
// of the note-attachments feature). Migrations referring to the old
// table use raw SQL via `customStatement` so the migrator no longer
// needs a typed table reference.

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();
  BoolColumn get isActivated => boolean().withDefault(const Constant(true))();
  // v6: sync metadata. lastModified drives per-name last-writer-wins;
  // deletedAt is the sync tombstone (distinct from the isActivated flag).
  DateTimeColumn get lastModified => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{name}];
}

class NoteTagRefs extends Table {
  IntColumn get noteId => integer().references(Notes, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

@DriftDatabase(
  tables: [Authors, NoteCatalogs, Notes, Tags, NoteTagRefs],
)
class HmmDatabase extends _$HmmDatabase {
  HmmDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('PRAGMA journal_mode=WAL');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Add new nullable columns.
        await m.addColumn(notes, notes.parentNoteId);
        await m.addColumn(notes, notes.deletedAt);

        // Backfill deleted_at from the retired is_deleted flag.
        // Choose the best available timestamp for old deletes.
        await customStatement('''
          UPDATE notes
             SET deleted_at = COALESCE(last_modified_date, create_date)
           WHERE is_deleted = 1 AND deleted_at IS NULL
        ''');

        // v2 historically created the `attachments` child table. We
        // re-create it here with raw SQL (the typed class was removed
        // in v5) so anyone upgrading from v1 still has the table
        // available for the v3 / v4 work before v5 drops it.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS attachments (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            note_id INTEGER NOT NULL REFERENCES notes(id),
            filename TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            size INTEGER NOT NULL,
            local_path TEXT,
            remote_path TEXT,
            create_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_modified_date DATETIME,
            deleted_at DATETIME
          )
        ''');
        await m.createIndex(
          Index(
            'idx_notes_last_modified',
            'CREATE INDEX IF NOT EXISTS idx_notes_last_modified '
                'ON notes (last_modified_date)',
          ),
        );
        await m.createIndex(
          Index(
            'idx_notes_catalog',
            'CREATE INDEX IF NOT EXISTS idx_notes_catalog '
                'ON notes (catalog_id)',
          ),
        );
        await m.createIndex(
          Index(
            'idx_notes_parent',
            'CREATE INDEX IF NOT EXISTS idx_notes_parent '
                'ON notes (parent_note_id)',
          ),
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attachments_note '
              'ON attachments (note_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attachments_last_modified '
              'ON attachments (last_modified_date)',
        );
      }
      if (from < 3) {
        // v3: cross-device record identity.
        await m.addColumn(notes, notes.uuid);
        await customStatement(
          'ALTER TABLE attachments ADD COLUMN uuid TEXT',
        );
        // Backfill one UUID per existing row. Small volumes expected during
        // upgrade (this is still pre-release), so per-row UPDATE is fine.
        final pendingNotes = await customSelect(
          'SELECT id FROM notes WHERE uuid IS NULL',
          readsFrom: {notes},
        ).get();
        for (final row in pendingNotes) {
          await customStatement(
            'UPDATE notes SET uuid = ? WHERE id = ?',
            [generateUuid(), row.read<int>('id')],
          );
        }
        final pendingAttachments = await customSelect(
          'SELECT id FROM attachments WHERE uuid IS NULL',
        ).get();
        for (final row in pendingAttachments) {
          await customStatement(
            'UPDATE attachments SET uuid = ? WHERE id = ?',
            [generateUuid(), row.read<int>('id')],
          );
        }
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_uuid ON notes (uuid)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_attachments_uuid '
              'ON attachments (uuid)',
        );
      }
      if (from < 4) {
        // v4: note-level attachments JSON column on Notes — the new
        // home for attachment refs (the old child table is dropped in
        // v5 below).
        await m.addColumn(notes, notes.attachments);
      }
      if (from < 5) {
        // v5 (Phase 11.5, 2026-05-17): retire the old `Attachments`
        // child table. Attachment refs now live in `Notes.attachments`
        // (JSON column added in v4); bytes live in the vault directory
        // and travel via the OS-level cloud sync client (cloudStorage)
        // or the future ApiVaultStore (cloudApi, Phase 15).
        await customStatement('DROP TABLE IF EXISTS attachments');
      }
      if (from < 6) {
        // v6: tag sync metadata. Existing rows get currentDateAndTime as
        // lastModified and NULL deletedAt (live).
        await m.addColumn(tags, tags.lastModified);
        await m.addColumn(tags, tags.deletedAt);
      }
    },
  );
}

const _dbPathKey = 'local_db_path';

Future<String> _resolveDbPath() async {
  final prefs = await SharedPreferences.getInstance();
  final customPath = prefs.getString(_dbPathKey);
  if (customPath != null && customPath.isNotEmpty) {
    final dir = Directory(p.dirname(customPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return customPath;
  }
  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'hmm.db');
}

final hmmDatabaseProvider = Provider<HmmDatabase>((ref) {
  throw UnimplementedError(
    'hmmDatabaseProvider must be overridden at startup with the resolved database path',
  );
});

Future<HmmDatabase> createHmmDatabase() async {
  final dbPath = await _resolveDbPath();
  return HmmDatabase(NativeDatabase(File(dbPath)));
}

Future<void> setDatabasePath(String path) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_dbPathKey, path);
}
