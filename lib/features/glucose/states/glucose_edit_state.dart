import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/uuid.dart';
import '../../activity/domain/offset_date_time.dart';
import '../domain/glucose_reading.dart';
import '../domain/glucose_units.dart';
import 'glucose_list_state.dart';
import 'glucose_providers.dart';
import 'glucose_settings_providers.dart';

/// The reading asked for is absent or deleted.
class GlucoseMissing implements Exception {
  const GlucoseMissing(this.id);

  final String id;

  @override
  String toString() => 'GlucoseMissing($id)';
}

/// The form fields; editing writes only the ones the user touched.
enum GlucoseField { value, time, context, notes }

/// The glucose form. [original] is null for a new entry.
@immutable
class GlucoseEditState {
  const GlucoseEditState({
    required this.original,
    required this.id,
    required this.unit,
    required this.value,
    required this.at,
    required this.context,
    required this.notes,
    required this.touched,
  });

  final GlucoseReading? original;
  final String id;
  final GlucoseUnit unit;

  /// The typed number, in [unit]; null when empty or not a number.
  final num? value;

  /// Wall-clock fields: device-local for a new entry; for an existing one
  /// the wall time at its recorded offset (the time its row shows).
  final DateTime at;
  final GlucoseContext? context;
  final String notes;
  final Set<GlucoseField> touched;

  bool get isNew => original == null;

  /// Value and time of an imported reading are read-only.
  bool get isImported => original?.source == GlucoseSource.appleHealth;

  /// A typed number that is outside the plausible bounds. An untouched
  /// stored value is never judged.
  bool get valueOutOfRange {
    final v = value;
    if (v == null || !touched.contains(GlucoseField.value)) return false;
    return !isValidTypedValue(GlucoseValue(v, unit));
  }

  bool get canSave {
    if (isImported) return true;
    if (value == null) return false;
    return !valueOutOfRange;
  }

  GlucoseEditState _copy({
    GlucoseUnit? unit,
    num? value,
    bool clearValue = false,
    DateTime? at,
    GlucoseContext? context,
    bool clearContext = false,
    String? notes,
    GlucoseField? touch,
  }) => GlucoseEditState(
    original: original,
    id: id,
    unit: unit ?? this.unit,
    value: clearValue ? null : value ?? this.value,
    at: at ?? this.at,
    context: clearContext ? null : context ?? this.context,
    notes: notes ?? this.notes,
    touched: touch == null ? touched : {...touched, touch},
  );
}

/// Loads a new or existing reading into an editable form and saves it. An
/// existing reading is rebuilt with `copyWith` on the decoded reading and
/// only touched fields are written, so unknown keys, `source`, `draft` and
/// an imported reading's value, time and `appleHealth` survive.
class GlucoseEditNotifier extends AsyncNotifier<GlucoseEditState> {
  GlucoseEditNotifier(this.readingId);

  /// Null for a new entry.
  final String? readingId;

  DateTime _now() {
    final t = ref.read(glucoseClockProvider)();
    // Whole minutes: the pickers and the stored time have no seconds.
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  @override
  Future<GlucoseEditState> build() async {
    final repo = ref.watch(glucoseRepositoryProvider);
    if (readingId == null) {
      return GlucoseEditState(
        original: null,
        id: generateUuid(),
        // Read once: a later settings change must not reset typed input.
        unit: ref.read(glucoseDisplayUnitProvider),
        value: null,
        at: _now(),
        context: null,
        notes: '',
        touched: const {},
      );
    }
    final r = await repo.getReading(readingId!);
    if (r == null) throw GlucoseMissing(readingId!);
    final w = r.takenAt.wall;
    return GlucoseEditState(
      original: r,
      id: r.id,
      unit: r.glucose.unit,
      value: r.glucose.value,
      at: DateTime(w.year, w.month, w.day, w.hour, w.minute),
      context: r.context,
      notes: r.notes,
      touched: const {},
    );
  }

  void _update(GlucoseEditState Function(GlucoseEditState s) f) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(f(s));
  }

  /// [text] as typed: a comma counts as the decimal point.
  void setValueText(String text) => _update((s) {
    final n = num.tryParse(text.trim().replaceAll(',', '.'));
    return n == null
        ? s._copy(clearValue: true, touch: GlucoseField.value)
        : s._copy(value: n, touch: GlucoseField.value);
  });

  /// Switches the unit the typed number is read in. The number is kept.
  void setUnit(GlucoseUnit unit) =>
      _update((s) => s._copy(unit: unit, touch: GlucoseField.value));

  void setAt(DateTime at) =>
      _update((s) => s._copy(at: at, touch: GlucoseField.time));

  void setContext(GlucoseContext? context) => _update(
    (s) => context == null
        ? s._copy(clearContext: true, touch: GlucoseField.context)
        : s._copy(context: context, touch: GlucoseField.context),
  );

  void setNotes(String notes) =>
      _update((s) => s._copy(notes: notes, touch: GlucoseField.notes));

  GlucoseReading _build(GlucoseEditState s) {
    final o = s.original;
    if (o == null) {
      return GlucoseReading(
        id: s.id,
        takenAt: OffsetDateTime.fromLocal(s.at),
        glucose: GlucoseValue(s.value!, s.unit),
        context: s.context,
        notes: s.notes,
        source: GlucoseSource.manual,
      );
    }
    var r = o;
    if (!s.isImported) {
      if (s.touched.contains(GlucoseField.value)) {
        r = r.copyWith(
          glucose: GlucoseValue(
            s.value!,
            s.unit,
            extraFields: o.glucose.extraFields,
          ),
        );
      }
      if (s.touched.contains(GlucoseField.time)) {
        final wall = DateTime.utc(
          s.at.year,
          s.at.month,
          s.at.day,
          s.at.hour,
          s.at.minute,
        );
        r = r.copyWith(
          takenAt: OffsetDateTime(
            wall.subtract(o.takenAt.offset),
            o.takenAt.offset,
          ),
        );
      }
    }
    if (s.touched.contains(GlucoseField.context)) {
      r = s.context == null
          ? r.copyWith(clearContext: true)
          : r.copyWith(context: s.context);
    }
    if (s.touched.contains(GlucoseField.notes)) {
      r = r.copyWith(notes: s.notes);
    }
    return r;
  }

  /// Writes the form; returns the saved reading. Throws [StateError] when
  /// the form cannot be saved.
  Future<GlucoseReading> save() async {
    final s = state.value;
    if (s == null || !s.canSave) {
      throw StateError('The glucose form cannot be saved');
    }
    return ref.read(glucoseRepositoryProvider).saveReading(_build(s));
  }
}

final glucoseEditProvider = AsyncNotifierProvider.autoDispose
    .family<GlucoseEditNotifier, GlucoseEditState, String?>(
      GlucoseEditNotifier.new,
    );
