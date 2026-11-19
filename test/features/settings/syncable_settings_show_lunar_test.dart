import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = SyncableSettingsRepository.calendarShowLunarKey;

SyncableSettings _bundle(bool? v) =>
    SyncableSettings.defaults().copyWith(calendarShowLunar: v);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('JSON round-trip keeps true and false', () {
    for (final v in [true, false]) {
      final back = SyncableSettings.fromJson(_bundle(v).toJson());
      expect(back.calendarShowLunar, v);
    }
  });

  test('a bundle without the key reads null and omits it on write', () {
    final json = SyncableSettings.defaults().toJson();
    expect(json.containsKey('calendarShowLunar'), isFalse);
    expect(SyncableSettings.fromJson(json).calendarShowLunar, isNull);
  });

  test('apply with null leaves a true pref alone (C-4)', () async {
    SharedPreferences.setMockInitialValues({_key: true});
    final repo = SyncableSettingsRepository();
    await repo.apply(_bundle(null));
    expect((await SharedPreferences.getInstance()).getBool(_key), isTrue);
    expect((await repo.read()).calendarShowLunar, isTrue);
  });

  test('apply with false sets false', () async {
    SharedPreferences.setMockInitialValues({_key: true});
    final repo = SyncableSettingsRepository();
    await repo.apply(_bundle(false));
    expect((await SharedPreferences.getInstance()).getBool(_key), isFalse);
  });

  test('read gives null when never set', () async {
    SharedPreferences.setMockInitialValues({});
    expect(
      (await SyncableSettingsRepository().read()).calendarShowLunar,
      isNull,
    );
  });
}
