// A sync must report where its time went.
//
// "Sync is slow" was unmeasurable: the orchestrator kept no timings, so the
// only way to find the slow phase was to guess. These pin that every phase
// is timed, that the timings are REAL (a slow provider shows up in the phase
// that called it), and that a failed sync still reports them.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

/// A provider whose manifest pull can be made deliberately slow, so the
/// timing attributed to that phase is checkable rather than assumed.
class _FakeProvider extends CloudSyncProvider {
  Duration manifestDelay = Duration.zero;
  bool failManifest = false;

  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async {
    if (manifestDelay > Duration.zero) await Future<void>.delayed(manifestDelay);
    if (failManifest) throw StateError('manifest exploded');
    return SyncManifest(
        version: 1, generatedAt: DateTime.utc(2026, 1, 1),
        deviceId: 't', notes: const [], attachments: const []);
  }
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    provider = _FakeProvider();
  });

  tearDown(() async => db.close());

  SyncOrchestrator orchestrator() => SyncOrchestrator(
        provider: provider,
        db: db,
        meta: SyncMetaRepository(),
        vaultStore: noopVaultStore,
      );

  test('a sync reports a duration for every phase, and a total', () async {
    final r = await orchestrator().syncNow();

    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    expect(r.timing, isNotNull);
    final t = r.timing!;
    // Every phase present, so a reader can see where the time went without
    // wondering whether a missing phase ran at all.
    expect(t.phases.keys, containsAll(SyncPhase.values));
    expect(t.total, greaterThanOrEqualTo(Duration.zero));
  });

  test('the phase timings are REAL: a slow manifest shows up as manifest',
      () async {
    provider.manifestDelay = const Duration(milliseconds: 120);

    final t = (await orchestrator().syncNow()).timing!;

    expect(t.phases[SyncPhase.pullManifest]!,
        greaterThanOrEqualTo(const Duration(milliseconds: 120)),
        reason: 'the delay was in the manifest pull; it must land there');
    // And NOT be smeared across a phase that did nothing slow.
    expect(t.phases[SyncPhase.settings]!,
        lessThan(const Duration(milliseconds: 100)));
  });

  test('the total is at least the sum of its phases', () async {
    provider.manifestDelay = const Duration(milliseconds: 60);

    final t = (await orchestrator().syncNow()).timing!;
    final sum = t.phases.values.fold(Duration.zero, (a, b) => a + b);

    expect(t.total, greaterThanOrEqualTo(sum));
  });

  test('a FAILED sync still reports timings — that is when they matter most',
      () async {
    provider.failManifest = true;

    final r = await orchestrator().syncNow();

    expect(r.errors, isNotEmpty);
    expect(r.timing, isNotNull,
        reason: 'a slow failure must be diagnosable, not just a fast one');
  });
}
