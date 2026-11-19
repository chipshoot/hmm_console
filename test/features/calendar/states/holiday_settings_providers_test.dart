import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';
import 'package:hmm_console/features/calendar/states/holiday_settings_providers.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/providers/settings_bus_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingRepo extends SyncableSettingsRepository {
  int bumps = 0;
  @override
  Future<DateTime> bumpLastModified() async {
    bumps++;
    return super.bumpLastModified();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, _CountingRepo)> mount() async {
    final repo = _CountingRepo();
    final c = ProviderContainer(
      overrides: [syncableSettingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(holidayRegionsProvider, (_, _) {});
    c.listen(myHolidaysProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return (c, repo);
  }

  test('default regions when never edited, and nothing written', () async {
    SharedPreferences.setMockInitialValues({});
    final (c, _) = await mount();
    expect(c.read(holidayRegionsProvider), kDefaultHolidayRegions);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(SyncableSettingsRepository.calendarHolidayRegionsKey),
      isFalse,
    );
  });

  test('hydrates stored regions', () async {
    SharedPreferences.setMockInitialValues({
      SyncableSettingsRepository.calendarHolidayRegionsKey:
          '[{"country":"JP","color":3}]',
    });
    final (c, _) = await mount();
    expect(c.read(holidayRegionsProvider), const [
      HolidayRegion(country: 'JP', color: 3),
    ]);
  });

  test('add rejects duplicates and picks the lowest free colour', () async {
    SharedPreferences.setMockInitialValues({});
    final (c, _) = await mount();
    final n = c.read(holidayRegionsProvider.notifier);
    expect(await n.add('US', null), isTrue);
    expect(c.read(holidayRegionsProvider).last.color, 2);
    expect(await n.add('CA', 'CA-ON'), isFalse);
    expect(c.read(holidayRegionsProvider).length, 3);
    await n.remove('CN');
    expect(await n.add('JP', null), isTrue);
    expect(c.read(holidayRegionsProvider).last.color, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(SyncableSettingsRepository.calendarHolidayRegionsKey),
      contains('JP'),
    );
  });

  test('restore puts a previous list back', () async {
    SharedPreferences.setMockInitialValues({});
    final (c, _) = await mount();
    final n = c.read(holidayRegionsProvider.notifier);
    final before = c.read(holidayRegionsProvider);
    await n.remove('CN');
    await n.restore(before);
    expect(c.read(holidayRegionsProvider), before);
  });

  test('hide is idempotent and unhide restores', () async {
    SharedPreferences.setMockInitialValues({});
    final (c, _) = await mount();
    final n = c.read(myHolidaysProvider.notifier);
    await n.hide('CN', 'X');
    await n.hide('CN', 'X');
    expect(c.read(myHolidaysProvider).hidden.length, 1);
    await n.unhide('CN', 'X');
    expect(c.read(myHolidaysProvider).hidden, isEmpty);
  });

  test('upsert replaces by id, delete removes, restore reverts', () async {
    SharedPreferences.setMockInitialValues({});
    final (c, _) = await mount();
    final n = c.read(myHolidaysProvider.notifier);
    MyHoliday h(String name) => MyHoliday(
      id: 'a',
      name: name,
      kind: MyHolidayKind.once,
      start: DateTime(2026, 1, 1),
      offDay: true,
    );
    await n.upsert(h('one'));
    await n.upsert(h('two'));
    expect(c.read(myHolidaysProvider).entries.single.name, 'two');
    final prev = c.read(myHolidaysProvider);
    await n.delete('a');
    expect(c.read(myHolidaysProvider).entries, isEmpty);
    await n.restore(prev);
    expect(c.read(myHolidaysProvider), prev);
  });

  test('every edit bumps last modified', () async {
    SharedPreferences.setMockInitialValues({});
    final (c, repo) = await mount();
    final r = c.read(holidayRegionsProvider.notifier);
    final m = c.read(myHolidaysProvider.notifier);
    await r.add('US', null);
    expect(repo.bumps, 1);
    await r.remove('US');
    expect(repo.bumps, 2);
    await m.upsert(
      MyHoliday(
        id: 'a',
        name: 'n',
        kind: MyHolidayKind.once,
        start: DateTime(2026, 1, 1),
        offDay: true,
      ),
    );
    expect(repo.bumps, 3);
    await m.delete('a');
    expect(repo.bumps, 4);
    await m.hide('CN', 'X');
    expect(repo.bumps, 5);
  });

  test('a settings pull keeps current state while re-reading prefs', () async {
    SharedPreferences.setMockInitialValues({
      SyncableSettingsRepository.calendarHolidayRegionsKey:
          '[{"country":"CN","color":0},{"country":"US","color":2}]',
      SyncableSettingsRepository.calendarMyHolidaysKey:
          '{"entries":[],"hidden":[{"source":"CN","name":"X"}]}',
    });
    final (c, _) = await mount();
    final regions = c.read(holidayRegionsProvider);
    expect(regions.map((r) => r.sourceId), ['CN', 'US']);
    final seen = <List<HolidayRegion>>[];
    final seenMine = <MyHolidaysData>[];
    c.listen(holidayRegionsProvider, (_, next) => seen.add(next));
    c.listen(myHolidaysProvider, (_, next) => seenMine.add(next));

    c.read(settingsBusProvider.notifier).bump();
    // Synchronously after the bump: no flash back to the defaults.
    expect(c.read(holidayRegionsProvider), regions);
    expect(c.read(myHolidaysProvider).hidden, hasLength(1));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(holidayRegionsProvider), regions);
    expect(seen.where((v) => v == kDefaultHolidayRegions), isEmpty);
    expect(seenMine.where((v) => v.hidden.isEmpty), isEmpty);
  });

  test('a settings pull applies the newly pulled value', () async {
    SharedPreferences.setMockInitialValues({});
    final (c, _) = await mount();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SyncableSettingsRepository.calendarHolidayRegionsKey,
      '[{"country":"JP","color":3}]',
    );
    c.read(settingsBusProvider.notifier).bump();
    c.read(holidayRegionsProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(holidayRegionsProvider), const [
      HolidayRegion(country: 'JP', color: 3),
    ]);
  });

  test('hydrated completes once prefs are read', () async {
    SharedPreferences.setMockInitialValues({
      SyncableSettingsRepository.calendarHolidayRegionsKey:
          '[{"country":"JP","color":3}]',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen(holidayRegionsProvider, (_, _) {});
    c.listen(myHolidaysProvider, (_, _) {});
    final regions = c.read(holidayRegionsProvider.notifier);
    final mine = c.read(myHolidaysProvider.notifier);
    expect(regions.isHydrated, isFalse);
    expect(mine.isHydrated, isFalse);
    await Future.wait([regions.hydrated, mine.hydrated]);
    expect(regions.isHydrated, isTrue);
    expect(mine.isHydrated, isTrue);
    expect(c.read(holidayRegionsProvider).single.country, 'JP');
  });
}
