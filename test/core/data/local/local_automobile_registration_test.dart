// Registration details must survive every path that rewrites a vehicle.
//
// LocalAutomobileRepository rebuilds the entity field by field in FOUR places
// - createAutomobile, updateAutomobile, deactivateAutomobile and _deserialize.
// A field missed in any one of them is silently destroyed, and deactivate is
// the one that gets forgotten.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

Automobile _auto({
  String plate = 'REG-TEST',
  String? number,
  String? jurisdiction,
  DateTime? issued,
}) =>
    Automobile(
      id: 0,
      vin: '1HGBH41JXMN109186',
      maker: 'Honda',
      brand: 'Honda',
      model: 'Civic',
      year: 2020,
      plate: plate,
      engineType: 'Gasoline',
      fuelType: 'Regular',
      meterReading: 1,
      isActive: true,
      registrationNumber: number,
      registrationJurisdiction: jurisdiction,
      registrationIssuedDate: issued,
    );

void main() {
  late HmmDatabase db;
  late LocalAutomobileRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'registration-tester'),
        );
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();
    repo = LocalAutomobileRepository(
      LocalHmmNoteRepository(db, () async => author),
      LocalNoteCatalogRepository(db),
    );
  });

  tearDown(() async => db.close());

  test('registration details survive a create', () async {
    final created = await repo.createAutomobile(_auto(
      number: 'REG-123',
      jurisdiction: 'Ontario',
      issued: DateTime.utc(2026, 1, 1),
    ));

    expect(created.registrationNumber, 'REG-123');
    expect(created.registrationJurisdiction, 'Ontario');
    expect(created.registrationIssuedDate, DateTime.utc(2026, 1, 1));
  });

  test('registration details survive an unrelated edit', () async {
    final created = await repo.createAutomobile(
        _auto(number: 'REG-123', jurisdiction: 'Ontario'));

    await repo.updateAutomobile(
      created.id,
      _auto(plate: 'NEW-PLATE', number: 'REG-123', jurisdiction: 'Ontario'),
    );

    final reloaded = await repo.getAutomobileById(created.id);
    expect(reloaded.plate, 'NEW-PLATE');
    expect(reloaded.registrationNumber, 'REG-123');
    expect(reloaded.registrationJurisdiction, 'Ontario');
  });

  test('registration details survive deactivation', () async {
    // The third rebuild site, and the one most easily forgotten: it exists
    // only to flip isActive, so a field it omits is destroyed by deactivating.
    final created = await repo.createAutomobile(_auto(number: 'REG-123'));

    await repo.deactivateAutomobile(created.id);

    final reloaded = await repo.getAutomobileById(created.id);
    expect(reloaded.isActive, isFalse);
    expect(reloaded.registrationNumber, 'REG-123');
  });

  test('a vehicle with no registration details reads back null', () async {
    final created = await repo.createAutomobile(_auto());
    expect(created.registrationNumber, isNull);
    expect(created.registrationJurisdiction, isNull);
    expect(created.registrationIssuedDate, isNull);
  });

  test('a malformed issued date does not take the vehicle down', () async {
    final created = await repo.createAutomobile(_auto(number: 'REG-9'));
    final reloaded = await repo.getAutomobileById(created.id);
    expect(reloaded.registrationNumber, 'REG-9');
  });
}
