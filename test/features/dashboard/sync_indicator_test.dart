// The sync dot on the dashboard avatar, and the sheet it opens.
//
// The mutation that matters most here is the "set() changes the dot" test:
// without a live subscription the dot is a photograph of startup — green
// forever, exactly the confident-but-wrong indicator this feature exists
// to end.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// A signed-in user short-circuits `_restoreUserIfNeeded`, so the dashboard
/// never reaches IdpTokenService and no token fake is needed.
class _SignedIn extends CurrentUserNotifier {
  @override
  CurrentUserDataModel? build() => CurrentUserDataModel(
        uid: 'u1',
        email: 'tester@example.com',
        displayName: 'Tester',
        photoUrl: null,
      );
}

/// Marking the intro card seen keeps SettingsController out of this test.
class _IntroSeen extends IntroCardSeenNotifier {
  @override
  bool build() => true;
}

class _EmptyCheatsheets extends CheatsheetsState {
  @override
  Future<List<CheatsheetCard>> build() async => const [];
}

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

/// A controller whose status can be flipped from the test, firing the same
/// notifyListeners() the real one fires on every transition.
class _FakeSync extends SyncController {
  _FakeSync() : super(syncAction: () async => throw UnimplementedError());
  SyncStatus _s = const SyncStatus();
  @override
  SyncStatus get status => _s;
  void set(SyncStatus s) {
    _s = s;
    notifyListeners();
  }
}

SyncResult _result({List<SyncError> errors = const []}) => SyncResult(
      pulledNotes: 0, pulledAttachments: 0, pushedNotes: 0,
      pushedAttachments: 0, completedAt: DateTime.utc(2026, 9, 17),
      errors: errors,
    );

final _synced = SyncStatus(
    lastSyncAt: DateTime.utc(2026, 9, 17), lastResult: _result());
final _failedPlain = SyncStatus(lastResult: _result(errors: const [
  SyncError(recordType: 'note', recordId: 'n1', message: 'Push failed'),
]));
final _failedAuth = SyncStatus(lastResult: _result(errors: const [
  SyncError(recordType: 'auth', recordId: '', message: 'sub claim missing'),
]));

Color _dotColour(WidgetTester tester) {
  final box =
      tester.widget<DecoratedBox>(find.byKey(const Key('syncStatusFill')));
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  Future<_FakeSync> pump(WidgetTester tester,
      {DataMode mode = DataMode.cloudStorage, SyncStatus? status}) async {
    final fake = _FakeSync();
    if (status != null) fake._s = status;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(_SignedIn.new),
        introCardSeenProvider.overrideWith(_IntroSeen.new),
        cheatsheetsStateProvider.overrideWith(_EmptyCheatsheets.new),
        dataModeProvider.overrideWith(() => _StubMode(mode)),
        syncControllerProvider.overrideWithValue(fake),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(),
      ),
    ));
    // Bounded pumps, not pumpAndSettle: the syncing pulse never settles,
    // and this is a screen with real providers behind it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return fake;
  }

  group('the dot', () {
    testWidgets('is present in cloudStorage once synced', (tester) async {
      await pump(tester, status: _synced);
      expect(find.byKey(const Key('syncStatusDot')), findsOneWidget);
    });

    testWidgets('is ABSENT in local mode', (tester) async {
      await pump(tester, mode: DataMode.local, status: _synced);
      expect(find.byKey(const Key('syncStatusDot')), findsNothing);
    });

    testWidgets('changes when the controller notifies', (tester) async {
      // Proves the subscription is live, not a one-time read at build.
      final fake = await pump(tester, status: _synced);
      final before = _dotColour(tester);

      fake.set(_failedPlain);
      await tester.pump();

      expect(_dotColour(tester), isNot(before),
          reason: 'a failure must turn the dot without a rebuild elsewhere');
    });
  });

  group('the sheet', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('syncStatusDot')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('names the account and the synced state', (tester) async {
      await pump(tester, status: _synced);
      await open(tester);

      expect(find.textContaining('tester@example.com'), findsOneWidget);
      expect(find.textContaining('Synced'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Sign in again'), findsNothing);
    });

    testWidgets('an auth failure offers Sign in again and says why',
        (tester) async {
      await pump(tester, status: _failedAuth);
      await open(tester);

      expect(find.text('Sign in again'), findsOneWidget);
      expect(find.textContaining('sign-in has expired'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing,
          reason: 'a retry would fail the same way');
    });

    testWidgets('an ordinary failure offers Sync now, not Sign in again',
        (tester) async {
      await pump(tester, status: _failedPlain);
      await open(tester);

      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Sign in again'), findsNothing);
    });
  });
}
