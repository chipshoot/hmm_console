import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/pending_remote_purge_store.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;
  late PendingRemotePurgeStore pending;
  late SyncMetaRepository meta;
  late SyncOrchestrator orchestrator;
  final t = DateTime.utc(2026, 9, 1, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeProvider();
    pending = PendingRemotePurgeStore();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: meta,
      vaultStore: noopVaultStore,
      pendingPurges: pending,
    );
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            uuid: const Value('p1'),
            subject: kTombstoneSubject,
            authorId: 1,
            createDate: Value(t),
            lastModifiedDate: Value(t),
            deletedAt: Value(t),
          ),
        );
    await pending.add('fake', 'p1', {'note-1/a.jpg'});
  });

  tearDown(() => db.close());

  void remote({required DateTime at, required bool deleted}) {
    provider.remoteManifest = SyncManifest(
      version: 1,
      generatedAt: at,
      deviceId: 'peer',
      notes: [ManifestEntry(id: 'p1', updatedAt: at, deleted: deleted)],
      attachments: const [],
    );
  }

  test('purges the remote blob once the tombstone still wins', () async {
    remote(at: t, deleted: true);

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(provider.purged, ['p1']);
    expect(provider.purgedPaths, {'note-1/a.jpg'});
    expect(await pending.read('fake'), isEmpty);
  });

  test(
    'a note restored on another device is revived, never purged remotely',
    () async {
      final later = t.add(const Duration(seconds: 10));
      remote(at: later, deleted: false);
      provider.remoteBodies['p1'] = {
        'uuid': 'p1',
        'subject': 'restored elsewhere',
        'content': 'body',
        'lastModifiedDate': later.toIso8601String(),
        'deletedAt': null,
        'tags': const <String>[],
      };

      await orchestrator.syncNow();

      final row = await (db.select(
        db.notes,
      )..where((n) => n.uuid.equals('p1'))).getSingle();
      expect(row.deletedAt, isNull);
      expect(row.subject, 'restored elsewhere');
      expect(provider.purged, isEmpty);
      expect(await pending.read('fake'), isEmpty);
    },
  );

  test(
    'a failed remote purge stays pending and does not hold the cursor back',
    () async {
      remote(at: t, deleted: true);
      provider.failPurge = true;

      final result = await orchestrator.syncNow();

      expect(result.errors.map((e) => e.recordType), ['purge']);
      expect((await pending.read('fake')).keys, ['p1']);
      expect(await meta.getLastPushedAt('fake'), isNotNull);
    },
  );

  test(
    'a vault path another note still references is not deleted remotely',
    () async {
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              uuid: const Value('keeper'),
              subject: 'keeper',
              authorId: 1,
              attachments: Value(
                NoteAttachmentsCodec.encode(
                  NoteAttachments(
                    images: [
                      const VaultRef(
                        path: 'note-1/a.jpg',
                        contentType: 'image/jpeg',
                        byteSize: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
      remote(at: t, deleted: true);

      await orchestrator.syncNow();

      expect(provider.purged, ['p1']);
      expect(provider.purgedPaths, isEmpty);
    },
  );
}

class _FakeProvider extends CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  final purged = <String>[];
  final purgedPaths = <String>{};
  bool failPurge = false;

  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => remoteManifest;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async =>
      remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}

  @override
  Future<void> purgeNote(
    String uuid, {
    Set<String> releasedVaultPaths = const {},
  }) async {
    if (failPurge) throw StateError('graph down');
    purged.add(uuid);
    purgedPaths.addAll(releasedVaultPaths);
  }
}
