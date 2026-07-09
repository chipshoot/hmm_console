import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_service_record_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

Automobile _seedAuto() => Automobile(
    id: 0,
    vin: '1HGBH41JXMN109186',
    maker: 'Honda',
    brand: 'Honda',
    model: 'Civic',
    year: 2020,
    plate: 'SVC-1',
    engineType: 'Gasoline',
    fuelType: 'Regular',
    meterReading: 1,
    isActive: true);

const _img = VaultRef(
    path: 'attachments/note-2/photo.jpg',
    contentType: 'image/jpeg',
    byteSize: 1000,
    originalName: 'photo.jpg');
const _pdf = VaultRef(
    path: 'attachments/note-2/receipt.pdf',
    contentType: 'application/pdf',
    byteSize: 2000,
    originalName: 'receipt.pdf');

void main() {
  late HmmDatabase db;
  late LocalServiceRecordRepository repo;
  late int autoId;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    final autoRepo = LocalAutomobileRepository(noteRepo, catalogRepo);
    repo = LocalServiceRecordRepository(noteRepo, catalogRepo);
    autoId = (await autoRepo.createAutomobile(_seedAuto())).id;
  });

  tearDown(() async => db.close());

  ServiceRecord record({NoteAttachments? attachments}) => ServiceRecord(
      id: 0,
      automobileId: autoId,
      date: DateTime(2026),
      mileage: 100,
      types: const [ServiceType.oilChange],
      attachments: attachments);

  test('create without attachments leaves the column null', () async {
    final created = await repo.createRecord(autoId, record());
    expect(created.attachments.isEmpty, isTrue);
    final row =
        await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
            .getSingle();
    expect(row.attachments, isNull);
  });

  test('image + pdf round-trip via getRecordById, not in content', () async {
    final created = await repo.createRecord(autoId, record());
    await repo.updateRecord(
        autoId,
        created.id,
        created.copyWith(
            attachments:
                NoteAttachments(images: const [_img], files: const [_pdf])));

    final back = await repo.getRecordById(autoId, created.id);
    expect(back.attachments.images, [_img]);
    expect(back.attachments.files, [_pdf]);

    final row =
        await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
            .getSingle();
    expect(row.content!.contains('photo.jpg'), isFalse);
    expect(row.attachments!.contains('receipt.pdf'), isTrue);
  });

  test('update with empty attachments clears the column', () async {
    final created = await repo.createRecord(
        autoId, record(attachments: NoteAttachments(images: const [_img])));
    await repo.updateRecord(autoId, created.id,
        created.copyWith(attachments: NoteAttachments.empty));
    final row =
        await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
            .getSingle();
    expect(row.attachments, isNull);
  });
}
