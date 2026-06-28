import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/syncable_settings_repository.dart';
import '../../settings/providers/settings_bus_provider.dart';
import '../domain/launcher_prefs.dart';

const _prefsKey = 'launcher_prefs';

/// Holds [LauncherPrefs] (favorites + aliases). Reads/writes the same
/// SharedPreferences key the SyncableSettingsRepository owns, and bumps
/// the settings stamp on every mutation so the change syncs. Watches
/// the settings bus so a remote pull refreshes the in-memory state.
class LauncherPrefsNotifier extends Notifier<LauncherPrefs> {
  @override
  LauncherPrefs build() {
    ref.watch(settingsBusProvider);
    ref.keepAlive();
    _loadFromPrefs();
    return LauncherPrefs.empty;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      state = LauncherPrefs.fromJsonString(json);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.toJsonString());
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }

  Future<void> toggleFavorite(String id) async {
    final favs = [...state.favorites];
    favs.contains(id) ? favs.remove(id) : favs.add(id);
    state = state.copyWith(favorites: favs);
    await _persist();
  }

  Future<void> setFavorites(List<String> ids) async {
    state = state.copyWith(favorites: List.of(ids));
    await _persist();
  }

  Future<void> addAlias(String alias, String id) async {
    final aliases = {...state.aliases, alias: id};
    state = state.copyWith(aliases: aliases);
    await _persist();
  }

  Future<void> removeAlias(String alias) async {
    final aliases = {...state.aliases}..remove(alias);
    state = state.copyWith(aliases: aliases);
    await _persist();
  }
}

final launcherPrefsProvider =
    NotifierProvider<LauncherPrefsNotifier, LauncherPrefs>(
  () => LauncherPrefsNotifier(),
);
