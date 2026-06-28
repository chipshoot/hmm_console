import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/launcher/presentation/launcher_search_screen.dart';
import 'package:hmm_console/features/launcher/providers/launcher_prefs_provider.dart';
import 'package:hmm_console/features/launcher/domain/launcher_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Minimal router: launcher search at '/', a stub Notes target so a tap
// has somewhere to land.
GoRouter _router() => GoRouter(routes: [
      GoRoute(path: '/', name: 'home', builder: (_, __) => const LauncherSearchScreen()),
      GoRoute(
          path: '/notes',
          name: 'notesList',
          builder: (_, __) => const Scaffold(body: Text('NOTES SCREEN'))),
    ]);

class _StubPrefs extends LauncherPrefsNotifier {
  _StubPrefs(this._initial);
  final LauncherPrefs _initial;
  @override
  LauncherPrefs build() => _initial;
}

Future<void> _pump(WidgetTester t, {LauncherPrefs prefs = LauncherPrefs.empty}) async {
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(ProviderScope(
    overrides: [
      launcherPrefsProvider.overrideWith(() => _StubPrefs(prefs)),
    ],
    child: MaterialApp.router(routerConfig: _router()),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('command mode "/no" shows Notes; tap navigates', (t) async {
    await _pump(t);
    await t.enterText(find.byType(TextField), '/no');
    await t.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
    await t.tap(find.text('Notes'));
    await t.pumpAndSettle();
    expect(find.text('NOTES SCREEN'), findsOneWidget);
  });

  testWidgets('assistant mode (plain text) shows the coming-soon stub, no results', (t) async {
    await _pump(t);
    await t.enterText(find.byType(TextField), 'gas');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('assistant-stub')), findsOneWidget);
    expect(find.text('Gas Log'), findsNothing);
  });

  testWidgets('lone "/" shows the favorites landing', (t) async {
    await _pump(t, prefs: const LauncherPrefs(favorites: ['notes']));
    await t.enterText(find.byType(TextField), '/');
    await t.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget); // favorite resolved
  });
}
