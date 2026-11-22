import '../domain/glucose_reading.dart';

/// Where glucose readings live. Local now; a server repository later.
abstract interface class IGlucoseRepository {
  /// Live, readable readings whose `takenAt.utc` is in `[from, to)`, newest
  /// first. Unreadable notes are skipped.
  Future<List<GlucoseReading>> readingsBetween(DateTime from, DateTime to);

  /// Null when absent or deleted; throws `GlucoseUnreadable` for a note
  /// that cannot be decoded.
  Future<GlucoseReading?> getReading(String id);

  /// True when a reading note of this catalog exists under [id], live or
  /// soft-deleted. Lets an importer avoid resurrecting a deleted reading.
  Future<bool> existsIncludingDeleted(String id);

  /// Creates, or updates (restoring a soft-deleted note). Always stamps
  /// `updatedAt` (UTC, whole seconds).
  Future<GlucoseReading> saveReading(GlucoseReading r);

  /// Soft delete; a missing id is a no-op.
  Future<void> deleteReading(String id);

  /// Emits after the stored readings change; never for the initial state.
  Stream<void> changes();
}
