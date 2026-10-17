import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/theme.dart';
import 'package:hmm_console/features/settings/providers/appearance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors main.dart's wiring: themeMode comes from appearanceProvider.
class _App extends ConsumerWidget {
  const _App({required this.onBuild});
  final void Function(BuildContext) onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.lightThemeData,
      darkTheme: AppTheme.darkThemeData,
      themeMode: ref.watch(appearanceProvider).themeMode,
      home: Builder(
        builder: (c) {
          onBuild(c);
          return const SizedBox();
        },
      ),
    );
  }
}

void main() {
  Future<(ProviderContainer, List<Brightness>, List<Brightness>)> pump(
    WidgetTester t,
    Brightness platform,
    AppearanceMode? mode,
  ) async {
    SharedPreferences.setMockInitialValues({});
    t.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final material = <Brightness>[];
    final cupertino = <Brightness>[];
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: _App(
          onBuild: (ctx) {
            material.add(Theme.of(ctx).brightness);
            cupertino.add(CupertinoTheme.brightnessOf(ctx));
          },
        ),
      ),
    );
    if (mode != null) {
      await c.read(appearanceProvider.notifier).set(mode);
      await t.pumpAndSettle(); // AnimatedTheme interpolates
    }
    return (c, material, cupertino);
  }

  testWidgets('dark wins over a light platform, incl. Cupertino', (t) async {
    final (_, m, cu) = await pump(t, Brightness.light, AppearanceMode.dark);
    expect(m.last, Brightness.dark);
    expect(cu.last, Brightness.dark);
  });

  testWidgets('light wins over a dark platform', (t) async {
    final (_, m, _) = await pump(t, Brightness.dark, AppearanceMode.light);
    expect(m.last, Brightness.light);
  });

  testWidgets('system follows a light platform', (t) async {
    final (_, m, _) = await pump(t, Brightness.light, null);
    expect(m.last, Brightness.light);
  });

  testWidgets('system follows a dark platform', (t) async {
    final (_, m, _) = await pump(t, Brightness.dark, null);
    expect(m.last, Brightness.dark);
  });

  testWidgets('initial Dark resolves dark on the very first frame', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    final seen = <Brightness>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppearanceProvider.overrideWithValue(AppearanceMode.dark),
        ],
        child: _App(onBuild: (c) => seen.add(Theme.of(c).brightness)),
      ),
    );
    expect(seen.first, Brightness.dark);
  });
}
