import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';

/// Persists whether the first-run "Quick start" defaults card on the
/// dashboard has been acknowledged. Once seen, the card never reappears
/// — Settings is the place to revisit defaults afterwards. Value +
/// persistence live in the unified SettingsController.
class IntroCardSeenNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsProvider).value?.dashboardIntroCardSeen ?? false;

  Future<void> markSeen() =>
      ref.read(settingsProvider.notifier).setDashboardIntroCardSeen(true);
}

final introCardSeenProvider = NotifierProvider<IntroCardSeenNotifier, bool>(
  () => IntroCardSeenNotifier(),
);
