import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/settings/app_settings.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('AppSettings defaults + json round-trip for quick panel flags', () {
    const s = AppSettings();
    expect(s.quickPanelEnabled, isTrue);
    expect(s.quickPanelHintShown, isFalse);

    final round = AppSettings.fromJson(s.toJson());
    expect(round.quickPanelEnabled, isTrue);
    expect(round.quickPanelHintShown, isFalse);

    expect(AppSettings.fromJson(const {}).quickPanelEnabled, isTrue,
        reason: 'missing key defaults to enabled');
  });

  test('quick panel view providers read + write through the controller',
      () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);

    expect(container.read(quickPanelEnabledProvider), isTrue);
    await container.read(quickPanelEnabledProvider.notifier).setEnabled(false);
    expect(container.read(quickPanelEnabledProvider), isFalse);

    expect(container.read(quickPanelHintShownProvider), isFalse);
    await container.read(quickPanelHintShownProvider.notifier).markShown();
    expect(container.read(quickPanelHintShownProvider), isTrue);
    await container.read(quickPanelHintShownProvider.notifier).replay();
    expect(container.read(quickPanelHintShownProvider), isFalse);
  });
}
