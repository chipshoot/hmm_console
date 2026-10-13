import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/sensitive_attachment_image.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/card_header.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/card_surface.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/card_tile.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cheatsheet_palette.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// A real 1x1 PNG: invalid bytes would fail decoding and fail the test.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
  'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Resolver implements IAttachmentResolver {
  _Resolver(this.answer);
  final Future<Uint8List?> Function() answer;
  int calls = 0;

  @override
  Future<Uint8List?> resolve(AttachmentRef ref) {
    calls++;
    return answer();
  }
}

class _StubVault extends VaultSessionController {
  _StubVault(this._status);
  final VaultStatus _status;
  static int unlockAttempts = 0;

  @override
  VaultStatus build() => _status;

  @override
  Future<void> refresh() async {
    state = _status;
  }

  @override
  Future<bool> unlockWithBiometric() async {
    unlockAttempts++;
    return false;
  }

  @override
  Future<bool> unlockWithPassphrase(String passphrase) async {
    unlockAttempts++;
    return false;
  }
}

const _cover = VaultRef(
  path: 'attachments/note-3/cover.png',
  contentType: 'image/png',
  byteSize: 70,
);
const _secretCover = VaultRef(
  path: 'attachments/note-3/sensitive/secret.png',
  contentType: 'image/png',
  byteSize: 70,
  sensitive: true,
);

const _card = CheatsheetCard(
  id: 'c1',
  title: 'Claim',
  walletGroup: 'Vehicle',
  tags: [],
  templateId: 'accidentClaim',
  rows: [
    CheatsheetRow(label: 'Plate', source: null),
    CheatsheetRow(label: 'VIN', source: null),
  ],
);

Future<List<String>> _captureLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final saved = debugPrint;
  debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
  try {
    await body();
  } finally {
    debugPrint = saved;
  }
  return logs;
}

void main() {
  setUp(() => _StubVault.unlockAttempts = 0);

  Future<List<String>> mountTile(
    WidgetTester tester,
    CheatsheetCard card, {
    IAttachmentResolver? resolver,
    VaultStatus vault = VaultStatus.unlocked,
    Brightness brightness = Brightness.light,
    Size size = const Size(200, 160),
    Uint8List? pending,
    Locale? locale,
  }) async {
    final taps = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentResolverProvider.overrideWith(
            (ref) async => resolver ?? _Resolver(() async => _png),
          ),
          vaultSessionProvider.overrideWith(() => _StubVault(vault)),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: CardTile(
                  card: card,
                  pendingCoverBytes: pending,
                  onTap: () => taps.add(card.id),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return taps;
  }

  Color themedColour(WidgetTester tester) =>
      ((tester
                  .widget<DecoratedBox>(
                    find.byKey(const Key('card-surface-themed')),
                  )
                  .decoration)
              as BoxDecoration)
          .color!;

  CardPattern paintedPattern(WidgetTester tester) =>
      (tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const Key('card-surface-themed')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as CardPatternPainter)
          .pattern;

  testWidgets('a plain card paints its template theme and icon, no pattern', (
    tester,
  ) async {
    await mountTile(tester, _card);

    expect(
      themedColour(tester),
      CheatsheetPalette.of(CardThemeId.blue, Brightness.light).background,
    );
    expect(paintedPattern(tester), CardPattern.none);
    expect(find.text(CardLookDefaults.car), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget);
    expect(find.text('Vehicle · 2 rows'), findsOneWidget);
  });

  testWidgets('a styled card paints its chosen theme and pattern', (
    tester,
  ) async {
    await mountTile(
      tester,
      _card.copyWith(
        style: CardStyle.empty
            .withTheme(CardThemeId.red, templateId: 'accidentClaim')
            .withPattern(CardPattern.dots),
      ),
    );

    expect(
      themedColour(tester),
      CheatsheetPalette.of(CardThemeId.red, Brightness.light).background,
    );
    expect(paintedPattern(tester), CardPattern.dots);
  });

  testWidgets('dark mode uses the dark variant', (tester) async {
    await mountTile(tester, _card, brightness: Brightness.dark);
    expect(
      themedColour(tester),
      CheatsheetPalette.of(CardThemeId.blue, Brightness.dark).background,
    );
  });

  testWidgets('a cover is drawn under a darkening scrim with white text', (
    tester,
  ) async {
    await mountTile(tester, _card.withCover(_cover));

    expect(find.byKey(const Key('card-surface-cover')), findsOneWidget);
    expect(find.byKey(const Key('card-surface-scrim')), findsOneWidget);
    expect(find.byKey(const Key('card-surface-themed')), findsNothing);
    expect(
      tester.widget<Text>(find.text('Claim')).style!.color,
      const Color(0xFFFFFFFF),
    );
  });

  testWidgets('a cover whose vault file is gone falls back to the theme', (
    tester,
  ) async {
    final logs = await _captureLogs(
      () => mountTile(
        tester,
        _card.withCover(_cover),
        resolver: _Resolver(() async => null),
      ),
    );

    expect(find.byKey(const Key('card-surface-themed')), findsOneWidget);
    expect(find.byKey(const Key('card-surface-cover')), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(logs.join('\n'), contains('missing'));
    expect(logs.join('\n'), isNot(contains('cover.png')));
  });

  testWidgets(
    'a cover that fails to decrypt falls back and logs the type only',
    (tester) async {
      final logs = await _captureLogs(
        () => mountTile(
          tester,
          _card.withCover(_cover),
          resolver: _Resolver(
            () async => throw StateError('attachments/note-3/cover.png'),
          ),
        ),
      );

      expect(find.byKey(const Key('card-surface-themed')), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(logs.join('\n'), contains('StateError'));
      expect(logs.join('\n'), isNot(contains('cover.png')));
    },
  );

  testWidgets('a locked sensitive cover shows the theme with a lock badge and '
      'never prompts', (tester) async {
    final resolver = _Resolver(() async => _png);
    final taps = await mountTile(
      tester,
      _card.withCover(_secretCover),
      resolver: resolver,
      vault: VaultStatus.locked,
    );

    expect(find.byKey(const Key('card-surface-themed')), findsOneWidget);
    expect(find.byKey(const Key('card-tile-cover-locked')), findsOneWidget);
    expect(find.byKey(sensitiveLockedPlaceholderKey), findsNothing);
    expect(resolver.calls, 0, reason: 'nothing is decrypted while locked');

    await tester.tap(find.byType(CardTile));
    await tester.pumpAndSettle();

    expect(taps, ['c1'], reason: 'the tap opens the card');
    expect(_StubVault.unlockAttempts, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('pending cover bytes preview without touching the resolver', (
    tester,
  ) async {
    final resolver = _Resolver(
      () async => throw StateError('must not be called'),
    );
    await mountTile(tester, _card, resolver: resolver, pending: _png);

    expect(find.byKey(const Key('card-surface-cover')), findsOneWidget);
    expect(resolver.calls, 0);
  });

  testWidgets('a long title and a ZWJ skin-tone icon render on a tile without '
      'overflow', (tester) async {
    const technologist = '\u{1F469}\u{1F3FD}‍\u{1F4BB}';
    final card = _card.copyWith(
      title: 'A very long cheatsheet title ' * 8,
      style: CardStyle.empty.withIcon(
        technologist,
        templateId: 'accidentClaim',
      ),
    );
    await mountTile(tester, card, size: const Size(160, 150));

    expect(tester.takeException(), isNull);
    expect(find.text(technologist), findsOneWidget);
    final title = tester.widget<Text>(find.byKey(const Key('card-tile-title')));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('an invalid stored icon renders the template icon', (
    tester,
  ) async {
    await mountTile(
      tester,
      _card.copyWith(style: const CardStyle({'icon': 'car'})),
    );
    expect(find.text(CardLookDefaults.car), findsOneWidget);
    expect(find.text('car'), findsNothing);
  });

  testWidgets('semantics read title, group and rows as one button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mountTile(tester, _card);

    final node = find.bySemanticsLabel('Claim, Vehicle, 2 rows');
    expect(node, findsOneWidget);
    final data = tester.getSemantics(node).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('semantics name a protected card without relying on the badge', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mountTile(tester, _card.copyWith(protected: true));

    expect(
      find.bySemanticsLabel('Claim, Vehicle, 2 rows, protected'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('semantics name a hidden sensitive cover', (tester) async {
    final handle = tester.ensureSemantics();
    await mountTile(
      tester,
      _card.withCover(_secretCover),
      vault: VaultStatus.locked,
    );

    expect(
      find.bySemanticsLabel('Claim, Vehicle, 2 rows, cover locked'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('semantics list protected before cover locked in zh', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await mountTile(
      tester,
      _card.copyWith(protected: true).withCover(_secretCover),
      vault: VaultStatus.locked,
      locale: const Locale('zh'),
    );

    expect(find.bySemanticsLabel('Claim，车辆，2 行，受保护，封面已锁定'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a tile decodes its cover at tile size, not full size', (
    tester,
  ) async {
    await mountTile(tester, _card.withCover(_cover));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const Key('card-surface-cover')),
    );
    final provider = image.image as ResizeImage;
    expect(provider.width, isNotNull);
    expect(provider.width, lessThanOrEqualTo(200 * 3));
  });

  testWidgets('a protected card shows a lock badge', (tester) async {
    await mountTile(tester, _card.copyWith(protected: true));
    expect(find.byKey(const Key('card-tile-protected')), findsOneWidget);
  });

  testWidgets('the header offers the shared tap-to-unlock tile for a locked '
      'sensitive cover', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentResolverProvider.overrideWith(
            (ref) async => _Resolver(() async => _png),
          ),
          vaultSessionProvider.overrideWith(
            () => _StubVault(VaultStatus.locked),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CardHeader(card: _card.withCover(_secretCover))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(sensitiveLockedPlaceholderKey), findsOneWidget);
    expect(find.byKey(const Key('detail-header-title')), findsOneWidget);
    expect(find.text('Vehicle · 2 rows'), findsOneWidget);
  });

  test('the app bar over a cover card uses the darkened theme with white', () {
    final plain = headerBarColors(_card, Brightness.light);
    expect(
      plain.background,
      CheatsheetPalette.of(CardThemeId.blue, Brightness.light).background,
    );

    final covered = headerBarColors(_card.withCover(_cover), Brightness.light);
    expect(covered.foreground, const Color(0xFFFFFFFF));
    expect(
      covered.background,
      CheatsheetPalette.forCover(CardThemeId.blue, Brightness.light).background,
    );
  });

  group('CardPatternPainter', () {
    // The palette's AA contrast was verified with the pattern ink as ONE 10%
    // layer, so no pixel may receive two layers: each pattern must reach the
    // canvas as exactly one path (overlaps inside it are painted once).
    for (final pattern in CardPattern.values.where(
      (p) => p != CardPattern.none,
    )) {
      testWidgets('$pattern paints a single path, never stacked strokes', (
        tester,
      ) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 200,
              height: 160,
              child: CustomPaint(
                key: const Key('p'),
                painter: CardPatternPainter(
                  pattern: pattern,
                  ink: const Color(0x1AFFFFFF),
                ),
              ),
            ),
          ),
        );
        final render = tester.renderObject(find.byKey(const Key('p')));
        expect(render, paintsExactlyCountTimes(#drawPath, 1));
        expect(render, paintsExactlyCountTimes(#drawLine, 0));
        expect(render, paintsExactlyCountTimes(#drawCircle, 0));
      });
    }

    testWidgets('none paints nothing', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 160,
            child: CustomPaint(
              key: const Key('p'),
              painter: CardPatternPainter(
                pattern: CardPattern.none,
                ink: const Color(0x1AFFFFFF),
              ),
            ),
          ),
        ),
      );
      expect(tester.renderObject(find.byKey(const Key('p'))), paintsNothing);
    });
  });
}
