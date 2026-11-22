import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/states/activity_list_state.dart';
import 'package:hmm_console/features/activity/states/activity_providers.dart';
import 'package:hmm_console/features/activity/states/health_minutes_today.dart';

import '../support/fake_activity_repository.dart';

Activity _act(String id, String kind, int min, String iso) => Activity(
  id: id,
  kind: kind,
  start: OffsetDateTime.tryParse(iso)!,
  durationMinutes: min,
  updatedAt: DateTime.utc(2026, 11, 21),
);

class _Mode extends DataModeNotifier {
  _Mode(this.mode);
  final DataMode mode;
  @override
  DataMode build() => mode;
}

/// A repository whose change stream can fail.
class _ErroringRepo extends FakeActivityRepository {
  _ErroringRepo(super.seed);

  final errors = StreamController<void>.broadcast();

  @override
  Stream<void> changes() => errors.stream;
}

void main() {
  final today = DateTime(2026, 11, 21);

  test('sums only health entries recorded today', () {
    final entries = [
      _act('a', 'health.walk', 30, '2026-11-21T08:00:00-05:00'),
      _act('b', 'health.gym', 45, '2026-11-21T18:00:00-05:00'),
      _act('c', 'reading.reading', 40, '2026-11-21T20:00:00-05:00'),
      _act('d', 'health.walk', 20, '2026-11-20T08:00:00-05:00'),
    ];
    expect(healthMinutesOn(entries, today), 75);
  });

  test('23:30-05:00 on 21 Nov counts for 21 Nov, not 22 Nov', () {
    final e = [_act('a', 'health.run', 25, '2026-11-21T23:30:00-05:00')];
    expect(healthMinutesOn(e, DateTime(2026, 11, 21)), 25);
    expect(healthMinutesOn(e, DateTime(2026, 11, 22)), 0);
  });

  ProviderContainer container(DataMode mode, List<Activity> seed) {
    final c = ProviderContainer(
      overrides: [
        dataModeProvider.overrideWith(() => _Mode(mode)),
        localActivityRepositoryProvider.overrideWithValue(
          FakeActivityRepository(seed),
        ),
        activityClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 21, 12),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('provider reads today from the repository', () async {
    final c = container(DataMode.local, [
      _act('a', 'health.walk', 30, '2026-11-21T08:00:00Z'),
      _act('b', 'health.gym', 45, '2026-11-21T09:00:00Z'),
    ]);
    expect(await c.read(healthMinutesTodayProvider.future), 75);
  });

  test('provider yields null in Cloud API mode', () async {
    final c = container(DataMode.cloudApi, const []);
    expect(await c.read(healthMinutesTodayProvider.future), isNull);
  });

  test('a change-stream error is swallowed; the value stays', () async {
    final repo = _ErroringRepo([
      _act('a', 'health.walk', 30, '2026-11-21T08:00:00Z'),
    ]);
    final c = ProviderContainer(
      overrides: [
        dataModeProvider.overrideWith(() => _Mode(DataMode.local)),
        localActivityRepositoryProvider.overrideWithValue(repo),
        activityClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 21, 12),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(healthMinutesTodayProvider, (_, _) {});
    expect(await c.read(healthMinutesTodayProvider.future), 30);
    repo.errors.addError(StateError('watch failed'));
    await pumpEventQueue();
    expect(c.read(healthMinutesTodayProvider).value, 30);
  });
}
