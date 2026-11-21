enum Frequency { daily, weekly, monthly, yearly }

enum Weekday {
  mo('MO'),
  tu('TU'),
  we('WE'),
  th('TH'),
  fr('FR'),
  sa('SA'),
  su('SU');

  const Weekday(this.code);
  final String code;

  /// `DateTime.weekday` value (Monday = 1).
  int get isoWeekday => index + 1;

  static Weekday? fromCode(String c) {
    for (final w in values) {
      if (w.code == c) return w;
    }
    return null;
  }
}

/// The RRULE subset the calendar understands, plus whatever it does not.
///
/// Understood: FREQ, INTERVAL, BYDAY (plain weekday codes), BYMONTHDAY,
/// COUNT, UNTIL, RSCALE, and for a Chinese-lunar rule BYMONTH (`4` or `4L`
/// for a leap month) and SKIP. Everything else is kept verbatim in [unsupported]
/// and written back by [format]; such a rule is [isCustom].
class RecurrenceRule {
  const RecurrenceRule({
    required this.freq,
    this.interval = 1,
    this.byDay = const [],
    this.byMonthDay = const [],
    this.count,
    this.until,
    this.untilIsDate = true,
    this.untilIsFloating = false,
    this.unsupported = '',
    this.rscale,
    this.byMonth,
    this.byMonthLeap = false,
    this.skip,
    this.original,
  });

  /// A Chinese-lunar yearly rule on [month]/[day] (leap month when [leap]).
  /// A day missing in a given year falls back (SKIP=BACKWARD).
  factory RecurrenceRule.lunarYearly({
    required int month,
    required int day,
    bool leap = false,
    int interval = 1,
    int? count,
    DateTime? until,
  }) => RecurrenceRule(
    freq: Frequency.yearly,
    interval: interval,
    byMonthDay: [day],
    byMonth: month,
    byMonthLeap: leap,
    skip: 'BACKWARD',
    rscale: 'CHINESE',
    count: count,
    until: until,
    untilIsDate: true,
  );

  /// A Gregorian yearly rule whose 29 February falls back to 28 February in
  /// non-leap years (SKIP=BACKWARD), used for birthdays.
  factory RecurrenceRule.gregorianYearlyBackward() => const RecurrenceRule(
    freq: Frequency.yearly,
    rscale: 'GREGORIAN',
    skip: 'BACKWARD',
  );

  final Frequency freq;
  final int interval;
  final List<Weekday> byDay;
  final List<int> byMonthDay;
  final int? count;

  /// UTC. For a date-only UNTIL ([untilIsDate]) this is midnight of that
  /// date and the whole date is included.
  ///
  /// For a local-form date-time UNTIL (`YYYYMMDDTHHMMSS`, no `Z`;
  /// [untilIsFloating]) the fields are the wall-clock reading in the
  /// series' own zone, not a UTC instant.
  final DateTime? until;
  final bool untilIsDate;
  final bool untilIsFloating;

  /// Parts this class does not understand, `;`-joined, verbatim.
  final String unsupported;
  final String? rscale;

  /// Lunar month (1..12) of a lunar rule; null for Gregorian rules, whose
  /// BYMONTH stays in [unsupported].
  final int? byMonth;
  final bool byMonthLeap;

  /// SKIP of a lunar rule, upper-case; null reads as BACKWARD.
  final String? skip;

  /// The text this rule was parsed from; returned by [format] for lunar rules.
  final String? original;

  bool get isLunar => rscale != null && rscale != 'GREGORIAN';

  /// A lunar yearly rule the calendar can expand and edit.
  bool get isSupportedLunar =>
      rscale == 'CHINESE' &&
      freq == Frequency.yearly &&
      byMonth != null &&
      byMonth! >= 1 &&
      byMonth! <= 12 &&
      byMonthDay.length == 1 &&
      byMonthDay.single >= 1 &&
      byMonthDay.single <= 30 &&
      (skip == null || skip == 'BACKWARD') &&
      byDay.isEmpty &&
      unsupported.isEmpty;

  /// A plain Gregorian yearly rule with SKIP=BACKWARD.
  bool get isGregorianSkipBackward =>
      rscale == 'GREGORIAN' &&
      freq == Frequency.yearly &&
      skip == 'BACKWARD' &&
      byDay.isEmpty &&
      byMonthDay.isEmpty &&
      unsupported.isEmpty;

  bool get isCustom =>
      (isLunar && !isSupportedLunar) ||
      unsupported.isNotEmpty ||
      (byDay.isNotEmpty && freq != Frequency.weekly) ||
      (byMonthDay.isNotEmpty && freq != Frequency.monthly && !isSupportedLunar);

  static const _freqs = {
    'DAILY': Frequency.daily,
    'WEEKLY': Frequency.weekly,
    'MONTHLY': Frequency.monthly,
    'YEARLY': Frequency.yearly,
  };

  static int _int(String v, String key) {
    final n = int.tryParse(v);
    if (n == null) throw FormatException('bad $key: $v');
    return n;
  }

  /// Throws [FormatException] when FREQ is missing/unknown or a number or
  /// date is malformed.
  static RecurrenceRule parse(String rrule) {
    Frequency? freq;
    var interval = 1;
    var byDay = <Weekday>[];
    var byMonthDay = <int>[];
    int? count;
    DateTime? until;
    var untilIsDate = true;
    var untilIsFloating = false;
    String? rscale;
    final unsupported = <String>[];

    final text = rrule.trim();
    for (final part in text.split(';')) {
      if (part.trim().isEmpty) continue;
      final eq = part.indexOf('=');
      if (eq < 0) throw FormatException('bad rule part: $part');
      final key = part.substring(0, eq).trim().toUpperCase();
      final value = part.substring(eq + 1).trim();
      switch (key) {
        case 'FREQ':
          freq = _freqs[value.toUpperCase()];
          if (freq == null) throw FormatException('bad FREQ: $value');
        case 'INTERVAL':
          interval = _int(value, key);
          if (interval < 1) throw FormatException('bad INTERVAL: $value');
        case 'COUNT':
          count = _int(value, key);
          if (count < 0) throw FormatException('bad COUNT: $value');
        case 'BYMONTHDAY':
          byMonthDay = [for (final v in value.split(',')) _int(v, key)];
        case 'BYDAY':
          final days = [
            for (final v in value.split(',')) Weekday.fromCode(v.toUpperCase()),
          ];
          if (days.contains(null)) {
            unsupported.add(part.trim()); // e.g. 1MO, -1FR
          } else {
            byDay = days.cast<Weekday>();
          }
        case 'UNTIL':
          final m = RegExp(
            r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
          ).firstMatch(value.toUpperCase());
          if (m == null) throw FormatException('bad UNTIL: $value');
          final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i) ?? '0')];
          untilIsDate = m.group(4) == null;
          untilIsFloating = !untilIsDate && m.group(7) == null;
          until = DateTime.utc(v[0], v[1], v[2], v[3], v[4], v[5]);
        case 'RSCALE':
          rscale = value.toUpperCase();
        default:
          unsupported.add(part.trim());
      }
    }
    if (freq == null) throw FormatException('missing FREQ: $rrule');
    int? byMonth;
    var byMonthLeap = false;
    String? skip;
    if (rscale != null && rscale != 'GREGORIAN') {
      final idx = unsupported.indexWhere(
        (p) => p.toUpperCase().startsWith('BYMONTH='),
      );
      final m = idx < 0
          ? null
          : RegExp(
              r'^(\d{1,2})(L)?$',
            ).firstMatch(unsupported[idx].substring(8).trim().toUpperCase());
      if (m != null) {
        byMonth = int.parse(m.group(1)!);
        byMonthLeap = m.group(2) != null;
        unsupported.removeAt(idx);
      }
      final sIdx = unsupported.indexWhere(
        (p) => p.toUpperCase().startsWith('SKIP='),
      );
      if (sIdx >= 0 && byMonth != null) {
        skip = unsupported[sIdx].substring(5).trim().toUpperCase();
        unsupported.removeAt(sIdx);
      }
    }
    if (rscale == 'GREGORIAN') {
      final sIdx = unsupported.indexWhere(
        (p) => p.toUpperCase().startsWith('SKIP='),
      );
      if (sIdx >= 0) {
        skip = unsupported[sIdx].substring(5).trim().toUpperCase();
        unsupported.removeAt(sIdx);
      }
    }
    return RecurrenceRule(
      freq: freq,
      interval: interval,
      byDay: byDay,
      byMonthDay: byMonthDay,
      count: count,
      until: until,
      untilIsDate: untilIsDate,
      untilIsFloating: untilIsFloating,
      unsupported: unsupported.join(';'),
      rscale: rscale,
      byMonth: byMonth,
      byMonthLeap: byMonthLeap,
      skip: skip,
      original: text,
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  String _untilText() {
    final u = until!;
    final date =
        '${u.year.toString().padLeft(4, '0')}${_two(u.month)}${_two(u.day)}';
    if (untilIsDate) return date;
    final time = '${_two(u.hour)}${_two(u.minute)}${_two(u.second)}';
    return untilIsFloating ? '${date}T$time' : '${date}T${time}Z';
  }

  /// Canonical text. A lunar rule is returned exactly as parsed; unsupported
  /// parts are appended verbatim.
  String format() {
    if (isLunar && original != null) return original!;
    final parts = <String>[
      if (rscale != null) 'RSCALE=$rscale',
      'FREQ=${freq.name.toUpperCase()}',
      if (interval != 1) 'INTERVAL=$interval',
      if (byDay.isNotEmpty) 'BYDAY=${byDay.map((d) => d.code).join(',')}',
      if (byMonth != null) 'BYMONTH=$byMonth${byMonthLeap ? 'L' : ''}',
      if (byMonthDay.isNotEmpty) 'BYMONTHDAY=${byMonthDay.join(',')}',
      if (skip != null) 'SKIP=$skip',
      if (count != null) 'COUNT=$count',
      if (until != null) 'UNTIL=${_untilText()}',
      if (unsupported.isNotEmpty) unsupported,
    ];
    return parts.join(';');
  }
}
