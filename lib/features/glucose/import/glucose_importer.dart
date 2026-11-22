import '../../../core/util/uuid.dart';
import '../../activity/domain/offset_date_time.dart';
import '../contract/i_glucose_repository.dart';
import '../domain/glucose_reading.dart';
import '../domain/glucose_units.dart';
import '../states/glucose_settings_providers.dart';
import 'glucose_sample_source.dart';

/// Fixed namespace for imported reading ids. Never change it: ids must stay
/// the same across reinstalls and devices so a sample is imported once.
const kGlucoseIdNamespace = '5b6f2c1e-8d3a-4f7b-9e2c-1a4d6b8c0e57';

/// The reading id for a health store sample: UUID v5 over
/// `appleHealth:<sampleId>`.
String glucoseIdForSample(String sampleId) =>
    uuidV5(kGlucoseIdNamespace, 'appleHealth:$sampleId');

/// The sync lock was held (a sync or another exclusive run), so the import
/// stopped. Nothing past the readings already saved changed; the next run
/// catches up.
class GlucoseImportBusy implements Exception {
  const GlucoseImportBusy();

  @override
  String toString() => 'GlucoseImportBusy';
}

class GlucoseImportResult {
  const GlucoseImportResult({this.added = 0, this.seen = 0, this.error});

  /// Readings created by this run.
  final int added;

  /// Distinct samples the source returned.
  final int seen;

  /// Set when the run failed; the window end and first-import flag were not
  /// advanced.
  final Object? error;
}

OffsetDateTime _deviceOffset(DateTime utc) =>
    OffsetDateTime.fromLocal(utc.toLocal());

/// Copies new health store samples into the glucose log. A sample whose
/// reading exists, live or deleted, is skipped; existing readings are never
/// modified.
class GlucoseImporter {
  GlucoseImporter({
    required this.repo,
    required this.source,
    required this.prefs,
    required this.now,
    required this.runExclusive,
    this.toOffset = _deviceOffset,
  });

  static const chunkSize = 100;
  static const overlap = Duration(days: 7);

  final IGlucoseRepository repo;
  final GlucoseSampleSource source;
  final GlucoseImportPrefs prefs;
  final DateTime Function() now;

  /// Returns null without running the body when the sync lock is held.
  final Future<T?> Function<T>(Future<T> Function() body) runExclusive;

  /// The recorded time for a sample instant: the zone's offset at that
  /// instant, by default the device's.
  final OffsetDateTime Function(DateTime utc) toOffset;

  /// Imports once. [manual] runs ask for access before the first import.
  Future<GlucoseImportResult> run({required bool manual}) async {
    var added = 0;
    var seen = 0;
    try {
      final importedOnce = await prefs.importedOnce();
      // iOS hides a refusal: a denied request simply yields no samples.
      if (manual && !importedOnce) await source.requestAccess();

      final end = now().toUtc();
      final lastEnd = await prefs.lastImportEnd();
      final from = lastEnd == null
          ? DateTime.utc(2000)
          : lastEnd.subtract(overlap);

      final bySampleId = <String, GlucoseSample>{};
      for (final s in await source.samples(from, end)) {
        bySampleId.putIfAbsent(s.sampleId, () => s);
      }
      final samples = bySampleId.values.toList();
      seen = samples.length;

      for (var i = 0; i < samples.length; i += chunkSize) {
        final chunk = samples.sublist(
          i,
          i + chunkSize < samples.length ? i + chunkSize : samples.length,
        );
        // The existence check and the save share the lock, so a sync cannot
        // land the same note in between and be overwritten.
        final saved = await runExclusive<int>(() => _saveNew(chunk));
        if (saved == null) throw const GlucoseImportBusy();
        added += saved;
      }

      await prefs.setLastImportEnd(end);
      await prefs.markImportedOnce();
      return GlucoseImportResult(added: added, seen: seen);
    } catch (e) {
      return GlucoseImportResult(added: added, seen: seen, error: e);
    }
  }

  Future<int> _saveNew(List<GlucoseSample> chunk) async {
    var saved = 0;
    for (final s in chunk) {
      final id = glucoseIdForSample(s.sampleId);
      if (await repo.existsIncludingDeleted(id)) continue;
      await repo.saveReading(
        GlucoseReading(
          id: id,
          takenAt: toOffset(s.instantUtc.toUtc()),
          glucose: GlucoseValue(s.mgdl, GlucoseUnit.mgdl),
          source: GlucoseSource.appleHealth,
          appleHealth: AppleHealthRef(
            sampleId: s.sampleId,
            sourceName: s.sourceName,
          ),
        ),
      );
      saved++;
    }
    return saved;
  }
}
