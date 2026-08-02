import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/cheatsheet_routes.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';

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

void main() {
  testWidgets('the Cheatsheets tile opens the wallet', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        ...cheatsheetRoutes,
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(_SignedIn.new),
          introCardSeenProvider.overrideWith(_IntroSeen.new),
          cheatsheetsStateProvider.overrideWith(_EmptyCheatsheets.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.text('Cheatsheets');
    expect(tile, findsOneWidget, reason: 'the dashboard offers the feature');

    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    // The real assertion: the tile's route string, the switch case and the
    // RouterNames entry all line up. A typo in any one of them drops the tap
    // into the dashboard's `default:` branch, which shows a "coming soon"
    // SnackBar and goes nowhere — so assert both the arrival and the absence
    // of that fallback.
    expect(find.byType(CheatsheetWalletScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing,
        reason: 'not the "coming soon" fallback');
  });
}
