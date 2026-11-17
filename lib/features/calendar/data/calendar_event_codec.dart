import '../domain/calendar_event.dart';
import '../domain/event_time.dart';

/// Thrown when an event note's JSON has no readable `start` or `title`.
/// An unreadable event is surfaced, never treated as absent.
class CalendarEventUnreadable implements Exception {
  const CalendarEventUnreadable(this.id);

  final String id;

  @override
  String toString() => 'CalendarEventUnreadable($id)';
}

/// `CalendarEvent` <-> the JSON map stored as note content.
///
/// Same safety rules as `ContactCodec`: unknown keys go to `extraFields` (on
/// the event, each override, reminder and owner) and are written back;
/// known keys with the wrong type decode to a default and the stored value is
/// kept in `rawKnownValues`, written back while the typed field still holds
/// that default; undecodable list entries are kept in `unreadableEntries` and
/// re-emitted.
class CalendarEventCodec {
  const CalendarEventCodec._();

  static const currentSchemaVersion = 1;

  static const _knownKeys = <String>{
    'schemaVersion',
    'id',
    'title',
    'notes',
    'start',
    'end',
    'rrule',
    'reminders',
    'owner',
    'status',
    'source',
    'draft',
    'occurrences',
    'updatedAt',
  };
  static const _reminderKeys = {'minutesBefore', 'channel'};
  static const _ownerKeys = {'subsystem', 'noteUuid'};
  static const _overrideKeys = {'originalStart', 'status', 'movedTo'};

  static CalendarEvent decode(String id, Map<String, Object?> json) {
    final raw = <String, Object?>{};
    final unreadable = <String, List<Object?>>{};

    T? read<T>(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is T) return v as T;
      raw[key] = v;
      return null;
    }

    final title = json['title'];
    final startJson = json['start'];
    if (title is! String || startJson is! Map) {
      throw CalendarEventUnreadable(id);
    }
    final EventTime start;
    try {
      start = EventTime.fromWire(startJson);
    } catch (_) {
      throw CalendarEventUnreadable(id);
    }

    EventTime? end;
    final endJson = read<Map>('end');
    if (endJson != null) {
      try {
        end = EventTime.fromWire(endJson);
      } catch (_) {
        raw['end'] = json['end'];
      }
    }

    T enumOf<T extends Enum>(String key, List<T> values, T fallback) {
      final s = read<String>(key);
      if (s == null) return fallback;
      for (final v in values) {
        if (v.name == s) return v;
      }
      raw[key] = s;
      return fallback;
    }

    final reminders = <Reminder>[];
    for (final e in read<List>('reminders') ?? const []) {
      try {
        final m = (e as Map).cast<String, Object?>();
        reminders.add(
          Reminder(
            minutesBefore: (m['minutesBefore'] as num).toInt(),
            channel: ReminderChannel.values.byName(m['channel'] as String),
            extraFields: _extras(m, _reminderKeys),
          ),
        );
      } catch (_) {
        (unreadable['reminders'] ??= []).add(e);
      }
    }

    final occurrences = <OccurrenceOverride>[];
    for (final e in read<List>('occurrences') ?? const []) {
      try {
        final m = (e as Map).cast<String, Object?>();
        final moved = m['movedTo'];
        occurrences.add(
          OccurrenceOverride(
            originalStart: EventTime.fromWire(m['originalStart']! as Map),
            status: OccurrenceStatus.values.byName(m['status']! as String),
            movedTo: moved == null ? null : EventTime.fromWire(moved as Map),
            extraFields: _extras(m, _overrideKeys),
          ),
        );
      } catch (_) {
        (unreadable['occurrences'] ??= []).add(e);
      }
    }

    EventOwner? owner;
    final ownerJson = read<Map>('owner');
    if (ownerJson != null) {
      final m = ownerJson.cast<String, Object?>();
      if (m['subsystem'] is String && (m['noteUuid'] ?? '') is String) {
        owner = EventOwner(
          subsystem: m['subsystem']! as String,
          noteUuid: m['noteUuid'] as String?,
          extraFields: _extras(m, _ownerKeys),
        );
      } else {
        raw['owner'] = json['owner'];
      }
    }

    DateTime updatedAt;
    final u = read<String>('updatedAt');
    try {
      updatedAt = DateTime.parse(u!);
    } catch (_) {
      if (u != null) raw['updatedAt'] = u;
      updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    final schema = read<num>('schemaVersion')?.toInt() ?? 1;

    return CalendarEvent(
      id: id,
      schemaVersion: schema,
      title: title,
      notes: read<String>('notes'),
      start: start,
      end: end,
      rrule: read<String>('rrule'),
      reminders: reminders,
      owner: owner,
      status: enumOf('status', EventStatus.values, EventStatus.active),
      source: enumOf('source', EventSource.values, EventSource.manual),
      draft: read<bool>('draft') ?? false,
      occurrences: occurrences,
      updatedAt: updatedAt,
      extraFields: _extras(json, _knownKeys),
      rawKnownValues: raw,
      unreadableEntries: unreadable,
    );
  }

  static Map<String, Object?> encode(CalendarEvent e) {
    final raw = e.rawKnownValues;
    // The raw wrong-typed value wins while the typed field is still the
    // default it decoded to.
    Object? keep(String key, Object? typed, bool isDefault) =>
        isDefault && raw.containsKey(key) ? raw[key] : typed;

    final out = <String, Object?>{...e.extraFields};
    out['schemaVersion'] = keep(
      'schemaVersion',
      e.schemaVersion,
      e.schemaVersion == 1,
    );
    out['id'] = e.id;
    out['title'] = e.title;
    out['notes'] = keep('notes', e.notes, e.notes == null);
    out['start'] = e.start.toWire();
    out['end'] = raw.containsKey('end') && e.end == null
        ? raw['end']
        : e.end?.toWire();
    out['rrule'] = keep('rrule', e.rrule, e.rrule == null);
    out['reminders'] =
        raw.containsKey('reminders') &&
            e.reminders.isEmpty &&
            e.unreadableEntries['reminders'] == null
        ? raw['reminders']
        : [
            for (final r in e.reminders)
              {
                ...r.extraFields,
                'minutesBefore': r.minutesBefore,
                'channel': r.channel.name,
              },
            ...?e.unreadableEntries['reminders'],
          ];
    out['owner'] = raw.containsKey('owner') && e.owner == null
        ? raw['owner']
        : e.owner == null
        ? null
        : {
            ...e.owner!.extraFields,
            'subsystem': e.owner!.subsystem,
            'noteUuid': e.owner!.noteUuid,
          };
    out['status'] = keep(
      'status',
      e.status.name,
      e.status == EventStatus.active,
    );
    out['source'] = keep(
      'source',
      e.source.name,
      e.source == EventSource.manual,
    );
    out['draft'] = keep('draft', e.draft, !e.draft);
    out['occurrences'] =
        raw.containsKey('occurrences') &&
            e.occurrences.isEmpty &&
            e.unreadableEntries['occurrences'] == null
        ? raw['occurrences']
        : [
            for (final o in e.occurrences)
              {
                ...o.extraFields,
                'originalStart': o.originalStart.toWire(),
                'status': o.status.name,
                if (o.movedTo != null) 'movedTo': o.movedTo!.toWire(),
              },
            ...?e.unreadableEntries['occurrences'],
          ];
    out['updatedAt'] =
        raw.containsKey('updatedAt') && e.updatedAt.millisecondsSinceEpoch == 0
        ? raw['updatedAt']
        : _isoLocal(e.updatedAt);
    return out;
  }

  /// ISO 8601 with the device's offset at that instant.
  static String _isoLocal(DateTime t) {
    final local = t.toLocal();
    return isoWithOffset(local, local.timeZoneOffset);
  }

  static Map<String, Object?> _extras(
    Map<String, Object?> m,
    Set<String> known,
  ) => {
    for (final entry in m.entries)
      if (!known.contains(entry.key)) entry.key: entry.value,
  };
}
