import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_actions_provider.dart';

List<String> labelsFor(String path) =>
    quickPanelActionsFor(path).map((a) => a.label).toList();

void main() {
  group('screen-aware contents', () {
    test('home drops the Home action — it would appear to do nothing', () {
      expect(labelsFor('/'), ['Sync']);
    });

    test('the notes list offers New Note, not New Gas Log', () {
      expect(labelsFor('/notes'), ['Home', 'New Note', 'Sync']);
    });

    test('the gas log list offers New Gas Log, not New Note', () {
      expect(labelsFor('/gas-logs'), ['Home', 'New Gas Log', 'Sync']);
    });

    test('a screen with no create action still gets Home and Sync', () {
      expect(labelsFor('/settings'), ['Home', 'Sync']);
    });

    test('create actions follow their subtree', () {
      expect(labelsFor('/notes/42'), contains('New Note'));
      expect(labelsFor('/gas-logs/new'), contains('New Gas Log'));
    });

    test('a lookalike path does not trigger a create action', () {
      // '/notesomething' must not count as being in Notes.
      expect(labelsFor('/notesomething'), ['Home', 'Sync']);
    });

    test('Sync is present everywhere', () {
      for (final p in ['/', '/notes', '/gas-logs', '/settings']) {
        expect(labelsFor(p), contains('Sync'), reason: 'missing on $p');
      }
    });
  });

  test('Home is a simple action; Sync is a custom builder action', () {
    final actions = quickPanelActionsFor('/notes');
    final home = actions.firstWhere((a) => a.label == 'Home');
    final sync = actions.firstWhere((a) => a.label == 'Sync');

    expect(home.isCustom, isFalse);
    expect(home.icon, isNotNull);
    expect(home.onTap, isNotNull);

    // NOTE: do NOT invoke sync.builder!(context, ref) here — WidgetRef is a
    // sealed class in flutter_riverpod 3.0.3 and cannot be faked/implemented
    // outside its library. That the Sync builder renders a live SyncPill is
    // verified end-to-end by the overlay reveal test, which pumps the real
    // registry through the real QuickAccessPanel.
    expect(sync.isCustom, isTrue);
    expect(sync.builder, isNotNull);
    expect(sync.icon, isNull);
    expect(sync.onTap, isNull);
  });

  test('the create actions are simple tap actions with icons', () {
    for (final (path, label) in [
      ('/notes', 'New Note'),
      ('/gas-logs', 'New Gas Log'),
    ]) {
      final action =
          quickPanelActionsFor(path).firstWhere((a) => a.label == label);
      expect(action.isCustom, isFalse, reason: '$label is a simple tile');
      expect(action.icon, isNotNull);
      expect(action.onTap, isNotNull);
    }
  });

  test('the provider returns the same list as the pure rule', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(quickPanelActionsProvider('/notes')).map((a) => a.label),
      labelsFor('/notes'),
    );
  });
}
