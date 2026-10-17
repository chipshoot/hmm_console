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

const _appearanceKey = 'appearance';

/// Reads the stored mode (missing/unknown => system) without rewriting it.
/// Called in main() before runApp so the first frame is already correct.
Future<AppearanceMode> loadStoredAppearance() async {
  final prefs = await SharedPreferences.getInstance();
  return AppearanceMode.parse(prefs.getString(_appearanceKey));
}

/// The mode known before the first frame. Overridden in main(); defaults to
/// system (tests).
final initialAppearanceProvider = Provider<AppearanceMode>(
  (ref) => AppearanceMode.system,
);

class AppearanceNotifier extends Notifier<AppearanceMode> {
  @override
  AppearanceMode build() => ref.read(initialAppearanceProvider);

  Future<void> set(AppearanceMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appearanceKey, mode.name);
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, AppearanceMode>(
  AppearanceNotifier.new,
);
