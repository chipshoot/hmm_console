import 'dart:convert';

import '../../activity/domain/offset_date_time.dart';
import '../domain/glucose_reading.dart';
import '../domain/glucose_units.dart';

/// Thrown when a glucose note's JSON has no readable `takenAt` or `glucose`.
/// An unreadable reading is surfaced, never absent.
class GlucoseUnreadable implements Exception {
  const GlucoseUnreadable(this.id);

  final String id;

  @override
  String toString() => 'GlucoseUnreadable($id)';
}

/// `GlucoseReading` <-> the JSON stored as note content. Same safety rules
/// as `ActivityCodec`: unknown keys (top level, in `glucose` and in
/// `appleHealth`) are written back; known keys with the wrong type decode to
/// a default and the stored value is kept in `rawKnownValues`, written back
/// while the typed field still holds that default.
class GlucoseCodec {
  const GlucoseCodec._();

  static const schemaVersion = 1;

  static const _knownKeys = <String>{
    'schemaVersion',
    'id',
    'takenAt',
    'glucose',
    'context',
    'notes',
    'source',
    'appleHealth',
    'draft',
    'updatedAt',
  };
  static const _glucoseKeys = {'value', 'unit'};
  static const _appleKeys = {'sampleId', 'sourceName'};

  static GlucoseReading decode(String id, String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      throw GlucoseUnreadable(id);
    }
    if (decoded is! Map) throw GlucoseUnreadable(id);
    final m = decoded.cast<String, Object?>();
    final raw = <String, Object?>{};

    T? read<T>(String key) {
      final v = m[key];
      if (v == null) return null;
      if (v is T) return v as T;
      raw[key] = v;
      return null;
    }

    final takenAtJson = m['takenAt'];
    final takenAt = takenAtJson is String
        ? OffsetDateTime.tryParse(takenAtJson)
        : null;
    final g = m['glucose'];
    if (takenAt == null || g is! Map) throw GlucoseUnreadable(id);
    final gm = g.cast<String, Object?>();
    final unit = gm['unit'] is String
        ? GlucoseUnit.fromWire(gm['unit']! as String)
        : null;
    final gv = gm['value'];
    // An integral double (112.0, from another writer) reads as an int.
    final num? value = switch (gv) {
      int v => v,
      double v when v.isFinite && v == v.truncateToDouble() => v.toInt(),
      double v when v.isFinite => v,
      _ => null,
    };
    if (unit == null || value == null) throw GlucoseUnreadable(id);

    T? enumOf<T extends Enum>(String key, List<T> values) {
      final s = read<String>(key);
      if (s == null) return null;
      for (final v in values) {
        if (v.name == s) return v;
      }
      raw[key] = s;
      return null;
    }

    AppleHealthRef? apple;
    final appleJson = read<Map>('appleHealth');
    if (appleJson != null) {
      final a = appleJson.cast<String, Object?>();
      final sampleId = a['sampleId'];
      final sourceName = a['sourceName'];
      if (sampleId is String && (sourceName == null || sourceName is String)) {
        apple = AppleHealthRef(
          sampleId: sampleId,
          sourceName: sourceName as String?,
          extraFields: _extras(a, _appleKeys),
        );
      } else {
        raw['appleHealth'] = appleJson;
      }
    }

    DateTime? updatedAt;
    final u = read<String>('updatedAt');
    if (u != null) {
      updatedAt = DateTime.tryParse(u)?.toUtc();
      if (updatedAt == null) raw['updatedAt'] = u;
    }

    return GlucoseReading(
      id: id,
      schemaVersion: read<num>('schemaVersion')?.toInt() ?? schemaVersion,
      takenAt: takenAt,
      glucose: GlucoseValue(
        value,
        unit,
        extraFields: _extras(gm, _glucoseKeys),
      ),
      context: enumOf('context', GlucoseContext.values),
      notes: read<String>('notes') ?? '',
      source: enumOf('source', GlucoseSource.values) ?? GlucoseSource.manual,
      appleHealth: apple,
      draft: read<bool>('draft') ?? false,
      updatedAt: updatedAt,
      extraFields: _extras(m, _knownKeys),
      rawKnownValues: raw,
    );
  }

  static String encode(GlucoseReading r) {
    final raw = r.rawKnownValues;
    // The raw wrong-typed value wins while the typed field is still the
    // default it decoded to.
    Object? keep(String key, Object? typed, bool isDefault) =>
        isDefault && raw.containsKey(key) ? raw[key] : typed;

    final out = <String, Object?>{...r.extraFields};
    out['schemaVersion'] = keep(
      'schemaVersion',
      r.schemaVersion,
      r.schemaVersion == schemaVersion,
    );
    out['id'] = r.id;
    out['takenAt'] = r.takenAt.toIso();
    out['glucose'] = {
      ...r.glucose.extraFields,
      'value': r.glucose.value,
      'unit': r.glucose.unit.wire,
    };

    final context = keep('context', r.context?.wire, r.context == null);
    if (context != null) out['context'] = context;
    out['notes'] = keep('notes', r.notes, r.notes.isEmpty);
    out['source'] = keep(
      'source',
      r.source.name,
      r.source == GlucoseSource.manual,
    );

    if (raw.containsKey('appleHealth') && r.appleHealth == null) {
      out['appleHealth'] = raw['appleHealth'];
    } else if (r.appleHealth != null) {
      final a = r.appleHealth!;
      out['appleHealth'] = {
        ...a.extraFields,
        'sampleId': a.sampleId,
        if (a.sourceName != null) 'sourceName': a.sourceName,
      };
    }

    out['draft'] = keep('draft', r.draft, !r.draft);
    final updated = keep(
      'updatedAt',
      r.updatedAt == null ? null : _isoUtc(r.updatedAt!),
      r.updatedAt == null,
    );
    if (updated != null) out['updatedAt'] = updated;
    return jsonEncode(out);
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
