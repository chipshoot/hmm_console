import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_controller.dart';

/// Whether the Quick Access Panel (hidden long-press Home+Sync panel) is
/// enabled. Device-local (see AppSettings); default true.
class QuickPanelEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsProvider).value?.quickPanelEnabled ?? true;

  Future<void> setEnabled(bool v) =>
      ref.read(settingsProvider.notifier).setQuickPanelEnabled(v);
}

final quickPanelEnabledProvider =
    NotifierProvider<QuickPanelEnabledNotifier, bool>(
        QuickPanelEnabledNotifier.new);

/// Whether the one-time "long-press here" coach mark has been shown.
/// Device-local; default false (a per-install first-run flag).
class QuickPanelHintShownNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsProvider).value?.quickPanelHintShown ?? false;

  Future<void> markShown() =>
      ref.read(settingsProvider.notifier).setQuickPanelHintShown(true);

  /// Resets the flag so the coach mark shows again ("Show me how").
  Future<void> replay() =>
      ref.read(settingsProvider.notifier).setQuickPanelHintShown(false);
}

final quickPanelHintShownProvider =
    NotifierProvider<QuickPanelHintShownNotifier, bool>(
        QuickPanelHintShownNotifier.new);
