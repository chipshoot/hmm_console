import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_flag.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_flag_sheet.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

Widget _host(
  TargetPlatform platform,
  NoteFlagColor? current,
  void Function(NoteFlagChoice?) onResult,
) => MaterialApp(
  theme: ThemeData(platform: platform),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (ctx) => TextButton(
        onPressed: () async =>
            onResult(await showNoteFlagSheet(ctx, current: current)),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'Android: a bottom sheet with seven named colours, no Clear when unflagged',
    (tester) async {
      NoteFlagChoice? result;
      await tester.pumpWidget(
        _host(TargetPlatform.android, null, (r) => result = r),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsNothing);
      for (final name in [
        'Red',
        'Orange',
        'Yellow',
        'Green',
        'Blue',
        'Purple',
        'Grey',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Clear flag'), findsNothing);

      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();
      expect(result!.color, NoteFlagColor.blue);
    },
  );

  testWidgets(
    'iOS: a Cupertino action sheet; Clear flag returns a null colour',
    (tester) async {
      NoteFlagChoice? result;
      await tester.pumpWidget(
        _host(TargetPlatform.iOS, NoteFlagColor.red, (r) => result = r),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Clear flag'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.color, isNull);
    },
  );

  testWidgets('Cancel returns null (nothing changes)', (tester) async {
    NoteFlagChoice? result = const NoteFlagChoice(NoteFlagColor.red);
    await tester.pumpWidget(_host(TargetPlatform.iOS, null, (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('labels are localized in zh', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            final l = AppLocalizations.of(ctx);
            return Text(noteFlagColorLabel(NoteFlagColor.purple, l));
          },
        ),
      ),
    );
    expect(find.text('紫色'), findsOneWidget);
  });
}
