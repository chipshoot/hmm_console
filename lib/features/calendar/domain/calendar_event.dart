import 'dart:convert';

import 'event_time.dart';

enum EventStatus { active, cancelled }

enum EventSource { manual, subsystem, assistant }

enum OccurrenceStatus { done, skipped, cancelled, moved }

enum ReminderChannel { device, email }

bool _jsonEq(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

class Reminder {
  const Reminder({
    required this.minutesBefore,
    this.channel = ReminderChannel.device,
    this.extraFields = const {},
  });

  final int minutesBefore;
  final ReminderChannel channel;
  final Map<String, Object?> extraFields;

  Reminder copyWith({int? minutesBefore, ReminderChannel? channel}) => Reminder(
    minutesBefore: minutesBefore ?? this.minutesBefore,
    channel: channel ?? this.channel,
    extraFields: extraFields,
  );

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.minutesBefore == minutesBefore &&
      other.channel == channel &&
      _jsonEq(other.extraFields, extraFields);

  @override
  int get hashCode => Object.hash(minutesBefore, channel);
}

class EventOwner {
  const EventOwner({
    required this.subsystem,
    this.noteUuid,
    this.extraFields = const {},
  });

  final String subsystem;
  final String? noteUuid;
  final Map<String, Object?> extraFields;

  @override
  bool operator ==(Object other) =>
      other is EventOwner &&
      other.subsystem == subsystem &&
      other.noteUuid == noteUuid &&
      _jsonEq(other.extraFields, extraFields);

  @override
  int get hashCode => Object.hash(subsystem, noteUuid);
}

class OccurrenceOverride {
  const OccurrenceOverride({
    required this.originalStart,
    required this.status,
    this.movedTo,
    this.extraFields = const {},
  });

  final EventTime originalStart;
  final OccurrenceStatus status;
  final EventTime? movedTo;

  /// Unknown keys of this override object, written back (a per-occurrence
  /// title is `extraFields['title']`).
  final Map<String, Object?> extraFields;

  OccurrenceOverride copyWith({
    OccurrenceStatus? status,
    EventTime? movedTo,
    Map<String, Object?>? extraFields,
  }) => OccurrenceOverride(
    originalStart: originalStart,
    status: status ?? this.status,
    movedTo: movedTo ?? this.movedTo,
    extraFields: extraFields ?? this.extraFields,
  );

  @override
  bool operator ==(Object other) =>
      other is OccurrenceOverride &&
      other.originalStart == originalStart &&
      other.status == status &&
      other.movedTo == movedTo &&
      _jsonEq(other.extraFields, extraFields);

  @override
  int get hashCode => Object.hash(originalStart, status, movedTo);
}

/// One occurrence of an event, computed by expansion and never stored.
class Occurrence {
  const Occurrence({
    required this.eventId,
    required this.start,
    this.end,
    this.status,
  });

  final String eventId;
  final DateTime start;
  final DateTime? end;
  final OccurrenceStatus? status;

  @override
  bool operator ==(Object other) =>
      other is Occurrence &&
      other.eventId == eventId &&
      other.start == start &&
      other.end == end &&
      other.status == status;

  @override
  int get hashCode => Object.hash(eventId, start, end, status);
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.updatedAt,
    this.schemaVersion = 1,
    this.notes,
    this.end,
    this.rrule,
    this.reminders = const [],
    this.owner,
    this.status = EventStatus.active,
    this.source = EventSource.manual,
    this.draft = false,
    this.occurrences = const [],
    this.extraFields = const {},
    this.rawKnownValues = const {},
    this.unreadableEntries = const {},
  });

  final String id;
  final int schemaVersion;
  final String title;
  final String? notes;
  final EventTime start;
  final EventTime? end;

  /// RFC 5545 RRULE subset as a string; null = one-off.
  final String? rrule;
  final List<Reminder> reminders;
  final EventOwner? owner;
  final EventStatus status;
  final EventSource source;
  final bool draft;
  final List<OccurrenceOverride> occurrences;
  final DateTime updatedAt;

  /// Unknown top-level keys, written back untouched.
  final Map<String, Object?> extraFields;

  /// Known keys whose stored value had the wrong type; see `CalendarEventCodec`.
  final Map<String, Object?> rawKnownValues;

  /// List entries (`reminders`, `occurrences`) that could not be decoded,
  /// kept verbatim and re-emitted after the readable ones.
  final Map<String, List<Object?>> unreadableEntries;

  CalendarEvent copyWith({
    String? title,
    String? notes,
    bool clearNotes = false,
    EventTime? start,
    EventTime? end,
    bool clearEnd = false,
    String? rrule,
    bool clearRrule = false,
    List<Reminder>? reminders,
    EventOwner? owner,
    bool clearOwner = false,
    EventStatus? status,
    EventSource? source,
    bool? draft,
    List<OccurrenceOverride>? occurrences,
    DateTime? updatedAt,
    Map<String, Object?>? extraFields,
  }) => CalendarEvent(
    id: id,
    schemaVersion: schemaVersion,
    title: title ?? this.title,
    notes: clearNotes ? null : (notes ?? this.notes),
    start: start ?? this.start,
    end: clearEnd ? null : (end ?? this.end),
    rrule: clearRrule ? null : (rrule ?? this.rrule),
    reminders: reminders ?? this.reminders,
    owner: clearOwner ? null : (owner ?? this.owner),
    status: status ?? this.status,
    source: source ?? this.source,
    draft: draft ?? this.draft,
    occurrences: occurrences ?? this.occurrences,
    updatedAt: updatedAt ?? this.updatedAt,
    extraFields: extraFields ?? this.extraFields,
    rawKnownValues: rawKnownValues,
    unreadableEntries: unreadableEntries,
  );

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.id == id &&
      other.schemaVersion == schemaVersion &&
      other.title == title &&
      other.notes == notes &&
      other.start == start &&
      other.end == end &&
      other.rrule == rrule &&
      _listEq(other.reminders, reminders) &&
      other.owner == owner &&
      other.status == status &&
      other.source == source &&
      other.draft == draft &&
      _listEq(other.occurrences, occurrences) &&
      other.updatedAt.isAtSameMomentAs(updatedAt) &&
      _jsonEq(other.extraFields, extraFields) &&
      _jsonEq(other.rawKnownValues, rawKnownValues) &&
      _jsonEq(other.unreadableEntries, unreadableEntries);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    start,
    end,
    rrule,
    Object.hashAll(reminders),
    owner,
    status,
    source,
    draft,
    Object.hashAll(occurrences),
    updatedAt.microsecondsSinceEpoch,
  );
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
