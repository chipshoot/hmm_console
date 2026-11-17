import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/calendar/contract/calendar_errors.dart';
import 'package:hmm_console/features/calendar/data/local_calendar_repository.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';

import '../../contacts/data/contact_repository_fakes.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

ProviderContainer _c(DataMode m) => ProviderContainer(
  overrides: [
    dataModeProvider.overrideWith(() => _Mode(m)),
    localCalendarRepositoryProvider.overrideWithValue(
      LocalCalendarRepository(FakeNoteRepository(), FakeCatalogRepository()),
    ),
  ],
);

void main() {
  test('local and cloudStorage resolve the local repository', () {
    for (final m in [DataMode.local, DataMode.cloudStorage]) {
      final c = _c(m);
      addTearDown(c.dispose);
      expect(
        c.read(calendarRepositoryProvider),
        isA<LocalCalendarRepository>(),
      );
    }
  });

  test('cloudApi throws the recognisable CalendarCloudApiUnavailable', () {
    final c = _c(DataMode.cloudApi);
    addTearDown(c.dispose);
    Object? caught;
    try {
      c.read(calendarRepositoryProvider);
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(isCalendarCloudApiUnavailable(caught!), isTrue);
    expect(isCalendarCloudApiUnavailable(StateError('x')), isFalse);
  });
}
