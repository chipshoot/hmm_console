import 'dart:convert';

import '../../../core/util/uuid.dart';
import '../domain/calendar_event.dart';
import '../domain/event_time.dart';
import '../domain/recurrence_rule.dart';

/// Fixed namespace for linked-event ids (UUID v5).
const kLinkedEventNamespace = '5b0e7c1a-9d4f-5e2b-8a63-0f1d2c3b4a59';

/// Deterministic event id for a linked date key (e.g. `licence:expiry`).
String linkedEventId(String key) => uuidV5(kLinkedEventNamespace, key);

const kLinkedSubsystemLicence = 'driverLicence';
const kLinkedSubsystemAutomobile = 'automobile';
const kLinkedSubsystemInsurance = 'insurance';
const kLinkedSubsystemScheduledService = 'scheduledService';
const kLinkedSubsystemContacts = 'contacts';

/// What a linked event is; the wire name is `.name`.
enum LinkedKind {
  licenceExpiry,
  registrationExpiry,
  insuranceExpiry,
  serviceDue,
  birthday,
}

/// One date a subsystem wants on the calendar.
class DatedItem {
  const DatedItem({
    required this.key,
    required this.kind,
    required this.args,
    required this.date,
    this.repeat,
    required this.owner,
    this.reminderBody,
  });

  final String key;
  final LinkedKind kind;
  final Map<String, Object?> args;
  final AllDay date;
  final RecurrenceRule? repeat;
  final EventOwner owner;
  final String? reminderBody;

  String get eventId => linkedEventId(key);

  @override
  bool operator ==(Object other) =>
      other is DatedItem &&
      other.key == key &&
      other.kind == kind &&
      jsonEncode(other.args) == jsonEncode(args) &&
      other.date == date &&
      other.repeat?.format() == repeat?.format() &&
      other.owner == owner &&
      other.reminderBody == reminderBody;

  @override
  int get hashCode => Object.hash(
    key,
    kind,
    jsonEncode(args),
    date,
    repeat?.format(),
    owner,
    reminderBody,
  );
}

/// A note-backed entity that exposes calendar dates.
abstract interface class DatedNote {
  List<DatedItem> get dates;
}

/// A subsystem that supplies dated notes to the calendar matcher.
abstract interface class DatedNoteSource {
  /// Owner subsystems this source covers (removal scope).
  Set<String> get subsystems;

  Future<List<DatedNote>> datedNotes();

  /// GoRouter location of the source screen for [owner], or null when the
  /// source no longer exists.
  Future<String?> locationOf(EventOwner owner);
}
