import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/inline_video_player.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import 'fake_video_controller.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 640, height: 360, child: child)),
  ),
);

void main() {
  late FakeVideoController controller;
  Duration? reported;
  var failed = 0;
  var closed = 0;
  var disposedAtClose = false;

  setUp(() {
    controller = FakeVideoController();
    reported = null;
    failed = 0;
    closed = 0;
    disposedAtClose = false;
  });

  Future<void> pumpPlayer(WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        InlineVideoPlayer(
          file: File('/v/u1.mov'),
          aspectRatio: 16 / 9,
          onFullScreen: (p) async {
            reported = p;
            return null;
          },
          onInitFailed: () => failed++,
          onClosed: () {
            closed++;
            disposedAtClose = controller.disposed;
          },
          controllerFactory: (_) => controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows play/pause, a slider and the time', (tester) async {
    await pumpPlayer(tester);
    expect(controller.calls, ['initialize', 'play']);
    // Playing, so the button offers Pause.
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('0:48'), findsOneWidget);
    expect(find.byTooltip('Full screen'), findsOneWidget);
  });

  testWidgets('pause toggles the controller', (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(controller.calls.last, 'pause');
    expect(find.byTooltip('Play video'), findsOneWidget);
    await tester.tap(find.byTooltip('Play video'));
    await tester.pump();
    expect(controller.calls.last, 'play');
  });

  testWidgets('the full-screen button reports the current position', (
    tester,
  ) async {
    await pumpPlayer(tester);
    await controller.seekTo(const Duration(seconds: 12));
    await tester.pump();
    expect(find.text('0:12'), findsOneWidget);
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    expect(controller.calls.last, 'pause');
    expect(reported, const Duration(seconds: 12));
  });

  testWidgets('disposing the widget disposes the controller', (tester) async {
    await pumpPlayer(tester);
    await tester.pumpWidget(_wrap(const SizedBox()));
    expect(controller.disposed, isTrue);
  });

  testWidgets('closing the player reports it once, after the controller is '
      'disposed, so audio can be handed back', (tester) async {
    await pumpPlayer(tester);
    expect(closed, 0);
    await tester.pumpWidget(_wrap(const SizedBox()));
    await tester.pump();
    expect(closed, 1);
    expect(disposedAtClose, isTrue);
  });

  testWidgets('a failed start reports it and does not play', (tester) async {
    controller = FakeVideoController(failInit: true);
    await pumpPlayer(tester);
    expect(failed, 1);
    expect(controller.calls, ['initialize']);
  });

  testWidgets('dragging the scrubber moves the time label, and releasing '
      'seeks to the chosen position', (tester) async {
    await pumpPlayer(tester);
    final box = tester.getRect(find.byType(Slider));
    final gesture = await tester.startGesture(
      Offset(box.left + 24, box.center.dy),
    );
    await gesture.moveTo(Offset(box.center.dx, box.center.dy));
    await tester.pump();
    // Mid-drag the label follows the thumb but nothing has been sought yet.
    expect(find.text('0:00'), findsNothing);
    expect(controller.calls.where((c) => c.startsWith('seekTo')), isEmpty);
    final slider = tester.widget<Slider>(find.byType(Slider));
    final chosenMs = slider.value;
    expect(chosenMs, greaterThan(15000));
    expect(chosenMs, lessThan(33000));

    await gesture.up();
    await tester.pump();
    await tester.pump();
    expect(controller.calls.last, 'seekTo ${chosenMs.round()}');
    expect(controller.value.position.inMilliseconds, chosenMs.round());
    final secs = (chosenMs / 1000).floor();
    expect(find.text('0:$secs'), findsOneWidget);
  });
}
