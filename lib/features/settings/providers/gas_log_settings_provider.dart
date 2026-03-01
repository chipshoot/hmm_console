import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/gas_log_settings.dart';
import '../domain/gas_log_units.dart';

const _prefsKey = 'gas_log_settings';

class GasLogSettingsNotifier extends Notifier<GasLogSettings> {
  @override
  GasLogSettings build() {
    ref.keepAlive();
    _loadFromPrefs();
    return const GasLogSettings();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      state = GasLogSettings.fromJsonString(json);
    }
  }

  Future<void> update({
    DistanceUnit? distanceUnit,
    FuelUnit? fuelUnit,
    CurrencyCode? currency,
  }) async {
    state = state.copyWith(
      distanceUnit: distanceUnit,
      fuelUnit: fuelUnit,
      currency: currency,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.toJsonString());
  }
}

final gasLogSettingsProvider =
    NotifierProvider<GasLogSettingsNotifier, GasLogSettings>(
  () => GasLogSettingsNotifier(),
);
