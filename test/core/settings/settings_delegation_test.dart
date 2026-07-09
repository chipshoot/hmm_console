import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:hmm_console/features/onboarding/providers/onboarding_provider.dart';
import 'package:hmm_console/features/settings/providers/geo_capture_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dataModeProvider reflects and writes through the controller', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future); // ensure loaded

    await c.read(dataModeProvider.notifier).setMode(DataMode.cloudApi);
    expect(c.read(dataModeProvider), DataMode.cloudApi);
    expect(c.read(settingsProvider).value!.dataMode, DataMode.cloudApi);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_settings'), contains('cloudApi'));
  });

  test('cloudProvider + vault path round-trip through the controller',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);

    await c.read(settingsProvider.notifier).setCloudStorageVaultPath('/Vault');
    expect(await c.read(cloudStorageVaultPathProvider.future), '/Vault');

    await c.read(cloudProviderProvider.notifier).setProvider(CloudProvider.onedrive);
    expect(c.read(cloudProviderProvider), CloudProvider.onedrive);
  });

  test('onboarding + geo-capture delegate to the controller', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);

    await c.read(onboardingCompletedProvider.notifier).markCompleted();
    expect(c.read(settingsProvider).value!.onboardingCompleted, true);

    await c.read(geoCaptureEnabledProvider.notifier).setEnabled(true);
    expect(c.read(settingsProvider).value!.geoCaptureEnabled, true);
  });
}
