import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_prefs.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('launcher prefs survive the bundle json round-trip', () {
    final s = SyncableSettings.defaults().copyWith(
      launcher: const LauncherPrefs(favorites: ['gasLog'], aliases: {'cs': 'serviceRecords'}),
    );
    final back = SyncableSettings.fromJson(s.toJson());
    expect(back.launcher.favorites, ['gasLog']);
    expect(back.launcher.aliases, {'cs': 'serviceRecords'});
  });

  test('absent launcher field decodes to empty prefs', () {
    final json = SyncableSettings.defaults().toJson()..remove('launcher');
    expect(SyncableSettings.fromJson(json).launcher.favorites, isEmpty);
  });

  test('repository read/apply persists launcher prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SyncableSettingsRepository();
    final s = SyncableSettings.defaults().copyWith(
      launcher: const LauncherPrefs(favorites: ['notes'], aliases: {}),
    );
    await repo.apply(s);
    final read = await repo.read();
    expect(read.launcher.favorites, ['notes']);
  });
}
