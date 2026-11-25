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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
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

/// Runs the router's top-level redirect for [path], as any navigation would.
/// This is also where the closure's ref.watch calls register.
Future<String?> _redirectFor(GoRouter router, String path) {
  final config = router.configuration;
  final state = config.buildTopLevelGoRouterState(
    config.findMatch(Uri.parse(path)),
  );
  return Future.value(config.topRedirect(_NoContext(), state));
}

/// A container whose auth stream the test drives, with settings loaded,
/// onboarding done and the data mode set to [mode].
Future<(ProviderContainer, StreamController<bool>)> _setUp(
  DataMode mode, {
  required bool signedIn,
}) async {
  final auth = StreamController<bool>.broadcast();
  final container = ProviderContainer(
    overrides: [
      routerAuthStateProvider.overrideWith((_) async* {
        yield signedIn;
        yield* auth.stream;
      }),
    ],
  );
  addTearDown(container.dispose);
  // Not awaited: a broadcast controller's close() waits for its listeners.
  addTearDown(() {
    auth.close();
  });
  final authSub = container.listen(routerAuthStateProvider, (_, _) {});
  addTearDown(authSub.close);
  await container.read(routerAuthStateProvider.future);
  await container.read(settingsProvider.future);
  final settings = container.read(settingsProvider.notifier);
  await settings.setOnboardingCompleted(true);
  await settings.setDataMode(mode);
  await container.pump();
  return (container, auth);
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

  test('signing in while in local mode does not rebuild the router', () async {
    final (container, auth) = await _setUp(DataMode.local, signedIn: false);
    final sub = container.listen(routerConfig, (_, _) {});
    addTearDown(sub.close);
    final before = container.read(routerConfig);
    expect(
      await _redirectFor(before, '/notes'),
      isNull,
      reason: 'local data needs no Hmm login',
    );

    auth.add(true);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();

    final after = container.read(routerConfig);
    expect(
      identical(before, after),
      isTrue,
      reason: 'a sign-in in local mode must not reset the navigation stack',
    );
  });

  test('signing out in cloudApi sends you to /auth', () async {
    final (container, auth) = await _setUp(DataMode.cloudApi, signedIn: true);
    final sub = container.listen(routerConfig, (_, _) {});
    addTearDown(sub.close);
    expect(
      await _redirectFor(container.read(routerConfig), '/notes'),
      isNull,
      reason: 'signed in to Hmm cloud: no redirect',
    );

    auth.add(false);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();

    expect(await _redirectFor(container.read(routerConfig), '/notes'), '/auth');
  });
}
