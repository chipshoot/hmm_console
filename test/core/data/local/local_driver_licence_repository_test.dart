// There is exactly ONE licence. The subject is fixed rather than derived, so
// a second save must update the same note and can never create a duplicate —
// a second note would shadow the first and the user's details would appear to
// revert at random depending on which one was read.
//
// The other invariant under test is that both image refs reach the note's
// `attachments` column. VaultGc builds its live-file set from that column
// alone, so a ref recorded only in content gets its bytes collected.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_driver_licence_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository notes;
  late LocalNoteCatalogRepository catalogs;
  late LocalDriverLicenceRepository repo;

  const front = VaultRef(
    path: 'attachments/note-1/sensitive/front.jpg',
    contentType: 'image/jpeg',
    byteSize: 100,
    sensitive: true,
  );
  const back = VaultRef(
    path: 'attachments/note-1/sensitive/back.jpg',
    contentType: 'image/jpeg',
    byteSize: 100,
    sensitive: true,
  );

  DriverLicence licence({VaultRef? f, VaultRef? b}) => DriverLicence(
        number: 'D1234-56789',
        licenceClass: 'G',
        jurisdiction: 'Ontario',
        issuedDate: DateTime.utc(2020, 5, 1),
        expiryDate: DateTime.utc(2030, 5, 1),
        frontImage: f,
        backImage: b,
      );

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'licence-tester'),
        );
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();

    notes = LocalHmmNoteRepository(db, () async => author);
    catalogs = LocalNoteCatalogRepository(db);
    repo = LocalDriverLicenceRepository(notes, catalogs);
  });

  tearDown(() async => db.close());

  Future<List<Note>> allRows() async => db.select(db.notes).get();

  test('nothing saved yet reads back null', () async {
    expect(await repo.getLicence(), isNull);
  });

  test('saving creates a note whose subject is exactly DriverLicence:self',
      () async {
    await repo.saveLicence(licence());

    final rows = await allRows();
    expect(rows, hasLength(1));
    expect(rows.single.subject, 'DriverLicence:self');
  });

  test('saving twice updates the one note rather than creating a second',
      () async {
    await repo.saveLicence(licence());
    await repo.saveLicence(const DriverLicence(number: 'CHANGED'));

    expect(await allRows(), hasLength(1));
    expect((await repo.getLicence())!.number, 'CHANGED');
  });

  test('the details survive a save and read back whole', () async {
    await repo.saveLicence(licence());

    final read = (await repo.getLicence())!;
    expect(read.number, 'D1234-56789');
    expect(read.licenceClass, 'G');
    expect(read.jurisdiction, 'Ontario');
    expect(read.issuedDate, DateTime.utc(2020, 5, 1));
    expect(read.expiryDate, DateTime.utc(2030, 5, 1));
  });

  test('both images reach the note attachments column, where VaultGc looks',
      () async {
    await repo.saveLicence(licence(f: front, b: back));

    final stored = (await allRows()).single.attachments;
    expect(stored, isNotNull);
    expect(stored, contains(front.path));
    expect(stored, contains(back.path));
  });

  test('both sides read back as refs, resolved from the column', () async {
    await repo.saveLicence(licence(f: front, b: back));

    final read = (await repo.getLicence())!;
    expect(read.frontImage, front);
    expect(read.backImage, back);
  });

  test('replacing the back leaves the front alone', () async {
    await repo.saveLicence(licence(f: front, b: back));

    const newBack = VaultRef(
      path: 'attachments/note-1/sensitive/back-2.jpg',
      contentType: 'image/jpeg',
      byteSize: 120,
      sensitive: true,
    );
    await repo.saveLicence(licence(f: front, b: newBack));

    final read = (await repo.getLicence())!;
    expect(read.frontImage, front);
    expect(read.backImage, newBack);

    // And the stale ref is gone from the column, or GC would keep its bytes
    // alive forever.
    expect((await allRows()).single.attachments, isNot(contains(back.path)));
  });

  test('dropping both images clears the column, not just the content',
      () async {
    await repo.saveLicence(licence(f: front, b: back));
    await repo.saveLicence(licence());

    final stored = (await allRows()).single.attachments ?? '';
    expect(stored, isNot(contains(front.path)));
    expect(stored, isNot(contains(back.path)));
    expect((await repo.getLicence())!.frontImage, isNull);
  });
}
