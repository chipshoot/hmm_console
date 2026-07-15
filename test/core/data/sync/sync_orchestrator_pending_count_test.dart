import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'onedrive_test_fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coverage for the "cheap COUNT of notes changed since the last-pushed
/// cursor" query (Finding 3 in the Phase 1 plan: this mirrors ONLY the
/// `lastModifiedDate > cursor` leg of `syncNow()`'s push collection — it
/// does NOT run the missing-from-remote self-healing check, which needs a
/// network round-trip and isn't "cheap").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeCloudSyncProvider provider;
  late SyncOrchestrator orchestrator;
  late SyncMetaRepository meta;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeCloudSyncProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(
        provider: provider, db: db, meta: meta, vaultStore: noopVaultStore);
  });

  tearDown(() async => db.close());

  test('0 when nothing has ever been synced and no notes exist', () async {
    expect(await orchestrator.pendingChangeCount(), equals(0));
  });

  test('counts notes modified after the cursor', () async {
    final cursor = DateTime.utc(2026, 5, 25, 12);
    await meta.setLastPushedAt(provider.providerId, cursor);

    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'after cursor',
          authorId: 1,
          createDate: Value(cursor.add(const Duration(minutes: 1))),
          lastModifiedDate: Value(cursor.add(const Duration(minutes: 1))),
        ));
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'before cursor',
          authorId: 1,
          createDate: Value(cursor.subtract(const Duration(minutes: 1))),
          lastModifiedDate: Value(cursor.subtract(const Duration(minutes: 1))),
        ));

    expect(await orchestrator.pendingChangeCount(), equals(1));
  });

  test('0 when a provider is not active (DataMode.local)', () async {
    final noSyncOrchestrator = SyncOrchestrator(
        provider: null, db: db, meta: meta, vaultStore: noopVaultStore);
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'irrelevant', authorId: 1));
    expect(await noSyncOrchestrator.pendingChangeCount(), equals(0));
  });
}

class _FakeCloudSyncProvider extends CloudSyncProvider {
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
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
}
