import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_prefs.dart';
import 'package:hmm_console/features/launcher/presentation/launcher_manage_screen.dart';
import 'package:hmm_console/features/launcher/providers/launcher_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubPrefs extends LauncherPrefsNotifier {
  @override
  LauncherPrefs build() => LauncherPrefs.empty;
}

class _StubPrefsWith extends LauncherPrefsNotifier {
  _StubPrefsWith(this._initial);
  final LauncherPrefs _initial;
  @override
  LauncherPrefs build() => _initial;
}

/// Tall viewport so the whole (lazy ListView) screen lays out and every
/// keyed field is built — avoids off-screen "No element" in enterText.
void _tallViewport(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

Future<ProviderContainer> _pump(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  _tallViewport(t);
  final c = ProviderContainer(
      overrides: [launcherPrefsProvider.overrideWith(() => _StubPrefs())]);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(home: LauncherManageScreen()),
  ));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('pinning a destination adds it to favorites', (t) async {
    final c = await _pump(t);
    // The "Gas Log" row has a star toggle; tap it.
    await t.tap(find.byKey(const Key('fav-toggle-gasLog')));
    await t.pumpAndSettle();
    expect(c.read(launcherPrefsProvider).favorites.contains('gasLog'), isTrue);
  });

  testWidgets('adding an alias stores alias -> id', (t) async {
    final c = await _pump(t);
    await t.enterText(find.byKey(const Key('alias-text')), 'cs');
    // pick a destination from the dropdown
    await t.tap(find.byKey(const Key('alias-dest')));
    await t.pumpAndSettle();
    await t.tap(find.text('Service Log').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('alias-add')));
    await t.pumpAndSettle();
    expect(c.read(launcherPrefsProvider).aliases['cs'], 'serviceRecords');
  });

  testWidgets('reordering pinned favorites calls setFavorites', (t) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(overrides: [
      launcherPrefsProvider.overrideWith(() => _StubPrefsWith(
          const LauncherPrefs(favorites: ['gasLog', 'notes', 'settings']))),
    ]);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: LauncherManageScreen()),
    ));
    await t.pumpAndSettle();
    // Drive the reorder callback directly (drag gestures are flaky in tests).
    final reorderable =
        t.widget<ReorderableListView>(find.byKey(const Key('pinned-reorder')));
    reorderable.onReorder(0, 3); // move 'gasLog' to the end
    await t.pumpAndSettle();
    expect(c.read(launcherPrefsProvider).favorites, ['notes', 'settings', 'gasLog']);
  });
}
