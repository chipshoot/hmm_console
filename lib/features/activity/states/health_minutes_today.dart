import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/activity_errors.dart';
import '../contract/i_activity_repository.dart';
import '../domain/activity.dart';
import 'activity_list_state.dart' show activityClockProvider;
import 'activity_providers.dart';

/// Minutes of health activity whose recorded wall date is the same
/// year/month/day as [deviceToday] (an entry keeps its own date, so one
/// logged at 23:30-05:00 counts for that day wherever the device is).
int healthMinutesOn(List<Activity> entries, DateTime deviceToday) {
  var total = 0;
  for (final a in entries) {
    if (a.area != 'health') continue;
    final d = a.start.wallDate;
    if (d.year == deviceToday.year &&
        d.month == deviceToday.month &&
        d.day == deviceToday.day) {
      total += a.durationMinutes;
    }
  }
  return total;
}

/// Today's health minutes for the dashboard tile; null in Cloud API mode.
/// Reads two days back and one ahead by `start.utc` so any zone's wall date
/// for today falls inside the window, and recomputes on repository changes.
final healthMinutesTodayProvider = FutureProvider<int?>((ref) async {
  final IActivityRepository repo;
  try {
    repo = ref.watch(activityRepositoryProvider);
  } catch (e) {
    if (isActivityCloudApiUnavailable(e)) return null;
    rethrow;
  }
  // A failed change stream only stops refreshing; the value stays.
  final sub = repo.changes().listen(
    (_) => ref.invalidateSelf(),
    onError: (Object _) {},
  );
  ref.onDispose(sub.cancel);
  final now = ref.read(activityClockProvider)();
  final entries = await repo.activitiesBetween(
    now.toUtc().subtract(const Duration(days: 2)),
    now.toUtc().add(const Duration(days: 1)),
    areas: {'health'},
  );
  return healthMinutesOn(entries, DateTime(now.year, now.month, now.day));
});
