import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/auth/current_author_account_name_provider.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/onedrive_test_fakes.dart' show noopVaultStore;

/// Verifies `localHmmNoteRepositoryProvider`'s production wiring: writing
/// a note through the Riverpod-resolved repository calls
/// `SyncController.notifyLocalChange()` ONLY when a sync orchestrator is
/// active, and does nothing (no throw, no crash) when it isn't.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an active orchestrator: writing a note eventually triggers a sync',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));

    final fakeProvider = _FakeCloudSyncProvider();
    final orchestrator = SyncOrchestrator(
      provider: fakeProvider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
    );
    var syncCalls = 0;
    final controller = SyncController(
      syncAction: () async {
        syncCalls++;
        return SyncResult(
          pulledNotes: 0,
          pulledAttachments: 0,
          pushedNotes: 0,
          pushedAttachments: 0,
          completedAt: DateTime.now().toUtc(),
        );
      },
      localChangeDebounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
      // currentAuthorAccountNameProvider normally reads the signed-in
      // Firebase user via currentUserProvider; this container has no auth
      // context, so pin it directly to the 'tester' account seeded above.
      currentAuthorAccountNameProvider.overrideWithValue('tester'),
    ]);
    addTearDown(container.dispose);

    await container.read(localHmmNoteRepositoryProvider).createNote(
          const HmmNoteCreate(subject: 'Hi', catalogId: 1),
        );

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(syncCalls, equals(1));
  });

  test('no active orchestrator (local mode): writing a note never triggers '
      'a sync', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));

    final orchestrator = SyncOrchestrator(
      provider: null, // DataMode.local
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
    );
    var syncCalls = 0;
    final controller = SyncController(
      syncAction: () async {
        syncCalls++;
        return SyncResult(
          pulledNotes: 0,
          pulledAttachments: 0,
          pushedNotes: 0,
          pushedAttachments: 0,
          completedAt: DateTime.now().toUtc(),
        );
      },
      localChangeDebounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
      // See the note in the previous test — no auth context here either.
      currentAuthorAccountNameProvider.overrideWithValue('tester'),
    ]);
    addTearDown(container.dispose);

    await container.read(localHmmNoteRepositoryProvider).createNote(
          const HmmNoteCreate(subject: 'Hi', catalogId: 1),
        );

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(syncCalls, equals(0));
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
