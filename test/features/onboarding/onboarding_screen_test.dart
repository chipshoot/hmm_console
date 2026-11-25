import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:hmm_console/features/onboarding/providers/onboarding_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _FakeMode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.local;

  @override
  Future<void> setMode(DataMode mode) async => state = mode;
}

class _FakeCompleted extends OnboardingCompletedNotifier {
  @override
  bool build() => false;

  @override
  Future<void> markCompleted() async => state = true;
}

class _FakeIdp implements IdpTokenService {
  _FakeIdp(this.session);
  final bool session;

  @override
  Future<bool> hasHmmSession() async => session;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  bool? authResult, {
  bool hmmSession = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/auth',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.pop(authResult),
            child: const Text('STUB-AUTH'),
          ),
        ),
      ),
    ],
    initialLocation: '/onboarding',
  );
  final container = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(_FakeMode.new),
      onboardingCompletedProvider.overrideWith(_FakeCompleted.new),
      idpTokenServiceProvider.overrideWithValue(_FakeIdp(hmmSession)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('three choices are shown', (tester) async {
    await _pump(tester, true);
    expect(find.text('New to Hmm'), findsOneWidget);
    expect(find.text('I already use Hmm on another device'), findsOneWidget);
    expect(find.text('Hmm cloud (server)'), findsOneWidget);
  });

  testWidgets('Hmm cloud: login success switches to cloudApi and finishes', (
    tester,
  ) async {
    final c = await _pump(tester, true);
    await tester.tap(find.text('Hmm cloud (server)'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STUB-AUTH'));
    await tester.pumpAndSettle();
    expect(c.read(dataModeProvider), DataMode.cloudApi);
    expect(c.read(onboardingCompletedProvider), isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Hmm cloud: login cancelled stays put', (tester) async {
    final c = await _pump(tester, null);
    await tester.tap(find.text('Hmm cloud (server)'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STUB-AUTH'));
    await tester.pumpAndSettle();
    expect(c.read(dataModeProvider), DataMode.local);
    expect(c.read(onboardingCompletedProvider), isFalse);
    expect(find.text('Hmm cloud (server)'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('Hmm cloud with a Hmm session already stored skips the login', (
    tester,
  ) async {
    final c = await _pump(tester, true, hmmSession: true);
    await tester.tap(find.text('Hmm cloud (server)'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('STUB-AUTH'), findsNothing);
    expect(c.read(dataModeProvider), DataMode.cloudApi);
    expect(c.read(onboardingCompletedProvider), isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Hmm cloud: a double tap pushes the login only once', (
    tester,
  ) async {
    await _pump(tester, null);
    await tester.tap(find.text('Hmm cloud (server)'));
    await tester.pump();
    // Both taps land on the same frame's (still enabled) button.
    await tester.tap(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('STUB-AUTH'));
    await tester.pumpAndSettle();
    expect(find.text('STUB-AUTH'), findsNothing);
    expect(find.text('Hmm cloud (server)'), findsOneWidget);
  });
}
