// Regression test for the Live-Entry odometer-propagation bug:
// `LocalGasLogRepository.createGasLog` (live tier path) must bump the
// parent automobile's meterReading when the new odometer is higher;
// `createHistoryGasLog` must NOT touch it.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_gas_log_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';

Automobile _seedAuto({
  int meter = 1,
  String plate = 'METER-TEST',
  AttachmentRef? primaryImage,
  List<AttachmentRef> images = const [],
}) =>
    Automobile(
      id: 0,
      vin: '1HGBH41JXMN109186',
      maker: 'Honda',
      brand: 'Honda',
      model: 'Civic',
      trim: 'Touring',
      year: 2020,
      color: 'Blue',
      plate: plate,
      engineType: 'Gasoline',
      fuelType: 'Regular',
      fuelTankCapacity: 12.4,
      cityMPG: 32,
      highwayMPG: 42,
      combinedMPG: 36,
      meterReading: meter,
      purchaseMeterReading: 12,
      purchasePrice: 22500,
      ownershipStatus: 'Owned',
      insuranceProvider: 'Acme',
      insurancePolicyNumber: 'POL-1234',
      isActive: true,
      notes: 'A real car with real fields',
      primaryImage: primaryImage,
      images: images,
    );

GasLog _gasLog({required int autoId, required double odometer}) => GasLog(
      id: 0,
      date: DateTime(2026, 5, 16, 10),
      automobileId: autoId,
      odometer: odometer,
      odometerUnit: 'Mile',
      distance: 100,
      distanceUnit: 'Mile',
      fuel: 5,
      fuelUnit: 'Gallon',
      fuelGrade: 'Regular',
      isFullTank: true,
      totalPrice: 20,
      unitPrice: 4,
      currency: 'CAD',
    );

void main() {
  late HmmDatabase db;
  late LocalAutomobileRepository autoRepo;
  late LocalGasLogRepository gasLogRepo;
  late int autoId;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());

    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'tester'),
        );
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(aid)))
        .getSingle();

    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    autoRepo = LocalAutomobileRepository(noteRepo, catalogRepo);
    gasLogRepo = LocalGasLogRepository(noteRepo, catalogRepo, autoRepo);

    final created = await autoRepo.createAutomobile(_seedAuto());
    autoId = created.id;
  });

  tearDown(() async {
    await db.close();
  });

  test('live gas log with higher odometer bumps the meter', () async {
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 100),
    );
    final after = await autoRepo.getAutomobileById(autoId);
    expect(after.meterReading, equals(100));
  });

  test('live gas log with same/lower odometer leaves the meter alone',
      () async {
    // Set the meter to 200 first.
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 200),
    );
    final mid = await autoRepo.getAutomobileById(autoId);
    expect(mid.meterReading, equals(200));

    // A "live" entry with a LOWER odometer (UI generally prevents this,
    // but the repo must be safe regardless) must not regress the meter.
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 150),
    );
    final after = await autoRepo.getAutomobileById(autoId);
    expect(after.meterReading, equals(200));
  });

  test('historical gas log never touches the meter', () async {
    // Start with meter at 1; record a historical fill-up at odometer 999.
    await gasLogRepo.createHistoryGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 999),
    );
    final after = await autoRepo.getAutomobileById(autoId);
    expect(after.meterReading, equals(1));
  });

  test('fractional odometer rounds to int when bumping meter', () async {
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 100.6),
    );
    final after = await autoRepo.getAutomobileById(autoId);
    expect(after.meterReading, equals(101));
  });

  test('odometer EQUAL to current meter is a no-op (not a regression)',
      () async {
    final before = await autoRepo.getAutomobileById(autoId);
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: before.meterReading.toDouble()),
    );
    final after = await autoRepo.getAutomobileById(autoId);
    expect(after.meterReading, equals(before.meterReading));
  });

  test('three sequential live entries each bump the meter monotonically',
      () async {
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 250),
    );
    expect((await autoRepo.getAutomobileById(autoId)).meterReading,
        equals(250));

    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 500),
    );
    expect((await autoRepo.getAutomobileById(autoId)).meterReading,
        equals(500));

    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 1000),
    );
    expect((await autoRepo.getAutomobileById(autoId)).meterReading,
        equals(1000));
  });

  test('meter bump preserves every other automobile field', () async {
    final before = await autoRepo.getAutomobileById(autoId);

    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 1234),
    );

    final after = await autoRepo.getAutomobileById(autoId);
    expect(after.meterReading, equals(1234));
    // Spot-check the fields most likely to get clobbered by a sloppy
    // "build new Automobile with one field changed" implementation.
    expect(after.vin, equals(before.vin));
    expect(after.maker, equals(before.maker));
    expect(after.brand, equals(before.brand));
    expect(after.model, equals(before.model));
    expect(after.trim, equals(before.trim));
    expect(after.year, equals(before.year));
    expect(after.color, equals(before.color));
    expect(after.plate, equals(before.plate));
    expect(after.engineType, equals(before.engineType));
    expect(after.fuelType, equals(before.fuelType));
    expect(after.fuelTankCapacity, equals(before.fuelTankCapacity));
    expect(after.cityMPG, equals(before.cityMPG));
    expect(after.highwayMPG, equals(before.highwayMPG));
    expect(after.combinedMPG, equals(before.combinedMPG));
    expect(after.purchaseMeterReading, equals(before.purchaseMeterReading));
    expect(after.purchasePrice, equals(before.purchasePrice));
    expect(after.ownershipStatus, equals(before.ownershipStatus));
    expect(after.insuranceProvider, equals(before.insuranceProvider));
    expect(after.insurancePolicyNumber, equals(before.insurancePolicyNumber));
    expect(after.notes, equals(before.notes));
    expect(after.isActive, equals(before.isActive));
  });

  test('meter bump preserves the photo (regression for Phase 12)',
      () async {
    // Seed a second automobile with a primary image and a gallery.
    const primary = VaultRef(
      path: 'attachments/note-2/main.jpg',
      contentType: 'image/jpeg',
      byteSize: 200,
    );
    const gallery = [
      VaultRef(
        path: 'attachments/note-2/extra.jpg',
        contentType: 'image/jpeg',
        byteSize: 50,
      ),
    ];
    final withPhotos = await autoRepo.createAutomobile(
      _seedAuto(plate: 'PHOTO-CAR', primaryImage: primary, images: gallery),
    );

    await gasLogRepo.createGasLog(
      withPhotos.id,
      _gasLog(autoId: withPhotos.id, odometer: 4321),
    );

    final after = await autoRepo.getAutomobileById(withPhotos.id);
    expect(after.meterReading, equals(4321));
    expect(after.primaryImage, equals(primary));
    expect(after.images, equals(gallery));
  });

  test('live entry only touches the parent automobile, not siblings',
      () async {
    // Add a second automobile alongside the seeded one.
    final sibling = await autoRepo.createAutomobile(
      _seedAuto(plate: 'OTHER-CAR', meter: 5000),
    );

    // Live entry on the first car only.
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(autoId: autoId, odometer: 333),
    );

    final firstAfter = await autoRepo.getAutomobileById(autoId);
    final siblingAfter = await autoRepo.getAutomobileById(sibling.id);
    expect(firstAfter.meterReading, equals(333));
    expect(siblingAfter.meterReading, equals(5000)); // untouched
  });

  test('historical entry on a car with a photo preserves the photo too',
      () async {
    const primary = VaultRef(
      path: 'attachments/note-3/historic.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
    );
    final withPhoto = await autoRepo.createAutomobile(
      _seedAuto(plate: 'HIST-CAR', primaryImage: primary),
    );

    await gasLogRepo.createHistoryGasLog(
      withPhoto.id,
      _gasLog(autoId: withPhoto.id, odometer: 9999),
    );

    final after = await autoRepo.getAutomobileById(withPhoto.id);
    // Historical → meter unchanged, photo unchanged.
    expect(after.meterReading, equals(1));
    expect(after.primaryImage, equals(primary));
  });
}
