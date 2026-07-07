import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/file_byte_source.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_service_record_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';
import 'package:hmm_console/features/automobile_records/states/mutate_service_record_state.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

/// In-memory vault that records writes/deletes.
class _MemVault implements IVaultStore {
  final Map<String, Uint8List> store = {};
  final List<String> deleted = [];
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async =>
      store[p] = b;
  @override
  Future<Uint8List> getBytes(String p) async => store[p]!;
  @override
  Future<bool> exists(String p) async => store.containsKey(p);
  @override
  Future<void> delete(String p) async {
    deleted.add(p);
    store.remove(p);
  }

  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

class _FakePicker implements IImageAttachmentPicker {
  _FakePicker(this.vault);
  final _MemVault vault;
  int _n = 0;
  @override
  Future<VaultRef?> pickForNote(
          {required int noteId,
          AttachmentPickSource source = AttachmentPickSource.gallery}) async =>
      null;
  @override
  Future<VaultRef> persistToVault(
      {required int noteId,
      required Uint8List bytes,
      required String originalName,
      String? contentTypeHint}) async {
    final path = 'attachments/note-$noteId/img${_n++}.jpg';
    await vault.putBytes(path, bytes, contentType: 'image/jpeg');
    return VaultRef(
        path: path,
        contentType: 'image/jpeg',
        byteSize: bytes.length,
        originalName: originalName);
  }

  @override
  Future<VaultRef> persistFileToVault(
      {required int noteId,
      required Uint8List bytes,
      required String originalName,
      required String contentType}) async {
    final path = 'attachments/note-$noteId/file${_n++}.pdf';
    await vault.putBytes(path, bytes, contentType: contentType);
    return VaultRef(
        path: path,
        contentType: contentType,
        byteSize: bytes.length,
        originalName: originalName);
  }
}

/// Minimal stub for the DataModeNotifier under test (no prefs access).
class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

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

void main() {
  late HmmDatabase db;
  late _MemVault vault;
  late LocalServiceRecordRepository serviceRepo;
  late int autoId;

  Future<ProviderContainer> container({DataMode mode = DataMode.local}) async {
    final c = ProviderContainer(overrides: [
      serviceRecordRepositoryModeProvider.overrideWithValue(serviceRepo),
      vaultStoreProvider.overrideWith((ref) async => vault),
      imageAttachmentPickerProvider
          .overrideWith((ref) async => _FakePicker(vault)),
      dataModeProvider.overrideWith(() => _StubMode(mode)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    vault = _MemVault();
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    serviceRepo = LocalServiceRecordRepository(noteRepo, catalogRepo);
    autoId = (await LocalAutomobileRepository(noteRepo, catalogRepo)
            .createAutomobile(_seedAuto()))
        .id;
  });

  tearDown(() async => db.close());

  ServiceRecord newRecord() => ServiceRecord(
      id: 0,
      automobileId: autoId,
      date: DateTime(2026),
      mileage: 50,
      type: ServiceType.oilChange);

  test('new record persists pending image + pdf as VaultRefs', () async {
    final c = await container();
    await c.read(mutateServiceRecordStateProvider.notifier).save(
      autoId: autoId,
      record: newRecord(),
      isEdit: false,
      pendingImages: [
        PickedImageBytes(bytes: Uint8List.fromList([9]), originalName: 'p.jpg')
      ],
      pendingFiles: [
        PickedFileBytes(
            bytes: Uint8List.fromList([8]),
            originalName: 'r.pdf',
            contentType: 'application/pdf')
      ],
    );
    final records = await serviceRepo.getRecords(autoId);
    expect(records, hasLength(1));
    expect(records.single.attachments.images, hasLength(1));
    expect(records.single.attachments.files, hasLength(1));
    expect(vault.store.keys.where((k) => k.endsWith('.jpg')), isNotEmpty);
  });

  test('line items survive when a new record is saved with a scanned pdf',
      () async {
    // Reproduces the receipt-scan flow: the scanned PDF becomes a pending
    // file attachment, so save() runs step 4 (updateRecord with attachments)
    // after step 1 created the record with its parts.
    final c = await container();
    final record = ServiceRecord(
      id: 0,
      automobileId: autoId,
      date: DateTime(2026),
      mileage: 50,
      type: ServiceType.oilChange,
      parts: const [
        PartItem(
            type: LineItemType.part,
            name: 'Oil filter',
            quantity: 1,
            unitCost: 12.0,
            currency: 'CAD'),
        PartItem(
            type: LineItemType.labour,
            name: 'Labour',
            quantity: 1,
            unitCost: 40.0,
            currency: 'CAD'),
      ],
    );
    await c.read(mutateServiceRecordStateProvider.notifier).save(
      autoId: autoId,
      record: record,
      isEdit: false,
      pendingFiles: [
        PickedFileBytes(
            bytes: Uint8List.fromList([8]),
            originalName: 'receipt.pdf',
            contentType: 'application/pdf')
      ],
    );

    final records = await serviceRepo.getRecords(autoId);
    expect(records, hasLength(1));
    expect(records.single.attachments.files, hasLength(1));
    expect(records.single.parts, hasLength(2),
        reason: 'line items must survive the attachment save step');
    expect(records.single.parts.map((p) => p.name),
        containsAll(['Oil filter', 'Labour']));
  });

  test('removing an attachment deletes its bytes', () async {
    final c = await container();
    final created = await serviceRepo.createRecord(autoId, newRecord());
    const ref = VaultRef(
        path: 'attachments/note-x/old.pdf',
        contentType: 'application/pdf',
        byteSize: 3);
    vault.store[ref.path] = Uint8List.fromList([1, 2, 3]);
    await c.read(mutateServiceRecordStateProvider.notifier).save(
          autoId: autoId,
          record: created,
          isEdit: true,
          removed: const [ref],
        );
    expect(vault.deleted, contains(ref.path));
  });

  test('a plain record with no attachments saves even if the vault fails to '
      'initialise (no attachment work must not touch the vault)', () async {
    final c = ProviderContainer(overrides: [
      serviceRecordRepositoryModeProvider.overrideWithValue(serviceRepo),
      vaultStoreProvider.overrideWith((ref) async => throw StateError('boom')),
      imageAttachmentPickerProvider
          .overrideWith((ref) async => throw StateError('boom')),
      dataModeProvider.overrideWith(() => _StubMode(DataMode.local)),
    ]);
    addTearDown(c.dispose);

    await c.read(mutateServiceRecordStateProvider.notifier).save(
          autoId: autoId,
          record: newRecord(),
          isEdit: false,
        );

    final records = await serviceRepo.getRecords(autoId);
    expect(records, hasLength(1));
    expect(c.read(mutateServiceRecordStateProvider).hasError, isFalse);
  });

  test('cloudApi mode skips vault work', () async {
    final c = await container(mode: DataMode.cloudApi);
    await c.read(mutateServiceRecordStateProvider.notifier).save(
      autoId: autoId,
      record: newRecord(),
      isEdit: false,
      pendingImages: [
        PickedImageBytes(bytes: Uint8List.fromList([9]), originalName: 'p.jpg')
      ],
    );
    // No bytes were written to the vault in cloudApi mode.
    expect(vault.store, isEmpty);
  });
}
