import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/settings/presentation/widgets/hmm_account_section.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _User extends CurrentUserNotifier {
  @override
  CurrentUserDataModel? build() =>
      const CurrentUserDataModel(uid: 'u1', email: 'me@example.com');
}

class _FakeSignOut implements IdpTokenService {
  int calls = 0;
  @override
  Future<void> clearTokens() async => calls++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required bool signedIn,
  required _FakeSignOut signOut,
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: HmmAccountSection()),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => const Scaffold(body: Text('login-screen')),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      if (signedIn) currentUserProvider.overrideWith(_User.new),
      idpTokenServiceProvider.overrideWithValue(signOut),
    ],
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
  testWidgets('signed out shows Sign in and pushes /auth', (tester) async {
    await _pump(tester, signedIn: false, signOut: _FakeSignOut());
    expect(find.textContaining('Not signed in'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('login-screen'), findsOneWidget);
  });

  testWidgets('signed in shows email and Sign out', (tester) async {
    await _pump(tester, signedIn: true, signOut: _FakeSignOut());
    expect(find.text('Signed in as me@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('sign-out in local mode stays on Settings and clears the user', (
    tester,
  ) async {
    final so = _FakeSignOut();
    final c = await _pump(tester, signedIn: true, signOut: so);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(so.calls, 1);
    expect(c.read(currentUserProvider), isNull);
    expect(find.text('login-screen'), findsNothing);
    expect(find.byType(HmmAccountSection), findsOneWidget);
    expect(
      find.text('Signed out of Hmm. Your data stays on this device.'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
  });
}
