import '../contract/dated_note.dart' show LinkedKind;
import 'calendar_event.dart';
import 'lunar.dart';

/// The `linked` extra field of an event a subsystem owns: a kind plus the
/// language-neutral arguments its title is rendered from.
class LinkedInfo {
  const LinkedInfo(this.kind, this.args);
  final LinkedKind kind;
  final Map<String, Object?> args;
}

/// The linked info of [e]; null when absent, malformed or of an unknown kind.
/// Accepts any key order.
LinkedInfo? linkedInfoOf(CalendarEvent e) {
  final raw = e.extraFields['linked'];
  if (raw is! Map) return null;
  final name = raw['kind'];
  if (name is! String) return null;
  LinkedKind? kind;
  for (final k in LinkedKind.values) {
    if (k.name == name) kind = k;
  }
  if (kind == null) return null;
  final args = raw['args'];
  return LinkedInfo(
    kind,
    args is Map ? Map<String, Object?>.from(args) : const {},
  );
}

/// The `linked` field value for [kind] and [args], with the args in sorted
/// key order so two encodings of the same content compare equal.
Map<String, Object?> linkedToJson(LinkedKind kind, Map<String, Object?> args) {
  final keys = args.keys.toList()..sort();
  return {
    'kind': kind.name,
    'args': {for (final k in keys) k: args[k]},
  };
}

/// Age turned on a birthday occurrence; null without a known birth year or
/// for a non-birthday. A lunar birthday counts lunar years.
int? birthdayAgeAt(LinkedInfo info, DateTime occurrenceDate) {
  if (info.kind != LinkedKind.birthday) return null;
  final year = info.args['birthYear'];
  if (year is! int) return null;
  if (info.args['calendar'] == 'lunar') {
    final lunar = toLunar(occurrenceDate);
    return lunar == null ? null : lunar.year - year;
  }
  return occurrenceDate.year - year;
}
