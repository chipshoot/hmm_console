import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('DB path set via the controller is what the open path resolves',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    await c.read(settingsProvider.notifier).setLocalDbPath('/tmp/custom.db');

    final prefs = await SharedPreferences.getInstance();
    expect(await resolveCustomDbPath(prefs), '/tmp/custom.db');
  });

  test('reset (empty string) clears the custom path', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    await c.read(settingsProvider.notifier).setLocalDbPath('/tmp/custom.db');
    await c.read(settingsProvider.notifier).setLocalDbPath('');

    final prefs = await SharedPreferences.getInstance();
    expect(await resolveCustomDbPath(prefs), isNull);
  });

  test('falls back to the legacy key when the blob is corrupt', () async {
    SharedPreferences.setMockInitialValues({
      'app_settings': 'not-json{{',
      'local_db_path': '/legacy/hmm.db',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(await resolveCustomDbPath(prefs), '/legacy/hmm.db');
  });

  test('returns null when nothing is configured', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(await resolveCustomDbPath(prefs), isNull);
  });
}
