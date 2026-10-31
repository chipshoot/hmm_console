import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

/// The local push queue is snapshotted BEFORE the pull. A note the pull then
/// overwrites (newer remote edit or tombstone) must not have its stale
/// snapshot pushed back: on the API that would PUT an old body over a newer
/// edit, or — via the restore path — un-delete a newer delete.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;
  late SyncOrchestrator orchestrator;
  final t = DateTime.utc(2026, 10, 1, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeProvider();
    orchestrator = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
    );
  });

  tearDown(() => db.close());

  Future<int> insert(String uuid, {required DateTime modified}) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          uuid: Value(uuid),
          subject: 'stale local $uuid',
          authorId: 1,
          createDate: Value(t),
          lastModifiedDate: Value(modified),
        ),
      );

  Future<Note> row(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

  Map<String, dynamic> remoteBody(String uuid, DateTime at) => {
    'uuid': uuid,
    'subject': 'remote $uuid',
    'lastModifiedDate': at.toIso8601String(),
    'deletedAt': null,
    'tags': const <String>[],
  };

  void manifest(List<ManifestEntry> entries) =>
      provider.remoteManifest = SyncManifest(
        version: 1,
        generatedAt: t,
        deviceId: 'device-a',
        notes: entries,
        attachments: const [],
      );

  test('a stale live edit loses to a newer remote tombstone and is not '
      'pushed', () async {
    final id = await insert('n1', modified: t);
    final deletedAt = t.add(const Duration(minutes: 1));
    manifest([ManifestEntry(id: 'n1', updatedAt: deletedAt, deleted: true)]);

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect((await row(id)).deletedAt, isNotNull);
    expect(
      provider.pushedBodies.containsKey('n1'),
      isFalse,
      reason: 'a stale live body would restore the newer delete',
    );
    expect(provider.lastPushedManifest!.notes.single.deleted, isTrue);
  });

  test('a newer remote edit wins and the stale body is not pushed', () async {
    final id = await insert('n1', modified: t);
    final at = t.add(const Duration(minutes: 1));
    manifest([ManifestEntry(id: 'n1', updatedAt: at, deleted: false)]);
    provider.remoteBodies['n1'] = remoteBody('n1', at);

    await orchestrator.syncNow();

    expect((await row(id)).subject, 'remote n1');
    expect(provider.pushedBodies.containsKey('n1'), isFalse);
  });

  test('a local change the pull did not touch is still pushed', () async {
    await insert('n1', modified: t);
    final at = t.add(const Duration(minutes: 1));
    await insert('n2', modified: t);
    manifest([
      ManifestEntry(id: 'n1', updatedAt: at, deleted: true),
      // Remote n2 is OLDER than the local edit: local wins, pull skips it.
      ManifestEntry(
        id: 'n2',
        updatedAt: t.subtract(const Duration(minutes: 1)),
        deleted: false,
      ),
    ]);

    await orchestrator.syncNow();

    expect(provider.pushedBodies.keys, ['n2']);
    expect(provider.pushedBodies['n2']!['subject'], 'stale local n2');
  });

  test('an edit made after the pull applied a note is pushed as the current '
      'row, not the snapshot', () async {
    final id = await insert('n1', modified: t);
    final at = t.add(const Duration(minutes: 1));
    final editedAt = t.add(const Duration(minutes: 2));
    manifest([
      ManifestEntry(id: 'n1', updatedAt: at, deleted: false),
      ManifestEntry(id: 'n2', updatedAt: at, deleted: false),
    ]);
    provider.remoteBodies['n1'] = remoteBody('n1', at);
    provider.remoteBodies['n2'] = remoteBody('n2', at);
    // The user edits n1 while the pull is still working on n2.
    provider.onPull = (uuid) async {
      if (uuid != 'n2') return;
      await (db.update(db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(
          subject: const Value('edited after pull'),
          lastModifiedDate: Value(editedAt),
        ),
      );
    };

    await orchestrator.syncNow();

    expect(provider.pushedBodies['n1']!['subject'], 'edited after pull');
  });
}

class _FakeProvider extends CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> pushedBodies = {};
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  SyncManifest? lastPushedManifest;
  Future<void> Function(String uuid)? onPull;

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
  Future<void> pushManifest(SyncManifest manifest) async =>
      lastPushedManifest = manifest;
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async {
    await onPull?.call(id);
    return remoteBodies[id];
  }

  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async =>
      pushedBodies[id] = body;
}
