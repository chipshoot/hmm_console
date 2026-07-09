import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';

const _cap = 8;

/// Most-recently-launched destination ids, newest first, capped at [_cap].
/// Device-local (NOT synced) — recents are personal to the device, like a
/// phone's app-switcher. Value + persistence live in the unified
/// SettingsController.
class LauncherRecentsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() =>
      ref.watch(settingsProvider).value?.launcherRecents ?? const [];

  /// Reads the current recents from the controller (the source of truth)
  /// rather than this notifier's derived state, so consecutive records don't
  /// race on a stale copy.
  Future<void> record(String id) async {
    final settings = await ref.read(settingsProvider.future);
    final next =
        [id, ...settings.launcherRecents.where((x) => x != id)].take(_cap).toList();
    await ref.read(settingsProvider.notifier).setLauncherRecents(next);
  }
}

final launcherRecentsProvider =
    NotifierProvider<LauncherRecentsNotifier, List<String>>(
  () => LauncherRecentsNotifier(),
);
