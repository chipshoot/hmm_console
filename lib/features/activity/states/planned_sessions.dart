import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/contract/i_calendar_repository.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../calendar/domain/linked_event.dart';
import '../../calendar/domain/occurrence.dart';
import '../../calendar/domain/recurrence_expander.dart';
import '../../calendar/states/calendar_providers.dart';
import '../../calendar/states/calendar_view_state.dart' show deviceResolver;
import '../contract/i_activity_repository.dart';
import '../domain/activity.dart';
import 'activity_list_state.dart' show activityClockProvider;
import 'activity_providers.dart';

/// One calendar occurrence an activity can be logged against.
@immutable
class PlannedSession {
  const PlannedSession({required this.event, required this.occurrence});

  final CalendarEvent event;
  final Occurrence occurrence;
}

/// How far ahead of [now] a planned session may start.
const _ahead = Duration(hours: 12);

/// Occurrences starting from local midnight of yesterday up to `now + 12 h`
/// that a log can fulfil: timed, not done / skipped / cancelled, of an
/// active event that no subsystem date owns (birthdays and expiries are
/// dates, not sessions). Nearest to [now] first.
Future<List<PlannedSession>> plannedSessions(
  ICalendarRepository repo, {
  required DateTime now,
}) async {
  final local = now.toLocal();
  final from = DateTime(local.year, local.month, local.day - 1).toUtc();
  final to = now.toUtc().add(_ahead);
  final resolve = deviceResolver();
  final out = <PlannedSession>[];
  for (final e in await repo.eventsBetween(from, to)) {
    if (e.status == EventStatus.cancelled) continue;
    if (e.owner != null && linkedInfoOf(e) != null) continue;
    for (final o in expandOccurrences(e, from, to, resolve: resolve)) {
      if (o.allDay) continue;
      if (o.start.isBefore(from) || !o.start.isBefore(to)) continue;
      if (o.status == OccurrenceStatus.done ||
          o.status == OccurrenceStatus.skipped ||
          o.status == OccurrenceStatus.cancelled) {
        continue;
      }
      out.add(PlannedSession(event: e, occurrence: o));
    }
  }
  final at = now.toUtc();
  Duration gap(PlannedSession p) => p.occurrence.start.difference(at).abs();
  out.sort((a, b) => gap(a).compareTo(gap(b)));
  return out;
}

/// The planned sessions the activity form offers. Errors (Cloud API mode,
/// an unreadable store) surface as `AsyncError`; the form then hides the row.
final plannedSessionsProvider =
    FutureProvider.autoDispose<List<PlannedSession>>(
      (ref) => plannedSessions(
        ref.watch(calendarRepositoryProvider),
        now: ref.read(activityClockProvider)(),
      ),
    );

/// Activities logged against occurrence [wireKey] of event [eventId], found
/// within two days of [around] (the occurrence's start).
Future<List<Activity>> activitiesForOccurrence(
  IActivityRepository repo, {
  required String eventId,
  required String wireKey,
  required DateTime around,
}) async {
  const window = Duration(days: 2);
  final list = await repo.activitiesBetween(
    around.subtract(window),
    around.add(window),
  );
  return [
    for (final a in list)
      if (a.plannedEvent?.eventId == eventId &&
          a.plannedEvent?.occurrence == wireKey)
        a,
  ];
}

/// Key for [activitiesForOccurrenceProvider].
typedef OccurrenceKey = ({String eventId, String wireKey, DateTime around});

/// Activities linked to one occurrence, for the calendar's event detail.
/// Empty when the activity store is unavailable (Cloud API mode) or fails,
/// so a calendar screen never errors because of Activity. Refreshes when
/// activities change.
final activitiesForOccurrenceProvider = FutureProvider.autoDispose
    .family<List<Activity>, OccurrenceKey>((ref, key) async {
      final IActivityRepository repo;
      try {
        repo = ref.watch(activityRepositoryProvider);
      } catch (e) {
        return const [];
      }
      final sub = repo.changes().listen(
        (_) => ref.invalidateSelf(),
        onError: (Object _) {},
      );
      ref.onDispose(sub.cancel);
      try {
        return await activitiesForOccurrence(
          repo,
          eventId: key.eventId,
          wireKey: key.wireKey,
          around: key.around,
        );
      } catch (e) {
        // Type only: the error text can quote stored data.
        debugPrint('activity: occurrence lookup failed (${e.runtimeType})');
        return const [];
      }
    });
