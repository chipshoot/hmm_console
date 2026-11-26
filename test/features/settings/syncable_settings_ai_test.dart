import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ai fields round-trip through JSON', () {
    final b = SyncableSettings.defaults().copyWith(
      aiEngines: '[{"id":"a"}]',
      aiDefault: 'a',
      aiRoutes: '{"receipts":"a"}',
    );
    final back = SyncableSettings.fromJson(b.toJson());
    expect(back.aiEngines, '[{"id":"a"}]');
    expect(back.aiDefault, 'a');
    expect(back.aiRoutes, '{"receipts":"a"}');
  });

  test('absent ai values stay absent', () {
    final json = SyncableSettings.defaults().toJson();
    expect(json.containsKey('aiEngines'), isFalse);
    expect(json.containsKey('aiDefault'), isFalse);
    expect(json.containsKey('aiRoutes'), isFalse);
    final back = SyncableSettings.fromJson(json);
    expect(back.aiEngines, isNull);
    expect(back.aiDefault, isNull);
    expect(back.aiRoutes, isNull);
  });

  test('apply writes ai.* keys and read returns them', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SyncableSettingsRepository();
    await repo.apply(
      SyncableSettings.defaults().copyWith(
        aiEngines: '[]',
        aiDefault: 'a',
        aiRoutes: '{}',
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SyncableSettingsRepository.aiEnginesKey), '[]');
    expect(prefs.getString('ai.default'), 'a');
    expect(prefs.getString('ai.routes'), '{}');
    final read = await repo.read();
    expect(read.aiDefault, 'a');
  });

  test(
    'apply with null leaves local ai values alone; read null when unset',
    () async {
      SharedPreferences.setMockInitialValues({'ai.default': 'x'});
      final repo = SyncableSettingsRepository();
      await repo.apply(SyncableSettings.defaults());
      expect((await repo.read()).aiDefault, 'x');
      SharedPreferences.setMockInitialValues({});
      expect((await repo.read()).aiEngines, isNull);
    },
  );
}
