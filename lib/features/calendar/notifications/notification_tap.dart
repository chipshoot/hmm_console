/// The route to open for a tapped reminder payload
/// (`calendar|<id>|<wireKey>`), or null for a payload that is not a calendar
/// reminder or is malformed; the tap is then ignored.
String? calendarRouteForPayload(String payload) {
  final parts = payload.split('|');
  if (parts.length < 2 || parts[0] != 'calendar' || parts[1].isEmpty) {
    return null;
  }
  final id = Uri.encodeComponent(parts[1]);
  final at = parts.skip(2).join('|');
  if (at.isEmpty) return '/calendar/event/$id';
  return '/calendar/event/$id?at=${Uri.encodeQueryComponent(at)}';
}
