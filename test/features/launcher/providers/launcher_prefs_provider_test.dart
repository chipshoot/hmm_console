import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/providers/launcher_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggleFavorite adds then removes, and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(launcherPrefsProvider.notifier);

    await n.toggleFavorite('gasLog');
    expect(c.read(launcherPrefsProvider).favorites, ['gasLog']);

    await n.toggleFavorite('gasLog');
    expect(c.read(launcherPrefsProvider).favorites, isEmpty);

    // persisted under the shared key
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('launcher_prefs'), isNotNull);
  });

  test('addAlias / removeAlias mutate the map', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(launcherPrefsProvider.notifier);

    await n.addAlias('cs', 'serviceRecords');
    expect(c.read(launcherPrefsProvider).aliases, {'cs': 'serviceRecords'});

    await n.removeAlias('cs');
    expect(c.read(launcherPrefsProvider).aliases, isEmpty);
  });

  test('loads existing prefs from disk on first read', () async {
    SharedPreferences.setMockInitialValues({
      'launcher_prefs': '{"favorites":["notes"],"aliases":{}}',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(launcherPrefsProvider); // trigger build() -> starts async load
    // allow the async _load to complete
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(launcherPrefsProvider).favorites, ['notes']);
  });
}
