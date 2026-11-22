import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local/local_hmm_note_repository.dart';
import '../contract/i_activity_repository.dart';
import '../domain/activity.dart';
import 'activity_providers.dart';

/// How far back the list reaches at first, and how much each "Load earlier"
/// adds.
const kActivityListSpan = Duration(days: 30);

/// The device's clock (local time). Tests pin it.
final activityClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The entries recorded on one wall-clock date.
class ActivityDay {
  const ActivityDay(this.date, this.entries);

  /// The entries' own recorded date (`OffsetDateTime.wallDate`).
  final DateTime date;

  /// Newest first.
  final List<Activity> entries;
}

class ActivityListData {
  const ActivityListData({
    required this.days,
    required this.today,
    required this.noteTitles,
  });

  /// Newest date first.
  final List<ActivityDay> days;

  /// The device's current local date, as `DateTime.utc(y, m, d)` so it
  /// compares directly with [ActivityDay.date].
  final DateTime today;

  /// Linked note uuid -> title, for live linked notes only.
  final Map<String, String> noteTitles;

  bool get isEmpty => days.isEmpty;

  /// The first linked note's title, when that note still exists.
  String? noteTitleFor(Activity a) =>
      a.links.isEmpty ? null : noteTitles[a.links.first.noteUuid];
}

/// Entries started within the window (30 days, extended by [loadEarlier]),
/// grouped by each entry's own recorded date, not the device zone: an
/// entry logged at 23:30 in New York stays on that date when read in
/// Beijing. Keyed by area filter (null = all). Re-reads on every
/// repository change; in cloud API mode the build fails with the
/// repository's error (`isActivityCloudApiUnavailable`).
class ActivityListNotifier extends AsyncNotifier<ActivityListData> {
  ActivityListNotifier(this.area);

  final String? area;
  Duration _span = kActivityListSpan;
  int _generation = 0;

  @override
  Future<ActivityListData> build() async {
    final repo = ref.watch(activityRepositoryProvider);
    // changes() never emits its current snapshot, so this cannot loop.
    final sub = repo.changes().listen(
      (_) => unawaited(_reload()),
      onError: (Object e) =>
          debugPrint('activityList: changes failed (${e.runtimeType})'),
    );
    ref.onDispose(sub.cancel);
    final gen = ++_generation;
    final data = await _load(repo);
    // A change-triggered reload that finished first is newer: keep it.
    if (gen != _generation) return state.value ?? data;
    return data;
  }

  /// Reaches another 30 days further back.
  Future<void> loadEarlier() {
    _span += kActivityListSpan;
    return _reload();
  }

  Future<void> _reload() async {
    if (!ref.mounted) return;
    final repo = ref.read(activityRepositoryProvider);
    final gen = ++_generation;
    final next = await AsyncValue.guard(() => _load(repo));
    // A later reload superseded this one: keep its result.
    if (!ref.mounted || gen != _generation) return;
    state = next;
  }

  Future<ActivityListData> _load(IActivityRepository repo) async {
    final now = ref.read(activityClockProvider)();
    final notes = ref.read(localHmmNoteRepositoryProvider);
    // No upper bound: an entry whose start is ahead of the device clock
    // (a skewed clock, or one logged in a zone ahead) still shows.
    final entries = await repo.activitiesBetween(
      now.toUtc().subtract(_span),
      DateTime.utc(9999),
      areas: area == null ? null : {area!},
    );

    final byDate = <DateTime, List<Activity>>{};
    for (final a in entries) {
      (byDate[a.start.wallDate] ??= []).add(a);
    }
    final dates = byDate.keys.toList()..sort((x, y) => y.compareTo(x));

    final titles = <String, String>{};
    final uuids = {
      for (final a in entries)
        if (a.links.isNotEmpty) a.links.first.noteUuid,
    };
    for (final uuid in uuids) {
      try {
        final n = await notes.getNoteByUuid(uuid);
        if (n != null && n.deletedAt == null && n.subject.trim().isNotEmpty) {
          titles[uuid] = n.subject.trim();
        }
      } catch (e) {
        // A missing title only shortens the summary.
        debugPrint('activityList: note title lookup failed (${e.runtimeType})');
      }
    }

    return ActivityListData(
      days: [for (final d in dates) ActivityDay(d, byDate[d]!)],
      today: DateTime.utc(now.year, now.month, now.day),
      noteTitles: titles,
    );
  }
}

final activityListProvider = AsyncNotifierProvider.autoDispose
    .family<ActivityListNotifier, ActivityListData, String?>(
      ActivityListNotifier.new,
    );
