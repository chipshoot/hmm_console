import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/undoable_action.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _Probe {
  bool failRun = false;
  bool failUndo = false;
  final calls = <String>[];
  int changed = 0;
}

/// Home screen with a "go" button that pushes a second screen, whose "act"
/// button triggers the undoable action. Lets a test leave the screen before
/// tapping Undo.
Widget _app(_Probe p) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (home) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(home).push(MaterialPageRoute(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  onPressed: () => showUndoableAction(
                    ctx,
                    run: () async {
                      p.calls.add('run');
                      if (p.failRun) throw StateError('offline');
                    },
                    undo: () async {
                      p.calls.add('undo');
                      if (p.failUndo) throw StateError('offline');
                    },
                    done: 'Moved',
                    failed: 'Move failed',
                    undone: 'Restored',
                    undoFailed: 'Restore failed',
                    onChanged: () => p.changed++,
                  ),
                  child: const Text('act'),
                ),
              ),
            )),
            child: const Text('go'),
          ),
        ),
      ),
    );

Future<void> _act(WidgetTester tester, _Probe p) async {
  await tester.pumpWidget(_app(p));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('act'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('success: says what happened and offers Undo', (tester) async {
    final p = _Probe();
    await _act(tester, p);
    expect(find.text('Moved'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(p.changed, 1);
  });

  testWidgets('failure: says so, no Undo, nothing reloaded', (tester) async {
    final p = _Probe()..failRun = true;
    await _act(tester, p);
    expect(find.text('Move failed'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(p.changed, 0);
  });

  testWidgets('Undo succeeds', (tester) async {
    final p = _Probe();
    await _act(tester, p);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(p.calls, ['run', 'undo']);
    expect(find.text('Restored'), findsOneWidget);
    expect(p.changed, 2);
  });

  testWidgets('Undo fails: says where the item is', (tester) async {
    final p = _Probe()..failUndo = true;
    await _act(tester, p);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Restore failed'), findsOneWidget);
    expect(p.changed, 1);
  });

  testWidgets('Undo still works after leaving the screen', (tester) async {
    final p = _Probe();
    await _act(tester, p);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget); // back on the home screen
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Restored'), findsOneWidget);
  });

  testWidgets('the Undo snackbar goes away by itself', (tester) async {
    final p = _Probe();
    await _act(tester, p);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Moved'), findsNothing);
  });
}
