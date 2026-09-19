// The Gas Log and Licence tiles fold into one Automobile tile that opens the
// hub. The tile must show in every mode: the cloudApi rule that used to hide
// the Licence tile now lives inside the hub, on its licence card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

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

Future<void> _pump(WidgetTester tester, DataMode mode) async {
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
    GoRoute(
        path: '/automobiles',
        builder: (_, _) => const Scaffold(body: Text('automobile hub'))),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(_SignedIn.new),
      introCardSeenProvider.overrideWith(_IntroSeen.new),
      cheatsheetsStateProvider.overrideWith(_EmptyCheatsheets.new),
      syncControllerProvider.overrideWithValue(_IdleSync()),
      dataModeProvider.overrideWith(() => _StubMode(mode)),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Automobile tile opens the hub', (tester) async {
    await _pump(tester, DataMode.local);

    expect(find.text('Gas Log'), findsNothing, reason: 'folded into Automobile');
    expect(find.text('Licence'), findsNothing, reason: 'folded into Automobile');

    final tile = find.text('Automobile');
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('automobile hub'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing,
        reason: 'not the "coming soon" fallback');
  });

  testWidgets('the tile shows in cloudApi too', (tester) async {
    await _pump(tester, DataMode.cloudApi);
    expect(find.text('Automobile'), findsOneWidget);
  });
}
