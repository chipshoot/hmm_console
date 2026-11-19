import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/states/show_lunar_provider.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = SyncableSettingsRepository.calendarShowLunarKey;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> mount() async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen(showLunarProvider, (_, _) {});
    return c;
  }

  test('starts false with nothing stored', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await mount();
    expect(c.read(showLunarProvider), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(showLunarProvider), isFalse);
  });

  test('hydrates true from prefs', () async {
    SharedPreferences.setMockInitialValues({_key: true});
    final c = await mount();
    expect(c.read(showLunarProvider), isFalse);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(showLunarProvider), isTrue);
  });

  test('set persists and bumps last-modified', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await mount();
    await c.read(showLunarProvider.notifier).set(true);
    expect(c.read(showLunarProvider), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_key), isTrue);
    expect(prefs.getString('settings.last_modified'), isNotNull);
  });
}
