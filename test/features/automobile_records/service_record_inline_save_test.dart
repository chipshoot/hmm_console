import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
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
import 'package:hmm_console/features/automobile_records/presentation/screens/service_record_form_screen.dart';
import 'package:hmm_console/features/automobile_records/presentation/widgets/optional_date_picker.dart';
import 'package:hmm_console/features/automobile_records/states/mutate_service_record_state.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

/// In-memory vault that records writes.
class _MemVault implements IVaultStore {
  final Map<String, Uint8List> store = {};
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async =>
      store[p] = b;
  @override
  Future<Uint8List> getBytes(String p) async => store[p]!;
  @override
  Future<bool> exists(String p) async => store.containsKey(p);
  @override
  Future<void> delete(String p) async => store.remove(p);
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
      String? contentTypeHint,
      bool sensitive = false}) async {
    final path = 'attachments/note-$noteId/img${_n++}.png';
    await vault.putBytes(path, bytes, contentType: 'image/png');
    return VaultRef(
        path: path,
        contentType: 'image/png',
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

/// Picker whose vault writes always fail — models a persist failure (disk full,
/// permission error) so the failed pick's placeholder must be stripped.
class _ThrowingPicker implements IImageAttachmentPicker {
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
          String? contentTypeHint,
          bool sensitive = false}) async =>
      throw StateError('vault write failed');
  @override
  Future<VaultRef> persistFileToVault(
          {required int noteId,
          required Uint8List bytes,
          required String originalName,
          required String contentType}) async =>
      throw StateError('vault write failed');
}

class _FakeImageSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(
        bytes: Uint8List.fromList(_png1x1),
        originalName: 'shot.png',
        contentType: 'image/png',
      );
}

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

const _png1x1 = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

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

  testWidgets(
      'saving a new record with an inline image rewrites notes + attaches it',
      (tester) async {
    final container = ProviderContainer(overrides: [
      serviceRecordRepositoryModeProvider.overrideWithValue(serviceRepo),
      vaultStoreProvider.overrideWith((ref) async => vault),
      imageAttachmentPickerProvider
          .overrideWith((ref) async => _FakePicker(vault)),
      imageByteSourceProvider.overrideWithValue(_FakeImageSource()),
      dataModeProvider.overrideWith(() => _StubMode(DataMode.local)),
    ]);
    addTearDown(container.dispose);
    await container.read(mutateServiceRecordStateProvider.future);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => ctx.push('/form'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/form',
          builder: (c, s) => ServiceRecordFormScreen(automobileId: autoId),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Required fields: mileage + a service date (types default to one).
    await tester.enterText(find.widgetWithText(TextField, 'Mileage'), '50');
    await tester.pump();
    await tester.ensureVisible(find.byType(OptionalDatePicker));
    await tester.tap(find.byType(OptionalDatePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Stage an inline image into the notes, then save.
    await tester.ensureVisible(find.byTooltip('Insert image into notes'));
    await tester.tap(find.byTooltip('Insert image into notes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Record'));
    await tester.tap(find.text('Add Record'));
    await tester.pumpAndSettle();

    // The saved record's notes reference a real vault path (no pending/), and
    // that image is attached.
    final records = await serviceRepo.getRecords(autoId);
    expect(records, hasLength(1));
    final saved = records.single;
    expect(saved.notes, isNotNull);
    expect(saved.notes, contains('hmm-attachment://attachments/note-'));
    expect(saved.notes, isNot(contains('pending/')));
    expect(saved.attachments.images, hasLength(1));
    final imgPath = saved.attachments.images.whereType<VaultRef>().single.path;
    expect(saved.notes, contains(imgPath));
  });

  testWidgets(
      'a failed inline persist strips the placeholder — no pending/ survives',
      (tester) async {
    final container = ProviderContainer(overrides: [
      serviceRecordRepositoryModeProvider.overrideWithValue(serviceRepo),
      vaultStoreProvider.overrideWith((ref) async => vault),
      imageAttachmentPickerProvider
          .overrideWith((ref) async => _ThrowingPicker()),
      imageByteSourceProvider.overrideWithValue(_FakeImageSource()),
      dataModeProvider.overrideWith(() => _StubMode(DataMode.local)),
    ]);
    addTearDown(container.dispose);
    await container.read(mutateServiceRecordStateProvider.future);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => ctx.push('/form'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/form',
          builder: (c, s) => ServiceRecordFormScreen(automobileId: autoId),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Mileage'), '50');
    await tester.pump();
    await tester.ensureVisible(find.byType(OptionalDatePicker));
    await tester.tap(find.byType(OptionalDatePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Insert an image with no other note text, then save (the persist fails).
    await tester.ensureVisible(find.byTooltip('Insert image into notes'));
    await tester.tap(find.byTooltip('Insert image into notes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Record'));
    await tester.tap(find.text('Add Record'));
    await tester.pumpAndSettle();

    // The record still saves, but the failed pick's placeholder was stripped:
    // the notes must NOT resurrect the pre-resolve pending/ URI (the copyWith
    // null-means-keep bug), and no image is attached.
    final records = await serviceRepo.getRecords(autoId);
    expect(records, hasLength(1));
    final saved = records.single;
    expect(saved.notes ?? '', isNot(contains('pending/')));
    expect(saved.notes ?? '', isNot(contains('hmm-attachment://')));
    expect(saved.attachments.images, isEmpty);
  });
}
