import 'package:hmm_console/features/glucose/import/glucose_sample_source.dart';

/// In-memory sample source. Records each access request and each window
/// asked for; returns the samples whose instant is in `[from, to]`.
class FakeGlucoseSampleSource implements GlucoseSampleSource {
  FakeGlucoseSampleSource([Iterable<GlucoseSample> seed = const []])
    : samplesList = [...seed];

  final List<GlucoseSample> samplesList;
  final List<(DateTime, DateTime)> windows = [];
  int accessRequests = 0;

  /// When set, [samples] throws it.
  Object? error;

  @override
  Future<bool> requestAccess() async {
    accessRequests++;
    return true;
  }

  @override
  Future<List<GlucoseSample>> samples(DateTime fromUtc, DateTime toUtc) async {
    windows.add((fromUtc, toUtc));
    final e = error;
    if (e != null) throw e;
    return [
      for (final s in samplesList)
        if (!s.instantUtc.isBefore(fromUtc) && !s.instantUtc.isAfter(toUtc)) s,
    ];
  }
}
