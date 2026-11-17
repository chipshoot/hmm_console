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
  });

  final int id;
  final DateTime fireAtUtc;
  final String title;
  final String? body;

  /// `calendar|<eventId>|<originalStart.wireKey>`.
  final String payload;

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

/// Local calendar date of an all-day occurrence: the moved-to date when the
/// occurrence was moved to an all-day slot, else its original all-day date,
/// else (unexpected) the occurrence start in the device zone.
AllDay _allDayDate(CalendarEvent e, Occurrence o) {
  for (final ov in e.occurrences) {
    if (ov.originalStart.wireKey == o.originalStart.wireKey &&
        ov.movedTo != null) {
      final m = ov.movedTo;
      if (m is AllDay) return m;
    }
  }
  final orig = o.originalStart;
  if (orig is AllDay) return orig;
  final l = o.start.toLocal();
  return AllDay(l.year, l.month, l.day);
}

/// Device reminders that should be pending now: fire time in
/// `(nowUtc, nowUtc + windowDays]`, nearest first, at most [cap].
List<PlannedReminder> planReminders({
  required List<CalendarEvent> events,
  required DateTime nowUtc,
  required LocalResolver resolve,
  required String Function(CalendarEvent event, Occurrence o) formatTitle,
  int windowDays = 14,
  int cap = 60,
}) {
  final now = nowUtc.toUtc();
  final windowEnd = now.add(Duration(days: windowDays));
  final out = <PlannedReminder>[];

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
      now,
      // +1 min: the range end is exclusive but fire == windowEnd is kept.
      windowEnd.add(Duration(minutes: lead + 1)),
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
        if (!fireAt.isAfter(now) || fireAt.isAfter(windowEnd)) continue;
        out.add(
          PlannedReminder(
            id: reminderNotificationId(e.id, o.originalStart, r.minutesBefore),
            fireAtUtc: fireAt,
            title: formatTitle(e, o),
            body: body is String ? body : null,
            payload: 'calendar|${e.id}|${o.originalStart.wireKey}',
          ),
        );
      }
    }
  }

  out.sort((a, b) {
    final c = a.fireAtUtc.compareTo(b.fireAtUtc);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out.length > cap ? out.sublist(0, cap) : out;
}
