import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/i_glucose_repository.dart';
import '../domain/glucose_reading.dart';
import 'glucose_providers.dart';

/// How far back the list reaches.
const kGlucoseListSpan = Duration(days: 90);

/// The device's clock (local time). Tests pin it.
final glucoseClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The readings taken on one wall-clock date.
class GlucoseDay {
  const GlucoseDay(this.date, this.readings);

  /// The readings' own recorded date (`OffsetDateTime.wallDate`).
  final DateTime date;

  /// Newest first.
  final List<GlucoseReading> readings;
}

class GlucoseListData {
  const GlucoseListData({required this.days, required this.today});

  /// Newest date first.
  final List<GlucoseDay> days;

  /// The device's current local date as `DateTime.utc(y, m, d)`, comparable
  /// with [GlucoseDay.date].
  final DateTime today;

  bool get isEmpty => days.isEmpty;
}

/// Readings of the last 90 days grouped by each reading's own recorded date
/// (not the device zone). Re-reads on every repository change; in cloud API
/// mode the build fails with the repository's error
/// (`isGlucoseCloudApiUnavailable`).
class GlucoseListNotifier extends AsyncNotifier<GlucoseListData> {
  int _generation = 0;

  @override
  Future<GlucoseListData> build() async {
    final repo = ref.watch(glucoseRepositoryProvider);
    // changes() never emits its current snapshot, so this cannot loop.
    final sub = repo.changes().listen(
      (_) => unawaited(_reload()),
      onError: (Object e) =>
          debugPrint('glucoseList: changes failed (${e.runtimeType})'),
    );
    ref.onDispose(sub.cancel);
    final gen = ++_generation;
    final data = await _load(repo);
    // A change-triggered reload that finished first is newer: keep it.
    if (gen != _generation) return state.value ?? data;
    return data;
  }

  Future<void> _reload() async {
    if (!ref.mounted) return;
    final repo = ref.read(glucoseRepositoryProvider);
    final gen = ++_generation;
    final next = await AsyncValue.guard(() => _load(repo));
    if (!ref.mounted || gen != _generation) return;
    state = next;
  }

  Future<GlucoseListData> _load(IGlucoseRepository repo) async {
    final now = ref.read(glucoseClockProvider)();
    // No upper bound: a reading ahead of the device clock still shows.
    final readings = await repo.readingsBetween(
      now.toUtc().subtract(kGlucoseListSpan),
      DateTime.utc(9999),
    );
    final byDate = <DateTime, List<GlucoseReading>>{};
    for (final r in readings) {
      (byDate[r.takenAt.wallDate] ??= []).add(r);
    }
    final dates = byDate.keys.toList()..sort((x, y) => y.compareTo(x));
    return GlucoseListData(
      days: [for (final d in dates) GlucoseDay(d, byDate[d]!)],
      today: DateTime.utc(now.year, now.month, now.day),
    );
  }
}

final glucoseListProvider =
    AsyncNotifierProvider.autoDispose<GlucoseListNotifier, GlucoseListData>(
      GlucoseListNotifier.new,
    );
