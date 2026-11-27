// When the IdP ends a registered user's session in local / cloudStorage,
// the home screen asks them to sign in again — without blocking anything.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/presentation/widges/hmm_session_expired_banner.dart';
import 'package:hmm_console/features/auth/providers/hmm_session_expired_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

class _FakeIdp implements IdpTokenService {
  int dismissed = 0;
  @override
  Future<void> dismissExpiredSession() async => dismissed++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<_FakeIdp> _pump(
  WidgetTester tester, {
  required DataMode mode,
  required String? expired,
}) async {
  final idp = _FakeIdp();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: HmmSessionExpiredBanner()),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => const Scaffold(body: Text('login-screen')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _StubMode(mode)),
        idpTokenServiceProvider.overrideWithValue(idp),
        hmmSessionExpiredProvider.overrideWith((_) => Stream.value(expired)),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return idp;
}

void main() {
  testWidgets('shows in local mode when the session expired', (tester) async {
    await _pump(tester, mode: DataMode.local, expired: 'me@x.com');
    expect(find.text('Hmm session expired'), findsOneWidget);
    expect(
      find.text(
        'Sign in again to keep using your Hmm account. Your data on this '
        'device is safe.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows in cloudStorage mode too', (tester) async {
    await _pump(tester, mode: DataMode.cloudStorage, expired: '');
    expect(find.text('Hmm session expired'), findsOneWidget);
  });

  testWidgets('hidden when no session expired', (tester) async {
    await _pump(tester, mode: DataMode.local, expired: null);
    expect(find.text('Hmm session expired'), findsNothing);
  });

  testWidgets('hidden in cloudApi, where the login gate handles it',
      (tester) async {
    await _pump(tester, mode: DataMode.cloudApi, expired: 'me@x.com');
    expect(find.text('Hmm session expired'), findsNothing);
  });

  testWidgets('Sign in opens the login screen', (tester) async {
    await _pump(tester, mode: DataMode.local, expired: 'me@x.com');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('login-screen'), findsOneWidget);
  });

  testWidgets('Not now dismisses the notice', (tester) async {
    final idp = await _pump(tester, mode: DataMode.local, expired: 'me@x.com');
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(idp.dismissed, 1);
  });
}
