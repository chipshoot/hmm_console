/// Where the router should send the user with respect to the one-shot
/// onboarding flow, or null to leave them where they are.
///
/// A sign-in is not a precondition: local and cloud-storage data need no Hmm
/// login, so a signed-out new install goes straight to setup. The login
/// gate (login_gate.dart) runs first and owns cloudApi sign-in.
///
/// Extracted from the router's redirect closure so the rule can be tested
/// without standing up auth, settings and a GoRouter.
///
/// [settingsLoaded] is the part that matters. The onboarding flag lives in
/// SharedPreferences and is read asynchronously, so on a cold start it is
/// briefly unknown. Treating "unknown" as "not onboarded" — which a bare
/// `?? false` does — sent every returning user through setup on every
/// launch. Until the persisted value has actually arrived, this declines to
/// decide.
String? onboardingRedirect({
  required bool settingsLoaded,
  required bool onboardingCompleted,
  required bool isOnboardingPath,
  required bool isAuthPath,
}) {
  // Never pull the user off the login: onboarding's Hmm cloud option pushes
  // /auth before onboarding is marked done.
  if (isAuthPath) return null;
  if (!settingsLoaded) return null;

  if (!onboardingCompleted && !isOnboardingPath) return '/onboarding';

  // Landing back on /onboarding once it is done (e.g. via a deep link)
  // bounces home — the flow is one-shot.
  if (onboardingCompleted && isOnboardingPath) return '/';

  return null;
}
