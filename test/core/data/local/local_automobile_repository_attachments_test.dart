// Phase 12: Automobile carries its attachments as a read-through
// projection of the owning note's `attachments` column.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

Automobile _automobile({
  AttachmentRef? primaryImage,
  List<AttachmentRef> images = const [],
}) {
  return Automobile(
    id: 0,
    vin: '1HGBH41JXMN109186',
    maker: 'Honda',
    brand: 'Honda',
    model: 'Civic',
    year: 2020,
    plate: 'TEST-001',
    engineType: 'Gasoline',
    fuelType: 'Regular',
    meterReading: 1,
    isActive: true,
    primaryImage: primaryImage,
    images: images,
  );
}

void main() {
  late HmmDatabase db;
  late LocalAutomobileRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'tester'),
        );
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid)))
            .getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    repo = LocalAutomobileRepository(noteRepo, catalogRepo);
  });

  tearDown(() async {
    await db.close();
  });

  test('createAutomobile without attachments persists null column',
      () async {
    final created = await repo.createAutomobile(_automobile());
    expect(created.primaryImage, isNull);
    expect(created.images, isEmpty);

    final row = await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
        .getSingle();
    expect(row.attachments, isNull);
  });

  test('createAutomobile with a primary image round-trips via getById',
      () async {
    const ref = VaultRef(
      path: 'attachments/note-1/main.jpg',
      contentType: 'image/jpeg',
      byteSize: 1000,
    );
    final created = await repo.createAutomobile(
      _automobile(primaryImage: ref),
    );
    expect(created.primaryImage, equals(ref));

    final fetched = await repo.getAutomobileById(created.id);
    expect(fetched.primaryImage, equals(ref));
    expect(fetched.images, isEmpty);
  });

  test('updateAutomobile replaces the photo set', () async {
    const first = VaultRef(
      path: 'attachments/note-1/first.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
    );
    const second = VaultRef(
      path: 'attachments/note-1/second.jpg',
      contentType: 'image/jpeg',
      byteSize: 200,
    );

    final created = await repo.createAutomobile(
      _automobile(primaryImage: first),
    );

    final replaced = Automobile(
      id: created.id,
      vin: created.vin,
      maker: created.maker,
      brand: created.brand,
      model: created.model,
      year: created.year,
      plate: created.plate,
      engineType: created.engineType,
      fuelType: created.fuelType,
      meterReading: created.meterReading,
      isActive: true,
      primaryImage: second,
    );
    await repo.updateAutomobile(created.id, replaced);

    final after = await repo.getAutomobileById(created.id);
    expect(after.primaryImage, equals(second));
  });

  test('updateAutomobile with no photos clears the column', () async {
    const ref = VaultRef(
      path: 'attachments/note-1/temp.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
    );
    final created = await repo.createAutomobile(
      _automobile(primaryImage: ref),
    );

    final without = Automobile(
      id: created.id,
      vin: created.vin,
      maker: created.maker,
      brand: created.brand,
      model: created.model,
      year: created.year,
      plate: created.plate,
      engineType: created.engineType,
      fuelType: created.fuelType,
      meterReading: created.meterReading,
      isActive: true,
    );
    await repo.updateAutomobile(created.id, without);

    final after = await repo.getAutomobileById(created.id);
    expect(after.primaryImage, isNull);
    expect(after.images, isEmpty);

    final row = await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
        .getSingle();
    expect(row.attachments, isNull);
  });

  test('a gallery of multiple images round-trips and preserves order',
      () async {
    final gallery = [
      const VaultRef(
        path: 'attachments/note-1/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 1,
      ),
      const VaultRef(
        path: 'attachments/note-1/b.jpg',
        contentType: 'image/jpeg',
        byteSize: 2,
      ),
      const VaultRef(
        path: 'attachments/note-1/c.jpg',
        contentType: 'image/jpeg',
        byteSize: 3,
      ),
    ];
    final created = await repo.createAutomobile(
      _automobile(images: gallery),
    );

    final after = await repo.getAutomobileById(created.id);
    expect(after.primaryImage, isNull);
    expect(after.images, equals(gallery));
  });

  test('content JSON does not contain the attachment refs', () async {
    const ref = VaultRef(
      path: 'attachments/note-1/contentless.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
    );
    final created = await repo.createAutomobile(
      _automobile(primaryImage: ref),
    );

    final row = await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
        .getSingle();
    // The content blob holds the AutomobileInfo data only; attachment
    // refs live in the separate column.
    expect(row.content, isNotNull);
    expect(row.content!.contains('primaryImage'), isFalse);
    expect(row.content!.contains('"images"'), isFalse);
    expect(row.attachments, isNotNull);
    expect(row.attachments!.contains('contentless.jpg'), isTrue);
  });
}
