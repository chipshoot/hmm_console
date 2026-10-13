import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/scanner/document_scanner.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cheatsheet_palette.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cover_action_sheet.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/emoji_picker.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_covers_supported.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_editor_state.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// A real 1x1 PNG: the preview and thumbnail decode it.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
  'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _eyes = '\u{1F440}';

class _Capturing extends CheatsheetsState {
  static List<CheatsheetCard> seed = const [];
  static final saved = <CheatsheetCard>[];
  static final covers = <PickedImageBytes?>[];
  static final releases = <List<VaultRef>>[];

  @override
  Future<List<CheatsheetCard>> build() async => seed;

  @override
  Future<void> save(
    CheatsheetCard card, {
    PickedImageBytes? newCover,
    List<VaultRef> released = const [],
  }) async {
    saved.add(card);
    covers.add(newCover);
    releases.add(released);
  }
}

class _Bytes implements ImageByteSource {
  final sources = <AttachmentPickSource>[];

  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async {
    sources.add(source);
    return PickedImageBytes(
      bytes: _png,
      originalName: 'cover.png',
      contentType: 'image/png',
    );
  }
}

class _Scanner implements DocumentScanner {
  _Scanner(this.available);
  final bool available;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<PickedImageBytes>> scan() async => [
    PickedImageBytes(
      bytes: _png,
      originalName: 'scan.png',
      contentType: 'image/png',
    ),
  ];
}

class _Resolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => _png;
}

const _cover = VaultRef(
  path: 'attachments/note-4/cover.png',
  contentType: 'image/png',
  byteSize: 70,
);

const _existing = CheatsheetCard(
  id: 'e1',
  title: 'Vim',
  walletGroup: 'Reference',
  tags: [],
  templateId: 'document',
  rows: [CheatsheetRow(label: 'Motions', source: null)],
);

void main() {
  late List<String?> emojiAnswers;
  late List<CoverAction?> coverAnswers;
  late List<(bool, bool)> coverCalls;
  late _Bytes bytes;

  setUp(() {
    _Capturing.seed = const [];
    _Capturing.saved.clear();
    _Capturing.covers.clear();
    _Capturing.releases.clear();
    emojiAnswers = [];
    coverAnswers = [];
    coverCalls = [];
    bytes = _Bytes();
  });

  Future<void> mount(
    WidgetTester tester, {
    String? cardId,
    bool coversSupported = true,
    bool canScan = false,
    TargetPlatform platform = TargetPlatform.android,
    Size physicalSize = const Size(800, 2400),
    double devicePixelRatio = 1,
    Locale? locale,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cheatsheetIdGenProvider.overrideWithValue(() => 'new-id'),
          cheatsheetsStateProvider.overrideWith(_Capturing.new),
          cheatsheetSourcePickerProvider.overrideWithValue(
            (_, {required templateId}) async => null,
          ),
          cheatsheetEmojiPickerProvider.overrideWithValue(
            (_, {bool allowClear = false}) async => emojiAnswers.removeAt(0),
          ),
          cheatsheetCoverActionProvider.overrideWithValue((
            _, {
            required bool hasCover,
            required bool canScan,
          }) async {
            coverCalls.add((hasCover, canScan));
            return coverAnswers.removeAt(0);
          }),
          cheatsheetCoversSupportedProvider.overrideWithValue(coversSupported),
          imageByteSourceProvider.overrideWithValue(bytes),
          documentScannerProvider.overrideWithValue(_Scanner(canScan)),
          attachmentResolverProvider.overrideWith((ref) async => _Resolver()),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CheatsheetDesignerScreen(cardId: cardId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// Creating a card: picking a template opens the form with Look already
  /// expanded, so no tap on `designer-look` (that would fold it).
  Future<void> start(WidgetTester tester, String templateId) =>
      tapKey(tester, 'template-$templateId');

  Color previewColour(WidgetTester tester) =>
      ((tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(const Key('look-preview')),
                      matching: find.byKey(const Key('card-surface-themed')),
                    ),
                  )
                  .decoration)
              as BoxDecoration)
          .color!;

  testWidgets('creating a card opens Look expanded', (tester) async {
    await mount(tester);
    await start(tester, 'blank');

    expect(find.byKey(const Key('look-preview')), findsOneWidget);
    expect(find.byKey(const Key('look-theme-red')), findsOneWidget);
    expect(find.byKey(const Key('look-layout')), findsOneWidget);
    expect(find.byKey(const Key('look-reset')), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('the mini-tile preview never clips its title at text scale '
        '$scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      _Capturing.seed = [_existing.copyWith(title: 'Claim notes')];
      await mount(tester, cardId: 'e1');

      final title = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const Key('look-preview')),
          matching: find.byKey(const Key('card-tile-title')),
        ),
      );
      expect(
        title.size.height,
        greaterThanOrEqualTo(
          title.getMaxIntrinsicHeight(title.size.width) - 0.01,
        ),
      );
    });
  }

  testWidgets('theme and pattern swatches have a 48x48 tap target', (
    tester,
  ) async {
    await mount(tester);
    await start(tester, 'blank');

    for (final key in ['look-theme-red', 'look-pattern-dots']) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
  });

  testWidgets('editing a card starts with Look collapsed, the preview in its '
      'header, and a tap expands it', (tester) async {
    _Capturing.seed = [
      _existing.copyWith(style: const CardStyle({'theme': 'red'})),
    ];
    await mount(tester, cardId: 'e1');

    expect(find.byKey(const Key('look-preview')), findsOneWidget);
    expect(
      previewColour(tester),
      CheatsheetPalette.of(CardThemeId.red, Brightness.light).background,
    );
    expect(
      find.byKey(const Key('look-theme-red')),
      findsNothing,
      reason: 'collapsed: the body is not built',
    );
    expect(find.byKey(const Key('look-reset')), findsNothing);

    await tapKey(tester, 'designer-look');

    expect(find.byKey(const Key('look-theme-red')), findsOneWidget);
    expect(find.byKey(const Key('look-theme-red-selected')), findsOneWidget);
  });

  testWidgets('the mini-tile preview follows the chosen theme', (tester) async {
    await mount(tester);
    await start(tester, 'accidentClaim');

    expect(
      previewColour(tester),
      CheatsheetPalette.of(CardThemeId.blue, Brightness.light).background,
    );
    expect(find.byKey(const Key('look-theme-blue-selected')), findsOneWidget);

    await tapKey(tester, 'look-theme-red');

    expect(
      previewColour(tester),
      CheatsheetPalette.of(CardThemeId.red, Brightness.light).background,
    );
    expect(find.byKey(const Key('look-theme-red-selected')), findsOneWidget);
    expect(find.byKey(const Key('look-theme-blue-selected')), findsNothing);
  });

  testWidgets('swatches have accessible names and report selection', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mount(tester);
    await start(tester, 'accidentClaim');

    expect(find.bySemanticsLabel('Red'), findsOneWidget);
    final blue = tester
        .getSemantics(find.bySemanticsLabel('Blue'))
        .getSemanticsData()
        .flagsCollection;
    expect(blue.isButton, isTrue);
    expect(blue.isSelected, Tristate.isTrue);
    final red = tester
        .getSemantics(find.bySemanticsLabel('Red'))
        .getSemanticsData()
        .flagsCollection;
    expect(red.isSelected, Tristate.isFalse);
    expect(find.bySemanticsLabel('Waves'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('saving writes only what differs from the template', (
    tester,
  ) async {
    await mount(tester);
    await start(tester, 'accidentClaim');

    await tapKey(tester, 'look-theme-blue'); // the template default
    await tapKey(tester, 'look-pattern-dots');
    await tapKey(tester, 'designer-save');

    expect(_Capturing.saved.single.style.toMap(), {'pattern': 'dots'});
  });

  testWidgets('the icon picker sets the card icon', (tester) async {
    await mount(tester);
    await start(tester, 'blank');
    emojiAnswers = ['\u{1F984}'];

    await tapKey(tester, 'look-icon-choose');

    expect(
      tester.widget<Text>(find.byKey(const Key('look-icon'))).data,
      '\u{1F984}',
    );
    await tapKey(tester, 'designer-save');
    expect(_Capturing.saved.single.style.icon, '\u{1F984}');
  });

  testWidgets('adding a cover from the library stages it and previews it', (
    tester,
  ) async {
    await mount(tester);
    await start(tester, 'blank');
    coverAnswers = [CoverAction.library];

    await tapKey(tester, 'look-cover-add');

    expect(bytes.sources, [AttachmentPickSource.gallery]);
    expect(find.byKey(const Key('look-cover-thumb')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('look-preview')),
        matching: find.byKey(const Key('card-surface-cover')),
      ),
      findsOneWidget,
    );

    await tapKey(tester, 'designer-save');
    expect(_Capturing.covers.single!.bytes, _png);
  });

  testWidgets('the cover thumbnail decodes at thumbnail size', (tester) async {
    await mount(tester);
    await start(tester, 'blank');
    coverAnswers = [CoverAction.library];

    await tapKey(tester, 'look-cover-add');

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('look-cover-thumb')),
        matching: find.byType(Image),
      ),
    );
    final dpr = tester.view.devicePixelRatio;
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, (56 * dpr).ceil());
  });

  testWidgets('the scanner is offered only when available, and scans a cover', (
    tester,
  ) async {
    await mount(tester, canScan: true);
    await start(tester, 'blank');
    coverAnswers = [CoverAction.scan];

    await tapKey(tester, 'look-cover-add');

    expect(coverCalls.single, (false, true));
    expect(find.byKey(const Key('look-cover-thumb')), findsOneWidget);
  });

  testWidgets('without a scanner the sheet is told so', (tester) async {
    await mount(tester);
    await start(tester, 'blank');
    coverAnswers = [null];

    await tapKey(tester, 'look-cover-add');

    expect(coverCalls.single, (false, false));
    expect(find.byKey(const Key('look-cover-thumb')), findsNothing);
  });

  testWidgets('removing an existing cover releases it on save', (tester) async {
    _Capturing.seed = [_existing.withCover(_cover)];
    await mount(tester, cardId: 'e1');
    await tapKey(tester, 'designer-look');
    expect(find.byKey(const Key('look-cover-thumb')), findsOneWidget);

    await tapKey(tester, 'look-cover-remove');
    await tapKey(tester, 'designer-save');

    expect(_Capturing.releases.single, [_cover]);
    expect(_Capturing.saved.single.cover, isNull);
  });

  testWidgets('covers are hidden in cloudApi mode', (tester) async {
    await mount(tester, coversSupported: false);
    await start(tester, 'blank');

    expect(find.byKey(const Key('look-cover-add')), findsNothing);
    expect(find.byKey(const Key('look-theme-red')), findsOneWidget);
  });

  testWidgets('Android picks the layout with a SegmentedButton', (
    tester,
  ) async {
    await mount(tester);
    await start(tester, 'accidentClaim');
    expect(find.byType(SegmentedButton<CardLayout>), findsOneWidget);
  });

  testWidgets('iOS picks the layout with a CupertinoSlidingSegmentedControl', (
    tester,
  ) async {
    await mount(tester, platform: TargetPlatform.iOS);
    await start(tester, 'accidentClaim');

    expect(
      find.byType(CupertinoSlidingSegmentedControl<CardLayout>),
      findsOneWidget,
    );
    await tester.tap(find.text('Key points'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('row-0-emoji')), findsOneWidget);
  });

  testWidgets('row emoji slots appear only in Key points', (tester) async {
    await mount(tester);
    await start(tester, 'accidentClaim');
    expect(find.byKey(const Key('row-0-emoji')), findsNothing);

    await tester.tap(find.text('Key points'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('row-0-emoji')), findsOneWidget);
  });

  testWidgets('row emoji survive Key points -> Facts -> Key points and are '
      'saved', (tester) async {
    await mount(tester);
    await start(tester, 'document');
    emojiAnswers = [_eyes];

    await tapKey(tester, 'row-0-emoji');
    await tester.tap(find.text('Facts'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('row-0-emoji')), findsNothing);
    await tester.tap(find.text('Key points'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('row-0-emoji')),
        matching: find.text(_eyes),
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'designer-save');
    expect(_Capturing.saved.single.rows.single.emoji, _eyes);
    expect(_Capturing.saved.single.style.isEmpty, isTrue);
  });

  testWidgets('Reset look clears style and row emoji and releases the cover', (
    tester,
  ) async {
    _Capturing.seed = [
      _existing
          .copyWith(
            style: const CardStyle({'theme': 'red', 'pattern': 'dots'}),
            rows: [_existing.rows.single.copyWith(emoji: _eyes)],
          )
          .withCover(_cover),
    ];
    await mount(tester, cardId: 'e1');
    await tapKey(tester, 'designer-look');

    await tapKey(tester, 'look-reset');
    await tapKey(tester, 'designer-save');

    final saved = _Capturing.saved.single;
    expect(saved.style.isEmpty, isTrue);
    expect(saved.cover, isNull);
    expect(saved.rows.single.emoji, isNull);
    expect(_Capturing.releases.single, [_cover]);
  });

  for (final code in ['en', 'zh']) {
    testWidgets('Look expanded fits a phone in $code without overflow', (
      tester,
    ) async {
      // 390x844 logical at DPR 3: an iPhone-sized viewport.
      await mount(
        tester,
        physicalSize: const Size(1170, 2532),
        devicePixelRatio: 3,
        locale: Locale(code),
        canScan: true,
      );
      await start(tester, 'accidentClaim');

      expect(find.byKey(const Key('look-reset')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Key points adds a row emoji slot to each row header.
      final keyPoints = code == 'en' ? 'Key points' : '要点';
      await tester.tap(find.text(keyPoints));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the designer has a help button that explains Look', (
    tester,
  ) async {
    await mount(tester);
    await tapKey(tester, 'template-blank');

    await tester.tap(find.byType(HelpButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('starts open on a new card'), findsOneWidget);
  });
}
