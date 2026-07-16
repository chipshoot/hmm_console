import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_actions_provider.dart';

void main() {
  test('registry ships Home + Sync in order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final actions = container.read(quickPanelActionsProvider);
    expect(actions.map((a) => a.label).toList(), ['Home', 'Sync']);
  });

  test('Home is a simple action; Sync is a custom builder action', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final actions = container.read(quickPanelActionsProvider);
    final home = actions.firstWhere((a) => a.label == 'Home');
    final sync = actions.firstWhere((a) => a.label == 'Sync');

    // Home: simple icon+tap action.
    expect(home.isCustom, isFalse);
    expect(home.icon, isNotNull);
    expect(home.onTap, isNotNull);
    expect(home.builder, isNull);

    // Sync: custom builder action (no icon/onTap).
    expect(sync.isCustom, isTrue);
    expect(sync.builder, isNotNull);
    expect(sync.icon, isNull);
    expect(sync.onTap, isNull);
    // NOTE: do NOT invoke sync.builder!(context, ref) here — WidgetRef is a
    // sealed class in flutter_riverpod 3.0.3 and cannot be faked/implemented
    // outside its library. That the Sync builder renders a live SyncPill is
    // verified end-to-end by Task 4's overlay reveal test, which pumps the
    // real registry through the real QuickAccessPanel.
  });
}
