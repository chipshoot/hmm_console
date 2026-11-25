import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/auth/owner_id.dart';
import 'package:hmm_console/core/core.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/auth/data/data.dart';
import 'package:hmm_console/features/auth/presentation/screens/login_screen.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/auth/states/login_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.user);
  final CurrentUserDataModel user;
  int signOuts = 0;

  @override
  Future<CurrentUserDataModel> loginWithEmailPassword({
    required String email,
    required String password,
  }) async => user;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  Future<CurrentUserDataModel> registerWithEmailPassword({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) => throw UnimplementedError();

  @override
  Stream<bool> isUserAuthenticated() => const Stream.empty();
}

class _FixedMode extends DataModeNotifier {
  _FixedMode(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
  @override
  Future<void> setMode(DataMode mode) async => state = mode;
}

Future<(ProviderContainer, _FakeAuth, OwnerIdStore)> _setup({
  String? linkSub,
  String? linkEmail,
  String uid = 'sub-a',
  DataMode mode = DataMode.local,
}) async {
  SharedPreferences.setMockInitialValues({
    'hmm.linkedHmmSub': ?linkSub,
    'hmm.linkedHmmEmail': ?linkEmail,
  });
  final auth = _FakeAuth(CurrentUserDataModel(uid: uid, email: '$uid@x.com'));
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      dataModeProvider.overrideWith(() => _FixedMode(mode)),
    ],
  );
  addTearDown(container.dispose);
  final store = await container.read(ownerIdStoreProvider.future);
  return (container, auth, store);
}

void main() {
  test('first sign-in sets the link', () async {
    final (c, auth, store) = await _setup();
    await c.read(loginStateProvider.notifier).loginWithEmailPassword('a', 'b');
    expect(c.read(loginStateProvider).value, isTrue);
    expect(store.linkedHmmSub, 'sub-a');
    expect(store.linkedHmmEmail, 'sub-a@x.com');
    expect(auth.signOuts, 0);
  });

  test('same account signs in', () async {
    final (c, auth, store) = await _setup(linkSub: 'sub-a', linkEmail: 'old');
    await c.read(loginStateProvider.notifier).loginWithEmailPassword('a', 'b');
    expect(c.read(loginStateProvider).value, isTrue);
    expect(c.read(currentUserProvider)?.uid, 'sub-a');
    expect(store.linkedHmmEmail, 'old');
    expect(auth.signOuts, 0);
  });

  test(
    'different account is refused, tokens cleared, link unchanged',
    () async {
      final (c, auth, store) = await _setup(
        linkSub: 'sub-z',
        linkEmail: 'z@x.com',
      );
      await c
          .read(loginStateProvider.notifier)
          .loginWithEmailPassword('a', 'b');
      final err = c.read(loginStateProvider).error;
      expect(err, isA<OtherHmmAccountException>());
      expect((err as OtherHmmAccountException).linkedAccount, 'z@x.com');
      expect(auth.signOuts, 1);
      expect(c.read(currentUserProvider), isNull);
      expect(store.linkedHmmSub, 'sub-z');
      expect(store.linkedHmmEmail, 'z@x.com');
    },
  );

  testWidgets('dialog shows the linked email; Keep data local in cloudApi '
      'switches to local', (tester) async {
    final (c, _, _) = await _setup(
      linkSub: 'sub-z',
      linkEmail: 'z@x.com',
      mode: DataMode.cloudApi,
    );
    final router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
        GoRoute(path: '/auth', builder: (_, _) => const LoginScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'a@x.com');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.pump();
    await tester.tap(find.widgetWithText(HighlightButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Different Hmm account'), findsOneWidget);
    expect(find.textContaining('z@x.com'), findsOneWidget);

    await tester.tap(find.text('Keep data local'));
    await tester.pumpAndSettle();
    expect(c.read(dataModeProvider), DataMode.local);
    expect(find.text('HOME'), findsOneWidget);
  });
}
