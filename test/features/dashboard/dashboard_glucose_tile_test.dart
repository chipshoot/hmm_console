import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/navigation/glucose_routes.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/features/glucose/domain/glucose_range.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/presentation/screens/glucose_list_screen.dart';
import 'package:hmm_console/features/glucose/states/glucose_list_state.dart';
import 'package:hmm_console/features/glucose/states/glucose_providers.dart';
import 'package:hmm_console/features/glucose/states/glucose_settings_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../glucose/support/fake_glucose_repository.dart';

class _SignedIn extends CurrentUserNotifier {
  @override
  CurrentUserDataModel? build() => CurrentUserDataModel(
    uid: 'u1',
    email: 'tester@example.com',
    displayName: 'Tester',
    photoUrl: null,
  );
}

class _IntroSeen extends IntroCardSeenNotifier {
  @override
  bool build() => true;
}

class _IdleSync extends SyncController {
  _IdleSync() : super(syncAction: () async => throw UnimplementedError());
}

class _Mode extends DataModeNotifier {
  _Mode(this.mode);
  final DataMode mode;
  @override
  DataMode build() => mode;
}

class _Range extends GlucoseRangeNotifier {
  @override
  GlucoseRange? build() =>
      const GlucoseRange(low: 4, high: 10, unit: GlucoseUnit.mmoll);
}

class _MmolUnit extends GlucoseDisplayUnitNotifier {
  @override
  GlucoseUnit build() => GlucoseUnit.mmoll;
}

final _now = DateTime(2026, 11, 22, 10);

GlucoseReading _reading() => GlucoseReading(
  id: 'g1',
  takenAt: OffsetDateTime.fromLocal(DateTime(2026, 11, 22, 8)),
  glucose: const GlucoseValue(6.2, GlucoseUnit.mmoll),
);

Future<void> _pump(
  WidgetTester tester,
  List<GlucoseReading> seed, {
  DataMode mode = DataMode.local,
  bool withRange = false,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      ...glucoseRoutes,
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(_SignedIn.new),
        introCardSeenProvider.overrideWith(_IntroSeen.new),
        syncControllerProvider.overrideWithValue(_IdleSync()),
        dataModeProvider.overrideWith(() => _Mode(mode)),
        localGlucoseRepositoryProvider.overrideWithValue(
          FakeGlucoseRepository(seed),
        ),
        glucoseClockProvider.overrideWithValue(() => _now),
        glucoseDisplayUnitProvider.overrideWith(_MmolUnit.new),
        if (withRange) glucoseRangeProvider.overrideWith(_Range.new),
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

void main() {
  const dot = ValueKey('glucose-tile-band-dot');

  testWidgets('shows the last reading and opens the glucose log', (
    tester,
  ) async {
    await _pump(tester, [_reading()]);
    expect(find.text('Last: 6.2 mmol/L · 2 hours ago'), findsOneWidget);
    expect(find.byKey(dot), findsNothing, reason: 'no range, no dot');

    final tile = find.text('Glucose');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(GlucoseListScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows a band dot when a range is set', (tester) async {
    await _pump(tester, [_reading()], withRange: true);
    expect(find.byKey(dot), findsOneWidget);
  });

  testWidgets('says so when there are no readings', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No readings yet'), findsOneWidget);
  });

  testWidgets('Cloud API keeps the tile and says unavailable', (tester) async {
    await _pump(tester, const [], mode: DataMode.cloudApi);
    expect(find.text('Glucose'), findsOneWidget);
    // The Activity tile says the same, so look inside the Glucose tile.
    final tile = find
        .ancestor(of: find.text('Glucose'), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: tile, matching: find.text('Not available')),
      findsOneWidget,
    );
  });
}
