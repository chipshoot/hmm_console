// Reported: choosing a domain filter on the notes list navigated to the
// main screen.
//
// The chain: the drawer records filter usage → settingsProvider emits →
// the routerConfig PROVIDER rebuilt, because its redirect closure called
// ref.watch(settingsProvider) and so depended on the whole settings blob.
// main.dart watches routerConfig, so a rebuilt provider handed
// MaterialApp.router a brand-new GoRouter, which starts at initialLocation
// and discards the stack the user was standing on.
//
// The property to pin: once a redirect has run (which is when the watch
// registers), an unrelated settings write must NOT hand out a new GoRouter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/auth_change_provider.dart';
import 'package:hmm_console/core/navigation/router_config.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The router's redirect never touches its BuildContext, and a real one
/// would drag the test into FakeAsync, where the settings load never wakes.
class _NoContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('redirect must not use BuildContext');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a settings write after a redirect does NOT rebuild the router',
      () async {
    final container = ProviderContainer(overrides: [
      routerAuthStateProvider.overrideWith((_) => Stream.value(true)),
    ]);
    addTearDown(container.dispose);
    // Riverpod 3 only subscribes a StreamProvider once it has a listener;
    // a bare read(.future) waits forever.
    final authSub = container.listen(routerAuthStateProvider, (_, _) {});
    addTearDown(authSub.close);
    await container.read(routerAuthStateProvider.future);
    await container.read(settingsProvider.future);
    await container.read(settingsProvider.notifier).setOnboardingCompleted(true);

    // Keep the provider alive across the write, as main.dart does.
    final sub = container.listen(routerConfig, (_, _) {});
    addTearDown(sub.close);
    final before = container.read(routerConfig);

    // Run the redirect once, as any navigation would. This is where the
    // closure's ref.watch calls register their dependencies.
    final config = before.configuration;
    final state = config.buildTopLevelGoRouterState(
        config.findMatch(Uri.parse('/notes')));
    expect(await config.topRedirect(_NoContext(), state), isNull,
        reason: 'authenticated + onboarded: /notes needs no redirect');

    // The exact write the filter drawer makes.
    await container
        .read(settingsProvider.notifier)
        .setNotesFilterUsage(const {'AutomobileMan': 1});
    await container.pump();

    final after = container.read(routerConfig);
    expect(identical(before, after), isTrue,
        reason: 'a new GoRouter resets the navigation stack to initialLocation; '
            'the filter tap writes a setting, so this is the reported bug');
  });
}
