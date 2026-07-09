import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';

/// Tracks whether the post-first-sign-in onboarding flow has completed
/// on THIS install. False until the user explicitly clicks through the
/// onboarding screen. Set-and-forget — once true, the screen is never
/// shown again for this install.
///
/// Scoped per install (not per user / not synced) on purpose. Value +
/// persistence live in the unified SettingsController.
class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsProvider).value?.onboardingCompleted ?? false;

  /// Marks onboarding done. Called by the onboarding screen on either
  /// branch (new user OR migrating from another device).
  Future<void> markCompleted() =>
      ref.read(settingsProvider.notifier).setOnboardingCompleted(true);

  /// Test-only escape hatch: reset the flag so an integration test can
  /// re-run onboarding from a fresh state.
  Future<void> reset() =>
      ref.read(settingsProvider.notifier).setOnboardingCompleted(false);
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
  () => OnboardingCompletedNotifier(),
);
