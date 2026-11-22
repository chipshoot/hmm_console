import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/local/local_hmm_note_repository.dart';
import '../../../core/util/uuid.dart';
import '../domain/activity.dart';
import '../domain/activity_kind.dart';
import '../domain/offset_date_time.dart';
import 'activity_kinds_provider.dart';
import 'activity_list_state.dart';
import 'activity_providers.dart';

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
  });

  final Activity? original;
  final String id;
  final String? kindId;

  /// The stored kind is not in the registry (written by a newer build).
  final bool isUnknownKind;
  final int? durationMinutes;

  /// When the activity ended, device-local.
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

  bool get isNew => original == null;

  bool get endedInFuture => ended.isAfter(now);

  bool get durationValid {
    final d = durationMinutes;
    return d != null && d >= 1 && d <= 1440;
  }

  bool get canSave => kindId != null && durationValid && !endedInFuture;

  /// Whether `start` follows `ended`: always for a new entry; for an
  /// existing one only once the user moves "ended" (until then the stored
  /// start, with its recorded offset, is kept).
  bool get _endedAnchors => isNew || touched.contains(ActivityField.ended);

  /// `ended − duration` (device offset), or the stored start (see
  /// [_endedAnchors]).
  OffsetDateTime get start {
    if (!_endedAnchors) return original!.start;
    return OffsetDateTime.fromLocal(
      ended.subtract(Duration(minutes: durationMinutes ?? 0)),
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
      ended: a.start.utc.add(Duration(minutes: a.durationMinutes)).toLocal(),
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
    // While the stored start anchors an existing entry, the end moves.
    if (next._endedAnchors || minutes == null) return next;
    return next._copy(
      ended: s.original!.start.utc.add(Duration(minutes: minutes)).toLocal(),
      now: now,
    );
  });

  void setEnded(DateTime ended) => _update(
    (s, now) => s._copy(ended: ended, now: now, touch: ActivityField.ended),
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
    return saved;
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
        links: [?s.link],
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
      links = [?s.link, ...rest];
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
