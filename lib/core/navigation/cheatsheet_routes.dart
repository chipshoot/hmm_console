import 'package:go_router/go_router.dart';

import '../../features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart';
import '../../features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart';
import '../../features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart';
import 'route_names.dart';

/// The cheatsheet route subtree, spread into the app router.
///
/// Kept as a standalone list so it can be mounted in a bare [GoRouter] under
/// test — the app's own router sits behind an auth redirect, which would turn
/// "does /cheatsheets/:id build the detail screen?" into an auth test.
///
/// `new` is declared before `:id` because GoRouter matches in order; reversed,
/// `/cheatsheets/new` would resolve as a card whose id is literally "new".
final cheatsheetRoutes = <RouteBase>[
  GoRoute(
    path: '/cheatsheets',
    name: RouterNames.cheatsheets.name,
    builder: (context, state) => const CheatsheetWalletScreen(),
    routes: [
      GoRoute(
        path: 'new',
        name: RouterNames.cheatsheetCreate.name,
        builder: (context, state) => const CheatsheetDesignerScreen(),
      ),
      GoRoute(
        path: ':id',
        name: RouterNames.cheatsheetDetail.name,
        builder: (context, state) => CheatsheetDetailScreen(
          cardId: state.pathParameters['id']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            name: RouterNames.cheatsheetEdit.name,
            builder: (context, state) => CheatsheetDesignerScreen(
              cardId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  ),
];
