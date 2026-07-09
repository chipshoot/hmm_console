import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_service_record_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository noteRepo;
  late LocalNoteCatalogRepository catalogRepo;
  late LocalServiceRecordRepository repo;

  Future<void> setup() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid)))
            .getSingle();
    noteRepo = LocalHmmNoteRepository(db, () async => author);
    catalogRepo = LocalNoteCatalogRepository(db);
    repo = LocalServiceRecordRepository(noteRepo, catalogRepo);
  }

  test('round-trips name + referenceNumber through Drift', () async {
    await setup();
    addTearDown(db.close);
    final created = await repo.createRecord(
      7,
      ServiceRecord(
          id: 0,
          automobileId: 7,
          date: DateTime(2026),
          mileage: 50,
          types: const [ServiceType.oilChange],
          name: 'Service A',
          referenceNumber: 'SO#952333'),
    );
    final reloaded = await repo.getRecordById(7, created.id);
    expect(reloaded.name, 'Service A');
    expect(reloaded.referenceNumber, 'SO#952333');
  });

  test('writes types array and reads it back', () async {
    await setup();
    addTearDown(db.close);
    final created = await repo.createRecord(
      7,
      ServiceRecord(
          id: 0,
          automobileId: 7,
          date: DateTime(2026),
          mileage: 50,
          types: const [ServiceType.oilChange, ServiceType.inspection]),
    );
    final reloaded = await repo.getRecordById(7, created.id);
    expect(reloaded.types, [ServiceType.oilChange, ServiceType.inspection]);
  });

  test('reads a legacy single-type payload as a one-element types list',
      () async {
    await setup();
    addTearDown(db.close);
    // A pre-migration note: content carries a single "type" and no "types".
    final legacyContent = jsonEncode({
      'note': {
        'content': {
          'ServiceRecord': {
            'automobileId': 7,
            'date': DateTime(2026).toUtc().toIso8601String(),
            'mileage': 50,
            'type': 'Brake',
            'parts': <dynamic>[],
            '_v': 1,
          }
        }
      }
    });
    final catalog = await catalogRepo.getOrCreateCatalog('legacy', '{}');
    final note = await noteRepo.createNote(HmmNoteCreate(
      subject: 'legacy',
      content: legacyContent,
      catalogId: catalog.id,
      parentNoteId: 7,
    ));
    final reloaded = await repo.getRecordById(7, note.id);
    expect(reloaded.types, [ServiceType.brake]);
  });
}
