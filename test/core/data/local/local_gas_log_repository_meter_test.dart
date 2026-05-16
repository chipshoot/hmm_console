// Regression test for the Live-Entry odometer-propagation bug:
// `LocalGasLogRepository.createGasLog` (live tier path) must bump the
// parent automobile's meterReading when the new odometer is higher;
// `createHistoryGasLog` must NOT touch it.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_gas_log_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';

Automobile _seedAuto({int meter = 1}) => Automobile(
      id: 0,
      vin: '1HGBH41JXMN109186',
      maker: 'Honda',
      brand: 'Honda',
      model: 'Civic',
      year: 2020,
      plate: 'METER-TEST',
      engineType: 'Gasoline',
      fuelType: 'Regular',
      meterReading: meter,
      isActive: true,
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
}
