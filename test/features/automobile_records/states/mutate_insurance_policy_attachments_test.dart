import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/contact_block/contact_info.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_insurance_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:hmm_console/features/automobile_records/data/repositories/insurance_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/auto_insurance_policy.dart';
import 'package:hmm_console/features/automobile_records/states/mutate_insurance_policy_state.dart';

// The notifier owns the TWO-PHASE save: write the policy, persist picked bytes
// against the returned note id, then merge the refs back on. The repository
// tests never reach it - they are handed policies with attachments already
// attached - so without these, deleting the whole merge left every test green.

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
      String? contentTypeHint,
      bool sensitive = false}) async {
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



/// Delegates to the real repository but fails the final write, to prove the
/// vault is not emptied by a save that never lands.
class _FailingUpdateRepo implements IInsuranceRepository {
  _FailingUpdateRepo(this.inner);
  final IInsuranceRepository inner;
  bool failNext = false;

  @override
  Future<void> updatePolicy(int autoId, int id, AutoInsurancePolicy p) {
    if (failNext) throw StateError('write failed');
    return inner.updatePolicy(autoId, id, p);
  }

  @override
  Future<AutoInsurancePolicy> createPolicy(int autoId, AutoInsurancePolicy p) =>
      inner.createPolicy(autoId, p);
  @override
  Future<List<AutoInsurancePolicy>> getPolicies(int autoId) =>
      inner.getPolicies(autoId);
  @override
  Future<AutoInsurancePolicy?> getActivePolicy(int autoId) =>
      inner.getActivePolicy(autoId);
  @override
  Future<AutoInsurancePolicy> getPolicyById(int autoId, int id) =>
      inner.getPolicyById(autoId, id);
  @override
  Future<void> deletePolicy(int autoId, int id) => inner.deletePolicy(autoId, id);
}

void main() {
  late HmmDatabase db;
  late _MemVault vault;
  late LocalInsuranceRepository insuranceRepo;

  AutoInsurancePolicy policy({List<ContactInfo> contacts = const []}) =>
      AutoInsurancePolicy(
        id: 0,
        automobileId: 1,
        provider: 'Intact',
        policyNumber: 'POL-1',
        effectiveDate: DateTime.utc(2026, 1, 1),
        expiryDate: DateTime.utc(2027, 1, 1),
        premium: 1200,
        contacts: contacts,
      );

  PickedImageBytes card() => PickedImageBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        originalName: 'card.jpg',
        contentType: 'image/jpeg',
      );

  Future<ProviderContainer> container({DataMode mode = DataMode.local}) async {
    final c = ProviderContainer(overrides: [
      insuranceRepositoryModeProvider.overrideWithValue(insuranceRepo),
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
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'insurance-notifier-tester'),
        );
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();
    insuranceRepo = LocalInsuranceRepository(
      LocalHmmNoteRepository(db, () async => author),
      LocalNoteCatalogRepository(db),
    );
  });

  tearDown(() async => db.close());

  test('create writes picked bytes to the vault and merges the ref back',
      () async {
    final c = await container();
    final created = await c
        .read(mutateInsurancePolicyStateProvider.notifier)
        .create(1, policy(), pendingImages: [card()]);

    expect(vault.store, hasLength(1));
    expect(created!.attachments.images, hasLength(1));

    // And it is actually persisted, not just returned in memory.
    final reloaded = await insuranceRepo.getPolicyById(1, created.id);
    expect(reloaded.attachments.images, hasLength(1));
  });

  test('create carries contacts through the attachment merge', () async {
    // The merge rebuilds the policy field by field; a field it forgets is lost.
    final c = await container();
    final created = await c
        .read(mutateInsurancePolicyStateProvider.notifier)
        .create(
          1,
          policy(contacts: [
            const ContactInfo(role: ContactRoles.agent, name: 'Ada', phone: '555')
          ]),
          pendingImages: [card()],
        );

    final reloaded = await insuranceRepo.getPolicyById(1, created!.id);
    expect(reloaded.contacts.single.name, 'Ada');
    expect(reloaded.attachments.images, hasLength(1));
  });

  test('create with no picks never touches the vault', () async {
    // Initialising the vault can fail; a plain save must not depend on it.
    final c = await container();
    await c.read(mutateInsurancePolicyStateProvider.notifier).create(1, policy());
    expect(vault.store, isEmpty);
  });

  test('cloudApi writes no bytes', () async {
    final c = await container(mode: DataMode.cloudApi);
    final created = await c
        .read(mutateInsurancePolicyStateProvider.notifier)
        .create(1, policy(), pendingImages: [card()]);

    expect(vault.store, isEmpty);
    expect(created!.attachments.images, isEmpty);
  });

  test('edit deletes the bytes of a removed attachment', () async {
    final c = await container();
    final created = await c
        .read(mutateInsurancePolicyStateProvider.notifier)
        .create(1, policy(), pendingImages: [card()]);
    final ref = created!.attachments.images.single as VaultRef;

    await c.read(mutateInsurancePolicyStateProvider.notifier).edit(
          1,
          created.id,
          AutoInsurancePolicy(
            id: created.id,
            automobileId: 1,
            provider: 'Intact',
            policyNumber: 'POL-1',
            effectiveDate: created.effectiveDate,
            expiryDate: created.expiryDate,
            premium: 1200,
          ),
          removed: [ref],
        );

    expect(vault.deleted, contains(ref.path));
    final reloaded = await insuranceRepo.getPolicyById(1, created.id);
    expect(reloaded.attachments.isEmpty, isTrue);
  });

  test('a failed write does not destroy the removed attachment bytes', () async {
    // Deleting before the write meant a failed save left the bytes gone while
    // the stored note still listed their paths - an attachment that exists on
    // screen and fails to open.
    final failing = _FailingUpdateRepo(insuranceRepo);
    final c = ProviderContainer(overrides: [
      insuranceRepositoryModeProvider.overrideWithValue(failing),
      vaultStoreProvider.overrideWith((ref) async => vault),
      imageAttachmentPickerProvider
          .overrideWith((ref) async => _FakePicker(vault)),
      dataModeProvider.overrideWith(() => _StubMode(DataMode.local)),
    ]);
    addTearDown(c.dispose);

    final created = await c
        .read(mutateInsurancePolicyStateProvider.notifier)
        .create(1, policy(), pendingImages: [card()]);
    final ref = created!.attachments.images.single as VaultRef;

    failing.failNext = true;
    await c.read(mutateInsurancePolicyStateProvider.notifier).edit(
          1,
          created.id,
          AutoInsurancePolicy(
            id: created.id,
            automobileId: 1,
            provider: 'Intact',
            policyNumber: 'POL-1',
            effectiveDate: created.effectiveDate,
            expiryDate: created.expiryDate,
            premium: 1200,
          ),
          removed: [ref],
        );

    // The save failed, so the note still references these bytes; they must
    // still be there.
    expect(vault.deleted, isNot(contains(ref.path)));
    expect(vault.store.containsKey(ref.path), isTrue);
  });

}
