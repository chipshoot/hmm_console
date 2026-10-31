import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

/// Pins the cloudStorage restore semantics verified 2026-10-18 (spec "Data
/// model and sync → Recently Deleted"): a restore is "clear deletedAt with a
/// newer lastModifiedDate" and travels by last-writer-wins, EXCEPT against a
/// tombstone with an equal-or-later timestamp. On a tie the receiving
/// device keeps what it has (`_maybePullNote`: `!entry.updatedAt.isAfter(local)`
/// ⇒ local wins).
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

  Future<int> insert({required DateTime modified, DateTime? deletedAt}) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          uuid: const Value('n1'),
          subject: 'note',
          authorId: 1,
          createDate: Value(t),
          lastModifiedDate: Value(modified),
          deletedAt: Value(deletedAt),
        ),
      );

  Future<Note> row(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

  void remote({required DateTime at, required bool deleted}) {
    provider.remoteManifest = SyncManifest(
      version: 1,
      generatedAt: at,
      deviceId: 'other',
      notes: [ManifestEntry(id: 'n1', updatedAt: at, deleted: deleted)],
      attachments: const [],
    );
    if (!deleted) {
      provider.remoteBodies['n1'] = {
        'uuid': 'n1',
        'subject': 'restored elsewhere',
        'lastModifiedDate': at.toIso8601String(),
        'deletedAt': null,
        'tags': const <String>[],
      };
    }
  }

  test(
    'a local restore newer than the remote tombstone stays live and is pushed',
    () async {
      final id = await insert(modified: t.add(const Duration(seconds: 5)));
      remote(at: t, deleted: true);

      final result = await orchestrator.syncNow();

      expect(result.errors, isEmpty, reason: result.errors.join('\n'));
      expect((await row(id)).deletedAt, isNull);
      expect(provider.pushedBodies['n1']!['deletedAt'], isNull);
      final entry = provider.lastPushedManifest!.notes.single;
      expect(entry.deleted, isFalse);
    },
  );

  test('a newer remote restore revives the local tombstone', () async {
    final id = await insert(modified: t, deletedAt: t);
    remote(at: t.add(const Duration(seconds: 1)), deleted: false);

    await orchestrator.syncNow();

    final r = await row(id);
    expect(r.deletedAt, isNull);
    expect(r.subject, 'restored elsewhere');
  });

  test('equal timestamps keep the local tombstone (documented tie)', () async {
    final id = await insert(modified: t, deletedAt: t);
    remote(at: t, deleted: false);

    await orchestrator.syncNow();

    expect(
      (await row(id)).deletedAt,
      isNotNull,
      reason: 'LWW tie: the receiver keeps what it has',
    );
  });

  test(
    'a restore made in the same second as its delete still wins on peers',
    () async {
      final author = await (db.select(db.authors)).getSingle();
      final repo = LocalHmmNoteRepository(db, () async => author);
      final created = await repo.createNote(
        const HmmNoteCreate(subject: 's', catalogId: 1),
      );
      await repo.deleteNote(created.id);
      final tombstone = (await repo.getNoteById(created.id))!;
      // A peer already holds the tombstone at exactly the delete's timestamp.
      provider.remoteManifest = SyncManifest(
        version: 1,
        generatedAt: tombstone.lastModifiedDate!,
        deviceId: 'peer',
        notes: [
          ManifestEntry(
            id: created.uuid,
            updatedAt: tombstone.lastModifiedDate!.toUtc(),
            deleted: true,
          ),
        ],
        attachments: const [],
      );

      await repo.restoreNote(created.id); // immediately: same wall-clock second

      await orchestrator.syncNow();
      final pushed = provider.lastPushedManifest!.notes.single;
      expect(pushed.deleted, isFalse);
      expect(
        pushed.updatedAt.isAfter(tombstone.lastModifiedDate!.toUtc()),
        isTrue,
        reason: 'strictly newer, so the peer applies it instead of tying',
      );
    },
  );
}

class _FakeProvider extends CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> pushedBodies = {};
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  SyncManifest? lastPushedManifest;

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
  Future<Map<String, dynamic>?> pullNoteBody(String id) async =>
      remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async =>
      pushedBodies[id] = body;
}
