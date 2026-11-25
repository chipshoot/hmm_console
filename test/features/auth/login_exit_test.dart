import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/auth/presentation/screens/login_screen.dart';
import 'package:hmm_console/features/auth/states/login_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// Succeeds without touching repositories.
class _SucceedingLoginState extends LoginState {
  @override
  Future<void> loginWithEmailPassword(String email, String password) async {
    state = const AsyncValue.loading();
    state = const AsyncValue.data(true);
  }
}

class _FixedMode extends DataModeNotifier {
  _FixedMode(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required DataMode mode,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loginStateProvider.overrideWith(() => _SucceedingLoginState()),
        dataModeProvider.overrideWith(() => _FixedMode(mode)),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _logIn(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'user@example.com');
  await tester.enterText(fields.at(1), 'secret123');
  await tester.pump();
  await tester.tap(find.widgetWithText(HighlightButton, 'Login'));
  await tester.pumpAndSettle();
}

GoRouter _router({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('HOME')),
    ),
    GoRoute(path: '/auth', builder: (_, _) => const LoginScreen()),
  ],
);

void main() {
  testWidgets('local mode: a login on a /auth that was not pushed goes home', (
    tester,
  ) async {
    // In local mode the router never moves on sign-in, so without this the
    // user would be stranded on the login screen.
    final router = _router(initialLocation: '/auth');
    addTearDown(router.dispose);
    await _pumpApp(tester, mode: DataMode.local, router: router);

    await _logIn(tester);

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('a pushed login pops back with true', (tester) async {
    final router = _router(initialLocation: '/');
    addTearDown(router.dispose);
    await _pumpApp(tester, mode: DataMode.local, router: router);

    // Captured with then(): awaiting inside the fake-async zone would hang
    // if the pop never came.
    bool? popped;
    router.push<bool>('/auth').then((v) => popped = v);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await _logIn(tester);

    expect(popped, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('cloudApi: an unpushed login leaves navigation to the router', (
    tester,
  ) async {
    // The real router rebuilds when loginRequiredProvider flips; this test
    // router does not, so the screen must stay put.
    final router = _router(initialLocation: '/auth');
    addTearDown(router.dispose);
    await _pumpApp(tester, mode: DataMode.cloudApi, router: router);

    await _logIn(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
