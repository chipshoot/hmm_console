import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('empty prefs -> defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = await c.read(settingsProvider.future);
    expect(s.dataMode, DataMode.local);
  });

  test('migrates legacy keys on first load and writes the blob', () async {
    SharedPreferences.setMockInitialValues({'data_mode': 'cloudApi'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = await c.read(settingsProvider.future);
    expect(s.dataMode, DataMode.cloudApi);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_settings'), isNotNull); // blob written
  });

  test('setDataMode persists and re-emits', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    await c.read(settingsProvider.notifier).setDataMode(DataMode.cloudStorage);
    expect(c.read(settingsProvider).value!.dataMode, DataMode.cloudStorage);
  });

  test('corrupt blob falls back to legacy for connection-critical fields',
      () async {
    SharedPreferences.setMockInitialValues({
      'app_settings': 'not-json{{',
      'data_mode': 'cloudApi', // legacy retained
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = await c.read(settingsProvider.future);
    expect(s.dataMode, DataMode.cloudApi); // legacy, not default local
  });
}
