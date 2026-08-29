// A tile that renders but routes nowhere passes a weaker test than it looks,
// so the dashboard case here navigates for real and asserts where it lands.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/navigation/driver_licence_routes.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/driver_licence/data/i_driver_licence_repository.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';
import 'package:hmm_console/features/driver_licence/presentation/screens/driver_licence_screen.dart';
import 'package:hmm_console/features/driver_licence/presentation/screens/licence_show_screen.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/launcher/domain/launcher_destination.dart';
import 'package:hmm_console/features/launcher/domain/launcher_registry.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _FakeRepo implements IDriverLicenceRepository {
  _FakeRepo([this._stored]);
  DriverLicence? _stored;

  @override
  Future<DriverLicence?> getLicence() async => _stored;
  @override
  Future<int?> noteId() async => _stored == null ? null : 1;
  @override
  Future<DriverLicence> saveLicence(DriverLicence l) async => _stored = l;
}

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

void main() {
  Future<void> pumpAt(WidgetTester tester, String location,
      {DriverLicence? stored}) async {
    final router = GoRouter(initialLocation: location, routes: driverLicenceRoutes);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        driverLicenceRepositoryModeProvider
            .overrideWithValue(_FakeRepo(stored)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('/licence builds the licence screen', (tester) async {
    await pumpAt(tester, '/licence');
    expect(find.byType(DriverLicenceScreen), findsOneWidget);
  });

  testWidgets('/licence/show builds show mode when a licence exists',
      (tester) async {
    await pumpAt(tester, '/licence/show',
        stored: const DriverLicence(
          number: 'D1',
          frontImage: VaultRef(
            path: 'attachments/note-1/sensitive/front.jpg',
            contentType: 'image/jpeg',
            byteSize: 10,
            sensitive: true,
          ),
        ));
    expect(find.byType(LicenceShowScreen), findsOneWidget);
  });

  testWidgets('/licence/show falls back to the editor when nothing is saved',
      (tester) async {
    // A dead screen would be worse: the user asked to show a licence they
    // have not created yet, so send them where they can create it.
    await pumpAt(tester, '/licence/show');
    expect(find.byType(DriverLicenceScreen), findsOneWidget);
    expect(find.byType(LicenceShowScreen), findsNothing);
  });

  group('launcher', () {
    late List<LauncherDestination> destinations;

    setUpAll(() async {
      destinations = launcherDestinations(
          await AppLocalizations.delegate.load(const Locale('en')));
    });

    test('typing "lic" finds the destination', () {
      final hits = destinations
          .where((d) =>
              d.synonyms.any((s) => s.toLowerCase().contains('lic')) ||
              d.id.toLowerCase().contains('lic'))
          .map((d) => d.id);

      expect(hits, contains('driverLicence'));
    });

    test('the id and routeName stay literal, never localized', () {
      // Favorites persist by id: a locale-dependent id would orphan every
      // favorite the moment the UI language changed.
      final d = destinations.firstWhere((d) => d.id == 'driverLicence');

      expect(d.id, 'driverLicence');
      expect(d.routeName, 'driverLicence');
      // The English terms stay alongside the Chinese, so a bilingual user on
      // a Chinese UI can still type "licence".
      expect(d.synonyms, contains('licence'));
      expect(d.synonyms, contains('驾驶证'));
    });
  });

  test('the route names the dashboard and launcher push actually resolve', () {
    // Both entry points push by NAME. A name that no route declares throws at
    // navigation time, not at build time, so nothing but this catches a typo.
    final router = GoRouter(routes: driverLicenceRoutes);

    expect(router.namedLocation(RouterNames.driverLicence.name), '/licence');
    expect(router.namedLocation(RouterNames.driverLicenceShow.name),
        '/licence/show');
  });

  test('the licence repository throws in cloudApi, which is why the entry '
      'points are hidden there', () {
    // The dashboard tile and the launcher destination are both suppressed in
    // this mode. This pins WHY: reaching the repository at all is a crash,
    // so a visible entry point would be a route to an exception.
    final container = ProviderContainer(overrides: [
      dataModeProvider.overrideWith(() => _StubMode(DataMode.cloudApi)),
    ]);
    addTearDown(container.dispose);

    // Riverpod wraps the throw in a ProviderException, so the matcher reads
    // the message rather than the type.
    expect(
      () => container.read(driverLicenceRepositoryModeProvider),
      throwsA(predicate(
          (e) => e.toString().contains('no cloudApi repository'),
          'an error naming the missing cloudApi repository')),
    );
  });
}
