import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counter-style bus that ticks each time a remotely-pulled
/// [SyncableSettings] bundle is applied to local SharedPreferences.
///
/// Per-feature settings notifiers (gasLogSettingsProvider,
/// syncSettingsProvider, localeProvider) `ref.watch` this in their
/// `build()` so a remote pull triggers a rebuild + re-read from prefs.
/// Without it, the in-memory cached Notifier state would stay stale
/// until the next app launch, because the orchestrator writes prefs
/// directly without going through the Notifier setters.
///
/// Notify-only: the actual value (int) is meaningless beyond "it
/// changed". The increment-and-set pattern matches the simplest
/// possible signaling mechanism in Riverpod 3.
class SettingsBus extends Notifier<int> {
  @override
  int build() => 0;

  /// Increment so `ref.watch` listeners rebuild.
  void bump() => state = state + 1;
}

final settingsBusProvider = NotifierProvider<SettingsBus, int>(
  () => SettingsBus(),
);
