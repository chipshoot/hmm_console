import '../domain/activity.dart';
import '../domain/offset_date_time.dart';

/// Thrown when an activity note's JSON has no readable `kind`, `start` or
/// `durationMinutes`. An unreadable activity is surfaced, never absent.
class ActivityUnreadable implements Exception {
  const ActivityUnreadable(this.id);

  final String id;

  @override
  String toString() => 'ActivityUnreadable($id)';
}

/// `Activity` <-> the JSON map stored as note content.
///
/// Same safety rules as `CalendarEventCodec`: unknown keys go to
/// `extraFields` (on the activity and each measurement, link and planned
/// event) and are written back; known keys with the wrong type decode to a
/// default and the stored value is kept in `rawKnownValues`, written back
/// while the typed field still holds that default; undecodable list entries
/// are kept in `unreadableEntries` and re-emitted.
class ActivityCodec {
  const ActivityCodec._();

  static const currentSchemaVersion = 1;

  static const _knownKeys = <String>{
    'schemaVersion',
    'id',
    'kind',
    'start',
    'durationMinutes',
    'intensity',
    'measurements',
    'links',
    'plannedEvent',
    'notes',
    'details',
    'source',
    'draft',
    'updatedAt',
  };
  static const _measurementKeys = {'name', 'value', 'unit'};
  static const _linkKeys = {'noteUuid', 'role'};
  static const _plannedKeys = {'eventId', 'occurrence', 'at'};

  static Activity decode(String id, Map<String, Object?> json) {
    final raw = <String, Object?>{};
    final unreadable = <String, List<Object?>>{};

    T? read<T>(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is T) return v as T;
      raw[key] = v;
      return null;
    }

    final kind = json['kind'];
    final startJson = json['start'];
    final duration = json['durationMinutes'];
    if (kind is! String || kind.isEmpty) throw ActivityUnreadable(id);
    final start = startJson is String
        ? OffsetDateTime.tryParse(startJson)
        : null;
    if (start == null || duration is! int) throw ActivityUnreadable(id);

    T? enumOf<T extends Enum>(String key, List<T> values) {
      final s = read<String>(key);
      if (s == null) return null;
      for (final v in values) {
        if (v.name == s) return v;
      }
      raw[key] = s;
      return null;
    }

    final measurements = <ActivityMeasurement>[];
    for (final e in read<List>('measurements') ?? const []) {
      try {
        final m = (e as Map).cast<String, Object?>();
        measurements.add(
          ActivityMeasurement(
            name: m['name']! as String,
            value: (m['value']! as num).toDouble(),
            unit: m['unit']! as String,
            extraFields: _extras(m, _measurementKeys),
          ),
        );
      } catch (_) {
        (unreadable['measurements'] ??= []).add(e);
      }
    }

    final links = <ActivityLink>[];
    for (final e in read<List>('links') ?? const []) {
      try {
        final m = (e as Map).cast<String, Object?>();
        final role = m['role'];
        if (role != null && role is! String) throw const FormatException();
        links.add(
          ActivityLink(
            noteUuid: m['noteUuid']! as String,
            role: role as String?,
            extraFields: _extras(m, _linkKeys),
          ),
        );
      } catch (_) {
        (unreadable['links'] ??= []).add(e);
      }
    }

    PlannedEventRef? planned;
    final plannedJson = read<Map>('plannedEvent');
    if (plannedJson != null) {
      try {
        final m = plannedJson.cast<String, Object?>();
        final at = m['at'];
        final parsedAt = at == null
            ? null
            : OffsetDateTime.tryParse(at as String);
        if (at != null && parsedAt == null) throw const FormatException();
        planned = PlannedEventRef(
          eventId: m['eventId']! as String,
          occurrence: m['occurrence']! as String,
          at: parsedAt,
          extraFields: _extras(m, _plannedKeys),
        );
      } catch (_) {
        raw['plannedEvent'] = json['plannedEvent'];
      }
    }

    DateTime? updatedAt;
    final u = read<String>('updatedAt');
    if (u != null) {
      updatedAt = DateTime.tryParse(u)?.toUtc();
      if (updatedAt == null) raw['updatedAt'] = u;
    }

    final detailsJson = read<Map>('details');

    return Activity(
      id: id,
      schemaVersion: read<num>('schemaVersion')?.toInt() ?? 1,
      kind: kind,
      start: start,
      durationMinutes: duration,
      intensity: enumOf('intensity', ActivityIntensity.values),
      measurements: measurements,
      links: links,
      plannedEvent: planned,
      notes: read<String>('notes'),
      details: detailsJson?.cast<String, Object?>() ?? const {},
      source: enumOf('source', ActivitySource.values) ?? ActivitySource.manual,
      draft: read<bool>('draft') ?? false,
      updatedAt: updatedAt,
      extraFields: _extras(json, _knownKeys),
      rawKnownValues: raw,
      unreadableEntries: unreadable,
    );
  }

  static Map<String, Object?> encode(Activity a) {
    final raw = a.rawKnownValues;
    // The raw wrong-typed value wins while the typed field is still the
    // default it decoded to.
    Object? keep(String key, Object? typed, bool isDefault) =>
        isDefault && raw.containsKey(key) ? raw[key] : typed;

    final out = <String, Object?>{...a.extraFields};
    out['schemaVersion'] = keep(
      'schemaVersion',
      a.schemaVersion,
      a.schemaVersion == 1,
    );
    out['id'] = a.id;
    out['kind'] = a.kind;
    out['start'] = a.start.toIso();
    out['durationMinutes'] = a.durationMinutes;

    final intensity = keep('intensity', a.intensity?.name, a.intensity == null);
    if (intensity != null) out['intensity'] = intensity;

    out['measurements'] =
        raw.containsKey('measurements') &&
            a.measurements.isEmpty &&
            a.unreadableEntries['measurements'] == null
        ? raw['measurements']
        : [
            for (final m in a.measurements)
              {
                ...m.extraFields,
                'name': m.name,
                'value': m.value,
                'unit': m.unit,
              },
            ...?a.unreadableEntries['measurements'],
          ];
    out['links'] =
        raw.containsKey('links') &&
            a.links.isEmpty &&
            a.unreadableEntries['links'] == null
        ? raw['links']
        : [
            for (final l in a.links)
              {
                ...l.extraFields,
                'noteUuid': l.noteUuid,
                if (l.role != null) 'role': l.role,
              },
            ...?a.unreadableEntries['links'],
          ];

    if (raw.containsKey('plannedEvent') && a.plannedEvent == null) {
      out['plannedEvent'] = raw['plannedEvent'];
    } else if (a.plannedEvent != null) {
      final p = a.plannedEvent!;
      out['plannedEvent'] = {
        ...p.extraFields,
        'eventId': p.eventId,
        'occurrence': p.occurrence,
        if (p.at != null) 'at': p.at!.toIso(),
      };
    }

    final notes = keep('notes', a.notes, a.notes == null);
    if (notes != null) out['notes'] = notes;

    out['details'] = keep('details', a.details, a.details.isEmpty);
    out['source'] = keep(
      'source',
      a.source.name,
      a.source == ActivitySource.manual,
    );
    out['draft'] = keep('draft', a.draft, !a.draft);

    final updated = keep(
      'updatedAt',
      a.updatedAt == null ? null : _isoUtc(a.updatedAt!),
      a.updatedAt == null,
    );
    if (updated != null) out['updatedAt'] = updated;
    return out;
  }

  /// UTC ISO 8601 with whole seconds and a `Z`.
  static String _isoUtc(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  static Map<String, Object?> _extras(
    Map<String, Object?> m,
    Set<String> known,
  ) => {
    for (final entry in m.entries)
      if (!known.contains(entry.key)) entry.key: entry.value,
  };
}
