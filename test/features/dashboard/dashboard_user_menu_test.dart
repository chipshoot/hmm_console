import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _SignedIn extends CurrentUserNotifier {
  @override
  CurrentUserDataModel? build() => const CurrentUserDataModel(
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

class _FakeSync extends SyncController {
  _FakeSync(this._s)
    : super(syncAction: () async => throw UnimplementedError());
  final SyncStatus _s;
  @override
  SyncStatus get status => _s;
}

class _FakeOneDrive implements OneDriveAuth {
  int signIns = 0;
  Object? throwOnSignIn;
  @override
  Future<void> signIn() async {
    signIns++;
    if (throwOnSignIn != null) throw throwOnSignIn!;
  }

  @override
  Future<bool> hasToken() async => false;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _failedAuth = SyncStatus(
  lastResult: SyncResult(
    pulledNotes: 0,
    pulledAttachments: 0,
    pushedNotes: 0,
    pushedAttachments: 0,
    completedAt: DateTime.utc(2026, 9, 17),
    errors: const [
      SyncError(recordType: 'auth', recordId: '', message: 'sub claim missing'),
    ],
  ),
);

Future<void> _open(
  WidgetTester tester, {
  required DataMode mode,
  SyncStatus status = const SyncStatus(),
  _FakeOneDrive? oneDrive,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(_SignedIn.new),
        introCardSeenProvider.overrideWith(_IntroSeen.new),
        cheatsheetsStateProvider.overrideWith(_EmptyCheatsheets.new),
        dataModeProvider.overrideWith(() => _StubMode(mode)),
        syncControllerProvider.overrideWithValue(_FakeSync(status)),
        if (oneDrive != null) oneDriveAuthProvider.overrideWithValue(oneDrive),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byKey(const Key('syncStatusDot')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('user menu has no Sign out', (tester) async {
    await _open(tester, mode: DataMode.cloudStorage);
    expect(find.textContaining('tester@example.com'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('cloudStorage auth failure offers OneDrive sign-in', (
    tester,
  ) async {
    final od = _FakeOneDrive();
    await _open(
      tester,
      mode: DataMode.cloudStorage,
      status: _failedAuth,
      oneDrive: od,
    );
    await tester.tap(find.text('Sign in again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(od.signIns, 1);
  });

  testWidgets('OneDrive sign-in failure shows a snackbar and does not throw', (
    tester,
  ) async {
    final od = _FakeOneDrive()
      ..throwOnSignIn = const OneDriveAuthException('Client ID missing');
    await _open(
      tester,
      mode: DataMode.cloudStorage,
      status: _failedAuth,
      oneDrive: od,
    );
    await tester.tap(find.text('Sign in again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Client ID missing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
