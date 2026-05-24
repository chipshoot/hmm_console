// Regression test for: after a gas station is renamed, gas logs referencing
// that station still surface the old name.
//
// Cause: `LocalGasLogRepository._serializeGasLog` denormalizes the station's
// current name into each gas-log note's JSON content alongside the
// stationId. Without intervention, updates to the station's `name` field
// never reach already-written notes.
//
// Fix: on read, `_deserializeGasLog` accepts an `id → station` snapshot
// from the station repo and prefers the live name. Falls back to the stored
// name when the station has been deleted, or when the log predates
// stationId tracking.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_gas_log_repository.dart';
import 'package:hmm_console/core/data/local/local_gas_station_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/gas_log/data/repositories/gas_station_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_station.dart';

Automobile _seedAuto() => Automobile(
      id: 0,
      vin: '1HGBH41JXMN109186',
      maker: 'Honda',
      brand: 'Honda',
      model: 'Civic',
      trim: 'Touring',
      year: 2020,
      color: 'Blue',
      plate: 'STATION-RENAME',
      engineType: '2.0L',
      fuelType: 'Regular',
      fuelTankCapacity: 12.4,
      cityMPG: 32,
      highwayMPG: 42,
      combinedMPG: 36,
      meterReading: 1,
      purchaseMeterReading: 1,
      purchasePrice: 22500,
      ownershipStatus: 'Owned',
      insuranceProvider: 'Acme',
      insurancePolicyNumber: 'POL-1234',
      isActive: true,
    );

GasLog _gasLog({
  required int autoId,
  required int? stationId,
  required String? stationName,
}) =>
    GasLog(
      id: 0,
      date: DateTime(2026, 5, 20, 9),
      automobileId: autoId,
      odometer: 100,
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
      stationId: stationId,
      stationName: stationName,
    );

GasStation _station({
  required String name,
  String? city,
}) =>
    GasStation(
      name: name,
      city: city,
      isActive: true,
    );

void main() {
  late HmmDatabase db;
  late LocalAutomobileRepository autoRepo;
  late LocalGasLogRepository gasLogRepo;
  late IGasStationRepository stationRepo;
  late int autoId;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'station-rename-tester'),
        );
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(aid)))
        .getSingle();

    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    autoRepo = LocalAutomobileRepository(noteRepo, catalogRepo);
    stationRepo = LocalGasStationRepository(noteRepo, catalogRepo);
    gasLogRepo = LocalGasLogRepository(
      noteRepo,
      catalogRepo,
      autoRepo,
      stationRepo,
    );

    final auto = await autoRepo.createAutomobile(_seedAuto());
    autoId = auto.id;
  });

  tearDown(() async {
    await db.close();
  });

  test('renamed station surfaces the new name on re-read of existing logs',
      () async {
    // 1) Create a station "Shell" and a gas log that references it.
    final original = await stationRepo.createGasStation(_station(name: 'Shell'));
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(
        autoId: autoId,
        stationId: original.id,
        stationName: original.name, // "Shell" — denormalized at write time
      ),
    );

    // 2) Sanity check: list returns "Shell" before the rename.
    final beforeRename = await gasLogRepo.getGasLogs(autoId);
    expect(beforeRename.items.single.stationName, equals('Shell'));

    // 3) Rename the station. This is the operation that previously left
    //    already-written gas logs out of sync.
    await stationRepo.updateGasStation(
      original.id!,
      original.copyWith(name: 'Shell Centennial'),
    );

    // 4) Re-read the gas log — it must surface the NEW name.
    final afterRename = await gasLogRepo.getGasLogs(autoId);
    expect(
      afterRename.items.single.stationName,
      equals('Shell Centennial'),
      reason: 'gas log should resolve stationName from current station, '
          'not the stale name baked into its note content',
    );

    // 5) getGasLogById takes the same code path — verify it too.
    final logId = afterRename.items.single.id;
    expect(logId, isNotNull);
    final byId = await gasLogRepo.getGasLogById(autoId, logId!);
    expect(byId.stationName, equals('Shell Centennial'));
  });

  test('deleted station falls back to the stored name (historical record)',
      () async {
    // A gas log written against "Esso" should still SAY "Esso" after the
    // station is deleted — the bug is "shows stale name after rename", not
    // "drops the name when the station no longer exists". Historical fuel
    // records should remain self-describing.
    final esso = await stationRepo.createGasStation(_station(name: 'Esso'));
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(
        autoId: autoId,
        stationId: esso.id,
        stationName: esso.name,
      ),
    );

    await stationRepo.deleteGasStation(esso.id!);

    final logs = await gasLogRepo.getGasLogs(autoId);
    expect(logs.items.single.stationName, equals('Esso'));
  });

  test('log without stationId keeps its stored name unchanged', () async {
    // Pre-station-id-tracking logs (or manual one-off entries) had only a
    // name. The resolver must leave those alone — there's no stationId to
    // look up, so the stored name is the only source of truth.
    await gasLogRepo.createGasLog(
      autoId,
      _gasLog(
        autoId: autoId,
        stationId: null,
        stationName: 'Mom-and-Pop Refuel',
      ),
    );

    final logs = await gasLogRepo.getGasLogs(autoId);
    expect(logs.items.single.stationId, isNull);
    expect(logs.items.single.stationName, equals('Mom-and-Pop Refuel'));
  });
}
