import '../../../l10n/gen/app_localizations.dart';
import '../domain/activity.dart';
import '../domain/activity_kind.dart';

/// `45 min`, `1 h`, `1 h 20 min`.
String activityDurationText(int minutes, AppLocalizations l) {
  if (minutes < 60) return l.activityMinutes(minutes);
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? l.activityHours(h) : l.activityHoursMinutes(h, m);
}

/// The kind's label; an unknown kind reads `Other (<id>)` so nothing is
/// silently renamed.
String activityKindText(
  String kind,
  ActivityKindRegistry r,
  AppLocalizations l,
) {
  final k = r.byId(kind);
  return k == null ? '${l.activityKindOther} ($kind)' : k.label(l);
}

String _intensityText(ActivityIntensity i, AppLocalizations l) => switch (i) {
  ActivityIntensity.light => l.activityIntensityLight,
  ActivityIntensity.moderate => l.activityIntensityModerate,
  ActivityIntensity.vigorous => l.activityIntensityVigorous,
}.toLowerCase();

/// `2.4 km`; a whole number drops its decimals.
String _number(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// One line describing [a]: `Walk · 30 min · moderate · 2.4 km`, or
/// `Reading · 40 min · "Dune"` when a linked note's [noteTitle] is known.
String activitySummary(
  Activity a,
  ActivityKindRegistry r,
  AppLocalizations l, {
  String? noteTitle,
}) {
  ActivityMeasurement? distance;
  for (final m in a.measurements) {
    if (m.name == 'distance') {
      distance = m;
      break;
    }
  }
  final title = noteTitle?.trim() ?? '';
  return [
    activityKindText(a.kind, r, l),
    activityDurationText(a.durationMinutes, l),
    if (a.intensity != null) _intensityText(a.intensity!, l),
    if (distance != null) '${_number(distance.value)} ${distance.unit}',
    if (title.isNotEmpty) '"$title"',
  ].join(' · ');
}
