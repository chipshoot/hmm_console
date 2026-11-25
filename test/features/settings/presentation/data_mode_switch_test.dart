import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/settings/presentation/widgets/data_mode_dropdown.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._initial);
  final DataMode _initial;
  @override
  DataMode build() => _initial;
  @override
  Future<void> setMode(DataMode mode) async => state = mode;
}

class _FakeIdp implements IdpTokenService {
  _FakeIdp(this.session);
  final bool session;
  @override
  Future<bool> hasHmmSession() async => session;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required DataMode start,
  required bool session,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: DataModeDropdown()),
      ),
      GoRoute(
        path: '/auth',
        builder: (c, _) => Scaffold(
          body: TextButton(
            onPressed: () => c.pop(true),
            child: const Text('stub-login'),
          ),
        ),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _Mode(start)),
      idpTokenServiceProvider.overrideWithValue(_FakeIdp(session)),
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

Future<void> _choose(WidgetTester tester, DataMode m) async {
  await tester.tap(find.byType(DropdownButtonFormField<DataMode>));
  await tester.pumpAndSettle();
  final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  await tester.tap(find.text(_label(l, m)).last);
  await tester.pumpAndSettle();
}

String _label(AppLocalizations l, DataMode m) => switch (m) {
  DataMode.local => l.dataModeLocal,
  DataMode.cloudStorage => l.dataModeCloudStorage,
  DataMode.cloudApi => l.dataModeCloudApi,
};

DataMode? _shown(WidgetTester tester) => tester
    .widget<DropdownButtonFormField<DataMode>>(
      find.byType(DropdownButtonFormField<DataMode>),
    )
    .initialValue;

void main() {
  testWidgets('switch to cloudApi cancelled keeps the mode and the dropdown', (
    tester,
  ) async {
    final c = await _pump(tester, start: DataMode.local, session: false);
    await _choose(tester, DataMode.cloudApi);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.read(dataModeProvider), DataMode.local);
    expect(_shown(tester), DataMode.local);
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<DataMode>),
        matching: find.text(_label(l, DataMode.local)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('switch to cloudApi with a session switches', (tester) async {
    final c = await _pump(tester, start: DataMode.local, session: true);
    await _choose(tester, DataMode.cloudApi);
    expect(c.read(dataModeProvider), DataMode.cloudApi);
  });

  testWidgets('sign in from the sheet then switches', (tester) async {
    final c = await _pump(tester, start: DataMode.local, session: false);
    await _choose(tester, DataMode.cloudApi);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('stub-login'));
    await tester.pumpAndSettle();
    expect(c.read(dataModeProvider), DataMode.cloudApi);
  });

  testWidgets('switch from cloudApi to local needs no sign-in', (tester) async {
    final c = await _pump(tester, start: DataMode.cloudApi, session: false);
    await _choose(tester, DataMode.local);
    expect(find.text('Cancel'), findsNothing);
    expect(c.read(dataModeProvider), DataMode.local);
  });
}
