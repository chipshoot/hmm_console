import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/onboarding/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coverage for the post-sign-in onboarding completion flag. Mirrors the
/// pattern in `sync_settings_provider_test.dart` — synchronous-default in
/// build(), async hydrate from SharedPreferences.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() => ProviderContainer();

  test('default is false when nothing is persisted', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    expect(container.read(onboardingCompletedProvider), isFalse,
        reason: 'fresh install must trigger the onboarding redirect');
  });

  test('reads a persisted true on first read', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
    });
    final container = makeContainer();
    addTearDown(container.dispose);

    // build() returns the synchronous default (false), then
    // _loadFromPrefs flips it after one microtask.
    expect(container.read(onboardingCompletedProvider), isFalse,
        reason: 'pre-hydrate default');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(onboardingCompletedProvider), isTrue);
  });

  test('markCompleted persists and updates state', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    // Drain the initial load before mutating.
    container.read(onboardingCompletedProvider);
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(onboardingCompletedProvider.notifier);
    await notifier.markCompleted();

    expect(container.read(onboardingCompletedProvider), isTrue);

    // Persistence: a fresh container reading from the same mocked
    // prefs singleton should see the flag.
    final container2 = makeContainer();
    addTearDown(container2.dispose);
    container2.read(onboardingCompletedProvider); // trigger build
    await Future<void>.delayed(Duration.zero);
    expect(container2.read(onboardingCompletedProvider), isTrue);
  });

  test('reset clears the flag (test-only escape hatch)', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
    });
    final container = makeContainer();
    addTearDown(container.dispose);
    // Read first to trigger build() + _loadFromPrefs, then await.
    container.read(onboardingCompletedProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(onboardingCompletedProvider), isTrue);

    await container.read(onboardingCompletedProvider.notifier).reset();
    expect(container.read(onboardingCompletedProvider), isFalse);

    // Verify it was wiped from prefs, not just from in-memory state.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isNull);
  });
}
