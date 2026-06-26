import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _attJson(String path) =>
    '{"images":[],"files":[{"kind":"vault","path":"$path",'
    '"contentType":"audio/mp4","byteSize":3}]}';

class _MemVault implements IVaultStore {
  final Map<String, Uint8List> files = {};
  @override
  Future<void> putBytes(String relativePath, Uint8List bytes,
          {String? contentType}) async =>
      files[relativePath] = bytes;
  @override
  Future<Uint8List> getBytes(String relativePath) async => files[relativePath]!;
  @override
  Future<bool> exists(String relativePath) async =>
      files.containsKey(relativePath);
  @override
  Future<void> delete(String relativePath) async => files.remove(relativePath);
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

class _MemProvider extends CloudSyncProvider {
  final Map<String, Uint8List> remote = {};
  bool throwOnPush = false;
  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => null;
  @override
  Future<void> pushManifest(SyncManifest m) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
  @override
  bool get supportsAttachments => true;
  @override
  Future<Set<String>> listAttachmentPaths() async => remote.keys.toSet();
  @override
  Future<void> pushAttachment(String path, Uint8List bytes) async {
    if (throwOnPush) throw Exception('boom');
    remote[path] = bytes;
  }

  @override
  Future<Uint8List?> pullAttachment(String path) async => remote[path];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _MemVault vault;
  late _MemProvider provider;
  late SyncMetaRepository meta;
  late SyncOrchestrator orchestrator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    vault = _MemVault();
    provider = _MemProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: meta,
      vaultStore: () async => vault,
    );
  });

  tearDown(() async => db.close());

  Future<void> seedNote(String vaultPath) async {
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 's',
          authorId: 1,
          uuid: const Value('n1'),
          attachments: Value(_attJson(vaultPath)),
        ));
  }

  test('pushes a local-only referenced file to remote', () async {
    await seedNote('attachments/note-1/a.m4a');
    vault.files['attachments/note-1/a.m4a'] = Uint8List.fromList([1, 2, 3]);

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    expect(provider.remote['attachments/note-1/a.m4a']!.toList(), [1, 2, 3]);
    expect(r.pushedAttachments, 1);
  });

  test('eagerly pulls a remote-only referenced file into the vault', () async {
    await seedNote('attachments/note-1/b.m4a');
    provider.remote['attachments/note-1/b.m4a'] = Uint8List.fromList([4, 5]);

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    expect(vault.files['attachments/note-1/b.m4a']!.toList(), [4, 5]);
    expect(r.pulledAttachments, 1);
  });

  test('a push failure is collected, sync still completes', () async {
    await seedNote('attachments/note-1/a.m4a');
    vault.files['attachments/note-1/a.m4a'] = Uint8List.fromList([1]);
    provider.throwOnPush = true;

    final r = await orchestrator.syncNow();
    expect(r.errors.where((e) => e.recordType == 'attachment'), isNotEmpty);
    expect(provider.remote, isEmpty);
  });

  test('an attachment failure does NOT block the note cursor', () async {
    await seedNote('attachments/note-1/a.m4a');
    vault.files['attachments/note-1/a.m4a'] = Uint8List.fromList([1]);
    provider.throwOnPush = true;

    await orchestrator.syncNow();
    // Metadata sync was clean, so the cursor advances despite the
    // attachment push failure — otherwise every note re-syncs next time.
    expect(await meta.getLastPushedAt('fake'), isNotNull);
  });

  test('idempotent: a second sync pushes/pulls nothing new', () async {
    await seedNote('attachments/note-1/a.m4a');
    vault.files['attachments/note-1/a.m4a'] = Uint8List.fromList([1]);
    await orchestrator.syncNow();
    final r2 = await orchestrator.syncNow();
    expect(r2.pushedAttachments, 0);
    expect(r2.pulledAttachments, 0);
  });
}
