import 'package:shared_preferences/shared_preferences.dart';

/// When the owner last looked at the reminders inbox on this device (ISO 8601
/// UTC). Per device, never synced. Reminders fired after it are unseen.
const kRemindersSeenAtKey = 'calendar.remindersSeenAt';

/// The stored seen instant in UTC; null when unset or unreadable.
Future<DateTime?> readRemindersSeenAt() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kRemindersSeenAtKey);
  if (raw == null) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

Future<void> writeRemindersSeenAt(DateTime utc) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kRemindersSeenAtKey, utc.toUtc().toIso8601String());
}

/// How far back the reminders inbox (and the unseen count) looks.
const kRemindersInboxWindow = Duration(days: 7);
