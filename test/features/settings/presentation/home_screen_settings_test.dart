import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/theme/theme.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/features/dashboard/domain/home_tiles.dart';
import 'package:hmm_console/features/settings/presentation/screens/home_screen_settings_screen.dart';
import 'package:hmm_console/features/settings/providers/home_hidden_tiles_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(
  WidgetTester t, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = ProviderContainer();
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.lightThemeData.copyWith(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreenSettingsScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lists every tile; toggling a switch hides it', (t) async {
    final c = await _pump(t);
    expect(find.byType(Switch), findsNWidgets(homeTiles.length));
    await t.tap(find.byKey(const ValueKey('home-tile-switch-glucose')));
    await t.pumpAndSettle();
    expect(c.read(homeHiddenTilesProvider), {'glucose'});
    await t.tap(find.byKey(const ValueKey('home-tile-switch-glucose')));
    await t.pumpAndSettle();
    expect(c.read(homeHiddenTilesProvider), isEmpty);
  });

  testWidgets('the last visible tile switch is disabled', (t) async {
    final c = await _pump(t);
    final n = c.read(homeHiddenTilesProvider.notifier);
    for (final tile in homeTiles.skip(1)) {
      await n.setVisible(tile.route, false);
    }
    await t.pumpAndSettle();
    final last = t.widget<Switch>(
      find.byKey(ValueKey('home-tile-switch-${homeTiles.first.route}')),
    );
    expect(last.onChanged, isNull);
    final other = t.widget<Switch>(
      find.byKey(ValueKey('home-tile-switch-${homeTiles.last.route}')),
    );
    expect(other.onChanged, isNotNull);
  });

  testWidgets('iOS uses Cupertino switches', (t) async {
    await _pump(t, platform: TargetPlatform.iOS);
    expect(find.byType(CupertinoSwitch), findsNWidgets(homeTiles.length));
  });

  testWidgets('has the help button', (t) async {
    await _pump(t);
    final b = t.widget<HelpButton>(find.byType(HelpButton));
    expect(b.helpId, HelpId.homeScreenSettings);
  });
}
