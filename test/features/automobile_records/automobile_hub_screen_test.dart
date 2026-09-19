// The hub is navigation: every assertion here is "tap X, land on Y" against
// a bare router with placeholder destinations, plus the two visibility rules
// (licence card by mode and by saved state).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/automobile_hub_screen.dart';
import 'package:hmm_console/features/driver_licence/data/i_driver_licence_repository.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/providers/selected_automobile_provider.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubResolver implements IAttachmentResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

class _FakeLicenceRepo implements IDriverLicenceRepository {
  _FakeLicenceRepo([this._stored]);
  DriverLicence? _stored;
  @override
  Future<DriverLicence?> getLicence() async => _stored;
  @override
  Future<int?> noteId() async => _stored == null ? null : 1;
  @override
  Future<DriverLicence> saveLicence(DriverLicence l) async => _stored = l;
}

class _StubAutomobiles extends AutomobilesState {
  _StubAutomobiles(this._items);
  final List<Automobile> _items;
  @override
  Future<List<Automobile>> build() async => _items;
}

class _FailingAutomobiles extends AutomobilesState {
  @override
  Future<List<Automobile>> build() async => throw StateError('boom');
}

Automobile _auto(int id, String model, {bool active = true}) => Automobile(
      id: id,
      year: 2020,
      maker: 'Honda',
      model: model,
      meterReading: 100,
      isActive: active,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  DataMode mode = DataMode.local,
  DriverLicence? licence,
  AutomobilesState Function()? automobiles,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    dataModeProvider.overrideWith(() => _StubMode(mode)),
    driverLicenceRepositoryModeProvider
        .overrideWithValue(_FakeLicenceRepo(licence)),
    automobilesStateProvider.overrideWith(
        automobiles ?? () => _StubAutomobiles([_auto(1, 'Civic')])),
    attachmentResolverProvider.overrideWith((_) async => _StubResolver()),
  ]);
  addTearDown(container.dispose);

  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  final router = GoRouter(initialLocation: '/automobiles', routes: [
    GoRoute(
        path: '/automobiles',
        builder: (_, _) => const AutomobileHubScreen(),
        routes: [
          GoRoute(
              path: 'manage',
              builder: (_, _) => stub('manage list'),
              routes: [
                GoRoute(path: 'new', builder: (_, _) => stub('new vehicle')),
                GoRoute(
                    path: ':id/edit',
                    builder: (_, s) =>
                        stub('edit ${s.pathParameters['id']}')),
              ]),
        ]),
    GoRoute(path: '/gas-logs', builder: (_, _) => stub('gas log list')),
    GoRoute(
        path: '/licence',
        builder: (_, _) => stub('licence editor'),
        routes: [
          GoRoute(path: 'show', builder: (_, _) => stub('licence show')),
        ]),
  ]);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('licence card', () {
    testWidgets('saved licence: shows class/jurisdiction/expiry, opens show',
        (tester) async {
      await _pump(tester,
          licence: DriverLicence(
              licenceClass: 'G',
              jurisdiction: 'Ontario',
              expiryDate: DateTime(2028, 3, 14)));

      expect(find.text("Driver's licence"), findsOneWidget);
      expect(find.textContaining('G · Ontario · expires'), findsOneWidget);

      await tester.tap(find.text("Driver's licence"));
      await tester.pumpAndSettle();
      expect(find.text('licence show'), findsOneWidget);
    });

    testWidgets('no licence: invites adding one, opens the editor',
        (tester) async {
      await _pump(tester);

      expect(find.text("Add your driver's licence"), findsOneWidget);
      await tester.tap(find.text("Add your driver's licence"));
      await tester.pumpAndSettle();
      expect(find.text('licence editor'), findsOneWidget);
    });

    testWidgets('cloudApi: no licence card at all', (tester) async {
      await _pump(tester, mode: DataMode.cloudApi);

      expect(find.text("Driver's licence"), findsNothing);
      expect(find.text("Add your driver's licence"), findsNothing);
      // The vehicles still show — the mode rule is about the licence only.
      expect(find.text('2020 Honda Civic'), findsOneWidget);
    });
  });

  group('vehicles', () {
    testWidgets('lists active vehicles only', (tester) async {
      await _pump(tester,
          automobiles: () => _StubAutomobiles([
                _auto(1, 'Civic'),
                _auto(2, 'Accord', active: false),
              ]));

      expect(find.text('2020 Honda Civic'), findsOneWidget);
      expect(find.text('2020 Honda Accord'), findsNothing);
    });

    testWidgets('row opens the vehicle screen', (tester) async {
      await _pump(tester);
      // The tile's banner pushes the row below the default test viewport.
      await tester.scrollUntilVisible(find.text('2020 Honda Civic'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2020 Honda Civic'));
      await tester.pumpAndSettle();
      expect(find.text('edit 1'), findsOneWidget);
    });

    testWidgets('fuel button selects the vehicle and opens its gas log',
        (tester) async {
      final container = await _pump(tester);
      // The tile's banner pushes the row below the default test viewport.
      await tester.scrollUntilVisible(
          find.byTooltip('Gas log for 2020 Honda Civic'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gas log for 2020 Honda Civic'));
      await tester.pumpAndSettle();

      expect(container.read(selectedAutomobileIdProvider), 1);
      expect(find.text('gas log list'), findsOneWidget);
    });

    testWidgets('Add vehicle opens the create screen', (tester) async {
      await _pump(tester);
      // The tile's banner pushes the button below the default test viewport.
      await tester.scrollUntilVisible(find.text('Add vehicle'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add vehicle'));
      await tester.pumpAndSettle();
      expect(find.text('new vehicle'), findsOneWidget);
    });

    testWidgets('Manage opens the vehicle list', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      expect(find.text('manage list'), findsOneWidget);
    });

    testWidgets('empty state offers Add vehicle', (tester) async {
      await _pump(tester, automobiles: () => _StubAutomobiles(const []));

      expect(find.text('No vehicles yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Add vehicle'));
      await tester.pumpAndSettle();
      expect(find.text('new vehicle'), findsOneWidget);
    });

    testWidgets('load failure shows Retry', (tester) async {
      await _pump(tester, automobiles: _FailingAutomobiles.new);

      expect(find.text('Failed to load vehicles'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
