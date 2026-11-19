import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/uuid.dart';
import '../contract/i_reminder_scheduler.dart';
import '../domain/calendar_event.dart';
import '../domain/event_time.dart';
import '../domain/lunar.dart';
import '../domain/occurrence.dart';
import '../domain/recurrence_expander.dart';
import '../domain/recurrence_rule.dart';
import 'calendar_providers.dart';
import 'calendar_view_state.dart';
import 'remind_on_device_provider.dart';

/// One event by id; re-reads on every repository change. Null = absent or
/// deleted; `CalendarEventUnreadable` and the Cloud API error surface as
/// errors.
final calendarEventProvider = FutureProvider.autoDispose
    .family<CalendarEvent?, String>(
      (ref, id) async {
        final repo = ref.watch(calendarRepositoryProvider);
        final sub = repo.changes().listen(
          (_) => ref.invalidateSelf(),
          // A failed change check keeps what is shown; the next change
          // re-reads.
          onError: (Object e) =>
              debugPrint('calendarEvent: changes failed (${e.runtimeType})'),
        );
        ref.onDispose(sub.cancel);
        return repo.getEvent(id);
      },
      // An unreadable note or Cloud API mode will not fix itself by retrying;
      // the next repository change re-reads anyway.
      retry: (_, _) => null,
    );

bool isRepeating(CalendarEvent e) => (e.rrule ?? '').trim().isNotEmpty;

// ---------------------------------------------------------------------------
// Wall-clock helpers. A "wall" is a plain DateTime whose fields are the clock
// reading; arithmetic goes through UTC so a DST change never adds an hour.

DateTime _naive(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);

DateTime _wall(DateTime d) =>
    DateTime(d.year, d.month, d.day, d.hour, d.minute);

Duration wallDiff(DateTime a, DateTime b) => _naive(a).difference(_naive(b));

DateTime wallAdd(DateTime w, Duration d) => _wall(_naive(w).add(d));

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The clock reading of [t] on this device.
DateTime wallOf(EventTime t) => switch (t) {
  FixedTime(:final instant) => _wall(localTimeOf(instant)),
  FloatingTime(
    :final year,
    :final month,
    :final day,
    :final hour,
    :final minute,
  ) =>
    DateTime(year, month, day, hour, minute),
  AllDay(:final year, :final month, :final day) => DateTime(year, month, day),
};

/// The [EventTime] an occurrence's `wireKey` names. A fixed key carries no
/// offset, so it takes the series' own.
EventTime? eventTimeFromWireKey(String key, CalendarEvent e) {
  final i = key.indexOf(':');
  if (i < 0) return null;
  final kind = key.substring(0, i);
  final rest = key.substring(i + 1);
  try {
    switch (kind) {
      case 'floating':
        return FloatingTime.parse(rest);
      case 'allDay':
        return AllDay.parse(rest);
      case 'fixed':
        final s = e.start;
        return FixedTime(
          DateTime.parse(rest).toUtc(),
          s is FixedTime ? s.offset : Duration.zero,
        );
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// The occurrence of a repeating event a screen was opened at (`?at=`).
class OccurrenceRef {
  const OccurrenceRef({
    required this.originalStart,
    required this.effectiveStart,
    this.override,
    this.occurrence,
  });

  /// The slot in the series (override key).
  final EventTime originalStart;

  /// Where it actually is (its moved time, else [originalStart]).
  final EventTime effectiveStart;
  final OccurrenceOverride? override;

  /// The expanded occurrence (start/end instants, title override); null when
  /// cancelled.
  final Occurrence? occurrence;

  OccurrenceStatus? get status => override?.status;

  String? get titleOverride {
    final t = override?.extraFields['title'];
    return t is String ? t : null;
  }

  /// [s] applied to this occurrence, keeping the rest of its override
  /// (including `movedTo`, which applies whatever the status: R-15).
  OccurrenceOverride withStatus(OccurrenceStatus s) =>
      override?.copyWith(status: s) ??
      OccurrenceOverride(originalStart: originalStart, status: s);
}

/// Null for a one-off event, a missing [at], or an unreadable key.
OccurrenceRef? resolveOccurrence(CalendarEvent e, String? at) {
  if (at == null || !isRepeating(e)) return null;
  OccurrenceOverride? ov;
  for (final o in e.occurrences) {
    if (o.originalStart.wireKey == at) {
      ov = o;
      break;
    }
  }
  final original = ov?.originalStart ?? eventTimeFromWireKey(at, e);
  if (original == null) return null;
  // R-15: movedTo applies whatever the status.
  final effective = ov?.movedTo ?? original;
  final resolve = deviceResolver();
  final start = switch (effective) {
    FixedTime(:final instant) => instant.toUtc(),
    FloatingTime(
      :final year,
      :final month,
      :final day,
      :final hour,
      :final minute,
    ) =>
      resolve(year, month, day, hour, minute),
    AllDay(:final year, :final month, :final day) => resolve(
      year,
      month,
      day,
      0,
      0,
    ),
  };
  Occurrence? occ;
  for (final o in expandOccurrences(
    e,
    start.subtract(const Duration(minutes: 1)),
    start.add(const Duration(minutes: 1)),
    resolve: resolve,
  )) {
    if (o.originalStart.wireKey == at) occ = o;
  }
  return OccurrenceRef(
    originalStart: original,
    effectiveStart: effective,
    override: ov,
    occurrence: occ,
  );
}

// ---------------------------------------------------------------------------
// Editor form.

enum RepeatFreq { none, daily, weekly, monthly, yearly }

enum RepeatEnd { never, onDate, afterCount }

enum EditScope { thisOccurrence, all }

/// Everything the editor shows, in wall-clock terms. Turned into stored time
/// types only on save ([buildEvent]).
class EventForm {
  const EventForm({
    required this.title,
    required this.start,
    required this.end,
    this.notes = '',
    this.allDay = false,
    this.freq = RepeatFreq.none,
    this.interval = 1,
    this.byDay = const {},
    this.byMonthDay = const [],
    this.repeatEnd = RepeatEnd.never,
    this.until,
    this.count = 10,
    this.customRule,
    this.reminders = const [Reminder(minutesBefore: 15)],
    this.timeSensitive = false,
    this.lunar = false,
    this.lunarAnchor,
  });

  final String title;
  final String notes;
  final bool allDay;
  final DateTime start;
  final DateTime end;
  final RepeatFreq freq;
  final int interval;
  final Set<Weekday> byDay;
  final List<int> byMonthDay;
  final RepeatEnd repeatEnd;

  /// Last date of the repeat (inclusive) when [repeatEnd] is onDate.
  final DateTime? until;
  final int count;

  /// A rule the picker cannot edit (custom, lunar or unreadable), kept as
  /// written until cleared.
  final String? customRule;

  /// Every reminder, device and other channels, with their unknown keys.
  final List<Reminder> reminders;

  /// Device reminders break through Focus (series-only).
  final bool timeSensitive;

  /// A yearly repeat follows the lunar date instead of the Gregorian one.
  final bool lunar;

  /// The lunar month/day/leap of a rule the form was opened from. Null means
  /// "the lunar date of [start]". Kept so a day-30 rule whose start fell on
  /// day 29 of a short month saves as day 30 (Review Focus 5).
  final LunarDate? lunarAnchor;

  /// The lunar date a lunar yearly repeat uses; null outside the lunar range.
  LunarDate? get lunarDate => lunarAnchor ?? toLunar(dateOnly(start));

  /// A new event on [day]: today starts at the next full hour, any other day
  /// at 09:00; one hour long; one reminder 15 minutes before.
  factory EventForm.newOn(DateTime day, DateTime now) {
    final isToday = dateOnly(day) == dateOnly(now);
    final start = isToday
        ? DateTime(day.year, day.month, day.day, now.hour + 1)
        : DateTime(day.year, day.month, day.day, 9);
    return EventForm(
      title: '',
      start: start,
      end: wallAdd(start, const Duration(hours: 1)),
    );
  }

  /// [e] as a form. With [at], the start (and title) are that occurrence's.
  factory EventForm.fromEvent(CalendarEvent e, {OccurrenceRef? at}) {
    final allDay = e.start is AllDay;
    final seriesStart = wallOf(e.start);
    final start = at != null ? wallOf(at.effectiveStart) : seriesStart;
    final DateTime end;
    final stored = e.end;
    if (stored != null && !wallDiff(wallOf(stored), seriesStart).isNegative) {
      end = wallAdd(start, wallDiff(wallOf(stored), seriesStart));
    } else if (stored != null) {
      // Stored end before start: shown as is so the editor can flag it.
      end = wallOf(stored);
    } else {
      end = allDay ? start : wallAdd(start, const Duration(hours: 1));
    }

    var form = EventForm(
      title: at?.titleOverride ?? e.title,
      notes: e.notes ?? '',
      allDay: allDay,
      start: start,
      end: end,
      reminders: e.reminders,
      timeSensitive: e.timeSensitive,
    );
    final text = e.rrule;
    if (text == null || text.trim().isEmpty) return form;
    final RecurrenceRule rule;
    try {
      rule = RecurrenceRule.parse(text);
    } on FormatException {
      return form.copyWith(customRule: text);
    }
    final anchor = rule.isSupportedLunar
        ? _lunarAnchorOf(rule, dateOnly(seriesStart))
        : null;
    // Any other lunar rule, or one that does not fall on its own start, stays
    // clear-only.
    if (rule.isCustom || (rule.isLunar && anchor == null)) {
      return form.copyWith(customRule: text);
    }
    final until = rule.until;
    form = form.copyWith(
      freq: RepeatFreq.values[rule.freq.index + 1],
      interval: rule.interval,
      byDay: rule.byDay.toSet(),
      byMonthDay: anchor != null ? const [] : rule.byMonthDay,
      lunar: anchor != null,
      // Opened at a later occurrence, a lunar choice still means the series
      // start's lunar date, which is what the rule is built from on save.
      lunarAnchor:
          anchor ?? (at != null ? toLunar(dateOnly(seriesStart)) : null),
      repeatEnd: rule.count != null
          ? RepeatEnd.afterCount
          : until != null
          ? RepeatEnd.onDate
          : RepeatEnd.never,
      count: rule.count ?? 10,
      until: until == null
          ? null
          : rule.untilIsDate || rule.untilIsFloating
          ? DateTime(until.year, until.month, until.day)
          : dateOnly(localTimeOf(until)),
    );
    return form;
  }

  /// The rule's lunar date when it falls on [seriesStart] (its first
  /// occurrence, C-1); null otherwise.
  static LunarDate? _lunarAnchorOf(RecurrenceRule rule, DateTime seriesStart) {
    final year = toLunar(seriesStart)?.year;
    if (year == null) return null;
    final month = rule.byMonth!;
    final day = rule.byMonthDay.single;
    final date = fromLunarBackward(year, month, day, leap: rule.byMonthLeap);
    if (date == null ||
        date.year != seriesStart.year ||
        date.month != seriesStart.month ||
        date.day != seriesStart.day) {
      return null;
    }
    return LunarDate(year, month, day, isLeap: rule.byMonthLeap);
  }

  /// A [start] on another date drops [lunarAnchor] (the lunar date is then
  /// read from the new start) unless [lunarAnchor] is passed too.
  EventForm copyWith({
    String? title,
    String? notes,
    bool? allDay,
    DateTime? start,
    DateTime? end,
    RepeatFreq? freq,
    int? interval,
    Set<Weekday>? byDay,
    List<int>? byMonthDay,
    RepeatEnd? repeatEnd,
    DateTime? until,
    int? count,
    String? customRule,
    bool clearCustomRule = false,
    List<Reminder>? reminders,
    bool? timeSensitive,
    bool? lunar,
    LunarDate? lunarAnchor,
  }) => EventForm(
    title: title ?? this.title,
    notes: notes ?? this.notes,
    allDay: allDay ?? this.allDay,
    start: start ?? this.start,
    end: end ?? this.end,
    freq: freq ?? this.freq,
    interval: interval ?? this.interval,
    byDay: byDay ?? this.byDay,
    byMonthDay: byMonthDay ?? this.byMonthDay,
    repeatEnd: repeatEnd ?? this.repeatEnd,
    until: until ?? this.until,
    count: count ?? this.count,
    customRule: clearCustomRule ? null : (customRule ?? this.customRule),
    reminders: reminders ?? this.reminders,
    timeSensitive: timeSensitive ?? this.timeSensitive,
    lunar: lunar ?? this.lunar,
    lunarAnchor:
        lunarAnchor ??
        (start != null && dateOnly(start) != dateOnly(this.start)
            ? null
            : this.lunarAnchor),
  );

  bool get repeats => customRule != null || freq != RepeatFreq.none;

  /// Review Focus 5: the editor refuses to save this.
  bool get endBeforeStart => allDay
      ? dateOnly(end).isBefore(dateOnly(start))
      : wallDiff(end, start).isNegative;

  bool get titleMissing => title.trim().isEmpty;

  bool get canSave => !titleMissing && !endBeforeStart;

  bool get hasDeviceReminder =>
      reminders.any((r) => r.channel == ReminderChannel.device);

  /// The RRULE text, or null for a one-off.
  String? get rrule {
    if (customRule != null) return customRule;
    if (freq == RepeatFreq.none) return null;
    final f = Frequency.values[freq.index - 1];
    final u = until;
    final count = repeatEnd == RepeatEnd.afterCount ? this.count : null;
    // Date-form UNTIL: repeating timed events are floating (R8), and the
    // expander compares a date UNTIL against each slot's own date.
    final untilUtc = repeatEnd == RepeatEnd.onDate && u != null
        ? DateTime.utc(u.year, u.month, u.day)
        : null;
    final anchor = f == Frequency.yearly && lunar ? lunarDate : null;
    if (anchor != null) {
      return RecurrenceRule.lunarYearly(
        month: anchor.month,
        day: anchor.day,
        leap: anchor.isLeap,
        interval: interval,
        count: count,
        until: untilUtc,
      ).format();
    }
    return RecurrenceRule(
      freq: f,
      interval: interval,
      byDay: f == Frequency.weekly
          ? (byDay.toList()..sort((a, b) => a.index - b.index))
          : const [],
      byMonthDay: f == Frequency.monthly ? byMonthDay : const [],
      count: count,
      until: untilUtc,
      untilIsDate: true,
    ).format();
  }
}

/// Stored start/end for [f]: all-day → [AllDay]; repeating timed →
/// [FloatingTime]; one-off timed → [FixedTime] with the device offset at that
/// instant.
(EventTime, EventTime?) storedTimes(EventForm f) {
  if (f.allDay) {
    final s = AllDay(f.start.year, f.start.month, f.start.day);
    final e = dateOnly(f.end).isAfter(dateOnly(f.start))
        ? AllDay(f.end.year, f.end.month, f.end.day)
        : null;
    return (s, e);
  }
  EventTime at(DateTime w) => f.repeats
      ? FloatingTime(w.year, w.month, w.day, w.hour, w.minute)
      : fixedTimeAtWall(w);
  return (at(f.start), at(f.end));
}

/// The series [f] describes. For an existing event, [initial] is the form as
/// first shown: the series start moves by the same wall-clock amount the
/// shown start moved, so editing "all" from a later occurrence keeps the
/// series' first day. Fields the form does not show (owner, source, status,
/// draft, overrides, unknown keys) are kept.
CalendarEvent buildEvent(
  EventForm f, {
  CalendarEvent? base,
  EventForm? initial,
  required DateTime now,
}) {
  var form = f;
  if (base != null && initial != null) {
    final shift = wallDiff(f.start, initial.start);
    final start = wallAdd(wallOf(base.start), shift);
    form = f.copyWith(
      start: start,
      end: wallAdd(start, wallDiff(f.end, f.start)),
      // The series' own lunar date stays unless the shown date moved.
      lunarAnchor: dateOnly(f.start) == dateOnly(initial.start)
          ? f.lunarAnchor
          : null,
    );
  }
  final (start, end) = storedTimes(form);
  final rrule = form.rrule;
  final notes = form.notes.trim().isEmpty ? null : form.notes;
  // The form shows an occurrence's own title when it has one; left as shown,
  // the series keeps its title.
  final title =
      base != null &&
          initial != null &&
          form.title.trim() == initial.title.trim()
      ? base.title
      : form.title.trim();
  // Time Sensitive only applies to device reminders; without one it is off,
  // so the detail screen never labels an event that cannot break through.
  final timeSensitive = form.timeSensitive && form.hasDeviceReminder;
  if (base == null) {
    return CalendarEvent(
      id: generateUuid(),
      title: title,
      notes: notes,
      start: start,
      end: end,
      rrule: rrule,
      reminders: form.reminders,
      timeSensitive: timeSensitive,
      updatedAt: now.toUtc(),
    );
  }
  return base.copyWith(
    title: title,
    notes: notes,
    clearNotes: notes == null,
    start: start,
    end: end,
    clearEnd: end == null,
    rrule: rrule,
    clearRrule: rrule == null,
    reminders: form.reminders,
    timeSensitive: timeSensitive,
    updatedAt: now.toUtc(),
  );
}

/// The override "This occurrence" writes, or null when neither the title nor
/// the time changed. A new time is a `moved` override; a new title is
/// `extraFields['title']` (ruling R-2), on top of whatever the override
/// already held.
OccurrenceOverride? buildOccurrenceOverride(
  CalendarEvent base,
  OccurrenceRef at,
  EventForm initial,
  EventForm f,
) {
  final timeChanged =
      f.allDay != initial.allDay ||
      wallDiff(f.start, initial.start) != Duration.zero;
  final title = f.title.trim();
  final titleChanged = title != initial.title.trim();
  if (!timeChanged && !titleChanged) return null;

  final existing = at.override;
  final extra = {...?existing?.extraFields};
  if (titleChanged) {
    if (title == base.title) {
      extra.remove('title');
    } else {
      extra['title'] = title;
    }
  }

  OccurrenceStatus status;
  EventTime? movedTo;
  if (timeChanged) {
    final w = f.start;
    status = OccurrenceStatus.moved;
    movedTo = f.allDay
        ? AllDay(w.year, w.month, w.day)
        : base.start is FixedTime
        ? fixedTimeAtWall(w)
        : FloatingTime(w.year, w.month, w.day, w.hour, w.minute);
  } else {
    // A title-only change on a plain occurrence: "moved" to its own slot,
    // which expands exactly like no move.
    status = existing?.status ?? OccurrenceStatus.moved;
    movedTo =
        existing?.movedTo ??
        (status == OccurrenceStatus.moved ? at.originalStart : null);
  }
  return OccurrenceOverride(
    originalStart: at.originalStart,
    status: status,
    movedTo: movedTo,
    extraFields: extra,
  );
}

/// [e] ending just before [originalStart] ("Delete this and following"):
/// UNTIL is the day before it (date form) for floating and all-day series,
/// and one second before it (UTC date-time, RFC 5545) for a fixed series.
/// COUNT is dropped. Null when nothing would be left, which means "delete the
/// series".
CalendarEvent? truncateBefore(CalendarEvent e, EventTime originalStart) {
  final RecurrenceRule rule;
  try {
    rule = RecurrenceRule.parse(e.rrule ?? '');
  } on FormatException {
    return null; // expands as a one-off: only the first occurrence exists
  }
  // An unsupported lunar rule expands only the first occurrence (R-3).
  if (rule.isLunar && !rule.isSupportedLunar) return null;

  final DateTime until;
  final bool untilIsDate;
  switch (originalStart) {
    case FixedTime(:final instant):
      until = instant.toUtc().subtract(const Duration(seconds: 1));
      untilIsDate = false;
    case FloatingTime(:final year, :final month, :final day):
      until = DateTime.utc(year, month, day - 1);
      untilIsDate = true;
    case AllDay(:final year, :final month, :final day):
      until = DateTime.utc(year, month, day - 1);
      untilIsDate = true;
  }
  final truncated = e.copyWith(
    rrule: RecurrenceRule(
      freq: rule.freq,
      interval: rule.interval,
      byDay: rule.byDay,
      byMonthDay: rule.byMonthDay,
      until: until,
      untilIsDate: untilIsDate,
      unsupported: rule.unsupported,
      rscale: rule.rscale,
      byMonth: rule.byMonth,
      byMonthLeap: rule.byMonthLeap,
      skip: rule.skip,
    ).format(),
  );

  // Anything left before the occurrence? Overrides ignored: a done or
  // skipped earlier occurrence still counts as left.
  final resolve = deviceResolver();
  DateTime startOf(EventTime t) => switch (t) {
    FixedTime(:final instant) => instant.toUtc(),
    FloatingTime(
      :final year,
      :final month,
      :final day,
      :final hour,
      :final minute,
    ) =>
      resolve(year, month, day, hour, minute),
    AllDay(:final year, :final month, :final day) => resolve(
      year,
      month,
      day,
      0,
      0,
    ),
  };
  final left = expandOccurrences(
    truncated.copyWith(occurrences: const []),
    startOf(e.start).subtract(const Duration(days: 1)),
    startOf(originalStart),
    resolve: resolve,
  );
  return left.isEmpty ? null : truncated;
}

/// R-11: the first save that has a device reminder, on a device where
/// reminders are on and permission was never asked, asks once and records
/// the answer (which drives the banner). Later saves never ask again. After
/// asking, [afterAsk] runs (R-18: a ReminderSync trigger, so a grant
/// schedules at once). Everything is passed in, so no WidgetRef is used
/// after an await.
Future<void> askReminderPermissionIfFirst({
  required bool remindOnDevice,
  required bool hasDeviceReminder,
  required IReminderScheduler scheduler,
  required CalendarPermissionDeniedNotifier denied,
  void Function()? afterAsk,
}) async {
  if (!remindOnDevice || !hasDeviceReminder) return;
  final answer = await askPermissionOnceIfNeverAsked(
    request: scheduler.requestPermission,
    markAsked: (granted) => denied.markPermissionAsked(granted: granted),
  );
  if (answer != null) afterAsk?.call();
}
