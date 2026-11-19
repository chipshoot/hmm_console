import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rKey = SyncableSettingsRepository.calendarHolidayRegionsKey;
const _mKey = SyncableSettingsRepository.calendarMyHolidaysKey;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('absent is not empty for both fields', () {
    final s = SyncableSettings.fromJson(SyncableSettings.defaults().toJson());
    expect(s.calendarHolidayRegions, isNull);
    expect(s.calendarMyHolidays, isNull);
    expect(s.toJson().containsKey('calendarHolidayRegions'), isFalse);
    expect(s.toJson().containsKey('calendarMyHolidays'), isFalse);
    final e = s.copyWith(
      calendarHolidayRegions: const [],
      calendarMyHolidays: const MyHolidaysData(entries: [], hidden: []),
    );
    final back = SyncableSettings.fromJson(e.toJson());
    expect(back.calendarHolidayRegions, isEmpty);
    expect(back.calendarMyHolidays, isNotNull);
  });

  test('round-trips regions and my holidays', () {
    final s = SyncableSettings.defaults().copyWith(
      calendarHolidayRegions: kDefaultHolidayRegions,
      calendarMyHolidays: MyHolidaysData(
        entries: [
          MyHoliday(
            id: 'a',
            name: 'Mine',
            kind: MyHolidayKind.yearly,
            start: DateTime(2026, 3, 4),
            offDay: true,
          ),
        ],
        hidden: const [HiddenHoliday(source: 'CN', name: 'X')],
      ),
    );
    final back = SyncableSettings.fromJson(s.toJson());
    expect(back.calendarHolidayRegions, kDefaultHolidayRegions);
    expect(back.calendarMyHolidays, s.calendarMyHolidays);
  });

  test('saving a bundle without the keys leaves local values', () async {
    const raw = '[{"country":"CN","color":0}]';
    SharedPreferences.setMockInitialValues({
      _rKey: raw,
      _mKey: '{"entries":[],"hidden":[]}',
    });
    final repo = SyncableSettingsRepository();
    await repo.apply(SyncableSettings.defaults());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_rKey), raw);
    expect(prefs.getString(_mKey), '{"entries":[],"hidden":[]}');
  });

  test('apply writes non-null values and read returns them', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SyncableSettingsRepository();
    await repo.apply(
      SyncableSettings.defaults().copyWith(
        calendarHolidayRegions: kDefaultHolidayRegions,
        calendarMyHolidays: MyHolidaysData.empty,
      ),
    );
    final s = await repo.read();
    expect(s.calendarHolidayRegions, kDefaultHolidayRegions);
    expect(s.calendarMyHolidays, MyHolidaysData.empty);
  });

  test('read gives null when absent or unreadable', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await SyncableSettingsRepository().read();
    expect(a.calendarHolidayRegions, isNull);
    expect(a.calendarMyHolidays, isNull);
    SharedPreferences.setMockInitialValues({_rKey: 'not json', _mKey: '{{'});
    final b = await SyncableSettingsRepository().read();
    expect(b.calendarHolidayRegions, isNull);
    expect(b.calendarMyHolidays, isNull);
  });
}
