import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/hmm_icon_button.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('long-press shows the tooltip', (tester) async {
    await tester.pumpWidget(
      _host(
        HmmIconButton(
          icon: Icons.link_off,
          tooltip: 'Detach note',
          onPressed: () {},
        ),
      ),
    );
    expect(find.byTooltip('Detach note'), findsOneWidget);
    await tester.longPress(find.byType(HmmIconButton));
    await tester.pumpAndSettle();
    expect(find.text('Detach note'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // let the tooltip timer end
  });

  testWidgets('a blank tooltip is rejected', (tester) async {
    await tester.pumpWidget(
      _host(
        const HmmIconButton(icon: Icons.add, tooltip: '  ', onPressed: null),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('tap calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        HmmIconButton(icon: Icons.add, tooltip: 'Add', onPressed: () => taps++),
      ),
    );
    await tester.tap(find.byType(HmmIconButton));
    expect(taps, 1);
  });

  testWidgets('badge only for a count of 1 or more', (tester) async {
    for (final (count, badged) in [(null, false), (0, false), (2, true)]) {
      await tester.pumpWidget(
        _host(
          HmmIconButton(
            icon: Icons.sticky_note_2_outlined,
            tooltip: 'Notes',
            badgeCount: count,
            onPressed: () {},
          ),
        ),
      );
      expect(
        find.byType(Badge),
        badged ? findsOneWidget : findsNothing,
        reason: 'count=$count',
      );
      if (badged) expect(find.widgetWithText(Badge, '2'), findsOneWidget);
    }
  });

  testWidgets('each style renders an IconButton', (tester) async {
    for (final style in HmmIconButtonStyle.values) {
      await tester.pumpWidget(
        _host(
          HmmIconButton(
            icon: Icons.add,
            tooltip: 'Add',
            style: style,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(IconButton), findsOneWidget, reason: '$style');
    }
  });

  group('Apple look on iOS', () {
    Widget host(TargetPlatform p, VoidCallback? onPressed) => MaterialApp(
      theme: ThemeData(platform: p, colorSchemeSeed: Colors.deepPurple),
      home: Scaffold(
        body: Center(
          child: HmmIconButton(
            icon: CupertinoIcons.question_circle,
            tooltip: 'Help',
            onPressed: onPressed,
          ),
        ),
      ),
    );

    testWidgets('iOS draws a 22 pt glyph in the accent colour', (t) async {
      var taps = 0;
      await t.pumpWidget(host(TargetPlatform.iOS, () => taps++));
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(CupertinoButton), findsOneWidget);
      final icon = t.widget<Icon>(find.byType(Icon));
      final theme = Theme.of(t.element(find.byType(HmmIconButton)));
      final style = IconTheme.of(t.element(find.byType(Icon)));
      expect(icon.size ?? style.size, 22);
      expect(icon.color ?? style.color, theme.colorScheme.primary);
      expect(
        t.getSize(find.byType(CupertinoButton)).height,
        greaterThanOrEqualTo(44),
      );
      expect(find.byTooltip('Help'), findsOneWidget);
      await t.tap(find.byType(HmmIconButton));
      expect(taps, 1);
    });

    testWidgets('a disabled iOS button is grey and does nothing', (t) async {
      await t.pumpWidget(host(TargetPlatform.iOS, null));
      final style = IconTheme.of(t.element(find.byType(Icon)));
      expect(style.color, CupertinoColors.inactiveGray);
    });

    testWidgets('Android keeps the Material icon button', (t) async {
      await t.pumpWidget(host(TargetPlatform.android, () {}));
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(CupertinoButton), findsNothing);
    });
  });
}
