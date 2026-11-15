import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/video/video_uploader.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> make({required bool setting}) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(
      overrides: [
        videoUnmeteredCheckProvider.overrideWithValue(() async => false),
      ],
    );
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    await c.read(settingsProvider.notifier).setVideoUploadOnMobileData(setting);
    return c;
  }

  test('with the setting on, a queued entry uploads on mobile data', () async {
    final c = await make(setting: true);
    expect(await c.read(videoMayUseNetworkProvider)(), isTrue);
  });

  test('with the setting off and no Wi-Fi, uploads wait', () async {
    final c = await make(setting: false);
    expect(await c.read(videoMayUseNetworkProvider)(), isFalse);
  });

  test('toggling takes effect without rebuilding the closure', () async {
    final c = await make(setting: false);
    final fn = c.read(videoMayUseNetworkProvider);
    expect(await fn(), isFalse);
    await c.read(settingsProvider.notifier).setVideoUploadOnMobileData(true);
    expect(await fn(), isTrue);
  });
}
