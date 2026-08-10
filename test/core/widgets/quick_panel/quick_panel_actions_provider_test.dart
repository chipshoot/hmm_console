import 'package:flutter/material.dart';
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
      expect(labelsFor('/gas-logs/17'), contains('New Gas Log'));
    });

    test('the create screen itself drops the create action', () {
      // Previously '/gas-logs/new' still offered "New Gas Log", which would
      // push a second editor on top of the one being filled in.
      expect(labelsFor('/gas-logs/new'), ['Home', 'Sync']);
      expect(labelsFor('/notes/new'), ['Home', 'Sync']);
    });

    test('every other list screen gets its own create', () {
      expect(labelsFor('/cheatsheets'), ['Home', 'New Cheatsheet', 'Sync']);
      expect(labelsFor('/automobiles/manage'),
          ['Home', 'New Vehicle', 'Sync']);
      expect(labelsFor('/automobiles/manage/7/services'),
          ['Home', 'New Service', 'Sync']);
      expect(labelsFor('/automobiles/manage/7/insurance'),
          ['Home', 'New Policy', 'Sync']);
      expect(labelsFor('/automobiles/manage/7/scheduled-services'),
          ['Home', 'New Scheduled Service', 'Sync']);
    });

    test('a vehicle-scoped rule beats the bare vehicle rule', () {
      // Rule order is load-bearing: '/automobiles/manage' would otherwise
      // swallow every screen beneath it and offer "New Vehicle" on all.
      // Asserted positively AND negatively — 'isNot(contains(...))' alone
      // would also pass in a world where neither rule fired.
      expect(labelsFor('/automobiles/manage/7/services'),
          ['Home', 'New Service', 'Sync']);
      expect(labelsFor('/automobiles/manage/7/services'),
          isNot(contains('New Vehicle')));
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

  group('create target', () {
    test('list screens push their own new route', () {
      expect(quickPanelCreateTargetFor('/notes'), '/notes/new');
      expect(quickPanelCreateTargetFor('/gas-logs'), '/gas-logs/new');
      expect(quickPanelCreateTargetFor('/cheatsheets'), '/cheatsheets/new');
    });

    test('a detail screen pushes the LIST create, not path + /new', () {
      // The bug this guards: deriving from the full path gives
      // '/notes/42/new', which is not a route in the app.
      expect(quickPanelCreateTargetFor('/notes/42'), '/notes/new');
      expect(quickPanelCreateTargetFor('/gas-logs/17'), '/gas-logs/new');
    });

    test('vehicle-scoped creates keep the concrete vehicle id', () {
      expect(quickPanelCreateTargetFor('/automobiles/manage/7/services'),
          '/automobiles/manage/7/services/new');
      expect(quickPanelCreateTargetFor('/automobiles/manage/12/insurance'),
          '/automobiles/manage/12/insurance/new');
      expect(
          quickPanelCreateTargetFor(
              '/automobiles/manage/3/scheduled-services'),
          '/automobiles/manage/3/scheduled-services/new');
    });

    test('an edit screen pushes the list create, not a nested one', () {
      expect(
          quickPanelCreateTargetFor('/automobiles/manage/7/services/99/edit'),
          '/automobiles/manage/7/services/new');
    });

    test('screens with no create return null', () {
      expect(quickPanelCreateTargetFor('/'), isNull);
      expect(quickPanelCreateTargetFor('/settings'), isNull);
      expect(quickPanelCreateTargetFor('/gas-stations'), isNull);
      expect(quickPanelCreateTargetFor('/notes/new'), isNull);
    });
  });

  test('each create action carries its OWN icon', () {
    // Swapping two icons in the 7-row rule table previously survived every
    // test — 'isNotNull' is not an identity check, and the table is seven
    // near-identical lines where a copy-paste slip is exactly the mistake
    // you would make.
    IconData iconFor(String path, String label) => quickPanelActionsFor(path)
        .firstWhere((a) => a.label == label)
        .icon!;

    expect(iconFor('/notes', 'New Note'), Icons.note_add_outlined);
    expect(iconFor('/gas-logs', 'New Gas Log'),
        Icons.local_gas_station_outlined);
    expect(iconFor('/cheatsheets', 'New Cheatsheet'), Icons.style_outlined);
    expect(iconFor('/automobiles/manage', 'New Vehicle'),
        Icons.directions_car_outlined);
    expect(iconFor('/automobiles/manage/7/services', 'New Service'),
        Icons.build_outlined);
    expect(iconFor('/automobiles/manage/7/insurance', 'New Policy'),
        Icons.shield_outlined);
    expect(
        iconFor('/automobiles/manage/7/scheduled-services',
            'New Scheduled Service'),
        Icons.event_outlined);
    expect(iconFor('/notes', 'Home'), Icons.home_outlined);
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
