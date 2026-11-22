import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/presentation/screens/activity_edit_screen.dart';
import '../../features/activity/presentation/screens/activity_list_screen.dart';
import 'route_names.dart';

/// The activity route subtree, spread into the app router. `new` is
/// declared before `:id` because GoRouter matches in order.
final activityRoutes = <RouteBase>[
  GoRoute(
    path: '/activity',
    name: RouterNames.activity.name,
    builder: (context, state) => const ActivityListScreen(),
    routes: [
      GoRoute(
        path: 'new',
        name: RouterNames.activityCreate.name,
        builder: (context, state) => const ActivityEditScreen(),
      ),
      GoRoute(
        path: ':id',
        name: RouterNames.activityEdit.name,
        builder: (context, state) => ActivityEditScreen(
          key: ValueKey('activity-${state.pathParameters['id']}'),
          activityId: state.pathParameters['id']!,
        ),
      ),
    ],
  ),
];
