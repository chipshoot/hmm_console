import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/onboarding_redirect.dart';

void main() {
  test('does NOT send a returning user to setup while settings are loading',
      () {
    // The regression. The onboarding flag is read asynchronously, so on a
    // cold start it is briefly unknown. Deciding then — which a bare
    // `?? false` did — sent every returning user through setup on every
    // launch, which looked exactly like their data had been wiped.
    expect(
      onboardingRedirect(
        settingsLoaded: false,
        onboardingCompleted: false, // the misleading not-yet-loaded default
        isOnboardingPath: false,
        isAuthPath: false,
      ),
      isNull,
      reason: 'hold position until the persisted flag actually arrives',
    );
  });

  test('sends a genuinely new user to setup once settings have loaded', () {
    expect(
      onboardingRedirect(
        settingsLoaded: true,
        onboardingCompleted: false,
        isOnboardingPath: false,
        isAuthPath: false,
      ),
      '/onboarding',
    );
  });

  test('leaves an onboarded user where they are', () {
    expect(
      onboardingRedirect(
        settingsLoaded: true,
        onboardingCompleted: true,
        isOnboardingPath: false,
        isAuthPath: false,
      ),
      isNull,
    );
  });

  test('bounces an onboarded user off the onboarding route', () {
    expect(
      onboardingRedirect(
        settingsLoaded: true,
        onboardingCompleted: true,
        isOnboardingPath: true,
        isAuthPath: false,
      ),
      '/',
    );
  });

  test('does not loop a new user already on the onboarding route', () {
    expect(
      onboardingRedirect(
        settingsLoaded: true,
        onboardingCompleted: false,
        isOnboardingPath: true,
        isAuthPath: false,
      ),
      isNull,
    );
  });

  test('a signed-out new install goes to setup (login is not a gate)', () {
    // Login-free tiers: onboarding no longer waits for a sign-in.
    expect(
      onboardingRedirect(
        settingsLoaded: true,
        onboardingCompleted: false,
        isOnboardingPath: false,
        isAuthPath: false,
      ),
      '/onboarding',
    );
  });

  test('never redirects off /auth, so onboarding can push the login', () {
    for (final loaded in [true, false]) {
      for (final done in [true, false]) {
        expect(
          onboardingRedirect(
            settingsLoaded: loaded,
            onboardingCompleted: done,
            isOnboardingPath: false,
            isAuthPath: true,
          ),
          isNull,
        );
      }
    }
  });
}
