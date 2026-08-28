// Registration scans ride the vehicle note's attachments column.
//
// The entity already carried primaryImage (the headline photo) and images;
// `files` - where a PDF scan lands - was neither exposed nor persisted.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

const _photo = VaultRef(
    path: 'attachments/note-1/car.jpg',
    contentType: 'image/jpeg',
    byteSize: 10,
    originalName: 'car.jpg');
const _scanImage = VaultRef(
    path: 'attachments/note-1/registration.jpg',
    contentType: 'image/jpeg',
    byteSize: 20,
    originalName: 'registration.jpg',
    sensitive: true);
const _scanPdf = VaultRef(
    path: 'attachments/note-1/registration.pdf',
    contentType: 'application/pdf',
    byteSize: 30,
    originalName: 'registration.pdf',
    sensitive: true);

Automobile _auto({
  String plate = 'SCAN-1',
  AttachmentRef? primaryImage,
  List<AttachmentRef> images = const [],
  List<AttachmentRef> files = const [],
}) =>
    Automobile(
      id: 0,
      year: 2020,
      plate: plate,
      meterReading: 1,
      isActive: true,
      primaryImage: primaryImage,
      images: images,
      files: files,
    );

void main() {
  late HmmDatabase db;
  late LocalAutomobileRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'auto-attachments-tester'),
        );
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();
    repo = LocalAutomobileRepository(
      LocalHmmNoteRepository(db, () async => author),
      LocalNoteCatalogRepository(db),
    );
  });

  tearDown(() async => db.close());

  test('an image scan survives a create', () async {
    final created = await repo.createAutomobile(_auto(images: const [_scanImage]));
    expect(created.images.single, _scanImage);
  });

  test('a PDF scan survives a create', () async {
    final created = await repo.createAutomobile(_auto(files: const [_scanPdf]));
    expect(created.files.single, _scanPdf);
  });

  test('scans survive an unrelated edit', () async {
    final created = await repo.createAutomobile(
        _auto(images: const [_scanImage], files: const [_scanPdf]));

    await repo.updateAutomobile(
      created.id,
      _auto(plate: 'NEW-PLATE', images: const [_scanImage], files: const [_scanPdf]),
    );

    final reloaded = await repo.getAutomobileById(created.id);
    expect(reloaded.plate, 'NEW-PLATE');
    expect(reloaded.images.single, _scanImage);
    expect(reloaded.files.single, _scanPdf);
  });

  test('scans survive deactivation', () async {
    // deactivateAutomobile rewrites CONTENT only - it passes no `attachments`
    // to updateNote, so the column is left alone and the scans survive. That
    // is load-bearing: its rebuilt entity does NOT carry primaryImage/images/
    // files, so "improving" it to pass attachments would wipe every scan.
    final created = await repo.createAutomobile(
        _auto(images: const [_scanImage], files: const [_scanPdf]));

    await repo.deactivateAutomobile(created.id);

    final reloaded = await repo.getAutomobileById(created.id);
    expect(reloaded.isActive, isFalse);
    expect(reloaded.images.single, _scanImage);
    expect(reloaded.files.single, _scanPdf);
  });

  test('the car photo stays in primaryImage and is not adopted as a scan',
      () async {
    final created = await repo.createAutomobile(
        _auto(primaryImage: _photo, images: const [_scanImage]));

    expect(created.primaryImage, _photo);
    expect(created.images, [_scanImage]);
    expect(created.images, isNot(contains(_photo)));
  });

  test('a vehicle with no scans reads back empty', () async {
    final created = await repo.createAutomobile(_auto());
    expect(created.images, isEmpty);
    expect(created.files, isEmpty);
  });
}
