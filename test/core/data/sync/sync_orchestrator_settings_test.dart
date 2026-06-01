// Orchestrator coverage for Phase D.2 (settings sync). Drives every
// LWW branch + the "fresh install, nothing to push" no-op.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/gas_log_settings.dart';
import 'package:hmm_console/features/settings/domain/gas_log_units.dart';
import 'package:hmm_console/features/settings/domain/sync_settings.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;
  late SyncableSettingsRepository settingsRepo;
  late SyncMetaRepository meta;
  late int onSettingsAppliedCalls;
  late SyncOrchestrator orchestrator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    provider = _FakeProvider();
    settingsRepo = SyncableSettingsRepository();
    meta = SyncMetaRepository();
    onSettingsAppliedCalls = 0;
    orchestrator = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: meta,
      settingsRepo: settingsRepo,
      onSettingsApplied: () => onSettingsAppliedCalls++,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('fresh install + empty cloud → no push (avoid uploading defaults)',
      () async {
    // No local mutations have happened, so lastModified is still
    // epoch zero. Cloud is empty (provider.remoteSettings = null).
    // Expected: orchestrator skips the settings leg entirely.
    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty);
    expect(provider.pushedSettings, isNull,
        reason: 'no point seeding cloud with all-defaults');
    expect(onSettingsAppliedCalls, equals(0));
  });

  test('local has changes + cloud is empty → push local', () async {
    // Simulate "user picked km + L on this device, hasn't synced yet".
    final localBundle = SyncableSettings(
      gasLog: const GasLogSettings(
        distanceUnit: DistanceUnit.kilometer,
        fuelUnit: FuelUnit.liter,
        currency: CurrencyCode.cad,
      ),
      syncSettings: const SyncSettings(),
      localeCode: 'zh',
      lastModified: DateTime.utc(2026, 5, 26, 9),
    );
    await settingsRepo.apply(localBundle);
    provider.remoteSettings = null;

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty);
    expect(provider.pushedSettings, isNotNull);
    final pushed = SyncableSettings.fromJson(provider.pushedSettings!);
    expect(pushed.gasLog.distanceUnit, DistanceUnit.kilometer);
    expect(pushed.localeCode, 'zh');
    expect(pushed.lastModified, DateTime.utc(2026, 5, 26, 9));
    // We pushed; we did NOT apply remote → no bus bump.
    expect(onSettingsAppliedCalls, equals(0));
  });

  test('cloud is newer → apply to local + bump the settings bus', () async {
    // Local has older settings; cloud bundle is newer. Pull-apply
    // wins.
    final localBundle = SyncableSettings(
      gasLog: const GasLogSettings(
        distanceUnit: DistanceUnit.mile,
        fuelUnit: FuelUnit.gallon,
        currency: CurrencyCode.cad,
      ),
      syncSettings: const SyncSettings(),
      localeCode: null,
      lastModified: DateTime.utc(2026, 5, 26, 8),
    );
    await settingsRepo.apply(localBundle);

    final remoteBundle = SyncableSettings(
      gasLog: const GasLogSettings(
        distanceUnit: DistanceUnit.kilometer,
        fuelUnit: FuelUnit.liter,
        currency: CurrencyCode.cad,
        showRegistration: false,
      ),
      syncSettings: const SyncSettings(
        networkPolicy: SyncNetworkPolicy.anyNetwork,
      ),
      localeCode: 'zh',
      lastModified: DateTime.utc(2026, 5, 26, 12),
    );
    provider.remoteSettings = remoteBundle.toJson();

    final result = await orchestrator.syncNow();
    expect(result.errors, isEmpty);

    final applied = await settingsRepo.read();
    expect(applied.gasLog.distanceUnit, DistanceUnit.kilometer);
    expect(applied.gasLog.showRegistration, false);
    expect(applied.syncSettings.networkPolicy, SyncNetworkPolicy.anyNetwork);
    expect(applied.localeCode, 'zh');
    expect(applied.lastModified, DateTime.utc(2026, 5, 26, 12));

    expect(onSettingsAppliedCalls, equals(1),
        reason: 'callback must fire so the UI reloads');
    expect(provider.pushedSettings, isNull,
        reason: 'cloud was newer — we pull, we don\'t push');
  });

  test('local is newer than cloud → push local (overwrite cloud)',
      () async {
    final localBundle = SyncableSettings(
      gasLog: const GasLogSettings(
        distanceUnit: DistanceUnit.kilometer,
      ),
      syncSettings: const SyncSettings(),
      localeCode: 'en',
      lastModified: DateTime.utc(2026, 5, 26, 14),
    );
    await settingsRepo.apply(localBundle);

    final remoteBundle = SyncableSettings(
      gasLog: const GasLogSettings(distanceUnit: DistanceUnit.mile),
      syncSettings: const SyncSettings(),
      localeCode: null,
      lastModified: DateTime.utc(2026, 5, 26, 10),
    );
    provider.remoteSettings = remoteBundle.toJson();

    final result = await orchestrator.syncNow();
    expect(result.errors, isEmpty);
    expect(provider.pushedSettings, isNotNull);
    final pushed = SyncableSettings.fromJson(provider.pushedSettings!);
    expect(pushed.gasLog.distanceUnit, DistanceUnit.kilometer);
    expect(pushed.lastModified, DateTime.utc(2026, 5, 26, 14));
    expect(onSettingsAppliedCalls, equals(0),
        reason: 'no apply happened — we wrote, we didn\'t read');
  });

  test('equal timestamps → no-op (neither push nor apply)', () async {
    final ts = DateTime.utc(2026, 5, 26, 11);
    final localBundle = SyncableSettings(
      gasLog: const GasLogSettings(),
      syncSettings: const SyncSettings(),
      localeCode: 'en',
      lastModified: ts,
    );
    await settingsRepo.apply(localBundle);
    provider.remoteSettings = localBundle.toJson();

    final result = await orchestrator.syncNow();
    expect(result.errors, isEmpty);
    expect(provider.pushedSettings, isNull);
    expect(onSettingsAppliedCalls, equals(0));
  });

  test('pull throws → recorded as SyncError, note sync still runs',
      () async {
    provider.pullSettingsShouldThrow = true;

    final result = await orchestrator.syncNow();

    expect(result.errors.any((e) => e.recordId == 'settings'), isTrue);
    // Note sync still completed cleanly (no notes in DB, but the call
    // chain reached the manifest push).
    expect(provider.pushedManifestCount, equals(1));
  });

  test('malformed remote bundle → non-fatal, local kept, notes still sync',
      () async {
    // A corrupt/partial remote bundle (here gasLog is not an object, so
    // SyncableSettings.fromJson throws) must NOT crash the whole sync —
    // the regression behind the on-device "Null is not a subtype of
    // String" crash. The settings leg is skipped with a logged error;
    // local stays put and the rest of the sync runs.
    final localBundle = SyncableSettings(
      gasLog: const GasLogSettings(distanceUnit: DistanceUnit.mile),
      syncSettings: const SyncSettings(),
      localeCode: 'en',
      lastModified: DateTime.utc(2026, 5, 26, 8),
    );
    await settingsRepo.apply(localBundle);

    // Newer-than-local stamp so the orchestrator would try to apply it,
    // plus a gasLog value that makes fromJson throw.
    provider.remoteSettings = {
      'gasLog': 'corrupt-not-an-object',
      'lastModified': '2026-05-27T00:00:00.000Z',
      '_v': 1,
    };

    final result = await orchestrator.syncNow();

    // Non-fatal: a settings error is recorded but syncNow didn't throw.
    expect(result.errors.any((e) => e.recordId == 'settings'), isTrue);
    // Local settings were not clobbered by the bad bundle.
    final applied = await settingsRepo.read();
    expect(applied.gasLog.distanceUnit, DistanceUnit.mile);
    expect(applied.localeCode, 'en');
    expect(onSettingsAppliedCalls, equals(0));
    // The rest of the sync still ran.
    expect(provider.pushedManifestCount, equals(1));
  });
}

/// Fake CloudSyncProvider focused on the settings leg.
class _FakeProvider implements CloudSyncProvider {
  Map<String, dynamic>? remoteSettings;
  Map<String, dynamic>? pushedSettings;
  bool pullSettingsShouldThrow = false;
  int pushedManifestCount = 0;

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
  Future<void> pushManifest(SyncManifest manifest) async {
    pushedManifestCount++;
  }

  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;

  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}

  @override
  Future<Map<String, dynamic>?> pullSettings() async {
    if (pullSettingsShouldThrow) {
      throw Exception('simulated 500 from provider');
    }
    return remoteSettings;
  }

  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {
    pushedSettings = body;
  }
}
