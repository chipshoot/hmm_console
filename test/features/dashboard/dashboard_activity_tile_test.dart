import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/states/activity_list_state.dart';
import 'package:hmm_console/features/activity/states/activity_providers.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../activity/support/fake_activity_repository.dart';

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

Activity _act(String id, String kind, int min, String iso) => Activity(
  id: id,
  kind: kind,
  start: OffsetDateTime.tryParse(iso)!,
  durationMinutes: min,
  updatedAt: DateTime.utc(2026, 11, 21),
);

Future<void> _pump(
  WidgetTester tester,
  List<Activity> seed, {
  DataMode mode = DataMode.local,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(
        path: '/activity',
        name: 'activity',
        builder: (_, _) => const Text('ACTIVITY SCREEN'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(_SignedIn.new),
        introCardSeenProvider.overrideWith(_IntroSeen.new),
        syncControllerProvider.overrideWithValue(_IdleSync()),
        dataModeProvider.overrideWith(() => _Mode(mode)),
        localActivityRepositoryProvider.overrideWithValue(
          FakeActivityRepository(seed),
        ),
        activityClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 21, 12),
        ),
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
  testWidgets('the Activity tile shows today\'s health minutes and opens '
      'the activity screen', (tester) async {
    await _pump(tester, [
      _act('a', 'health.walk', 30, '2026-11-21T08:00:00Z'),
      _act('b', 'health.gym', 45, '2026-11-21T09:00:00Z'),
      _act('c', 'reading.reading', 40, '2026-11-21T10:00:00Z'),
      _act('d', 'health.walk', 20, '2026-11-20T08:00:00Z'),
    ]);
    expect(find.text('Active today: 1 h 15 min'), findsOneWidget);

    final tile = find.text('Activity');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('ACTIVITY SCREEN'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reads none today at zero minutes', (tester) async {
    await _pump(tester, [_act('d', 'health.walk', 20, '2026-11-20T08:00:00Z')]);
    expect(find.text('No activity yet today'), findsOneWidget);
  });

  testWidgets('Cloud API keeps the tile and says it is unavailable', (
    tester,
  ) async {
    await _pump(tester, const [], mode: DataMode.cloudApi);
    expect(find.text('Activity'), findsOneWidget);
    final tile = find
        .ancestor(of: find.text('Activity'), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: tile, matching: find.text('Not available')),
      findsOneWidget,
    );
    expect(
      find.textContaining("isn't available in Cloud API mode"),
      findsNothing,
    );
  });
}
