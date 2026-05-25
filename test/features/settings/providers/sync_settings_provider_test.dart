import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/domain/sync_settings.dart';
import 'package:hmm_console/features/settings/providers/sync_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coverage for the WiFi-only / Any-network persistence layer added in
/// Phase C. Uses `SharedPreferences.setMockInitialValues` so we don't
/// touch the real platform channel under `flutter test`.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() => ProviderContainer();

  test('default is wifiOnly when nothing is persisted', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    expect(
      container.read(syncSettingsProvider).networkPolicy,
      SyncNetworkPolicy.wifiOnly,
    );
  });

  test('reads a persisted "anyNetwork" value on first read', () async {
    SharedPreferences.setMockInitialValues({
      'sync.network_policy': 'anyNetwork',
    });
    final container = makeContainer();
    addTearDown(container.dispose);

    // build() returns the default synchronously; the async _loadFromPrefs
    // overwrites state after one microtask. Wait for it.
    expect(
      container.read(syncSettingsProvider).networkPolicy,
      SyncNetworkPolicy.wifiOnly,
      reason: 'sync default before async load completes',
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(syncSettingsProvider).networkPolicy,
      SyncNetworkPolicy.anyNetwork,
    );
  });

  test('falls back to wifiOnly on unknown / typo / legacy value', () async {
    SharedPreferences.setMockInitialValues({
      'sync.network_policy': 'wifi_only_LEGACY_TYPO',
    });
    final container = makeContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(syncSettingsProvider).networkPolicy,
      SyncNetworkPolicy.wifiOnly,
    );
  });

  test('setNetworkPolicy persists + updates state', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    // Drain the initial async `_loadFromPrefs` before mutating — if we
    // don't, it can race with `setNetworkPolicy` and overwrite our
    // change with the default (the mock's empty-prefs result lands
    // after our write).
    container.read(syncSettingsProvider);
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(syncSettingsProvider.notifier);
    await notifier.setNetworkPolicy(SyncNetworkPolicy.anyNetwork);
    expect(
      container.read(syncSettingsProvider).networkPolicy,
      SyncNetworkPolicy.anyNetwork,
    );

    // Verify persistence by spinning up a fresh container that reads
    // from the same SharedPreferences singleton.
    final container2 = makeContainer();
    addTearDown(container2.dispose);
    container2.read(syncSettingsProvider); // trigger build
    await Future<void>.delayed(Duration.zero);
    expect(
      container2.read(syncSettingsProvider).networkPolicy,
      SyncNetworkPolicy.anyNetwork,
    );
  });
}
