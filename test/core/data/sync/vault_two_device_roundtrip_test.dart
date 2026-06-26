// End-to-end proof of the goal: media attached on device A is resolvable
// (bytes present) on device B after both sync through a shared cloud.

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _path = 'attachments/note-1/a.m4a';

String _attJson() =>
    '{"images":[],"files":[{"kind":"vault","path":"$_path",'
    '"contentType":"audio/mp4","byteSize":3}]}';

class _MemVault implements IVaultStore {
  final Map<String, Uint8List> files = {};
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async =>
      files[p] = b;
  @override
  Future<Uint8List> getBytes(String p) async => files[p]!;
  @override
  Future<bool> exists(String p) async => files.containsKey(p);
  @override
  Future<void> delete(String p) async => files.remove(p);
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

/// One shared "cloud": note bodies + manifest + vault bytes, shared by both
/// device providers.
class _Cloud {
  final Map<String, Map<String, dynamic>> noteBodies = {};
  final Map<String, Uint8List> vault = {};
  SyncManifest? manifest;
}

class _CloudProvider extends CloudSyncProvider {
  _CloudProvider(this._cloud);
  final _Cloud _cloud;
  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => _cloud.manifest;
  @override
  Future<void> pushManifest(SyncManifest m) async => _cloud.manifest = m;
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async =>
      _cloud.noteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async =>
      _cloud.noteBodies[id] = body;
  @override
  bool get supportsAttachments => true;
  @override
  Future<Set<String>> listAttachmentPaths() async => _cloud.vault.keys.toSet();
  @override
  Future<void> pushAttachment(String path, Uint8List bytes) async =>
      _cloud.vault[path] = bytes;
  @override
  Future<Uint8List?> pullAttachment(String path) async => _cloud.vault[path];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('media attached on A is present + resolvable on B after sync', () async {
    SharedPreferences.setMockInitialValues({});
    final cloud = _Cloud();

    // ---- Device A: has the note + the bytes locally ----
    final aDb = HmmDatabase(NativeDatabase.memory());
    addTearDown(aDb.close);
    await aDb.into(aDb.authors).insert(AuthorsCompanion.insert(accountName: 'a'));
    await aDb.into(aDb.notes).insert(NotesCompanion.insert(
          subject: 's', authorId: 1, uuid: const Value('n1'),
          attachments: Value(_attJson()),
        ));
    final aVault = _MemVault()..files[_path] = Uint8List.fromList([1, 2, 3]);
    final aOrch = SyncOrchestrator(
      provider: _CloudProvider(cloud), db: aDb, meta: SyncMetaRepository(),
      vaultStore: () async => aVault,
    );

    final aRes = await aOrch.syncNow();
    expect(aRes.errors, isEmpty, reason: aRes.errors.join('\n'));
    // Cloud now holds the note body AND the bytes.
    expect(cloud.noteBodies.containsKey('n1'), isTrue);
    expect(cloud.vault[_path]!.toList(), [1, 2, 3]);

    // ---- Device B: empty db + empty vault ----
    final bDb = HmmDatabase(NativeDatabase.memory());
    addTearDown(bDb.close);
    await bDb.into(bDb.authors).insert(AuthorsCompanion.insert(accountName: 'b'));
    final bVault = _MemVault();
    final bOrch = SyncOrchestrator(
      provider: _CloudProvider(cloud), db: bDb, meta: SyncMetaRepository(),
      vaultStore: () async => bVault,
    );

    final bRes = await bOrch.syncNow();
    expect(bRes.errors, isEmpty, reason: bRes.errors.join('\n'));

    // B pulled the note...
    final row = await (bDb.select(bDb.notes)
          ..where((n) => n.uuid.equals('n1')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(NoteAttachmentsCodec.decode(row!.attachments).files, isNotEmpty);
    // ...and B's vault now has the bytes (eager pull) → media resolvable.
    expect(bVault.files[_path]!.toList(), [1, 2, 3]);
  });
}
