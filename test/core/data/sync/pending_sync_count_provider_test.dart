import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/auth/current_author_account_name_provider.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/pending_sync_count_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('0 when no orchestrator is active', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final orchestrator = SyncOrchestrator(
      provider: null,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: () async => throw UnimplementedError(),
    );
    final controller = SyncController(syncAction: () async {
      throw StateError('should never be called — no provider');
    });
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);

    // Keep-alive listener: without an active subscriber, this
    // StreamProvider.autoDispose can be torn down by the scheduler before
    // the synchronously-produced Stream.value(0) is delivered to a bare
    // `container.read(...future)` (a flutter_riverpod 3.0.3 autoDispose
    // scheduling race, not specific to this provider's logic).
    final sub = container.listen<AsyncValue<int>>(
      pendingSyncCountProvider,
      (prev, next) {},
    );
    addTearDown(sub.close);

    final value = await container.read(pendingSyncCountProvider.future);
    expect(value, equals(0));
  });

  test('recomputes when the notes table changes', () async {
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
      vaultStore: () async => throw UnimplementedError(),
    );
    final controller = SyncController(syncAction: () async {
      throw StateError('not exercised in this test');
    });
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
      // currentAuthorAccountNameProvider normally reads the signed-in
      // Firebase user via currentUserProvider; this container has no auth
      // context, so pin it directly to the 'tester' account seeded above
      // (same fix Task 2's local_hmm_note_repository_provider_wiring_test
      // uses for the same reason).
      currentAuthorAccountNameProvider.overrideWithValue('tester'),
    ]);
    addTearDown(container.dispose);

    final completer = Completer<int>();
    final sub = container.listen<AsyncValue<int>>(
      pendingSyncCountProvider,
      (prev, next) {
        final v = next.value;
        if (v != null && v > 0 && !completer.isCompleted) {
          completer.complete(v);
        }
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    final initial = await container.read(pendingSyncCountProvider.future);
    expect(initial, equals(0));

    await container
        .read(hmmNoteRepositoryProvider)
        .createNote(const HmmNoteCreate(subject: 'new', catalogId: 1));

    final after = await completer.future.timeout(const Duration(seconds: 2));
    expect(after, equals(1));
  });

  test('recomputes to 0 after a sync completes (cursor advances) even '
      'though the note row itself did not change', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    // lastModifiedDate must be set explicitly: it's nullable with no
    // clientDefault, and pendingChangeCount()'s `> cursor` predicate (like
    // syncNow()'s _collectChangedNotes) never matches a NULL column in
    // SQL — a bare NotesCompanion.insert() would leave this row
    // permanently invisible to both, defeating the test's premise that
    // it starts out pending against the epoch-zero cursor.
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'pending',
          authorId: 1,
          lastModifiedDate: Value(DateTime.now().toUtc()),
        ));

    final fakeProvider = _FakeCloudSyncProvider();
    final meta = SyncMetaRepository();
    final orchestrator = SyncOrchestrator(
      provider: fakeProvider,
      db: db,
      meta: meta,
      vaultStore: () async => throw UnimplementedError(),
    );
    // Real syncAction = orchestrator.syncNow, so a successful sync
    // actually advances the meta cursor — the effect under test.
    final controller = SyncController(syncAction: orchestrator.syncNow);
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(container.dispose);

    // Keep-alive listener established up front (and kept for the whole
    // test) — otherwise a bare `container.read(...future)` with zero
    // active listeners can race the scheduler's autoDispose teardown
    // before the synchronously-seeded value is delivered (flutter_riverpod
    // 3.0.3 autoDispose scheduling quirk, unrelated to this provider's
    // logic).
    final completer = Completer<int>();
    final sub = container.listen<AsyncValue<int>>(
      pendingSyncCountProvider,
      (prev, next) {
        final v = next.value;
        if (v != null && v == 0 && !completer.isCompleted) {
          completer.complete(v);
        }
      },
    );
    addTearDown(sub.close);

    final before = await container.read(pendingSyncCountProvider.future);
    expect(before, equals(1));

    final result = await controller.triggerManualSync();
    expect(result!.success, isTrue);

    final after = await completer.future.timeout(const Duration(seconds: 2));
    expect(after, equals(0));
  });

  test(
      'emit() does not add to a closed StreamController when disposed '
      'while pendingChangeCount() is still in flight', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));

    final fakeProvider = _FakeCloudSyncProvider();
    final orchestrator = _GatedOrchestrator(
      provider: fakeProvider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: () async => throw UnimplementedError(),
    );
    final controller = SyncController(syncAction: () async {
      throw StateError('not exercised in this test');
    });
    addTearDown(controller.dispose);

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWithValue(orchestrator),
      syncControllerProvider.overrideWithValue(controller),
      currentAuthorAccountNameProvider.overrideWithValue('tester'),
    ]);

    final zoneErrors = <Object>[];
    await runZonedGuarded(() async {
      final sub = container.listen<AsyncValue<int>>(
        pendingSyncCountProvider,
        (prev, next) {},
      );

      // Let the (unguarded) seed `emit()` call resolve first, so the gate
      // armed below only catches the *next* recompute.
      final initial = await container.read(pendingSyncCountProvider.future);
      expect(initial, equals(0));

      // Arm the gate, then trigger a recompute via a notes-table write —
      // this is the reproduction of "a notes-table write's recompute is
      // still in flight" from the review finding. The ensuing emit() call
      // will suspend inside pendingChangeCount() until releaseGate().
      orchestrator.armGate();
      await container
          .read(hmmNoteRepositoryProvider)
          .createNote(const HmmNoteCreate(subject: 'new', catalogId: 1));

      // Wait until emit() has actually entered the gated await (i.e. it's
      // genuinely mid-flight on the COUNT query) before disposing —
      // otherwise disposing might race ahead of the recompute even being
      // scheduled, and the test wouldn't exercise the race at all.
      await orchestrator.entered.future.timeout(const Duration(seconds: 2));

      // Dispose while emit() is suspended awaiting the COUNT query. This
      // is "navigate away from a screen while a recompute is still in
      // flight": ref.onDispose cancels dbSub, removes the controller
      // listener, and closes `out` — concurrently with the gated
      // pendingChangeCount() call above.
      sub.close();
      container.dispose();

      // Let the gated query resolve now that the controller is closed.
      // With the pre-fix code (isClosed checked *before* the await),
      // emit() would resume and call out.add() on a closed
      // StreamController, throwing an unhandled StateError caught below.
      orchestrator.releaseGate();
      await orchestrator.done.future.timeout(const Duration(seconds: 2));

      // Flush the microtask queue: emit()'s post-await continuation
      // (the isClosed re-check / out.add) is scheduled as a microtask
      // right after pendingChangeCount() resolves, so a zero-duration
      // Timer (which runs after all pending microtasks) is enough to
      // guarantee it has run before we assert below.
      await Future<void>.delayed(Duration.zero);
    }, (error, stack) {
      zoneErrors.add(error);
    });

    expect(zoneErrors, isEmpty,
        reason: 'emit() must re-check out.isClosed AFTER awaiting '
            'pendingChangeCount(), not before, or it adds to an '
            'already-closed StreamController when disposed mid-recompute');
  });
}

class _GatedOrchestrator extends SyncOrchestrator {
  _GatedOrchestrator({
    required super.provider,
    required super.db,
    required super.meta,
    required super.vaultStore,
  });

  /// Completes the moment a gated `pendingChangeCount()` call has
  /// suspended on [_gate] — signals "the recompute is now genuinely
  /// in flight".
  final Completer<void> entered = Completer<void>();

  /// Completes once the (gated) call has finished querying the DB —
  /// used to know when to flush the microtask queue before asserting.
  final Completer<void> done = Completer<void>();

  Completer<void>? _gate;
  bool _armed = false;

  /// Arms the gate so the *next* call to [pendingChangeCount] suspends
  /// until [releaseGate] is called.
  void armGate() {
    _armed = true;
    _gate = Completer<void>();
  }

  void releaseGate() {
    _gate?.complete();
  }

  @override
  Future<int> pendingChangeCount() async {
    if (_armed) {
      _armed = false;
      entered.complete();
      await _gate!.future;
    }
    final result = await super.pendingChangeCount();
    if (!done.isCompleted) done.complete();
    return result;
  }
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
