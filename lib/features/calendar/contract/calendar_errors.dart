import 'package:flutter_riverpod/misc.dart' show ProviderException;

export '../data/calendar_event_codec.dart' show CalendarEventUnreadable;

/// A write that needs an existing event found none under [id].
class CalendarEventNotFound implements Exception {
  const CalendarEventNotFound(this.id);

  final String id;

  @override
  String toString() => 'CalendarEventNotFound($id)';
}

/// Thrown in `cloudApi` mode, where no calendar repository exists yet. Still
/// an [UnimplementedError] so the UI can recognise it and show a friendly
/// message (the Contacts pattern).
class CalendarCloudApiUnavailable extends UnimplementedError {
  CalendarCloudApiUnavailable()
    : super('calendar cloudApi repo ships in the backend plan');
}

/// True when [error] is, or is Riverpod's wrapper around, a
/// [CalendarCloudApiUnavailable].
bool isCalendarCloudApiUnavailable(Object error) {
  var e = error;
  while (e is ProviderException) {
    e = e.exception;
  }
  return e is CalendarCloudApiUnavailable;
}
