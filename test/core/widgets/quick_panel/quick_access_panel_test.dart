import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_access_panel.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_action.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_actions_provider.dart';

Future<void> _pump(WidgetTester tester,
    {required List<QuickPanelAction> actions,
    required VoidCallback onDismiss}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [quickPanelActionsProvider.overrideWithValue(actions)],
      child: MaterialApp(
        home: Scaffold(body: QuickAccessPanel(onDismiss: onDismiss)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders one tile per registry action, in order',
      (tester) async {
    await _pump(tester, onDismiss: () {}, actions: [
      QuickPanelAction.simple(
          label: 'Home', icon: Icons.home_outlined, onTap: (_) {}),
      QuickPanelAction.custom(
          label: 'Sync', builder: (c, r) => const Text('SYNC-WIDGET')),
    ]);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('SYNC-WIDGET'), findsOneWidget);
  });

  testWidgets('tapping a simple action runs onTap then onDismiss',
      (tester) async {
    var tapped = false;
    var dismissed = false;
    await _pump(tester, onDismiss: () => dismissed = true, actions: [
      QuickPanelAction.simple(
          label: 'Home', icon: Icons.home_outlined, onTap: (_) => tapped = true),
    ]);
    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(dismissed, isTrue);
  });

  testWidgets('extension point: an injected 3rd action appears', (tester) async {
    await _pump(tester, onDismiss: () {}, actions: [
      QuickPanelAction.simple(
          label: 'Home', icon: Icons.home_outlined, onTap: (_) {}),
      QuickPanelAction.simple(label: 'New note', icon: Icons.add, onTap: (_) {}),
      QuickPanelAction.simple(label: 'Search', icon: Icons.search, onTap: (_) {}),
    ]);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('panel surface is half-transparent', (tester) async {
    await _pump(tester, onDismiss: () {}, actions: [
      QuickPanelAction.simple(
          label: 'Home', icon: Icons.home_outlined, onTap: (_) {}),
    ]);
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(QuickAccessPanel),
        matching: find.byType(Material),
      ).first,
    );
    expect(material.color!.a, lessThan(1.0));
  });
}
