import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selected appearance. Per-device only: deliberately NOT part of
/// `SyncableSettings` (a phone and a tablet may want different looks).
enum AppearanceMode {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
    AppearanceMode.system => ThemeMode.system,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
  };

  /// Missing or unknown stored values fall back to [system].
  static AppearanceMode parse(String? raw) {
    for (final m in values) {
      if (m.name == raw) return m;
    }
    return AppearanceMode.system;
  }
}

class AppearanceNotifier extends Notifier<AppearanceMode> {
  static const _key = 'appearance';

  // Set once the user picks, so a slow initial prefs load can't overwrite it.
  bool _picked = false;

  @override
  AppearanceMode build() {
    _load();
    return AppearanceMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || _picked) return;
    state = AppearanceMode.parse(prefs.getString(_key));
  }

  Future<void> set(AppearanceMode mode) async {
    _picked = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, AppearanceMode>(
  AppearanceNotifier.new,
);
