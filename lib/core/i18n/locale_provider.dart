import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/settings/data/syncable_settings_repository.dart';
import '../../features/settings/providers/settings_bus_provider.dart';

/// User-selected UI locale. `null` = follow the platform locale.
class LocaleNotifier extends Notifier<Locale?> {
  static const _key = 'app_locale';

  @override
  Locale? build() {
    // Same settings-bus subscription as the other syncable settings —
    // remote pull writes the locale to prefs + bumps the bus, this
    // notifier rebuilds + re-reads.
    ref.watch(settingsBusProvider);
    _loadFromPrefs();
    return null; // Default: follow system until user picks.
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final code = prefs.getString(_key);
    if (code != null && code.isNotEmpty) {
      state = Locale(code);
    } else {
      state = null;
    }
  }

  /// Pass `null` to go back to "follow system".
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  () => LocaleNotifier(),
);
