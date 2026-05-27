import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/gas_log_settings.dart';
import 'package:hmm_console/features/settings/domain/gas_log_units.dart';
import 'package:hmm_console/features/settings/domain/sync_settings.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the SharedPreferences ↔ SyncableSettings translation. The
/// repo is pure-Dart (no Riverpod) so the test setup is just the
/// shared_preferences mock initializer.
void main() {
  late SyncableSettingsRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = SyncableSettingsRepository();
  });

  group('read', () {
    test('returns defaults when no keys are persisted', () async {
      final s = await repo.read();
      expect(s.gasLog.distanceUnit, DistanceUnit.mile);
      expect(s.gasLog.fuelUnit, FuelUnit.gallon);
      expect(s.gasLog.showRegistration, true);
      expect(s.syncSettings.networkPolicy, SyncNetworkPolicy.wifiOnly);
      expect(s.localeCode, isNull);
      expect(s.lastModified, SyncableSettings.epochZero);
    });

    test('hydrates from the existing per-feature SharedPreferences keys',
        () async {
      SharedPreferences.setMockInitialValues({
        'gas_log_settings': const GasLogSettings(
          distanceUnit: DistanceUnit.kilometer,
          fuelUnit: FuelUnit.liter,
          currency: CurrencyCode.cad,
          showRegistration: false,
        ).toJsonString(),
        'sync.network_policy': 'anyNetwork',
        'app_locale': 'zh',
        'settings.last_modified': '2026-05-26T10:00:00.000Z',
      });
      repo = SyncableSettingsRepository();

      final s = await repo.read();
      expect(s.gasLog.distanceUnit, DistanceUnit.kilometer);
      expect(s.gasLog.fuelUnit, FuelUnit.liter);
      expect(s.gasLog.showRegistration, false);
      expect(s.syncSettings.networkPolicy, SyncNetworkPolicy.anyNetwork);
      expect(s.localeCode, 'zh');
      expect(s.lastModified, DateTime.utc(2026, 5, 26, 10));
    });

    test('treats a garbage `gas_log_settings` blob as defaults', () async {
      // Don't crash on legacy / corrupt data — a v0 install or a
      // partial write should fall back to defaults, not throw.
      SharedPreferences.setMockInitialValues({
        'gas_log_settings': 'not-json-at-all',
      });
      repo = SyncableSettingsRepository();

      final s = await repo.read();
      expect(s.gasLog.distanceUnit, DistanceUnit.mile);
    });

    test('treats an unknown network_policy value as wifiOnly (safe default)',
        () async {
      SharedPreferences.setMockInitialValues({
        'sync.network_policy': 'unknown_typo',
      });
      repo = SyncableSettingsRepository();

      final s = await repo.read();
      expect(s.syncSettings.networkPolicy, SyncNetworkPolicy.wifiOnly);
    });
  });

  group('apply', () {
    test('writes every field through to the underlying prefs keys',
        () async {
      final bundle = SyncableSettings(
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

      await repo.apply(bundle);
      final prefs = await SharedPreferences.getInstance();

      // Round-trips via the same parsers the per-feature notifiers use.
      final gasLogJson = prefs.getString('gas_log_settings');
      expect(gasLogJson, isNotNull);
      final gas = GasLogSettings.fromJsonString(gasLogJson!);
      expect(gas.distanceUnit, DistanceUnit.kilometer);
      expect(gas.showRegistration, false);

      expect(prefs.getString('sync.network_policy'), 'anyNetwork');
      expect(prefs.getString('app_locale'), 'zh');
      expect(prefs.getString('settings.last_modified'),
          '2026-05-26T12:00:00.000Z');
    });

    test('apply with a null localeCode REMOVES the app_locale key '
        '(switches device back to "follow system")', () async {
      // Seed a non-null locale first.
      SharedPreferences.setMockInitialValues({'app_locale': 'zh'});
      repo = SyncableSettingsRepository();

      final bundle = SyncableSettings(
        gasLog: const GasLogSettings(),
        syncSettings: const SyncSettings(),
        localeCode: null,
        lastModified: DateTime.utc(2026, 5, 26),
      );

      await repo.apply(bundle);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), isNull,
          reason: 'apply(localeCode: null) must remove, not write empty');
    });
  });

  group('bumpLastModified', () {
    test('updates the persisted timestamp + returns the new value',
        () async {
      final before = await repo.read();
      expect(before.lastModified, SyncableSettings.epochZero);

      final now = await repo.bumpLastModified();
      final after = await repo.read();

      expect(after.lastModified.isAtSameMomentAs(now), isTrue);
      expect(after.lastModified.isAfter(SyncableSettings.epochZero), isTrue);
    });
  });
}
