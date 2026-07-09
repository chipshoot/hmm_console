import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/states/filter_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts empty, increments, and persists across containers', () async {
    SharedPreferences.setMockInitialValues({});

    final c1 = ProviderContainer();
    final initial = await c1.read(filterUsageProvider.future);
    expect(initial, isEmpty);

    await c1.read(filterUsageProvider.notifier).record('AutomobileMan');
    await c1.read(filterUsageProvider.notifier).record('AutomobileMan');
    await c1.read(filterUsageProvider.notifier).record('General');
    expect(await c1.read(filterUsageProvider.future),
        {'AutomobileMan': 2, 'General': 1});
    c1.dispose();

    // A fresh container reads the persisted counts.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final reloaded = await c2.read(filterUsageProvider.future);
    expect(reloaded, {'AutomobileMan': 2, 'General': 1});
  });
}
