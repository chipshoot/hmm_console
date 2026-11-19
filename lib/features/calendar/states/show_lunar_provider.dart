// lib/features/calendar/states/show_lunar_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/syncable_settings_repository.dart';
import '../../settings/providers/settings_bus_provider.dart';

/// "Show lunar calendar". Synced (a [SyncableSettings] field). Same shape as
/// `ContactSortByNotifier`: a synchronous default of off, hydrated from
/// prefs, re-read when a pulled settings bundle bumps the bus.
class ShowLunarNotifier extends Notifier<bool> {
  // A set() that lands before hydration finishes must not be overwritten by
  // the stale prefs read.
  int _writes = 0;

  @override
  bool build() {
    ref.watch(settingsBusProvider);
    _writes = 0;
    _load();
    return false;
  }

  Future<void> _load() async {
    final writesAtStart = _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || _writes != writesAtStart) return;
      state =
          prefs.getBool(SyncableSettingsRepository.calendarShowLunarKey) ??
          false;
    } catch (e) {
      // Type only. The calendar stays Gregorian-only.
      debugPrint('ShowLunar: setting unreadable (${e.runtimeType})');
    }
  }

  Future<void> set(bool value) async {
    _writes++;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SyncableSettingsRepository.calendarShowLunarKey, value);
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final showLunarProvider = NotifierProvider<ShowLunarNotifier, bool>(
  ShowLunarNotifier.new,
);
