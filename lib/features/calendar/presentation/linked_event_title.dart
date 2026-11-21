import '../../../l10n/gen/app_localizations.dart';
import '../contract/dated_note.dart' show LinkedKind;
import '../domain/calendar_event.dart';
import '../domain/event_time.dart';
import '../domain/linked_event.dart';
import '../domain/occurrence.dart';

String _arg(LinkedInfo info, String key) {
  final v = info.args[key];
  return v is String ? v : '';
}

/// The title of a linked event in the language of [l].
String linkedTitle(LinkedInfo info, AppLocalizations l) => switch (info.kind) {
  LinkedKind.licenceExpiry => l.calendarLinkedLicenceExpiry,
  LinkedKind.registrationExpiry => l.calendarLinkedRegistrationExpiry(
    _arg(info, 'vehicle'),
  ),
  LinkedKind.insuranceExpiry => l.calendarLinkedInsuranceExpiry(
    _arg(info, 'vehicle'),
  ),
  LinkedKind.serviceDue => l.calendarLinkedServiceDue(
    _arg(info, 'vehicle'),
    _arg(info, 'service'),
  ),
  LinkedKind.birthday => l.calendarLinkedBirthday(_arg(info, 'name')),
};

/// An occurrence's title override, else the linked title, else the stored
/// title.
String eventTitle(CalendarEvent e, Occurrence? o, AppLocalizations l) =>
    eventTitleWithOverride(e, o?.titleOverride, l);

/// As [eventTitle] with the override given directly.
String eventTitleWithOverride(
  CalendarEvent e,
  String? titleOverride,
  AppLocalizations l,
) {
  if (titleOverride != null) return titleOverride;
  final info = linkedInfoOf(e);
  return info == null ? e.title : linkedTitle(info, l);
}

/// The calendar date of [t] (the device-local date for a fixed instant).
DateTime eventTimeDate(EventTime t) => switch (t) {
  FixedTime(:final instant) => DateTime(
    instant.toLocal().year,
    instant.toLocal().month,
    instant.toLocal().day,
  ),
  FloatingTime(:final year, :final month, :final day) => DateTime(
    year,
    month,
    day,
  ),
  AllDay(:final year, :final month, :final day) => DateTime(year, month, day),
};

/// " · turns N" for a birthday with a known birth year, else ''.
String birthdayAgeSuffix(
  CalendarEvent e,
  DateTime occurrenceDate,
  AppLocalizations l,
) {
  final info = linkedInfoOf(e);
  if (info == null) return '';
  final age = birthdayAgeAt(info, occurrenceDate);
  return age == null ? '' : ' · ${l.calendarLinkedTurnsAge(age)}';
}
