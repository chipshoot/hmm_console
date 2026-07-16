import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_coach_mark.dart';

void main() {
  testWidgets('shows the hint copy and fires onDismiss on "Got it"',
      (tester) async {
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        QuickPanelCoachMark(onDismiss: () => dismissed = true),
      ]),
    ));
    expect(find.textContaining('Long-press'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(dismissed, isTrue);
  });
}
