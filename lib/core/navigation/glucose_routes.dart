import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/glucose/presentation/screens/glucose_list_screen.dart';
import 'route_names.dart';

/// The glucose route subtree, spread into the app router. GoRouter matches
/// in order, so literal child paths go before `:id`: `new` now, and `range`
/// (the target range screen) must also be declared before `:id` when it is
/// added.
final glucoseRoutes = <RouteBase>[
  GoRoute(
    path: '/glucose',
    name: RouterNames.glucose.name,
    builder: (context, state) => const GlucoseListScreen(),
    routes: [
      GoRoute(
        path: 'new',
        name: RouterNames.glucoseCreate.name,
        builder: (context, state) => const _FormPending(),
      ),
      GoRoute(
        path: ':id',
        name: RouterNames.glucoseEdit.name,
        builder: (context, state) => const _FormPending(),
      ),
    ],
  ),
];

/// Stands in for the entry form until it is built.
class _FormPending extends StatelessWidget {
  const _FormPending();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}
