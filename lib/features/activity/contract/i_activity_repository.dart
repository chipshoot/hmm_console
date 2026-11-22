import '../domain/activity.dart';

/// Where activities live. Local now; a server repository later.
abstract interface class IActivityRepository {
  /// Live, readable activities whose `start.utc` is in `[from, to)`, newest
  /// first. Unreadable notes are skipped. [areas] keeps only those whose
  /// [Activity.area] is in the set.
  Future<List<Activity>> activitiesBetween(
    DateTime from,
    DateTime to, {
    Set<String>? areas,
  });

  /// Null when absent or deleted; throws `ActivityUnreadable` for a note
  /// that cannot be decoded.
  Future<Activity?> getActivity(String id);

  /// Creates, or updates (restoring a soft-deleted note). Stamps `updatedAt`.
  Future<Activity> saveActivity(Activity a);

  /// Soft delete; a missing id is a no-op.
  Future<void> deleteActivity(String id);

  /// Emits after the stored activities change; never for the initial state.
  Stream<void> changes();
}
