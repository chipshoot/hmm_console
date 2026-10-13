import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cover_action_sheet.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/emoji_picker.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  Future<List<T?>> open<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext) show, {
    TargetPlatform platform = TargetPlatform.android,
    Locale? locale,
  }) async {
    final results = <T?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () async => results.add(await show(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return results;
  }

  group('emoji picker', () {
    testWidgets('groups the curated emoji and returns the tapped one', (
      tester,
    ) async {
      final results = await open<String>(tester, (c) => showEmojiPicker(c));

      expect(find.byKey(const Key('emoji-group-vehicle')), findsOneWidget);
      expect(find.text('Vehicle'), findsOneWidget);
      await tester.tap(find.byKey(const Key('emoji-\u{1F697}')));
      await tester.pumpAndSettle();

      expect(results, ['\u{1F697}']);
    });

    testWidgets('searches English and Chinese keywords', (tester) async {
      await open<String>(tester, (c) => showEmojiPicker(c));

      await tester.enterText(find.byKey(const Key('emoji-search')), 'passport');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-\u{1F6C2}')), findsOneWidget);
      expect(find.byKey(const Key('emoji-\u{1F697}')), findsNothing);

      await tester.enterText(find.byKey(const Key('emoji-search')), '护照');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-\u{1F6C2}')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('emoji-search')), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-no-matches')), findsOneWidget);
    });

    testWidgets('free typing accepts one emoji and rejects anything else', (
      tester,
    ) async {
      final results = await open<String>(tester, (c) => showEmojiPicker(c));

      await tester.enterText(find.byKey(const Key('emoji-custom')), 'abc');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('emoji-custom-use')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('emoji-custom-error')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('emoji-custom')),
        '\u{1F984}',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('emoji-custom-use')));
      await tester.pumpAndSettle();

      expect(results, ['\u{1F984}']);
    });

    testWidgets('allowClear offers No emoji, which returns an empty string', (
      tester,
    ) async {
      final results = await open<String>(
        tester,
        (c) => showEmojiPicker(c, allowClear: true),
      );

      await tester.tap(find.byKey(const Key('emoji-clear')));
      await tester.pumpAndSettle();

      expect(results, ['']);
    });

    testWidgets('without allowClear there is no No emoji option', (
      tester,
    ) async {
      await open<String>(tester, (c) => showEmojiPicker(c));
      expect(find.byKey(const Key('emoji-clear')), findsNothing);
    });

    testWidgets('iOS opens a Cupertino popup with a Cupertino search field', (
      tester,
    ) async {
      await open<String>(
        tester,
        (c) => showEmojiPicker(c),
        platform: TargetPlatform.iOS,
      );

      expect(find.byType(CupertinoPopupSurface), findsOneWidget);
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    });

    testWidgets('group headings are translated', (tester) async {
      await open<String>(
        tester,
        (c) => showEmojiPicker(c),
        locale: const Locale('zh'),
      );
      expect(find.text('车辆'), findsOneWidget);
    });
  });

  group('cover action sheet', () {
    testWidgets('Android offers camera and library; scan and remove only when '
        'available', (tester) async {
      final results = await open<CoverAction>(
        tester,
        (c) => showCoverActionSheet(c, hasCover: false, canScan: false),
      );

      expect(find.byKey(const Key('cover-camera')), findsOneWidget);
      expect(find.byKey(const Key('cover-library')), findsOneWidget);
      expect(find.byKey(const Key('cover-scan')), findsNothing);
      expect(find.byKey(const Key('cover-remove')), findsNothing);

      await tester.tap(find.byKey(const Key('cover-library')));
      await tester.pumpAndSettle();
      expect(results, [CoverAction.library]);
    });

    testWidgets('scan and remove appear when offered', (tester) async {
      final results = await open<CoverAction>(
        tester,
        (c) => showCoverActionSheet(c, hasCover: true, canScan: true),
      );

      expect(find.byKey(const Key('cover-scan')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cover-remove')));
      await tester.pumpAndSettle();
      expect(results, [CoverAction.remove]);
    });

    testWidgets('iOS uses a Cupertino action sheet', (tester) async {
      final results = await open<CoverAction>(
        tester,
        (c) => showCoverActionSheet(c, hasCover: false, canScan: true),
        platform: TargetPlatform.iOS,
      );

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('cover-camera')));
      await tester.pumpAndSettle();
      expect(results, [CoverAction.camera]);
    });
  });
}
