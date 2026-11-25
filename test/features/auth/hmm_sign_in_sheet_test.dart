import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/presentation/hmm_sign_in_sheet.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _FakeIdp implements IdpTokenService {
  _FakeIdp(this.session);
  final bool session;
  @override
  Future<bool> hasHmmSession() async => session;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _pump(
  WidgetTester tester, {
  required bool session,
  required void Function(bool) onResult,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await ensureHmmSignedIn(context, ref, feature: 'rates'),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.pop(true),
            child: const Text('stub-login'),
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [idpTokenServiceProvider.overrideWithValue(_FakeIdp(session))],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('session present returns true with no sheet', (tester) async {
    bool? result;
    await _pump(tester, session: true, onResult: (v) => result = v);
    expect(result, isTrue);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('no session shows sheet; Cancel returns false', (tester) async {
    bool? result;
    await _pump(tester, session: false, onResult: (v) => result = v);
    expect(find.text('Sign in to Hmm to use rates'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('Sign in pushes /auth and returns its result', (tester) async {
    bool? result;
    await _pump(tester, session: false, onResult: (v) => result = v);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('stub-login'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('iOS shows a CupertinoActionSheet', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    bool? result;
    await _pump(tester, session: false, onResult: (v) => result = v);
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
