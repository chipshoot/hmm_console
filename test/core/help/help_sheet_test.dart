import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

Widget _app({Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(actions: const [HelpButton(helpId: HelpId.vehicleNotes)]),
      ),
    );

void main() {
  testWidgets('the ? button opens that screen\'s help', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Car notes'), findsOneWidget);
    expect(find.text('Detach'), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
  });

  testWidgets('Material bottom sheet on Android', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Cupertino popup on iOS', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPopupSurface), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Close dismisses the sheet on both platforms', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Car notes'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Close dismisses the Android sheet too', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Car notes'), findsNothing);
  });

  testWidgets('Chinese help fits a small phone and scrolls', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(locale: const Locale('zh')));
    await tester.tap(find.byTooltip('帮助'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no RenderFlex overflow
    expect(find.text('车辆备注'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('打开备注'), findsOneWidget);
  });
}
