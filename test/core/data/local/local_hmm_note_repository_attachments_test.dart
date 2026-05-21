// Phase 11 round-trip: HmmNote ↔ Notes.attachments JSON column,
// driven through LocalHmmNoteRepository against an in-memory Drift db.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';

void main() {
  late HmmDatabase db;
  late Author author;
  late int catalogId;
  late LocalHmmNoteRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());

    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'tester'),
        );
    author = await (db.select(db.authors)
          ..where((a) => a.id.equals(aid)))
        .getSingle();

    catalogId = await db.into(db.noteCatalogs).insert(
          NoteCatalogsCompanion.insert(name: 'TestCatalog', schema: '{}'),
        );

    repo = LocalHmmNoteRepository(db, () async => author);
  });

  tearDown(() async {
    await db.close();
  });

  test('createNote without attachments stores SQL NULL', () async {
    final n = await repo.createNote(HmmNoteCreate(
      subject: 'no attachments',
      catalogId: catalogId,
    ));
    expect(n.attachments, isNull);

    final row = await (db.select(db.notes)..where((x) => x.id.equals(n.id)))
        .getSingle();
    expect(row.attachments, isNull);
  });

  test('createNote with attachments round-trips via getNoteById', () async {
    final payload = NoteAttachments(
      primaryImage: const VaultRef(
        path: 'attachments/note-1/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      ),
      images: const [
        VaultRef(
          path: 'attachments/note-1/b.jpg',
          contentType: 'image/jpeg',
          byteSize: 50,
        ),
      ],
    );

    final created = await repo.createNote(HmmNoteCreate(
      subject: 'with attachments',
      catalogId: catalogId,
      attachments: payload,
    ));
    expect(created.attachments, equals(payload));

    final fetched = await repo.getNoteById(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.attachments, equals(payload));
    expect(fetched.effectiveAttachments.primaryImage,
        equals(payload.primaryImage));
    expect(fetched.effectiveAttachments.images, equals(payload.images));
  });

  test('createNote with an empty payload stores SQL NULL', () async {
    final n = await repo.createNote(HmmNoteCreate(
      subject: 'empty payload',
      catalogId: catalogId,
      attachments: NoteAttachments.empty,
    ));
    expect(n.attachments, isNull);

    final row = await (db.select(db.notes)..where((x) => x.id.equals(n.id)))
        .getSingle();
    expect(row.attachments, isNull);
  });

  test('updateNote attaches photos to a note that had none', () async {
    final note = await repo.createNote(HmmNoteCreate(
      subject: 'plain',
      catalogId: catalogId,
    ));
    expect(note.attachments, isNull);

    final payload = NoteAttachments(
      primaryImage: const VaultRef(
        path: 'attachments/note-1/x.png',
        contentType: 'image/png',
        byteSize: 200,
      ),
    );
    final updated = await repo.updateNote(
      note.id,
      HmmNoteUpdate(attachments: payload),
    );
    expect(updated.attachments, equals(payload));
  });

  test('updateNote with NoteAttachments.empty clears the column', () async {
    final payload = NoteAttachments(
      primaryImage: const VaultRef(
        path: 'attachments/note-1/clear-me.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      ),
    );
    final note = await repo.createNote(HmmNoteCreate(
      subject: 'to be cleared',
      catalogId: catalogId,
      attachments: payload,
    ));
    expect(note.attachments, isNotNull);

    final cleared = await repo.updateNote(
      note.id,
      HmmNoteUpdate(attachments: NoteAttachments.empty),
    );
    expect(cleared.attachments, isNull);

    final row = await (db.select(db.notes)..where((x) => x.id.equals(note.id)))
        .getSingle();
    expect(row.attachments, isNull);
  });

  test('updateNote without attachments leaves the column untouched', () async {
    final payload = NoteAttachments(
      primaryImage: const VaultRef(
        path: 'attachments/note-1/keepme.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      ),
    );
    final note = await repo.createNote(HmmNoteCreate(
      subject: 'keeps its photo',
      catalogId: catalogId,
      attachments: payload,
    ));

    final updated = await repo.updateNote(
      note.id,
      const HmmNoteUpdate(subject: 'new subject'),
    );
    expect(updated.subject, equals('new subject'));
    expect(updated.attachments, equals(payload));
  });

  test('attachments survive a fresh repo instance against the same db',
      () async {
    final payload = NoteAttachments(
      primaryImage: const VaultRef(
        path: 'attachments/note-1/persist.jpg',
        contentType: 'image/jpeg',
        byteSize: 100,
      ),
    );
    final created = await repo.createNote(HmmNoteCreate(
      subject: 'persistent',
      catalogId: catalogId,
      attachments: payload,
    ));

    final repo2 = LocalHmmNoteRepository(db, () async => author);
    final got = await repo2.getNoteById(created.id);
    expect(got!.attachments, equals(payload));
  });
}
