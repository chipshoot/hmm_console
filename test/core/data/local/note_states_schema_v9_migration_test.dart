import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';

/// The v8 `notes` table exactly as Drift created it (DateTime columns are
/// unix seconds). Only `notes` is needed: the v8 → v9 step creates
/// `note_states` and touches nothing else.
const _v8Notes = '''
CREATE TABLE notes (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NULL,
  subject TEXT NOT NULL,
  content TEXT NULL,
  author_id INTEGER NOT NULL,
  catalog_id INTEGER NULL,
  parent_note_id INTEGER NULL,
  deleted_at INTEGER NULL,
  version BLOB NULL,
  create_date INTEGER NOT NULL,
  note_date INTEGER NULL,
  latitude REAL NULL,
  longitude REAL NULL,
  location_label TEXT NULL,
  last_modified_date INTEGER NULL,
  description TEXT NULL,
  attachments TEXT NULL
)''';

void main() {
  test('v8 → v9 creates an empty note_states table and leaves notes untouched',
      () async {
    final db = HmmDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute(_v8Notes);
      raw.execute(
          "INSERT INTO notes (uuid, subject, content, author_id, create_date, "
          "last_modified_date) VALUES ('u-old', 'old note', 'body', 1, "
          "1700000000, 1700000000)");
      raw.userVersion = 8;
    }));
    addTearDown(db.close);

    expect(db.schemaVersion, 9);
    final row = await db.select(db.notes).getSingle();
    expect(row.uuid, 'u-old');
    expect(row.subject, 'old note');
    expect(row.lastModifiedDate!.toUtc(),
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true));
    expect(await db.select(db.noteStates).get(), isEmpty,
        reason: 'no row = unpinned and unflagged; nothing is backfilled');

    final noteColumns = await db.customSelect('PRAGMA table_info(notes)').get();
    expect(noteColumns.map((c) => c.read<String>('name')),
        isNot(anyOf(contains('is_pinned'), contains('flag_color'))),
        reason: 'pin and flag are never note columns (G14)');
  });

  test('a fresh v9 database stores a state row keyed by note uuid', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.noteStates).insert(NoteStatesCompanion.insert(
          noteUuid: 'u1',
          flagColor: const Value(42),
          lastModifiedDate: DateTime.utc(2026, 10, 18, 9),
        ));
    final row = await db.select(db.noteStates).getSingle();
    expect(row.noteUuid, 'u1');
    expect(row.isPinned, isFalse, reason: 'isPinned defaults to false');
    expect(row.flagColor, 42, reason: 'unknown colours are stored verbatim');
  });
}
