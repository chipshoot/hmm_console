import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/syncable_settings_repository.dart';
import '../domain/sync_settings.dart';
import 'settings_bus_provider.dart';

/// Mirrors the pattern in `lib/core/data/data_mode.dart`'s
/// [DataModeNotifier]: synchronous `build()` returns the default so the
/// UI doesn't need to handle a Future state, and an async `_loadFromPrefs`
/// hydrates the persisted value (overwriting `state` once shared_prefs
/// returns).
class SyncSettingsNotifier extends Notifier<SyncSettings> {
  static const _networkPolicyKey = 'sync.network_policy';

  @override
  SyncSettings build() {
    // Same settings-bus subscription as the other settings notifiers
    // so a remotely-pulled SyncableSettings bundle propagates into the
    // in-memory state without needing an app restart.
    ref.watch(settingsBusProvider);
    _loadFromPrefs();
    // Default per decision C2: WiFi only. Conservative — matches the
    // OneDrive desktop client's default behavior and keeps a metered
    // cellular plan from being chewed through silently.
    return const SyncSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Riverpod 3 throws on `state =` after the Notifier is disposed.
    // This Notifier is normally singleton-for-app-lifetime, but tests
    // dispose containers eagerly — without this guard the load
    // continuation fires after the test's `addTearDown(container.dispose)`
    // and yields a "Cannot use Ref after it has been disposed" error.
    if (!ref.mounted) return;
    final stored = prefs.getString(_networkPolicyKey);
    state = SyncSettings(
      networkPolicy: switch (stored) {
        'anyNetwork' => SyncNetworkPolicy.anyNetwork,
        // Any other value (null, legacy, typo) falls back to the safe
        // default.
        _ => SyncNetworkPolicy.wifiOnly,
      },
    );
  }

  Future<void> setNetworkPolicy(SyncNetworkPolicy policy) async {
    state = state.copyWith(networkPolicy: policy);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_networkPolicyKey, policy.name);
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final syncSettingsProvider =
    NotifierProvider<SyncSettingsNotifier, SyncSettings>(
  () => SyncSettingsNotifier(),
);
