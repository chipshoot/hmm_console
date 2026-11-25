import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/auth/presentation/screens/register_screen.dart';
import 'package:hmm_console/features/auth/states/register_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// Lets the test complete a registration without touching repositories.
class _FakeRegisterState extends RegisterState {
  void succeed() => state = const AsyncValue.data(true);
}

GoRouter _router({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('HOME')),
    ),
    GoRoute(
      path: '/auth',
      builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      routes: [GoRoute(path: 'register', builder: (_, _) => RegisterScreen())],
    ),
  ],
);

Future<ProviderContainer> _pump(WidgetTester tester, GoRouter router) async {
  final container = ProviderContainer(
    overrides: [registerStateProvider.overrideWith(_FakeRegisterState.new)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('register pushed from a pushed login pops back to it, keeping '
      'the stack below', (tester) async {
    final router = _router(initialLocation: '/');
    addTearDown(router.dispose);
    final container = await _pump(tester, router);

    bool? loginResult;
    var loginPopped = false;
    router.push<bool>('/auth').then((v) {
      loginPopped = true;
      loginResult = v;
    });
    await tester.pumpAndSettle();
    router.push('/auth/register');
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    (container.read(registerStateProvider.notifier) as _FakeRegisterState)
        .succeed();
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(loginPopped, isFalse, reason: 'the login push is still pending');

    // The screen that pushed the login is still underneath.
    router.pop(true);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(loginResult, isTrue);
  });

  testWidgets('register opened directly (nothing to pop) lands on /auth', (
    tester,
  ) async {
    // A top-level route, so no /auth page is built underneath.
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/auth',
          builder: (_, _) => const Scaffold(body: Text('LOGIN')),
        ),
        GoRoute(path: '/register', builder: (_, _) => RegisterScreen()),
      ],
    );
    addTearDown(router.dispose);
    final container = await _pump(tester, router);
    expect(find.byType(RegisterScreen), findsOneWidget);

    (container.read(registerStateProvider.notifier) as _FakeRegisterState)
        .succeed();
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
