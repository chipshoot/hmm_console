import 'package:health/health.dart';

import 'glucose_sample_source.dart';

/// Blood glucose from Apple Health (the `health` package). Every `health`
/// import in the app stays in this file.
class HealthGlucoseSampleSource implements GlucoseSampleSource {
  HealthGlucoseSampleSource([Health? health]) : _health = health ?? Health();

  final Health _health;
  Future<void>? _configured;

  static const _types = [HealthDataType.BLOOD_GLUCOSE];

  // A failed configure is retried on the next call.
  Future<void> _configure() =>
      _configured ??= _health.configure().catchError((Object e) {
        _configured = null;
        throw e;
      });

  @override
  Future<bool> requestAccess() async {
    await _configure();
    return _health.requestAuthorization(
      _types,
      permissions: const [HealthDataAccess.READ],
    );
  }

  @override
  Future<List<GlucoseSample>> samples(DateTime fromUtc, DateTime toUtc) async {
    await _configure();
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: fromUtc,
      endTime: toUtc,
      preferredUnits: const {
        HealthDataType.BLOOD_GLUCOSE: HealthDataUnit.MILLIGRAM_PER_DECILITER,
      },
    );
    return [
      for (final p in points)
        if (p.type == HealthDataType.BLOOD_GLUCOSE &&
            p.unit == HealthDataUnit.MILLIGRAM_PER_DECILITER &&
            p.uuid.isNotEmpty &&
            p.value is NumericHealthValue)
          GlucoseSample(
            sampleId: p.uuid,
            instantUtc: p.dateFrom.toUtc(),
            mgdl: (p.value as NumericHealthValue).numericValue,
            sourceName: p.sourceName.isEmpty ? null : p.sourceName,
          ),
    ];
  }
}
