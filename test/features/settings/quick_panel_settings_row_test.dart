import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_settings.dart';
import 'package:hmm_console/features/settings/presentation/screens/settings_screen.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the real SettingsScreen behind a ProviderContainer we can read
/// directly, with the app's localization delegates wired up (the screen
/// calls AppLocalizations.of(context) unconditionally). databasePathProvider
/// is overridden because it hits the path_provider platform channel, which
/// hangs (no mock handler) rather than erroring in a plain widget test,
/// which would make pumpAndSettle time out on the "local" data-mode branch
/// this screen renders by default.
Future<ProviderContainer> _pump(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    databasePathProvider.overrideWith((ref) async => '/tmp/hmm-test.db'),
  ]);
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Quick access panel toggle is present, defaults on, and flips the provider',
      (t) async {
    final container = await _pump(t);

    expect(find.text('Quick access panel'), findsOneWidget);
    final sw = t.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Quick access panel'),
    );
    expect(sw.value, isTrue);

    // The row lives near the bottom of a long SingleChildScrollView; it's
    // present in the tree (SingleChildScrollView builds eagerly) but may be
    // laid out off the default test viewport, so scroll it into view first.
    await t.ensureVisible(find.text('Quick access panel'));
    await t.pumpAndSettle();
    await t.tap(find.text('Quick access panel'));
    await t.pumpAndSettle();

    expect(container.read(quickPanelEnabledProvider), isFalse);
  });

  testWidgets('"Show me how" replays the coach mark by resetting the hint flag',
      (t) async {
    final container = await _pump(t);

    await container.read(quickPanelHintShownProvider.notifier).markShown();
    expect(container.read(quickPanelHintShownProvider), isTrue);

    expect(find.text('Show me how'), findsOneWidget);
    await t.ensureVisible(find.text('Show me how'));
    await t.pumpAndSettle();
    await t.tap(find.text('Show me how'));
    await t.pumpAndSettle();

    expect(container.read(quickPanelHintShownProvider), isFalse);
  });
}
