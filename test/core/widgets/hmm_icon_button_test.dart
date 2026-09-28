import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/hmm_icon_button.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('long-press shows the tooltip', (tester) async {
    await tester.pumpWidget(_host(HmmIconButton(
        icon: Icons.link_off, tooltip: 'Detach note', onPressed: () {})));
    expect(find.byTooltip('Detach note'), findsOneWidget);
    await tester.longPress(find.byType(HmmIconButton));
    await tester.pumpAndSettle();
    expect(find.text('Detach note'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // let the tooltip timer end
  });

  testWidgets('a blank tooltip is rejected', (tester) async {
    await tester.pumpWidget(_host(
        const HmmIconButton(icon: Icons.add, tooltip: '  ', onPressed: null)));
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('tap calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(HmmIconButton(
        icon: Icons.add, tooltip: 'Add', onPressed: () => taps++)));
    await tester.tap(find.byType(HmmIconButton));
    expect(taps, 1);
  });

  testWidgets('badge only for a count of 1 or more', (tester) async {
    for (final (count, badged) in [(null, false), (0, false), (2, true)]) {
      await tester.pumpWidget(_host(HmmIconButton(
          icon: Icons.sticky_note_2_outlined,
          tooltip: 'Notes',
          badgeCount: count,
          onPressed: () {})));
      expect(find.byType(Badge), badged ? findsOneWidget : findsNothing,
          reason: 'count=$count');
      if (badged) expect(find.widgetWithText(Badge, '2'), findsOneWidget);
    }
  });

  testWidgets('each style renders an IconButton', (tester) async {
    for (final style in HmmIconButtonStyle.values) {
      await tester.pumpWidget(_host(HmmIconButton(
          icon: Icons.add, tooltip: 'Add', style: style, onPressed: () {})));
      expect(find.byType(IconButton), findsOneWidget, reason: '$style');
    }
  });
}
