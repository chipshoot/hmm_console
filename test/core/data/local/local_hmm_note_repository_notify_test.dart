import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';

/// Regression coverage for the sync-safety incident: a successful local
/// write to a note (createNote/updateNote) must notify the caller-supplied
/// [LocalHmmNoteRepository.onLocalWrite] hook exactly once each — this is
/// the chokepoint both the notes editor (`MutateNote`) AND gas logs
/// (`LocalGasLogRepository`, which never goes through `MutateNote`) share,
/// so hooking here (not `MutateNote`) is what actually gives gas logs the
/// same auto-sync protection notes get. See Finding 1 in
/// `docs/superpowers/plans/2026-07-15-sync-safety-phase1.md`.
void main() {
  test('createNote and updateNote each call onLocalWrite once', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();

    var writeCount = 0;
    final repo = LocalHmmNoteRepository(
      db,
      () async => author,
      onLocalWrite: () => writeCount++,
    );

    final created = await repo.createNote(
      const HmmNoteCreate(subject: 'Hi', catalogId: 1),
    );
    expect(writeCount, equals(1));

    await repo.updateNote(created.id, const HmmNoteUpdate(subject: 'Bye'));
    expect(writeCount, equals(2));
  });

  test('deleteNote and setParentNote do NOT call onLocalWrite (Phase 1 '
      'scope is create/update only — see spec §1)', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();

    var writeCount = 0;
    final repo = LocalHmmNoteRepository(
      db,
      () async => author,
      onLocalWrite: () => writeCount++,
    );

    final created = await repo.createNote(
      const HmmNoteCreate(subject: 'Hi', catalogId: 1),
    );
    writeCount = 0; // ignore the create's own notification

    await repo.deleteNote(created.id);
    await repo.setParentNote(created.id, null);
    expect(writeCount, equals(0));
  });

  test('onLocalWrite is optional — omitting it is safe (existing call '
      'sites unaffected)', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();

    final repo = LocalHmmNoteRepository(db, () async => author);
    await repo.createNote(const HmmNoteCreate(subject: 'Hi', catalogId: 1));
    // No throw = pass.
  });
}
