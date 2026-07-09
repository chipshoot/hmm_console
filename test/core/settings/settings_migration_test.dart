import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/settings/settings_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('empty prefs -> all defaults', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = migrateFromLegacy(prefs);
    expect(s.dataMode, DataMode.local);
    expect(s.onboardingCompleted, false);
  });

  test('reads scalar legacy keys', () async {
    SharedPreferences.setMockInitialValues({
      'geo_capture_enabled': true,
      'onboarding_completed': true,
      'local_db_path': '/tmp/x.db',
      'cloud_storage_vault_path': '/Vault',
      'launcher_recents': '["a","b"]',
      'notes.filter_usage': '{"notes":2}',
    });
    final prefs = await SharedPreferences.getInstance();
    final s = migrateFromLegacy(prefs);
    expect(s.geoCaptureEnabled, true);
    expect(s.onboardingCompleted, true);
    expect(s.localDbPath, '/tmp/x.db');
    expect(s.cloudStorageVaultPath, '/Vault');
    expect(s.launcherRecents, ['a', 'b']);
    expect(s.notesFilterUsage, {'notes': 2});
  });

  // Connection-critical matrix (refinement #3).
  for (final entry in {
    'local': DataMode.local,
    'cloudStorage': DataMode.cloudStorage,
    'cloudApi': DataMode.cloudApi,
    'api': DataMode.cloudApi, // legacy alias
  }.entries) {
    test('data_mode "${entry.key}" -> ${entry.value}', () async {
      SharedPreferences.setMockInitialValues({'data_mode': entry.key});
      final prefs = await SharedPreferences.getInstance();
      expect(migrateFromLegacy(prefs).dataMode, entry.value);
    });
  }

  test('does not delete legacy keys', () async {
    SharedPreferences.setMockInitialValues({'data_mode': 'cloudApi'});
    final prefs = await SharedPreferences.getInstance();
    migrateFromLegacy(prefs);
    expect(prefs.getString('data_mode'), 'cloudApi'); // retained
  });
}
