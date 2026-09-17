// A sensitive attachment must sync while the vault is LOCKED, and what lands
// remotely must be the ciphertext.
//
// Reported as "cannot sync to OneDrive" after the first sensitive attachments
// (registration scans, licence photos) ever existed on the device. Sync runs
// in the background after a write, when the vault is almost always locked,
// and _reconcileVault read attachments through the DECRYPTING store — which
// throws VaultLockedException on a sensitive path. Every run failed, forever.
//
// And had the vault been unlocked, it would have been worse: the plaintext
// licence photo would have been uploaded. The vault exists so that bytes at
// rest are ciphertext; that has to hold on OneDrive too.

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/data/vault/encrypted_vault_store.dart';
import 'package:hmm_console/core/data/vault/sensitive_path.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sensitivePath = 'attachments/note-1/sensitive/front.jpg';
const _plainPath = 'attachments/note-1/photo.jpg';

const _attachmentsJson = '{"images":['
    '{"kind":"vault","path":"$_sensitivePath","contentType":"image/jpeg",'
    '"byteSize":4,"sensitive":true},'
    '{"kind":"vault","path":"$_plainPath","contentType":"image/jpeg",'
    '"byteSize":4}'
    '],"files":[]}';

/// The raw bytes on disk. For the sensitive path these ARE the ciphertext.
final _cipherOnDisk = Uint8List.fromList([9, 9, 9, 9]);
final _plainOnDisk = Uint8List.fromList([1, 2, 3, 4]);

/// Behaves like EncryptedVaultStore with no key: a sensitive read throws,
/// everything else passes through. This is the exact production condition.
class _LockedStore implements IVaultStore {
  @override
  Future<Uint8List> getBytes(String relativePath) async {
    if (isSensitiveVaultPath(relativePath)) {
      throw VaultLockedException(relativePath);
    }
    return _plainOnDisk;
  }

  @override
  Future<bool> exists(String relativePath) async => true;
  @override
  Future<void> putBytes(String relativePath, Uint8List bytes,
          {String? contentType}) async {}
  @override
  Future<void> delete(String relativePath) async {}
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

/// The raw, non-decrypting store underneath it: hands back bytes as stored.
class _RawStore implements IVaultStore {
  @override
  Future<Uint8List> getBytes(String relativePath) async =>
      isSensitiveVaultPath(relativePath) ? _cipherOnDisk : _plainOnDisk;
  @override
  Future<bool> exists(String relativePath) async => true;
  @override
  Future<void> putBytes(String relativePath, Uint8List bytes,
          {String? contentType}) async {}
  @override
  Future<void> delete(String relativePath) async {}
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

class _FakeProvider extends CloudSyncProvider {
  final pushedAttachments = <String, Uint8List>{};

  @override
  String get providerId => 'fake';
  @override
  bool get supportsAttachments => true;
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => SyncManifest(
      version: 1, generatedAt: DateTime.utc(2026, 1, 1),
      deviceId: 't', notes: const [], attachments: const []);
  @override
  Future<void> pushManifest(SyncManifest m) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;
  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullTags() async => null;
  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {}
  @override
  Future<Set<String>> listAttachmentPaths() async => const {};
  @override
  Future<void> pushAttachment(String path, Uint8List bytes) async =>
      pushedAttachments[path] = bytes;
  @override
  Future<Uint8List?> pullAttachment(String path) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'licence', authorId: 1,
          attachments: const Value(_attachmentsJson),
        ));
    provider = _FakeProvider();
  });

  tearDown(() async => db.close());

  test('the orchestrator does not need the vault unlocked at all', () async {
    // The bug: sync went through the DECRYPTING store, which throws on a
    // sensitive path while locked. Wiring that store in still fails, which
    // is what pins the provider wiring to baseVaultStoreProvider.
    final wrong = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: () async => _LockedStore(),
    );
    final r = await wrong.syncNow();
    expect(r.errors.map((e) => e.message).join(), contains('VaultLocked'));
  });

  test('a sensitive attachment syncs while the vault is LOCKED', () async {
    final orchestrator = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: () async => _RawStore(),
    );

    final r = await orchestrator.syncNow();

    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    expect(provider.pushedAttachments.keys, contains(_sensitivePath));
    expect(provider.pushedAttachments.keys, contains(_plainPath));
  });

  test('what lands remotely is the CIPHERTEXT, never the plaintext', () async {
    final orchestrator = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: () async => _RawStore(),
    );

    await orchestrator.syncNow();

    expect(provider.pushedAttachments[_sensitivePath], _cipherOnDisk,
        reason: 'the encrypted vault exists so bytes at rest are ciphertext; '
            'that must hold on OneDrive too');
    // The plain attachment is unaffected either way.
    expect(provider.pushedAttachments[_plainPath], _plainOnDisk);
  });
}
