import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/screens/calendar_home_screen.dart';
import '../../features/calendar/presentation/screens/event_detail_screen.dart';
import '../../features/calendar/presentation/screens/event_edit_screen.dart';
import 'route_names.dart';

/// `yyyy-MM-dd` as a local date; null when missing or malformed.
DateTime? parseDayParam(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

/// The calendar route subtree, spread into the app router.
///
/// `new` is declared before `:id` because GoRouter matches in order (see
/// `contact_routes.dart`). `/calendar/event/:id` and its `edit` take `?at=`
/// (the occurrence's `originalStart.wireKey`); `/calendar/event/new` takes an
/// optional `?day=yyyy-MM-dd`.
final calendarRoutes = <RouteBase>[
  GoRoute(
    path: '/calendar',
    name: RouterNames.calendar.name,
    builder: (context, state) => const CalendarHomeScreen(),
    routes: [
      GoRoute(
        path: 'event/new',
        name: RouterNames.calendarEventCreate.name,
        builder: (context, state) => EventEditScreen(
          day: parseDayParam(state.uri.queryParameters['day']),
        ),
      ),
      GoRoute(
        path: 'event/:id',
        name: RouterNames.calendarEvent.name,
        builder: (context, state) => EventDetailScreen(
          key: ValueKey('calendar-event-${state.pathParameters['id']}'),
          eventId: state.pathParameters['id']!,
          at: state.uri.queryParameters['at'],
        ),
        routes: [
          GoRoute(
            path: 'edit',
            name: RouterNames.calendarEventEdit.name,
            builder: (context, state) => EventEditScreen(
              key: ValueKey('calendar-edit-${state.pathParameters['id']}'),
              eventId: state.pathParameters['id']!,
              at: state.uri.queryParameters['at'],
            ),
          ),
        ],
      ),
    ],
  ),
];
