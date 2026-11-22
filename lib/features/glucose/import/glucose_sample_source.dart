/// One blood glucose sample from the device's health store.
class GlucoseSample {
  const GlucoseSample({
    required this.sampleId,
    required this.instantUtc,
    required this.mgdl,
    this.sourceName,
  });

  /// The health store's stable sample id (HealthKit UUID).
  final String sampleId;

  /// When the sample was taken, in UTC.
  final DateTime instantUtc;

  /// The value in mg/dL, exactly as the health store returned it.
  final num mgdl;

  /// The app or device that wrote the sample, when known.
  final String? sourceName;
}

/// Where imported glucose samples come from. Apple Health on device; a fake
/// in tests.
abstract interface class GlucoseSampleSource {
  /// Asks for read access to blood glucose. iOS hides a refusal, so true
  /// means only that the request completed.
  Future<bool> requestAccess();

  /// Samples taken in `[fromUtc, toUtc]`.
  Future<List<GlucoseSample>> samples(DateTime fromUtc, DateTime toUtc);
}
