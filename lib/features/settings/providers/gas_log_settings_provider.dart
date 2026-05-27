import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/syncable_settings_repository.dart';
import '../domain/gas_log_settings.dart';
import '../domain/gas_log_units.dart';
import 'settings_bus_provider.dart';

const _prefsKey = 'gas_log_settings';

class GasLogSettingsNotifier extends Notifier<GasLogSettings> {
  @override
  GasLogSettings build() {
    // Watch the settings bus so a remotely-pulled SyncableSettings
    // bundle (orchestrator writes to SharedPreferences + bumps the
    // bus) triggers a rebuild + re-read from prefs. Without this,
    // pulled settings would only show up after an app restart.
    ref.watch(settingsBusProvider);
    ref.keepAlive();
    _loadFromPrefs();
    return const GasLogSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      state = GasLogSettings.fromJsonString(json);
    }
  }

  Future<void> update({
    DistanceUnit? distanceUnit,
    FuelUnit? fuelUnit,
    CurrencyCode? currency,
    bool? showRegistration,
  }) async {
    state = state.copyWith(
      distanceUnit: distanceUnit,
      fuelUnit: fuelUnit,
      currency: currency,
      showRegistration: showRegistration,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.toJsonString());
    // Bump the shared SyncableSettings stamp so the next sync knows
    // this device wrote more recently than whatever's in the cloud.
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final gasLogSettingsProvider =
    NotifierProvider<GasLogSettingsNotifier, GasLogSettings>(
  () => GasLogSettingsNotifier(),
);
