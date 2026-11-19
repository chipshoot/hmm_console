import 'dart:convert';

import '../domain/calendar_event.dart';
import '../domain/event_time.dart';
import '../domain/occurrence.dart';
import '../domain/recurrence_expander.dart';

/// One device notification to schedule.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.fireAtUtc,
    required this.title,
    required this.payload,
    this.body,
    this.timeSensitive = false,
    this.badgeNumber,
  });

  final int id;
  final DateTime fireAtUtc;
  final String title;
  final String? body;

  /// `calendar|<eventId>|<originalStart.wireKey>`.
  final String payload;

  /// Copied from [CalendarEvent.timeSensitive].
  final bool timeSensitive;

  /// App icon badge shown when this reminder fires: unseen count at plan
  /// time plus this reminder's 1-based position in fire order.
  final int? badgeNumber;

  @override
  String toString() => 'PlannedReminder($id, $fireAtUtc, $payload)';
}

/// Stable 31-bit id: FNV-1a 32-bit over the UTF-8 bytes of
/// `"$eventId|${originalStart.wireKey}|$minutesBefore"`.
int reminderNotificationId(
  String eventId,
  EventTime originalStart,
  int minutesBefore,
) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(
    '$eventId|${originalStart.wireKey}|$minutesBefore',
  )) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// Local calendar date of an all-day occurrence ([allDayDateOf]), else
/// (unexpected) the occurrence start in the device zone.
AllDay _allDayDate(CalendarEvent e, Occurrence o) {
  final d = allDayDateOf(e, o);
  if (d != null) return d;
  final l = o.start.toLocal();
  return AllDay(l.year, l.month, l.day);
}

/// A reminder whose fire time has passed (the inbox lists these).
class FiredReminder {
  const FiredReminder({
    required this.eventId,
    required this.originalStart,
    required this.fireAtUtc,
    required this.occurrenceStartUtc,
    required this.title,
    required this.payload,
  });

  final String eventId;
  final EventTime originalStart;
  final DateTime fireAtUtc;
  final DateTime occurrenceStartUtc;
  final String title;

  /// Same format as [PlannedReminder.payload]; opens via
  /// `calendarRouteForPayload`.
  final String payload;

  @override
  String toString() => 'FiredReminder($eventId, $fireAtUtc)';
}

class _Candidate {
  const _Candidate({
    required this.id,
    required this.eventId,
    required this.originalStart,
    required this.fireAtUtc,
    required this.occurrenceStartUtc,
    required this.title,
    required this.body,
    required this.payload,
    required this.timeSensitive,
  });

  final int id;
  final String eventId;
  final EventTime originalStart;
  final DateTime fireAtUtc;
  final DateTime occurrenceStartUtc;
  final String title;
  final String? body;
  final String payload;
  final bool timeSensitive;
}

/// Every device reminder with `fromUtc < fire <= toUtc`, unsorted. The single
/// home of the skip rules and the all-day 09:00 rule.
List<_Candidate> _candidates({
  required List<CalendarEvent> events,
  required DateTime fromUtc,
  required DateTime toUtc,
  required LocalResolver resolve,
  required String Function(CalendarEvent event, Occurrence o) formatTitle,
}) {
  final from = fromUtc.toUtc();
  final to = toUtc.toUtc();
  final out = <_Candidate>[];

  for (final e in events) {
    if (e.draft || e.status == EventStatus.cancelled) continue;
    final device = e.reminders
        .where((r) => r.channel == ReminderChannel.device)
        .toList();
    if (device.isEmpty) continue;
    final maxLead = device
        .map((r) => r.minutesBefore)
        .reduce((a, b) => a > b ? a : b);
    final lead = maxLead < 0 ? 0 : maxLead;
    final occs = expandOccurrences(
      e,
      from,
      // +1 min: the range end is exclusive but fire == to is kept.
      to.add(Duration(minutes: lead + 1)),
      resolve: resolve,
    );
    final body = e.extraFields['reminderBody'];
    for (final o in occs) {
      final s = o.status;
      if (s == OccurrenceStatus.done ||
          s == OccurrenceStatus.skipped ||
          s == OccurrenceStatus.cancelled) {
        continue;
      }
      final DateTime anchor;
      if (o.allDay) {
        final d = _allDayDate(e, o);
        anchor = resolve(d.year, d.month, d.day, 9, 0);
      } else {
        anchor = o.start;
      }
      for (final r in device) {
        final fireAt = anchor.toUtc().subtract(
          Duration(minutes: r.minutesBefore),
        );
        if (!fireAt.isAfter(from) || fireAt.isAfter(to)) continue;
        out.add(
          _Candidate(
            id: reminderNotificationId(e.id, o.originalStart, r.minutesBefore),
            eventId: e.id,
            originalStart: o.originalStart,
            fireAtUtc: fireAt,
            occurrenceStartUtc: o.start.toUtc(),
            title: formatTitle(e, o),
            body: body is String ? body : null,
            payload: 'calendar|${e.id}|${o.originalStart.wireKey}',
            timeSensitive: e.timeSensitive,
          ),
        );
      }
    }
  }
  return out;
}

/// Device reminders that should be pending now: fire time in
/// `(nowUtc, nowUtc + windowDays]`, nearest first, at most [cap]. The i-th
/// (1-based) carries `badgeNumber: unseenNow + i`.
List<PlannedReminder> planReminders({
  required List<CalendarEvent> events,
  required DateTime nowUtc,
  required LocalResolver resolve,
  required String Function(CalendarEvent event, Occurrence o) formatTitle,
  int windowDays = 14,
  int cap = 60,
  int unseenNow = 0,
}) {
  final now = nowUtc.toUtc();
  final cands = _candidates(
    events: events,
    fromUtc: now,
    toUtc: now.add(Duration(days: windowDays)),
    resolve: resolve,
    formatTitle: formatTitle,
  );
  cands.sort((a, b) {
    final c = a.fireAtUtc.compareTo(b.fireAtUtc);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  final kept = cands.length > cap ? cands.sublist(0, cap) : cands;
  return [
    for (var i = 0; i < kept.length; i++)
      PlannedReminder(
        id: kept[i].id,
        fireAtUtc: kept[i].fireAtUtc,
        title: kept[i].title,
        body: kept[i].body,
        payload: kept[i].payload,
        timeSensitive: kept[i].timeSensitive,
        badgeNumber: unseenNow + i + 1,
      ),
  ];
}

/// Reminders that already fired in `(fromUtc, toUtc]`, newest first, under
/// the same skip rules as [planReminders].
List<FiredReminder> firedReminders({
  required List<CalendarEvent> events,
  required DateTime fromUtc,
  required DateTime toUtc,
  required LocalResolver resolve,
  required String Function(CalendarEvent event, Occurrence o) formatTitle,
}) {
  final cands = _candidates(
    events: events,
    fromUtc: fromUtc,
    toUtc: toUtc,
    resolve: resolve,
    formatTitle: formatTitle,
  );
  cands.sort((a, b) {
    final c = b.fireAtUtc.compareTo(a.fireAtUtc);
    return c != 0 ? c : b.id.compareTo(a.id);
  });
  return [
    for (final c in cands)
      FiredReminder(
        eventId: c.eventId,
        originalStart: c.originalStart,
        fireAtUtc: c.fireAtUtc,
        occurrenceStartUtc: c.occurrenceStartUtc,
        title: c.title,
        payload: c.payload,
      ),
  ];
}
