import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/local/local_hmm_note_repository.dart';
import '../../../core/util/uuid.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../calendar/states/calendar_providers.dart';
import '../../calendar/states/event_edit_state.dart' show eventTimeFromWireKey;
import '../domain/activity.dart';
import '../domain/activity_kind.dart';
import '../domain/offset_date_time.dart';
import 'activity_kinds_provider.dart';
import 'activity_list_state.dart';
import 'activity_providers.dart';
import 'planned_sessions.dart';

/// Per-device prefs key: the most recently saved kinds, newest first.
const kActivityRecentKindsKey = 'activity.recentKinds';

/// How many recent kinds are remembered.
const kActivityRecentKindsMax = 5;

/// The kind a first-run device starts with.
const kActivityFirstKind = 'health.walk';

/// The measurement name the form edits.
const kActivityDistance = 'distance';

/// The link role a note picked for an activity of [area] gets.
String? activityLinkRole(String area) => switch (area) {
  'reading' => 'book',
  'development' => 'project',
  'health' => 'meal',
  _ => null,
};

/// The activity asked for is absent or deleted.
class ActivityMissing implements Exception {
  const ActivityMissing(this.id);

  final String id;

  @override
  String toString() => 'ActivityMissing($id)';
}

/// The form fields; editing applies only the ones the user touched.
enum ActivityField {
  kind,
  duration,
  ended,
  intensity,
  distance,
  link,
  notes,
  planned,
}

/// The activity form. [original] is null for a new entry.
@immutable
class ActivityEditState {
  const ActivityEditState({
    required this.original,
    required this.id,
    required this.kindId,
    required this.isUnknownKind,
    required this.durationMinutes,
    required this.ended,
    required this.intensity,
    required this.distance,
    required this.distanceUnit,
    required this.link,
    required this.linkTitle,
    required this.linkRemoved,
    required this.notes,
    required this.planned,
    required this.recentKinds,
    required this.now,
    required this.touched,
    this.plannedMarkFailed = false,
    this.startFromPlanned = false,
  });

  final Activity? original;
  final String id;
  final String? kindId;

  /// The stored kind is not in the registry (written by a newer build).
  final bool isUnknownKind;
  final int? durationMinutes;

  /// When the activity ended, as wall-clock fields: device-local for a new
  /// entry; for an existing one, the wall time at the entry's recorded
  /// offset (`original.start.offset`), the time its list row shows.
  final DateTime ended;
  final ActivityIntensity? intensity;
  final double? distance;

  /// The stored distance unit; null until set (the screen picks the
  /// device's default).
  final String? distanceUnit;

  /// The first link (the one the form shows).
  final ActivityLink? link;

  /// The linked note's title, when it still exists.
  final String? linkTitle;

  /// The linked note is gone or deleted; the link itself is kept.
  final bool linkRemoved;
  final String? notes;
  final PlannedEventRef? planned;

  /// Known kinds, most recent first.
  final List<String> recentKinds;

  /// The clock at the last change, for the "ended in the future" check.
  final DateTime now;
  final Set<ActivityField> touched;

  /// The last save stored the activity but could not mark its planned
  /// occurrence done in the calendar.
  final bool plannedMarkFailed;

  /// "Ended" was last set by picking a planned session, so a duration
  /// change keeps the session's start and moves "ended".
  final bool startFromPlanned;

  bool get isNew => original == null;

  bool get endedInFuture => _instantOf(ended).isAfter(now.toUtc());

  /// The UTC instant of the wall-clock fields [wall] (see [ended]).
  DateTime _instantOf(DateTime wall) {
    final o = original;
    if (o == null) return wall.toUtc();
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    ).subtract(o.start.offset);
  }

  /// The wall-clock fields of [instant] (see [ended]).
  DateTime _wallOf(DateTime instant) {
    final o = original;
    if (o == null) return instant.toLocal();
    final w = instant.toUtc().add(o.start.offset);
    return DateTime(w.year, w.month, w.day, w.hour, w.minute, w.second);
  }

  /// [instant] with the form's offset: the device's for a new entry, the
  /// recorded one for an existing entry.
  OffsetDateTime _at(DateTime instant) {
    final o = original;
    if (o == null) return OffsetDateTime.fromLocal(instant.toLocal());
    return OffsetDateTime(instant.toUtc(), o.start.offset);
  }

  bool get durationValid {
    final d = durationMinutes;
    return d != null && d >= 1 && d <= 1440;
  }

  bool get canSave => kindId != null && durationValid && !endedInFuture;

  /// Whether `start` follows `ended`: always for a new entry; for an
  /// existing one only once the user moves "ended" (until then the stored
  /// start, with its recorded offset, is kept).
  bool get _endedAnchors => isNew || touched.contains(ActivityField.ended);

  /// `ended − duration` (in the form's offset, see [_at]), or the stored
  /// start (see [_endedAnchors]).
  OffsetDateTime get start {
    if (!_endedAnchors) return original!.start;
    return _at(
      _instantOf(ended).subtract(Duration(minutes: durationMinutes ?? 0)),
    );
  }

  ActivityEditState _copy({
    String? kindId,
    int? durationMinutes,
    bool clearDuration = false,
    DateTime? ended,
    ActivityIntensity? intensity,
    bool clearIntensity = false,
    double? distance,
    bool clearDistance = false,
    String? distanceUnit,
    ActivityLink? link,
    bool clearLink = false,
    String? linkTitle,
    bool? linkRemoved,
    String? notes,
    PlannedEventRef? planned,
    bool clearPlanned = false,
    required DateTime now,
    ActivityField? touch,
    bool? plannedMarkFailed,
    bool? startFromPlanned,
  }) => ActivityEditState(
    original: original,
    id: id,
    kindId: kindId ?? this.kindId,
    isUnknownKind: isUnknownKind,
    durationMinutes: clearDuration
        ? null
        : durationMinutes ?? this.durationMinutes,
    ended: ended ?? this.ended,
    intensity: clearIntensity ? null : intensity ?? this.intensity,
    distance: clearDistance ? null : distance ?? this.distance,
    distanceUnit: distanceUnit ?? this.distanceUnit,
    link: clearLink ? null : link ?? this.link,
    linkTitle: clearLink ? null : linkTitle ?? this.linkTitle,
    linkRemoved: clearLink ? false : linkRemoved ?? this.linkRemoved,
    notes: notes ?? this.notes,
    planned: clearPlanned ? null : planned ?? this.planned,
    recentKinds: recentKinds,
    now: now,
    touched: touch == null ? touched : {...touched, touch},
    plannedMarkFailed: plannedMarkFailed ?? this.plannedMarkFailed,
    startFromPlanned: startFromPlanned ?? this.startFromPlanned,
  );
}

/// Loads a new or existing activity into an editable form and saves it.
/// For an existing entry only touched fields are written, via `copyWith`
/// on the decoded activity, so an unknown kind, unknown keys, `details`,
/// `source` and `draft` survive an edit by this build.
class ActivityEditNotifier extends AsyncNotifier<ActivityEditState> {
  ActivityEditNotifier(this.activityId);

  /// Null for a new entry.
  final String? activityId;

  DateTime _now() {
    final t = ref.read(activityClockProvider)();
    // Whole minutes: the pickers and the stored start have no seconds.
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  ActivityKindRegistry get _kinds => ref.read(activityKindRegistryProvider);

  @override
  Future<ActivityEditState> build() async {
    final repo = ref.watch(activityRepositoryProvider);
    final kinds = _kinds;
    final now = _now();
    final recent = await _readRecentKinds(kinds);

    if (activityId == null) {
      final kindId = recent.isEmpty ? kActivityFirstKind : recent.first;
      return ActivityEditState(
        original: null,
        id: generateUuid(),
        kindId: kindId,
        isUnknownKind: false,
        durationMinutes: null,
        ended: now,
        intensity: kinds.byId(kindId)?.defaultIntensity,
        distance: null,
        distanceUnit: null,
        link: null,
        linkTitle: null,
        linkRemoved: false,
        notes: null,
        planned: null,
        recentKinds: recent,
        now: now,
        touched: const {},
      );
    }

    final a = await repo.getActivity(activityId!);
    if (a == null) throw ActivityMissing(activityId!);
    final dist = a.measurements
        .where((m) => m.name == kActivityDistance)
        .firstOrNull;
    final link = a.links.firstOrNull;
    String? title;
    var removed = false;
    if (link != null) {
      try {
        final n = await ref
            .read(localHmmNoteRepositoryProvider)
            .getNoteByUuid(link.noteUuid);
        if (n == null || n.deletedAt != null) {
          removed = true;
        } else {
          title = n.subject.trim();
        }
      } catch (e) {
        // The row then shows the note's id instead of a title.
        debugPrint('activityEdit: note lookup failed (${e.runtimeType})');
      }
    }
    return ActivityEditState(
      original: a,
      id: a.id,
      kindId: a.kind,
      isUnknownKind: kinds.byId(a.kind) == null,
      durationMinutes: a.durationMinutes,
      ended: _wallFields(a.start.wall, a.durationMinutes),
      intensity: a.intensity,
      distance: dist?.value,
      distanceUnit: dist?.unit,
      link: link,
      linkTitle: title,
      linkRemoved: removed,
      notes: a.notes,
      planned: a.plannedEvent,
      recentKinds: recent,
      now: now,
      touched: const {},
    );
  }

  Future<List<String>> _readRecentKinds(ActivityKindRegistry kinds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return [
        for (final k in prefs.getStringList(kActivityRecentKindsKey) ?? [])
          if (kinds.byId(k) != null) k,
      ];
    } catch (e) {
      // Type only. The form falls back to the first-run kind.
      debugPrint('activityEdit: recent kinds unreadable (${e.runtimeType})');
      return const [];
    }
  }

  void _update(
    ActivityEditState Function(ActivityEditState s, DateTime now) f,
  ) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(f(s, _now()));
  }

  void setKind(String kindId) => _update((s, now) {
    final kind = _kinds.byId(kindId);
    // A picked intensity stays; otherwise follow the new kind's default.
    final picked =
        s.touched.contains(ActivityField.intensity) ||
        (!s.isNew && s.original!.intensity != null);
    final next = s._copy(kindId: kindId, now: now, touch: ActivityField.kind);
    if (picked || kind == null) return next;
    return kind.defaultIntensity == null
        ? next._copy(clearIntensity: true, now: now)
        : next._copy(intensity: kind.defaultIntensity, now: now);
  });

  void setDuration(int? minutes) => _update((s, now) {
    final next = minutes == null
        ? s._copy(clearDuration: true, now: now, touch: ActivityField.duration)
        : s._copy(
            durationMinutes: minutes,
            now: now,
            touch: ActivityField.duration,
          );
    // A picked session's start stays; the end moves.
    if (s.startFromPlanned) {
      return next._copy(
        ended: s._wallOf(s.start.utc.add(Duration(minutes: minutes ?? 0))),
        now: now,
      );
    }
    // While the stored start anchors an existing entry, the end moves.
    if (next._endedAnchors || minutes == null) return next;
    return next._copy(
      ended: _wallFields(s.original!.start.wall, minutes),
      now: now,
    );
  });

  void setEnded(DateTime ended) => _update(
    (s, now) => s._copy(
      ended: ended,
      now: now,
      touch: ActivityField.ended,
      startFromPlanned: false,
    ),
  );

  void setIntensity(ActivityIntensity? intensity) => _update(
    (s, now) => intensity == null
        ? s._copy(
            clearIntensity: true,
            now: now,
            touch: ActivityField.intensity,
          )
        : s._copy(
            intensity: intensity,
            now: now,
            touch: ActivityField.intensity,
          ),
  );

  /// [value] null (or not positive) clears the distance.
  void setDistance(double? value, String unit) => _update(
    (s, now) => value == null || value <= 0
        ? s._copy(
            clearDistance: true,
            distanceUnit: unit,
            now: now,
            touch: ActivityField.distance,
          )
        : s._copy(
            distance: value,
            distanceUnit: unit,
            now: now,
            touch: ActivityField.distance,
          ),
  );

  /// Links the note; its role follows the current kind's area.
  void setLink(String noteUuid, String title) => _update((s, now) {
    final area = s.kindId == null ? '' : _areaOf(s.kindId!);
    return s._copy(
      link: ActivityLink(noteUuid: noteUuid, role: activityLinkRole(area)),
      linkTitle: title,
      linkRemoved: false,
      now: now,
      touch: ActivityField.link,
    );
  });

  void clearLink() => _update(
    (s, now) => s._copy(clearLink: true, now: now, touch: ActivityField.link),
  );

  void setNotes(String notes) => _update(
    (s, now) => s._copy(notes: notes, now: now, touch: ActivityField.notes),
  );

  /// The calendar occurrence this activity fulfils (null clears it).
  void setPlanned(PlannedEventRef? planned) => _update(
    (s, now) => planned == null
        ? s._copy(clearPlanned: true, now: now, touch: ActivityField.planned)
        : s._copy(planned: planned, now: now, touch: ActivityField.planned),
  );

  /// Links [p] and moves "ended" so the start is the occurrence's start
  /// (its moved time when moved), keeping the duration; with no duration
  /// yet, ended = the occurrence's start.
  void pickPlannedSession(PlannedSession p) => _update((s, now) {
    final start = p.occurrence.start.toLocal();
    final ended = s._wallOf(
      p.occurrence.start.add(Duration(minutes: s.durationMinutes ?? 0)),
    );
    return s
        ._copy(
          ended: ended,
          startFromPlanned: true,
          planned: PlannedEventRef(
            eventId: p.event.id,
            occurrence: p.occurrence.originalStart.wireKey,
            at: OffsetDateTime.fromLocal(start),
          ),
          now: now,
          touch: ActivityField.ended,
        )
        ._copy(now: now, touch: ActivityField.planned);
  });

  /// [wall] (UTC-flagged wall fields) plus [minutes], as local-flagged
  /// wall fields (see [ActivityEditState.ended]).
  static DateTime _wallFields(DateTime wall, int minutes) {
    final w = wall.add(Duration(minutes: minutes));
    return DateTime(w.year, w.month, w.day, w.hour, w.minute, w.second);
  }

  static String _areaOf(String kindId) {
    final i = kindId.indexOf('.');
    return i < 0 ? kindId : kindId.substring(0, i);
  }

  /// Writes the form; returns the saved activity. Throws [StateError] when
  /// the form cannot be saved.
  Future<Activity> save() async {
    final s0 = state.value;
    if (s0 == null) throw StateError('activity form not loaded');
    // Re-check against the clock now, not at the last change.
    final s = s0._copy(now: _now());
    if (!s.canSave) throw StateError('activity form incomplete');
    final repo = ref.read(activityRepositoryProvider);
    final saved = await repo.saveActivity(_build(s));
    await _rememberKind(saved.kind);
    final planned = s.planned;
    final linkChanged =
        planned != null &&
        (s.isNew ||
            (s.touched.contains(ActivityField.planned) &&
                planned != s.original!.plannedEvent));
    final failed = linkChanged && !await _markDone(planned);
    final after = state.value;
    if (after != null) {
      state = AsyncData(after._copy(now: _now(), plannedMarkFailed: failed));
    }
    return saved;
  }

  /// Marks [p]'s occurrence done, keeping the rest of its override (a moved
  /// occurrence stays moved). False when the calendar could not be updated;
  /// the activity is saved either way.
  Future<bool> _markDone(PlannedEventRef p) async {
    try {
      final cal = ref.read(calendarRepositoryProvider);
      final e = await cal.getEvent(p.eventId);
      if (e == null) return false;
      OccurrenceOverride? existing;
      for (final o in e.occurrences) {
        if (o.originalStart.wireKey == p.occurrence) existing = o;
      }
      final original =
          existing?.originalStart ?? eventTimeFromWireKey(p.occurrence, e);
      if (original == null) return false;
      await cal.setOccurrence(
        p.eventId,
        existing?.copyWith(status: OccurrenceStatus.done) ??
            OccurrenceOverride(
              originalStart: original,
              status: OccurrenceStatus.done,
            ),
      );
      return true;
    } catch (e) {
      // Type only: the error text can quote stored data.
      debugPrint('activityEdit: planned mark failed (${e.runtimeType})');
      return false;
    }
  }

  Activity _build(ActivityEditState s) {
    final kind = _kinds.byId(s.kindId!);
    final notes = s.notes?.trim();
    final original = s.original;
    if (original == null) {
      return Activity(
        id: s.id,
        kind: s.kindId!,
        start: s.start,
        durationMinutes: s.durationMinutes!,
        intensity: s.intensity,
        measurements: [
          if ((kind?.offersDistance ?? false) && s.distance != null)
            ActivityMeasurement(
              name: kActivityDistance,
              value: s.distance!,
              unit: s.distanceUnit!,
            ),
        ],
        links: [?_linkForSave(s)],
        plannedEvent: s.planned,
        notes: notes == null || notes.isEmpty ? null : notes,
        source: ActivitySource.manual,
      );
    }

    bool t(ActivityField f) => s.touched.contains(f);
    List<ActivityMeasurement>? measurements;
    if (t(ActivityField.kind) || t(ActivityField.distance)) {
      // An unknown kind keeps what it has.
      final offers = kind?.offersDistance ?? true;
      final others = [
        for (final m in original.measurements)
          if (m.name != kActivityDistance) m,
      ];
      final old = original.measurements
          .where((m) => m.name == kActivityDistance)
          .firstOrNull;
      if (!offers) {
        measurements = others;
      } else if (t(ActivityField.distance)) {
        final updated = s.distance == null
            ? null
            : (old ??
                      ActivityMeasurement(
                        name: kActivityDistance,
                        value: s.distance!,
                        unit: s.distanceUnit!,
                      ))
                  .copyWith(value: s.distance, unit: s.distanceUnit);
        // Keep the distance where it was in the list.
        final at = original.measurements.indexWhere(
          (m) => m.name == kActivityDistance,
        );
        measurements = [...others];
        if (updated != null) {
          measurements.insert(at < 0 ? others.length : at, updated);
        }
      }
    }

    List<ActivityLink>? links;
    if (t(ActivityField.link)) {
      final rest = original.links.skip(1);
      links = [?_linkForSave(s), ...rest];
    }

    return original.copyWith(
      kind: t(ActivityField.kind) ? s.kindId : null,
      durationMinutes: t(ActivityField.duration) ? s.durationMinutes : null,
      start: t(ActivityField.ended) ? s.start : null,
      intensity: t(ActivityField.intensity) || t(ActivityField.kind)
          ? s.intensity
          : null,
      clearIntensity:
          (t(ActivityField.intensity) || t(ActivityField.kind)) &&
          s.intensity == null,
      measurements: measurements,
      links: links,
      plannedEvent: t(ActivityField.planned) ? s.planned : null,
      clearPlannedEvent: t(ActivityField.planned) && s.planned == null,
      notes: t(ActivityField.notes) && notes != null && notes.isNotEmpty
          ? notes
          : null,
      clearNotes: t(ActivityField.notes) && (notes == null || notes.isEmpty),
    );
  }

  /// The form's link with its role recomputed from the final kind's area:
  /// the link is new or was touched, so the role follows what was saved.
  ActivityLink? _linkForSave(ActivityEditState s) {
    final link = s.link;
    if (link == null) return null;
    return ActivityLink(
      noteUuid: link.noteUuid,
      role: activityLinkRole(_areaOf(s.kindId!)),
      extraFields: link.extraFields,
    );
  }

  Future<void> _rememberKind(String kindId) async {
    if (_kinds.byId(kindId) == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getStringList(kActivityRecentKindsKey) ?? const [];
      await prefs.setStringList(
        kActivityRecentKindsKey,
        [
          kindId,
          ...old.where((k) => k != kindId),
        ].take(kActivityRecentKindsMax).toList(),
      );
    } catch (e) {
      // Saved already; only the recent-kinds order is lost.
      debugPrint('activityEdit: recent kinds not saved (${e.runtimeType})');
    }
  }
}

/// The activity form, keyed by activity id (null = new entry).
final activityEditProvider = AsyncNotifierProvider.autoDispose
    .family<ActivityEditNotifier, ActivityEditState, String?>(
      ActivityEditNotifier.new,
    );
