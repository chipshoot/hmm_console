import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/providers/geo_capture_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to false and persists when set', () async {
    SharedPreferences.setMockInitialValues({});
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);

    expect(await c1.read(geoCaptureEnabledProvider.future), isFalse);
    await c1.read(geoCaptureEnabledProvider.notifier).setEnabled(true);
    expect(await c1.read(geoCaptureEnabledProvider.future), isTrue);

    // New container re-reads the persisted value.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    expect(await c2.read(geoCaptureEnabledProvider.future), isTrue);
  });
}
