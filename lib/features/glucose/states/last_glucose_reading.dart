import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/glucose_errors.dart';
import '../contract/i_glucose_repository.dart';
import '../domain/glucose_reading.dart';
import 'glucose_list_state.dart' show glucoseClockProvider, kGlucoseListSpan;
import 'glucose_providers.dart';

/// The newest live reading within the list's span, for the dashboard tile;
/// null when there is none or in Cloud API mode (the tile tells those apart
/// by data mode). Refreshes on repository changes; a failing change stream
/// only stops refreshing.
final lastGlucoseReadingProvider = FutureProvider<GlucoseReading?>((ref) async {
  final IGlucoseRepository repo;
  try {
    repo = ref.watch(glucoseRepositoryProvider);
  } catch (e) {
    if (isGlucoseCloudApiUnavailable(e)) return null;
    rethrow;
  }
  final sub = repo.changes().listen(
    (_) => ref.invalidateSelf(),
    onError: (Object _) {},
  );
  ref.onDispose(sub.cancel);
  final now = ref.read(glucoseClockProvider)().toUtc();
  // Readings are newest first; allow a day ahead for clock skew.
  final readings = await repo.readingsBetween(
    now.subtract(kGlucoseListSpan),
    now.add(const Duration(days: 1)),
  );
  return readings.isEmpty ? null : readings.first;
});
