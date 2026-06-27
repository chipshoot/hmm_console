import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_service_record_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

Automobile _seedAuto() => Automobile(
      id: 0, vin: '1HGBH41JXMN109186', maker: 'Honda', brand: 'Honda',
      model: 'Civic', trim: 'T', year: 2020, color: 'Blue', plate: 'SVC-1',
      engineType: 'Gasoline', fuelType: 'Regular', fuelTankCapacity: 12.4,
      cityMPG: 32, highwayMPG: 42, combinedMPG: 36, meterReading: 1,
      purchaseMeterReading: 1, purchasePrice: 22500, ownershipStatus: 'Owned',
      insuranceProvider: 'Acme', insurancePolicyNumber: 'POL-1', isActive: true,
      notes: '');

void main() {
  late HmmDatabase db;
  late LocalServiceRecordRepository repo;
  late int autoId;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    final autoRepo = LocalAutomobileRepository(noteRepo, catalogRepo);
    repo = LocalServiceRecordRepository(noteRepo, catalogRepo);
    final created = await autoRepo.createAutomobile(_seedAuto());
    autoId = created.id;
  });

  tearDown(() async => db.close());

  test('typed line items + tax survive create -> read', () async {
    final created = await repo.createRecord(autoId, ServiceRecord(
      id: 0, automobileId: autoId, date: DateTime(2026), mileage: 100,
      type: ServiceType.oilChange, tax: 5.0,
      parts: const [
        PartItem(type: LineItemType.labour, name: 'L', quantity: 1, unitCost: 10.0),
        PartItem(type: LineItemType.fee, name: 'Env', quantity: 1, unitCost: 1.5),
      ],
    ));
    final back = await repo.getRecordById(autoId, created.id);
    expect(back.parts[0].type, LineItemType.labour);
    expect(back.parts[1].type, LineItemType.fee);
    expect(back.tax, 5.0);
    expect(back.grandTotal, closeTo(16.5, 1e-9));
  });
}
