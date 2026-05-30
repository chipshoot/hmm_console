// Vault orphan-GC coverage: the pure sweep (against a real
// LocalVaultStore on a tmp dir) and the DB-backed referenced-path
// collector (against an in-memory Drift db), plus an end-to-end run
// proving an orphaned file is reclaimed while live attachments stay.

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/vault/local_vault_store.dart';
import 'package:hmm_console/core/data/vault/vault_gc.dart';

Uint8List _bytes(int n) => Uint8List.fromList(List<int>.filled(n, 65));

void main() {
  group('VaultGarbageCollector.sweep', () {
    late Directory tmp;
    late LocalVaultStore store;
    late VaultGarbageCollector gc;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('hmm_gc_test_');
      store = LocalVaultStore(rootDir: tmp);
      gc = VaultGarbageCollector(store);
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('deletes orphans, keeps referenced files', () async {
      await store.putBytes('attachments/note-1/keep.jpg', _bytes(10));
      await store.putBytes('attachments/note-1/orphan.jpg', _bytes(30));
      await store.putBytes('attachments/note-2/keep.png', _bytes(20));

      final result = await gc.sweep({
        'attachments/note-1/keep.jpg',
        'attachments/note-2/keep.png',
      });

      expect(result.deletedPaths, ['attachments/note-1/orphan.jpg']);
      expect(result.bytesReclaimed, 30);
      expect(result.deletedCount, 1);
      expect(result.isClean, isFalse);

      expect(await store.exists('attachments/note-1/keep.jpg'), isTrue);
      expect(await store.exists('attachments/note-2/keep.png'), isTrue);
      expect(await store.exists('attachments/note-1/orphan.jpg'), isFalse);
    });

    test('empty referenced set reclaims everything', () async {
      await store.putBytes('attachments/note-1/a.jpg', _bytes(5));
      await store.putBytes('attachments/note-1/b.jpg', _bytes(7));

      final result = await gc.sweep({});

      expect(result.deletedCount, 2);
      expect(result.bytesReclaimed, 12);
      expect(await store.list(''), isEmpty);
    });

    test('all referenced → nothing deleted, isClean', () async {
      await store.putBytes('attachments/note-1/a.jpg', _bytes(5));

      final result = await gc.sweep({'attachments/note-1/a.jpg'});

      expect(result.isClean, isTrue);
      expect(result.bytesReclaimed, 0);
      expect(await store.exists('attachments/note-1/a.jpg'), isTrue);
    });

    test('dryRun reports orphans without deleting them', () async {
      await store.putBytes('attachments/note-1/orphan.jpg', _bytes(40));

      final result = await gc.sweep({}, dryRun: true);

      expect(result.deletedPaths, ['attachments/note-1/orphan.jpg']);
      expect(result.bytesReclaimed, 40);
      // Still on disk — dry run is read-only.
      expect(await store.exists('attachments/note-1/orphan.jpg'), isTrue);
    });

    test('empty vault yields a clean result', () async {
      final result = await gc.sweep({'attachments/note-1/whatever.jpg'});
      expect(result.isClean, isTrue);
      expect(result.bytesReclaimed, 0);
    });
  });

  group('collectReferencedVaultPaths', () {
    late HmmDatabase db;
    late Author author;
    late int catalogId;
    late LocalHmmNoteRepository repo;

    setUp(() async {
      db = HmmDatabase(NativeDatabase.memory());
      final aid = await db.into(db.authors).insert(
            AuthorsCompanion.insert(accountName: 'tester'),
          );
      author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
          .getSingle();
      catalogId = await db.into(db.noteCatalogs).insert(
            NoteCatalogsCompanion.insert(name: 'Cat', schema: '{}'),
          );
      repo = LocalHmmNoteRepository(db, () async => author);
    });

    tearDown(() async => db.close());

    test('collects vault paths from primaryImage + images across notes',
        () async {
      await repo.createNote(HmmNoteCreate(
        subject: 'n1',
        catalogId: catalogId,
        attachments: NoteAttachments(
          primaryImage: const VaultRef(
            path: 'attachments/note-1/p.jpg',
            contentType: 'image/jpeg',
            byteSize: 1,
          ),
          images: const [
            VaultRef(
              path: 'attachments/note-1/g.jpg',
              contentType: 'image/jpeg',
              byteSize: 1,
            ),
          ],
        ),
      ));
      await repo.createNote(HmmNoteCreate(
        subject: 'n2',
        catalogId: catalogId,
        attachments: NoteAttachments(
          primaryImage: const VaultRef(
            path: 'attachments/note-2/p.jpg',
            contentType: 'image/jpeg',
            byteSize: 1,
          ),
        ),
      ));

      final paths = await collectReferencedVaultPaths(db);

      expect(paths, {
        'attachments/note-1/p.jpg',
        'attachments/note-1/g.jpg',
        'attachments/note-2/p.jpg',
      });
    });

    test('includes soft-deleted notes (bytes survive a tombstone)',
        () async {
      final n = await repo.createNote(HmmNoteCreate(
        subject: 'doomed',
        catalogId: catalogId,
        attachments: NoteAttachments(
          primaryImage: const VaultRef(
            path: 'attachments/note-9/p.jpg',
            contentType: 'image/jpeg',
            byteSize: 1,
          ),
        ),
      ));
      await repo.deleteNote(n.id); // soft delete

      final paths = await collectReferencedVaultPaths(db);
      expect(paths, contains('attachments/note-9/p.jpg'));
    });

    test('skips non-vault refs (phasset / cloudFile)', () async {
      await repo.createNote(HmmNoteCreate(
        subject: 'smart-refs',
        catalogId: catalogId,
        attachments: NoteAttachments(
          primaryImage: const PhAssetRef(
            id: 'PH-123',
            contentType: 'image/heic',
          ),
          images: const [
            CloudFileRef(
              provider: CloudProvider.oneDrive,
              path: 'Photos/car.jpg',
              contentType: 'image/jpeg',
            ),
            VaultRef(
              path: 'attachments/note-3/real.jpg',
              contentType: 'image/jpeg',
              byteSize: 1,
            ),
          ],
        ),
      ));

      final paths = await collectReferencedVaultPaths(db);
      expect(paths, {'attachments/note-3/real.jpg'});
    });

    test('returns empty when no note has attachments', () async {
      await repo.createNote(
        HmmNoteCreate(subject: 'plain', catalogId: catalogId),
      );
      expect(await collectReferencedVaultPaths(db), isEmpty);
    });
  });

  group('end-to-end sweep against collected references', () {
    test('reclaims an orphan, preserves live attachments', () async {
      final tmp = await Directory.systemTemp.createTemp('hmm_gc_e2e_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final db = HmmDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final aid = await db.into(db.authors).insert(
            AuthorsCompanion.insert(accountName: 'tester'),
          );
      final author = await (db.select(db.authors)
            ..where((a) => a.id.equals(aid)))
          .getSingle();
      final catalogId = await db.into(db.noteCatalogs).insert(
            NoteCatalogsCompanion.insert(name: 'Cat', schema: '{}'),
          );
      final repo = LocalHmmNoteRepository(db, () async => author);
      final store = LocalVaultStore(rootDir: tmp);

      // A saved note references one file...
      const liveRef = VaultRef(
        path: 'attachments/note-1/live.jpg',
        contentType: 'image/jpeg',
        byteSize: 3,
      );
      await repo.createNote(HmmNoteCreate(
        subject: 'saved',
        catalogId: catalogId,
        attachments: NoteAttachments(primaryImage: liveRef),
      ));
      await store.putBytes(liveRef.path, _bytes(3));
      // ...and a stray file from a cancelled pick sits beside it.
      await store.putBytes('attachments/note-1/cancelled.jpg', _bytes(99));

      final referenced = await collectReferencedVaultPaths(db);
      final result = await VaultGarbageCollector(store).sweep(referenced);

      expect(result.deletedPaths, ['attachments/note-1/cancelled.jpg']);
      expect(result.bytesReclaimed, 99);
      expect(await store.exists(liveRef.path), isTrue);
      expect(
        await store.exists('attachments/note-1/cancelled.jpg'),
        isFalse,
      );
    });
  });
}
