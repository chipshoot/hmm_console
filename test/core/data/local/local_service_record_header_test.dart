import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_service_record_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

void main() {
  test('round-trips name + referenceNumber through Drift', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid)))
            .getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final repo =
        LocalServiceRecordRepository(noteRepo, LocalNoteCatalogRepository(db));

    final created = await repo.createRecord(
      7,
      ServiceRecord(
          id: 0,
          automobileId: 7,
          date: DateTime(2026),
          mileage: 50,
          type: ServiceType.oilChange,
          name: 'Service A',
          referenceNumber: 'SO#952333'),
    );
    final reloaded = await repo.getRecordById(7, created.id);
    expect(reloaded.name, 'Service A');
    expect(reloaded.referenceNumber, 'SO#952333');
  });
}
