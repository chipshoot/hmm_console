import 'calendar_event.dart';
import 'event_time.dart';
import 'occurrence.dart';
import 'recurrence_rule.dart';

/// Resolves a wall-clock time to a UTC instant in the device zone.
typedef LocalResolver = DateTime Function(int y, int m, int d, int hh, int mm);

DateTime defaultLocalResolver(int y, int m, int d, int hh, int mm) =>
    DateTime(y, m, d, hh, mm).toUtc();

/// Upper bound on candidates (and on periods scanned) per call.
const int kMaxExpansionCandidates = 5000;

/// Occurrences of [e] whose start is in [fromUtc, toUtc), plus any that
/// started earlier and are still running at [fromUtc], sorted by start.
///
/// Candidate dates are walked in wall-clock terms and each is resolved
/// through [resolve], so a floating 07:00 stays 07:00 across DST. A wall time
/// that does not exist or happens twice resolves to exactly one instant
/// (whatever [resolve] returns), never dropped or doubled.
///
/// A series that started more than [kMaxExpansionCandidates] candidates
/// before the range is cut short by the cap. A fixed-time series uses the
/// wall-clock of its own offset as the pattern (no resolver involved).
List<Occurrence> expandOccurrences(
  CalendarEvent e,
  DateTime fromUtc,
  DateTime toUtc, {
  LocalResolver resolve = defaultLocalResolver,
}) {
  if (e.status == EventStatus.cancelled) return const [];
  final from = fromUtc.toUtc();
  final to = toUtc.toUtc();

  final overrides = <String, OccurrenceOverride>{};
  for (final o in e.occurrences) {
    overrides.putIfAbsent(o.originalStart.wireKey, () => o);
  }

  final rule = _parseRule(e.rrule);
  final ctx = _Ctx(e, resolve);

  // A moved occurrence can land inside the range although its original slot
  // is past `to`; widen the generation bound so that slot is still visited.
  var bound = to;
  for (final o in overrides.values) {
    final m = o.movedTo;
    if (o.status == OccurrenceStatus.moved && m != null) {
      final moved = ctx.startOf(m);
      if (moved.isBefore(to)) {
        final orig = ctx.startOf(o.originalStart);
        if (!orig.isBefore(bound)) bound = orig.add(const Duration(minutes: 1));
      }
    }
  }

  final out = <Occurrence>[];
  var seen = 0;
  for (final slot in ctx.slots(rule)) {
    if (rule?.count != null && seen >= rule!.count!) break;
    if (seen >= kMaxExpansionCandidates) break;
    final start = ctx.startOf(slot);
    final u = rule?.until;
    if (u != null) {
      final afterUntil = rule!.untilIsDate
          ? ctx.wallDate(slot).isAfter(DateTime.utc(u.year, u.month, u.day))
          : start.isAfter(u);
      if (afterUntil) break;
    }
    seen++;
    if (!start.isBefore(bound)) break;

    final ov = overrides[slot.wireKey];
    if (ov?.status == OccurrenceStatus.cancelled) continue;
    final moved = ov?.status == OccurrenceStatus.moved ? ov!.movedTo : null;
    final t = moved ?? slot;
    final built = ctx.build(t);
    final title = ov?.extraFields['title'];
    final occ = Occurrence(
      eventId: e.id,
      originalStart: slot,
      start: built.start,
      end: built.end,
      allDay: built.allDay,
      status: ov?.status,
      titleOverride: title is String ? title : null,
    );
    final running =
        occ.end != null && occ.start.isBefore(from) && occ.end!.isAfter(from);
    final inRange = !occ.start.isBefore(from) && occ.start.isBefore(to);
    if (inRange || running) out.add(occ);
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

RecurrenceRule? _parseRule(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  try {
    return RecurrenceRule.parse(text);
  } on FormatException {
    return null; // unreadable rule: treat as a one-off
  }
}

class _Built {
  _Built(this.start, this.end, this.allDay);
  final DateTime start;
  final DateTime? end;
  final bool allDay;
}

class _Ctx {
  _Ctx(this.e, this.resolve);
  final CalendarEvent e;
  final LocalResolver resolve;

  DateTime _res(DateTime w) =>
      resolve(w.year, w.month, w.day, w.hour, w.minute);

  /// UTC start instant of any [EventTime].
  DateTime startOf(EventTime t) => switch (t) {
    FixedTime() => t.instant.toUtc(),
    FloatingTime() => resolve(t.year, t.month, t.day, t.hour, t.minute),
    AllDay() => resolve(t.year, t.month, t.day, 0, 0),
  };

  /// The calendar date (UTC midnight) of a slot in its own wall clock.
  DateTime wallDate(EventTime t) => switch (t) {
    FixedTime() => () {
      final w = t.instant.toUtc().add(t.offset);
      return DateTime.utc(w.year, w.month, w.day);
    }(),
    FloatingTime() => DateTime.utc(t.year, t.month, t.day),
    AllDay() => DateTime.utc(t.year, t.month, t.day),
  };

  /// Wall-clock origin of the series pattern.
  DateTime get _baseWall => switch (e.start) {
    FixedTime(:final instant, :final offset) => instant.toUtc().add(offset),
    FloatingTime(
      :final year,
      :final month,
      :final day,
      :final hour,
      :final minute,
    ) =>
      DateTime.utc(year, month, day, hour, minute),
    AllDay(:final year, :final month, :final day) => DateTime.utc(
      year,
      month,
      day,
    ),
  };

  EventTime _slotAt(DateTime date) {
    final w = _baseWall;
    return switch (e.start) {
      FixedTime(:final offset) => FixedTime(
        DateTime.utc(
          date.year,
          date.month,
          date.day,
          w.hour,
          w.minute,
        ).subtract(offset),
        offset,
      ),
      FloatingTime() => FloatingTime(
        date.year,
        date.month,
        date.day,
        w.hour,
        w.minute,
      ),
      AllDay() => AllDay(date.year, date.month, date.day),
    };
  }

  /// Series slots in order, lazily. One-off events yield just their start.
  Iterable<EventTime> slots(RecurrenceRule? rule) sync* {
    final base = DateTime.utc(_baseWall.year, _baseWall.month, _baseWall.day);
    if (rule == null ||
        rule.isLunar ||
        (rule.count != null && rule.count! <= 0)) {
      if (rule?.count == 0) return;
      yield e.start;
      return;
    }
    for (final d in _dates(rule, base)) {
      yield _slotAt(d);
    }
  }

  Iterable<DateTime> _dates(RecurrenceRule r, DateTime base) sync* {
    final step = r.interval < 1 ? 1 : r.interval;
    for (var k = 0; k < kMaxExpansionCandidates; k++) {
      switch (r.freq) {
        case Frequency.daily:
          yield DateTime.utc(base.year, base.month, base.day + k * step);
        case Frequency.weekly:
          final monday = DateTime.utc(
            base.year,
            base.month,
            base.day - (base.weekday - 1) + 7 * step * k,
          );
          final days =
              (r.byDay.isEmpty ? [Weekday.values[base.weekday - 1]] : r.byDay)
                  .map((w) => w.isoWeekday)
                  .toSet()
                  .toList()
                ..sort();
          for (final wd in days) {
            final d = DateTime.utc(
              monday.year,
              monday.month,
              monday.day + wd - 1,
            );
            if (!d.isBefore(base)) yield d;
          }
        case Frequency.monthly:
          final m0 = base.month - 1 + step * k;
          final y = base.year + m0 ~/ 12;
          final m = m0 % 12 + 1;
          final dim = DateTime.utc(y, m + 1, 0).day;
          final days = <int>{
            for (final n in (r.byMonthDay.isEmpty ? [base.day] : r.byMonthDay))
              if (n > 0) n else dim + n + 1,
          }.where((n) => n >= 1 && n <= dim).toList()..sort();
          for (final n in days) {
            final d = DateTime.utc(y, m, n);
            if (!d.isBefore(base)) yield d;
          }
        case Frequency.yearly:
          final y = base.year + step * k;
          final dim = DateTime.utc(y, base.month + 1, 0).day;
          if (base.day <= dim) yield DateTime.utc(y, base.month, base.day);
      }
    }
  }

  /// Start/end for an occurrence beginning at [t], keeping the event's duration.
  _Built build(EventTime t) {
    final end = e.end;
    switch (t) {
      case FixedTime():
        final start = t.instant.toUtc();
        return _Built(start, _after(start, end), false);
      case FloatingTime():
        final start = startOf(t);
        final s = e.start;
        if (end is FloatingTime && s is FloatingTime) {
          final naive = DateTime.utc(
            end.year,
            end.month,
            end.day,
            end.hour,
            end.minute,
          ).difference(DateTime.utc(s.year, s.month, s.day, s.hour, s.minute));
          if (naive.isNegative) return _Built(start, null, false);
          final ew = DateTime.utc(
            t.year,
            t.month,
            t.day,
            t.hour,
            t.minute,
          ).add(naive);
          return _Built(start, _res(ew), false);
        }
        return _Built(start, _after(start, end), false);
      case AllDay():
        final start = startOf(t);
        final s = e.start;
        var span = 0;
        if (end is AllDay && s is AllDay) {
          span = DateTime.utc(
            end.year,
            end.month,
            end.day,
          ).difference(DateTime.utc(s.year, s.month, s.day)).inDays;
          if (span < 0) span = 0;
        }
        final last = DateTime.utc(t.year, t.month, t.day + span + 1);
        return _Built(start, _res(last), true);
    }
  }

  /// [start] plus the event's own (end - start) in instants, or null.
  DateTime? _after(DateTime start, EventTime? end) {
    if (end == null) return null;
    final d = startOf(end).difference(startOf(e.start));
    return d.isNegative ? null : start.add(d);
  }
}
