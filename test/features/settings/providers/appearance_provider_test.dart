import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/providers/appearance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final c = ProviderContainer();
  addTearDown(c.dispose);
  c.listen(appearanceProvider, (_, _) {}); // keep alive
  // Let the async prefs load complete.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c;
}

void main() {
  test('defaults to system with nothing stored', () async {
    final c = await _container({});
    expect(c.read(appearanceProvider), AppearanceMode.system);
  });

  test('reads stored light and dark', () async {
    var c = await _container({'appearance': 'light'});
    expect(c.read(appearanceProvider), AppearanceMode.light);
    c = await _container({'appearance': 'dark'});
    expect(c.read(appearanceProvider), AppearanceMode.dark);
  });

  test(
    'unknown stored value falls back to system and is left untouched',
    () async {
      final c = await _container({'appearance': 'sepia'});
      expect(c.read(appearanceProvider), AppearanceMode.system);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('appearance'), 'sepia');
    },
  );

  test('set updates state immediately and persists under appearance', () async {
    final c = await _container({});
    final f = c.read(appearanceProvider.notifier).set(AppearanceMode.dark);
    expect(c.read(appearanceProvider), AppearanceMode.dark);
    await f;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance'), 'dark');
  });

  test('is not part of the synced settings bundle', () async {
    SharedPreferences.setMockInitialValues({'appearance': 'dark'});
    final read = await SyncableSettingsRepository().read();
    final json = read.toJson();
    expect(
      json.keys.any((k) => k.toLowerCase().contains('appearance')),
      isFalse,
    );
    expect(json.toString().toLowerCase().contains('appearance'), isFalse);
  });
}
