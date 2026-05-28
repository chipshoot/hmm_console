import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the post-first-sign-in onboarding flow has completed
/// on THIS install. False until the user explicitly clicks through the
/// onboarding screen (either "New to Hmm" or "I use Hmm on another
/// device"). Set-and-forget — once true, the screen is never shown
/// again for this install.
///
/// Scoped per install (not per user / not synced) on purpose. Onboarding
/// is a "first-launch on a fresh install" decision; sync settings would
/// re-show it after the per-user toggle propagated, which we don't want.
class OnboardingCompletedNotifier extends Notifier<bool> {
  static const _key = 'onboarding_completed';

  @override
  bool build() {
    // Same synchronous-default + async-hydrate pattern as the other
    // SharedPreferences-backed notifiers (DataModeNotifier,
    // SyncSettingsNotifier). Default `false` so a first-launch redirect
    // catches the onboarding screen before the hydrate finishes.
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_key) ?? false;
  }

  /// Marks onboarding done. Called by the onboarding screen on either
  /// branch (new user OR migrating from another device); the screen's
  /// own redirect away from /onboarding kicks in on the next router
  /// rebuild.
  Future<void> markCompleted() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Test-only escape hatch. Resets the flag back to false so an
  /// integration test can re-run onboarding from a fresh state without
  /// nuking the rest of the prefs.
  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
  () => OnboardingCompletedNotifier(),
);
