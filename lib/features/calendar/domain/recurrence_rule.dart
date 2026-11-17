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
/// COUNT, UNTIL, RSCALE. Everything else is kept verbatim in [unsupported]
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
    this.unsupported = '',
    this.rscale,
    this.original,
  });

  final Frequency freq;
  final int interval;
  final List<Weekday> byDay;
  final List<int> byMonthDay;
  final int? count;

  /// UTC. For a date-only UNTIL ([untilIsDate]) this is midnight of that
  /// date and the whole date is included.
  final DateTime? until;
  final bool untilIsDate;

  /// Parts this class does not understand, `;`-joined, verbatim.
  final String unsupported;
  final String? rscale;

  /// The text this rule was parsed from; returned by [format] for lunar rules.
  final String? original;

  bool get isLunar => rscale != null && rscale != 'GREGORIAN';

  bool get isCustom =>
      isLunar ||
      unsupported.isNotEmpty ||
      (byDay.isNotEmpty && freq != Frequency.weekly) ||
      (byMonthDay.isNotEmpty && freq != Frequency.monthly);

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
            r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})Z)?$',
          ).firstMatch(value);
          if (m == null) throw FormatException('bad UNTIL: $value');
          final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i) ?? '0')];
          untilIsDate = m.group(4) == null;
          until = DateTime.utc(v[0], v[1], v[2], v[3], v[4], v[5]);
        case 'RSCALE':
          rscale = value.toUpperCase();
        default:
          unsupported.add(part.trim());
      }
    }
    if (freq == null) throw FormatException('missing FREQ: $rrule');
    return RecurrenceRule(
      freq: freq,
      interval: interval,
      byDay: byDay,
      byMonthDay: byMonthDay,
      count: count,
      until: until,
      untilIsDate: untilIsDate,
      unsupported: unsupported.join(';'),
      rscale: rscale,
      original: text,
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  String _untilText() {
    final u = until!;
    final date =
        '${u.year.toString().padLeft(4, '0')}${_two(u.month)}${_two(u.day)}';
    if (untilIsDate) return date;
    return '${date}T${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
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
      if (byMonthDay.isNotEmpty) 'BYMONTHDAY=${byMonthDay.join(',')}',
      if (count != null) 'COUNT=$count',
      if (until != null) 'UNTIL=${_untilText()}',
      if (unsupported.isNotEmpty) unsupported,
    ];
    return parts.join(';');
  }
}
