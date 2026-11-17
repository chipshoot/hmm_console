import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/screens/calendar_home_screen.dart';
import '../../l10n/gen/app_localizations.dart';
import 'route_names.dart';

/// The calendar route subtree, spread into the app router.
///
/// `new` is declared before `:id` because GoRouter matches in order (see
/// `contact_routes.dart`). `/calendar/event/:id` takes `?at=` (the
/// occurrence's `originalStart.wireKey`); `/calendar/event/new` takes an
/// optional `?day=yyyy-MM-dd`. The event screens are placeholders until
/// Task 8 swaps the builders.
final calendarRoutes = <RouteBase>[
  GoRoute(
    path: '/calendar',
    name: RouterNames.calendar.name,
    builder: (context, state) => const CalendarHomeScreen(),
    routes: [
      GoRoute(
        path: 'event/new',
        name: RouterNames.calendarEventCreate.name,
        builder: (context, state) => const _EventPlaceholder(),
      ),
      GoRoute(
        path: 'event/:id',
        name: RouterNames.calendarEvent.name,
        builder: (context, state) => _EventPlaceholder(
          key: ValueKey('calendar-event-${state.pathParameters['id']}'),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            name: RouterNames.calendarEventEdit.name,
            builder: (context, state) => _EventPlaceholder(
              key: ValueKey('calendar-edit-${state.pathParameters['id']}'),
            ),
          ),
        ],
      ),
    ],
  ),
];

class _EventPlaceholder extends StatelessWidget {
  const _EventPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).calendarEventPlaceholderTitle),
    ),
    body: const SizedBox.shrink(),
  );
}
