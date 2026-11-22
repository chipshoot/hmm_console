import 'dart:convert';

import 'offset_date_time.dart';

enum ActivityIntensity { light, moderate, vigorous }

enum ActivitySource { manual, appleHealth, assistant }

bool _jsonEq(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

/// A named number with an explicit unit (v1: `distance` in `km` or `mi`).
class ActivityMeasurement {
  const ActivityMeasurement({
    required this.name,
    required this.value,
    required this.unit,
    this.extraFields = const {},
  });

  final String name;
  final double value;
  final String unit;

  /// Unknown keys of this measurement, written back.
  final Map<String, Object?> extraFields;

  ActivityMeasurement copyWith({String? name, double? value, String? unit}) =>
      ActivityMeasurement(
        name: name ?? this.name,
        value: value ?? this.value,
        unit: unit ?? this.unit,
        extraFields: extraFields,
      );

  @override
  bool operator ==(Object other) =>
      other is ActivityMeasurement &&
      other.name == name &&
      other.value == value &&
      other.unit == unit &&
      _jsonEq(other.extraFields, extraFields);

  @override
  int get hashCode => Object.hash(name, value, unit);
}

/// A note this activity relates to. A link to a deleted note stays.
class ActivityLink {
  const ActivityLink({
    required this.noteUuid,
    this.role,
    this.extraFields = const {},
  });

  final String noteUuid;
  final String? role;
  final Map<String, Object?> extraFields;

  @override
  bool operator ==(Object other) =>
      other is ActivityLink &&
      other.noteUuid == noteUuid &&
      other.role == role &&
      _jsonEq(other.extraFields, extraFields);

  @override
  int get hashCode => Object.hash(noteUuid, role);
}

/// One calendar occurrence this activity fulfils.
class PlannedEventRef {
  const PlannedEventRef({
    required this.eventId,
    required this.occurrence,
    this.at,
    this.extraFields = const {},
  });

  final String eventId;

  /// The calendar's own occurrence key (`EventTime.wireKey`).
  final String occurrence;
  final OffsetDateTime? at;
  final Map<String, Object?> extraFields;

  @override
  bool operator ==(Object other) =>
      other is PlannedEventRef &&
      other.eventId == eventId &&
      other.occurrence == occurrence &&
      other.at == at &&
      _jsonEq(other.extraFields, extraFields);

  @override
  int get hashCode => Object.hash(eventId, occurrence, at);
}

class Activity {
  const Activity({
    required this.id,
    required this.kind,
    required this.start,
    required this.durationMinutes,
    this.intensity,
    this.measurements = const [],
    this.links = const [],
    this.plannedEvent,
    this.notes,
    this.details = const {},
    this.source = ActivitySource.manual,
    this.draft = false,
    this.updatedAt,
    this.schemaVersion = 1,
    this.extraFields = const {},
    this.rawKnownValues = const {},
    this.unreadableEntries = const {},
  });

  final String id;
  final String kind;
  final OffsetDateTime start;
  final int durationMinutes;
  final ActivityIntensity? intensity;
  final List<ActivityMeasurement> measurements;
  final List<ActivityLink> links;
  final PlannedEventRef? plannedEvent;
  final String? notes;

  /// Per-area sections keyed by area id; kept untouched.
  final Map<String, Object?> details;
  final ActivitySource source;
  final bool draft;
  final DateTime? updatedAt;
  final int schemaVersion;

  /// Unknown top-level keys, written back.
  final Map<String, Object?> extraFields;

  /// Wrong-typed known values, written back while the typed field still
  /// holds the default it decoded to.
  final Map<String, Object?> rawKnownValues;

  /// Undecodable list entries (`measurements`, `links`), re-emitted.
  final Map<String, List<Object?>> unreadableEntries;

  /// The kind's area: the part before the first `.`.
  String get area {
    final i = kind.indexOf('.');
    return i < 0 ? kind : kind.substring(0, i);
  }

  Activity copyWith({
    String? kind,
    OffsetDateTime? start,
    int? durationMinutes,
    ActivityIntensity? intensity,
    bool clearIntensity = false,
    List<ActivityMeasurement>? measurements,
    List<ActivityLink>? links,
    PlannedEventRef? plannedEvent,
    bool clearPlannedEvent = false,
    String? notes,
    bool clearNotes = false,
    Map<String, Object?>? details,
    ActivitySource? source,
    bool? draft,
    DateTime? updatedAt,
  }) => Activity(
    id: id,
    kind: kind ?? this.kind,
    start: start ?? this.start,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    intensity: clearIntensity ? null : intensity ?? this.intensity,
    measurements: measurements ?? this.measurements,
    links: links ?? this.links,
    plannedEvent: clearPlannedEvent ? null : plannedEvent ?? this.plannedEvent,
    notes: clearNotes ? null : notes ?? this.notes,
    details: details ?? this.details,
    source: source ?? this.source,
    draft: draft ?? this.draft,
    updatedAt: updatedAt ?? this.updatedAt,
    schemaVersion: schemaVersion,
    extraFields: extraFields,
    rawKnownValues: rawKnownValues,
    unreadableEntries: unreadableEntries,
  );
}
