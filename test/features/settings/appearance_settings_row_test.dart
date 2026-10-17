import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/settings/presentation/screens/settings_screen.dart';
import 'package:hmm_console/features/settings/providers/appearance_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(
  WidgetTester t, {
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      databasePathProvider.overrideWith((ref) async => '/tmp/hmm-test.db'),
    ],
  );
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  final row = find.byKey(const Key('settings-appearance'));
  await t.ensureVisible(row);
  await t.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Android: SegmentedButton with three options; Dark updates', (
    t,
  ) async {
    final c = await _pump(t);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.byType(SegmentedButton<AppearanceMode>), findsOneWidget);
    expect(
      find.byType(CupertinoSlidingSegmentedControl<AppearanceMode>),
      findsNothing,
    );
    final seg = find.byKey(const Key('settings-appearance'));
    for (final s in ['System', 'Light', 'Dark']) {
      expect(find.descendant(of: seg, matching: find.text(s)), findsOneWidget);
    }
    await t.tap(find.descendant(of: seg, matching: find.text('Dark')));
    await t.pumpAndSettle();
    expect(c.read(appearanceProvider), AppearanceMode.dark);
  });

  testWidgets('iOS: CupertinoSlidingSegmentedControl; Dark updates', (t) async {
    final c = await _pump(t, platform: TargetPlatform.iOS);
    expect(
      find.byType(CupertinoSlidingSegmentedControl<AppearanceMode>),
      findsOneWidget,
    );
    expect(find.byType(SegmentedButton<AppearanceMode>), findsNothing);
    final seg = find.byKey(const Key('settings-appearance'));
    await t.tap(find.descendant(of: seg, matching: find.text('Dark')));
    await t.pumpAndSettle();
    expect(c.read(appearanceProvider), AppearanceMode.dark);
  });

  testWidgets('zh labels render', (t) async {
    await _pump(t, locale: const Locale('zh'));
    expect(find.text('外观'), findsOneWidget);
    final seg = find.byKey(const Key('settings-appearance'));
    for (final s in ['跟随系统', '浅色', '深色']) {
      expect(find.descendant(of: seg, matching: find.text(s)), findsOneWidget);
    }
  });
}
