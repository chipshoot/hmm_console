import '../../activity/domain/offset_date_time.dart';
import 'glucose_units.dart';

enum GlucoseContext { fasting, beforeMeal, afterMeal, bedtime, other }

extension GlucoseContextWire on GlucoseContext {
  String get wire => name;
}

enum GlucoseSource { manual, appleHealth, assistant }

/// Where an imported reading came from in Apple Health.
class AppleHealthRef {
  const AppleHealthRef({
    required this.sampleId,
    this.sourceName,
    this.extraFields = const <String, Object?>{},
  });

  final String sampleId;
  final String? sourceName;

  /// Unknown keys of the stored object, written back.
  final Map<String, Object?> extraFields;

  @override
  bool operator ==(Object other) =>
      other is AppleHealthRef &&
      other.sampleId == sampleId &&
      other.sourceName == sourceName &&
      other.extraFields.toString() == extraFields.toString();

  @override
  int get hashCode => Object.hash(sampleId, sourceName);
}

class GlucoseReading {
  const GlucoseReading({
    required this.id,
    required this.takenAt,
    required this.glucose,
    this.context,
    this.notes = '',
    this.source = GlucoseSource.manual,
    this.appleHealth,
    this.draft = false,
    this.updatedAt,
    this.schemaVersion = 1,
    this.extraFields = const <String, Object?>{},
    this.rawKnownValues = const <String, Object?>{},
  });

  final String id;
  final OffsetDateTime takenAt;
  final GlucoseValue glucose;
  final GlucoseContext? context;
  final String notes;
  final GlucoseSource source;
  final AppleHealthRef? appleHealth;
  final bool draft;
  final DateTime? updatedAt;
  final int schemaVersion;

  /// Unknown top-level keys, written back.
  final Map<String, Object?> extraFields;

  /// Wrong-typed known values, written back while the typed field still
  /// holds the default it decoded to.
  final Map<String, Object?> rawKnownValues;

  GlucoseReading copyWith({
    OffsetDateTime? takenAt,
    GlucoseValue? glucose,
    GlucoseContext? context,
    bool clearContext = false,
    String? notes,
    GlucoseSource? source,
    AppleHealthRef? appleHealth,
    bool? draft,
    DateTime? updatedAt,
  }) => GlucoseReading(
    id: id,
    takenAt: takenAt ?? this.takenAt,
    glucose: glucose ?? this.glucose,
    context: clearContext ? null : context ?? this.context,
    notes: notes ?? this.notes,
    source: source ?? this.source,
    appleHealth: appleHealth ?? this.appleHealth,
    draft: draft ?? this.draft,
    updatedAt: updatedAt ?? this.updatedAt,
    schemaVersion: schemaVersion,
    extraFields: extraFields,
    rawKnownValues: rawKnownValues,
  );
}
