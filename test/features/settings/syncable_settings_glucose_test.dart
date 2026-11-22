import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

SyncableSettings _full() => SyncableSettings.defaults().copyWith(
  glucoseRangeLow: 4.0,
  glucoseRangeHigh: 7.0,
  glucoseRangeUnit: 'mmol/L',
  glucoseDisplayUnit: 'mg/dL',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('JSON round-trip keeps all four glucose fields', () {
    final back = SyncableSettings.fromJson(_full().toJson());
    expect(back.glucoseRangeLow, 4.0);
    expect(back.glucoseRangeHigh, 7.0);
    expect(back.glucoseRangeUnit, 'mmol/L');
    expect(back.glucoseDisplayUnit, 'mg/dL');
  });

  test('old JSON without the keys decodes with nulls and omits them', () {
    final json = SyncableSettings.defaults().toJson();
    for (final k in [
      'glucoseRangeLow',
      'glucoseRangeHigh',
      'glucoseRangeUnit',
      'glucoseDisplayUnit',
    ]) {
      expect(json.containsKey(k), isFalse);
    }
    final back = SyncableSettings.fromJson(json);
    expect(back.glucoseRangeLow, isNull);
    expect(back.glucoseRangeHigh, isNull);
    expect(back.glucoseRangeUnit, isNull);
    expect(back.glucoseDisplayUnit, isNull);
  });

  test('apply then read round-trips through prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SyncableSettingsRepository();
    await repo.apply(_full());
    final back = await repo.read();
    expect(back.glucoseRangeLow, 4.0);
    expect(back.glucoseRangeHigh, 7.0);
    expect(back.glucoseRangeUnit, 'mmol/L');
    expect(back.glucoseDisplayUnit, 'mg/dL');
  });

  test('apply with nulls leaves this device values alone', () async {
    SharedPreferences.setMockInitialValues({
      'glucose.rangeLow': 70.0,
      'glucose.rangeHigh': 140.0,
      'glucose.rangeUnit': 'mg/dL',
      'glucose.displayUnit': 'mg/dL',
    });
    final repo = SyncableSettingsRepository();
    await repo.apply(SyncableSettings.defaults());
    final back = await repo.read();
    expect(back.glucoseRangeLow, 70.0);
    expect(back.glucoseDisplayUnit, 'mg/dL');
  });
}
