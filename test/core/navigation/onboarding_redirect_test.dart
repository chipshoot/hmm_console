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
        isAuthenticated: true,
        settingsLoaded: false,
        onboardingCompleted: false, // the misleading not-yet-loaded default
        isOnboardingPath: false,
      ),
      isNull,
      reason: 'hold position until the persisted flag actually arrives',
    );
  });

  test('sends a genuinely new user to setup once settings have loaded', () {
    expect(
      onboardingRedirect(
        isAuthenticated: true,
        settingsLoaded: true,
        onboardingCompleted: false,
        isOnboardingPath: false,
      ),
      '/onboarding',
    );
  });

  test('leaves an onboarded user where they are', () {
    expect(
      onboardingRedirect(
        isAuthenticated: true,
        settingsLoaded: true,
        onboardingCompleted: true,
        isOnboardingPath: false,
      ),
      isNull,
    );
  });

  test('bounces an onboarded user off the onboarding route', () {
    expect(
      onboardingRedirect(
        isAuthenticated: true,
        settingsLoaded: true,
        onboardingCompleted: true,
        isOnboardingPath: true,
      ),
      '/',
    );
  });

  test('does not loop a new user already on the onboarding route', () {
    expect(
      onboardingRedirect(
        isAuthenticated: true,
        settingsLoaded: true,
        onboardingCompleted: false,
        isOnboardingPath: true,
      ),
      isNull,
    );
  });

  test('never redirects an unauthenticated user — auth owns that', () {
    for (final loaded in [true, false]) {
      for (final done in [true, false]) {
        expect(
          onboardingRedirect(
            isAuthenticated: false,
            settingsLoaded: loaded,
            onboardingCompleted: done,
            isOnboardingPath: false,
          ),
          isNull,
        );
      }
    }
  });
}
