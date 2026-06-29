import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/providers/launcher_recents_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('record moves to front, dedups, caps at 8', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(launcherRecentsProvider.notifier);

    for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i']) {
      await n.record(id);
    }
    // 9 distinct -> capped to last 8, most-recent first
    expect(c.read(launcherRecentsProvider), ['i', 'h', 'g', 'f', 'e', 'd', 'c', 'b']);

    await n.record('c'); // existing -> moves to front, no dup
    final r = c.read(launcherRecentsProvider);
    expect(r.first, 'c');
    expect(r.where((x) => x == 'c').length, 1);
    expect(r.length, 8);
  });

  test('persists across containers', () async {
    SharedPreferences.setMockInitialValues({});
    final c1 = ProviderContainer();
    await c1.read(launcherRecentsProvider.notifier).record('x');
    c1.dispose();

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    c2.read(launcherRecentsProvider); // trigger build() -> async load
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c2.read(launcherRecentsProvider), ['x']);
  });
}
