import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/glucose_errors.dart';
import '../contract/i_glucose_repository.dart';
import '../domain/glucose_reading.dart';
import 'glucose_list_state.dart' show glucoseClockProvider, kGlucoseListSpan;
import 'glucose_providers.dart';

/// The newest live reading within the list's span, for the dashboard tile;
/// null when there is none or in Cloud API mode (the tile tells those apart
/// by data mode). Refreshes on repository changes, at most one read at a
/// time: changes during a read are folded into one more read after it. A
/// failing change stream only stops refreshing.
class LastGlucoseReadingNotifier extends AsyncNotifier<GlucoseReading?> {
  bool _reloading = false;
  bool _reloadAgain = false;

  @override
  Future<GlucoseReading?> build() async {
    final IGlucoseRepository repo;
    try {
      repo = ref.watch(glucoseRepositoryProvider);
    } catch (e) {
      if (isGlucoseCloudApiUnavailable(e)) return null;
      rethrow;
    }
    final sub = repo.changes().listen(
      (_) => unawaited(_reload()),
      onError: (Object _) {},
    );
    ref.onDispose(sub.cancel);
    return _load(repo);
  }

  Future<void> _reload() async {
    if (_reloading) {
      _reloadAgain = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _reloadAgain = false;
        if (!ref.mounted) return;
        final repo = ref.read(glucoseRepositoryProvider);
        final next = await AsyncValue.guard(() => _load(repo));
        if (!ref.mounted) return;
        state = next;
      } while (_reloadAgain);
    } finally {
      _reloading = false;
    }
  }

  Future<GlucoseReading?> _load(IGlucoseRepository repo) async {
    final now = ref.read(glucoseClockProvider)().toUtc();
    // Readings are newest first; allow a day ahead for clock skew.
    final readings = await repo.readingsBetween(
      now.subtract(kGlucoseListSpan),
      now.add(const Duration(days: 1)),
    );
    return readings.isEmpty ? null : readings.first;
  }
}

final lastGlucoseReadingProvider =
    AsyncNotifierProvider<LastGlucoseReadingNotifier, GlucoseReading?>(
      LastGlucoseReadingNotifier.new,
    );
