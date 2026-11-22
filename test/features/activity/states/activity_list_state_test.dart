import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/states/activity_list_state.dart';
import 'package:hmm_console/features/activity/states/activity_providers.dart';

import '../support/fake_activity_repository.dart';

class _Mode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.local;
}

Activity _act(String id, String iso) => Activity(
  id: id,
  kind: 'health.walk',
  start: OffsetDateTime.tryParse(iso)!,
  durationMinutes: 30,
  updatedAt: DateTime.utc(2026, 11, 21),
);

void main() {
  test('groups by each entry\'s recorded date on both sides of the date '
      'line, whatever the device zone', () async {
    // west: 20 Nov 23:00 at -12:00 = 21 Nov 11:00 UTC (21 Nov in every zone
    // from -11:00 east). east: 21 Nov 00:30 at +14:00 = 20 Nov 10:30 UTC
    // (20 Nov in every zone up to +13:00). Device-local grouping would swap
    // them in any zone between -11:00 and +13:00.
    final container = ProviderContainer(
      overrides: [
        dataModeProvider.overrideWith(_Mode.new),
        localActivityRepositoryProvider.overrideWithValue(
          FakeActivityRepository([
            _act('west', '2026-11-20T23:00:00-12:00'),
            _act('east', '2026-11-21T00:30:00+14:00'),
          ]),
        ),
        activityClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 21, 12),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(activityListProvider(null), (_, _) {});
    addTearDown(sub.close);

    final data = await container.read(activityListProvider(null).future);
    final byDate = {
      for (final d in data.days) d.date: [for (final a in d.entries) a.id],
    };
    expect(byDate, {
      DateTime.utc(2026, 11, 21): ['east'],
      DateTime.utc(2026, 11, 20): ['west'],
    });
    expect(data.today, DateTime.utc(2026, 11, 21));
  });
}
