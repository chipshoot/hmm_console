import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/features/settings/providers/home_hidden_tiles_provider.dart';
import 'package:hmm_console/features/dashboard/domain/home_tiles.dart';
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

class _Hidden extends HomeHiddenTilesNotifier {
  @override
  Set<String> build() => {'glucose'};
}

void main() {
  testWidgets('a hidden tile is not shown; the others still are', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const DashboardScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(_SignedIn.new),
          introCardSeenProvider.overrideWith(_IntroSeen.new),
          cheatsheetsStateProvider.overrideWith(_EmptyCheatsheets.new),
          syncControllerProvider.overrideWithValue(_IdleSync()),
          homeHiddenTilesProvider.overrideWith(_Hidden.new),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glucose'), findsNothing);
    for (final name in [
      'Automobile',
      'Expenses',
      'Notes',
      'Cheatsheets',
      'Contacts',
      'Calendar',
      'Activity',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('every tile stored hidden still shows the first tile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'home.hiddenTiles': [for (final t in homeTiles) t.route],
    });
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const DashboardScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(_SignedIn.new),
          introCardSeenProvider.overrideWith(_IntroSeen.new),
          cheatsheetsStateProvider.overrideWith(_EmptyCheatsheets.new),
          syncControllerProvider.overrideWithValue(_IdleSync()),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(homeTiles.first.title), findsOneWidget);
    expect(find.text('Notes'), findsNothing);
  });
}
