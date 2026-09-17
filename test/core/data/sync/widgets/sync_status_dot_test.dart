import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/sync_indicator_state.dart';
import 'package:hmm_console/core/data/sync/widgets/sync_status_dot.dart';

const _visible = [
  SyncIndicatorState.synced,
  SyncIndicatorState.syncing,
  SyncIndicatorState.waiting,
  SyncIndicatorState.failed,
];

void main() {
  // A single pump, never pumpAndSettle: the syncing pulse repeats forever,
  // so settling would never return.
  Future<void> pump(WidgetTester tester, SyncIndicatorState s,
      {bool reducedMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: Center(child: SyncStatusDot(state: s))),
      ),
    ));
    await tester.pump();
  }

  testWidgets('none renders nothing at all', (tester) async {
    await pump(tester, SyncIndicatorState.none);
    expect(find.byKey(const Key('syncStatusDot')), findsNothing);
  });

  for (final s in _visible) {
    testWidgets('$s renders a dot', (tester) async {
      await pump(tester, s);
      expect(find.byKey(const Key('syncStatusDot')), findsOneWidget);
    });
  }

  testWidgets('each visible state is a DIFFERENT colour', (tester) async {
    // The whole point is telling them apart at a glance.
    final colours = <Color>{};
    for (final s in _visible) {
      await pump(tester, s);
      final box = tester
          .widget<DecoratedBox>(find.byKey(const Key('syncStatusFill')));
      colours.add((box.decoration as BoxDecoration).color!);
    }
    expect(colours, hasLength(_visible.length));
  });

  testWidgets('syncing pulses, and the pulse honours reduced motion',
      (tester) async {
    await pump(tester, SyncIndicatorState.syncing);
    expect(find.byKey(const Key('syncStatusPulse')), findsOneWidget);

    await pump(tester, SyncIndicatorState.syncing, reducedMotion: true);
    expect(find.byKey(const Key('syncStatusPulse')), findsNothing);
  });

  testWidgets('a settled state does not pulse', (tester) async {
    await pump(tester, SyncIndicatorState.synced);
    expect(find.byKey(const Key('syncStatusPulse')), findsNothing);
  });

  testWidgets('the non-green states carry a shape, not just a colour',
      (tester) async {
    // Green and orange differ by hue alone (luminance contrast 1.08), which
    // red-green colour-blind users cannot see. A "waiting" that reads as
    // "synced" is the quiet lie this feature exists to prevent, so those
    // states carry a glyph too.
    await pump(tester, SyncIndicatorState.waiting);
    expect(find.byKey(const Key('syncStatusGlyphWaiting')), findsOneWidget);

    await pump(tester, SyncIndicatorState.failed);
    expect(find.byKey(const Key('syncStatusGlyphFailed')), findsOneWidget);

    await pump(tester, SyncIndicatorState.synced);
    expect(find.byKey(const Key('syncStatusGlyphWaiting')), findsNothing);
    expect(find.byKey(const Key('syncStatusGlyphFailed')), findsNothing);
  });
}
