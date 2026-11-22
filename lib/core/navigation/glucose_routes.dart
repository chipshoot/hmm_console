import 'package:go_router/go_router.dart';

import '../../features/glucose/presentation/screens/glucose_edit_screen.dart';
import '../../features/glucose/presentation/screens/glucose_list_screen.dart';
import '../../features/glucose/presentation/screens/glucose_range_screen.dart';
import 'route_names.dart';

/// The glucose route subtree, spread into the app router. GoRouter matches
/// in order, so the literal child paths `new` and `range` go before `:id`.
final glucoseRoutes = <RouteBase>[
  GoRoute(
    path: '/glucose',
    name: RouterNames.glucose.name,
    builder: (context, state) => const GlucoseListScreen(),
    routes: [
      GoRoute(
        path: 'new',
        name: RouterNames.glucoseCreate.name,
        builder: (context, state) => const GlucoseEditScreen(),
      ),
      GoRoute(
        path: 'range',
        name: RouterNames.glucoseRange.name,
        builder: (context, state) => const GlucoseRangeScreen(),
      ),
      GoRoute(
        path: ':id',
        name: RouterNames.glucoseEdit.name,
        builder: (context, state) =>
            GlucoseEditScreen(readingId: state.pathParameters['id']),
      ),
    ],
  ),
];
