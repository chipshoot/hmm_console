import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/sensitive_attachment_image.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/card_tile.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';

class _SeededCheatsheets extends CheatsheetsState {
  static List<CheatsheetCard> seed = const [];

  @override
  Future<List<CheatsheetCard>> build() async => seed;
}

class _FailingCheatsheets extends CheatsheetsState {
  @override
  Future<List<CheatsheetCard>> build() async => throw Exception('boom');
}

class _Resolver implements IAttachmentResolver {
  int calls = 0;
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async {
    calls++;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
      'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
  }
}

class _LockedVault extends VaultSessionController {
  static int unlockAttempts = 0;
  @override
  VaultStatus build() => VaultStatus.locked;
  @override
  Future<void> refresh() async {
    state = VaultStatus.locked;
  }

  @override
  Future<bool> unlockWithBiometric() async {
    unlockAttempts++;
    return false;
  }
}

CheatsheetCard card(
  String id, {
  required String title,
  String group = 'Vehicle',
  List<String> tags = const [],
}) => CheatsheetCard(
  id: id,
  title: title,
  walletGroup: group,
  tags: tags,
  templateId: 'blank',
  rows: const [],
);

void main() {
  setUp(() {
    _SeededCheatsheets.seed = const [];
    _LockedVault.unlockAttempts = 0;
  });

  Future<List<String>> mount(
    WidgetTester tester, {
    bool failing = false,
    List<Override> extra = const [],
  }) async {
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cheatsheetsStateProvider.overrideWith(
            failing ? _FailingCheatsheets.new : _SeededCheatsheets.new,
          ),
          cheatsheetOpenCardProvider.overrideWithValue(
            (_, id) => opened.add(id),
          ),
          cheatsheetCreateCardProvider.overrideWithValue(
            (_) => opened.add('#create'),
          ),
          ...extra,
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CheatsheetWalletScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  /// Reading order in the grid: top to bottom, then left to right.
  bool before(WidgetTester tester, String a, String b) {
    final pa = tester.getTopLeft(find.byKey(Key('wallet-card-$a')));
    final pb = tester.getTopLeft(find.byKey(Key('wallet-card-$b')));
    return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
  }

  int columns(WidgetTester tester) =>
      (tester
                  .widget<GridView>(find.byKey(const Key('wallet-grid')))
                  .gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount;

  testWidgets('every card is a tile', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    expect(find.byType(CardTile), findsNWidgets(2));
    expect(find.text('Claim'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
  });

  testWidgets('offers All plus one translated chip per wallet group in use', (
    tester,
  ) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    expect(find.byKey(const Key('wallet-group-all')), findsOneWidget);
    expect(find.byKey(const Key('wallet-group-Vehicle')), findsOneWidget);
    expect(find.byKey(const Key('wallet-group-Health')), findsOneWidget);
    expect(find.byKey(const Key('wallet-group-Reference')), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('wallet-group-all')))
          .selected,
      isTrue,
    );
  });

  testWidgets('a group chip filters the grid and All restores it', (
    tester,
  ) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-group-Health')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-card-a')), findsNothing);
    expect(find.byKey(const Key('wallet-card-b')), findsOneWidget);

    await tester.tap(find.byKey(const Key('wallet-group-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-card-a')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-b')), findsOneWidget);
  });

  testWidgets('tapping a card opens its detail', (tester) async {
    _SeededCheatsheets.seed = [card('a', title: 'Claim')];
    final opened = await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-card-a')));
    await tester.pumpAndSettle();

    expect(opened, ['a']);
  });

  testWidgets('the add action opens the designer', (tester) async {
    final opened = await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-add')));
    await tester.pumpAndSettle();

    expect(opened, ['#create']);
  });

  testWidgets('cards with the same title order by id, stably', (tester) async {
    _SeededCheatsheets.seed = [
      card('b', title: 'Claim'),
      card('a', title: 'Claim'),
    ];
    await mount(tester);

    expect(before(tester, 'a', 'b'), isTrue);
    await tester.pump(); // rebuild
    expect(
      before(tester, 'a', 'b'),
      isTrue,
      reason: 'order is stable across builds',
    );
  });

  testWidgets('titles sort case-insensitively across groups', (tester) async {
    _SeededCheatsheets.seed = [
      card('1', title: 'zebra', group: 'vehicle'),
      card('2', title: 'Apple', group: 'Health'),
    ];
    await mount(tester);

    expect(before(tester, '2', '1'), isTrue, reason: 'Apple before zebra');
  });

  testWidgets('columns: 2 on phones, 3 from 600 dp, 4 from 900 dp', (
    tester,
  ) async {
    expect(walletColumnsFor(320), 2);
    expect(walletColumnsFor(599), 2);
    expect(walletColumnsFor(600), 3);
    expect(walletColumnsFor(899), 3);
    expect(walletColumnsFor(900), 4);

    _SeededCheatsheets.seed = [card('a', title: 'Claim')];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (width, expected) in [(400.0, 2), (700.0, 3), (1000.0, 4)]) {
      tester.view.physicalSize = Size(width, 900);
      await mount(tester);
      expect(columns(tester), expected, reason: '$width wide');
    }
  });

  testWidgets('a locked sensitive cover shows a badge and triggers no unlock', (
    tester,
  ) async {
    const secret = VaultRef(
      path: 'attachments/note-1/sensitive/c.png',
      contentType: 'image/png',
      byteSize: 70,
      sensitive: true,
    );
    _SeededCheatsheets.seed = [card('a', title: 'Claim').withCover(secret)];
    final resolver = _Resolver();
    final opened = await mount(
      tester,
      extra: [
        attachmentResolverProvider.overrideWith((ref) async => resolver),
        vaultSessionProvider.overrideWith(_LockedVault.new),
      ],
    );

    expect(find.byKey(const Key('card-tile-cover-locked')), findsOneWidget);
    expect(find.byKey(sensitiveLockedPlaceholderKey), findsNothing);
    expect(resolver.calls, 0);

    await tester.tap(find.byKey(const Key('wallet-card-a')));
    await tester.pumpAndSettle();
    expect(opened, ['a']);
    expect(_LockedVault.unlockAttempts, 0);
  });

  testWidgets('search matches titles case-insensitively', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    await tester.enterText(find.byKey(const Key('wallet-search')), 'cla');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-card-a')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-b')), findsNothing);
  });

  testWidgets('search and the group chip intersect', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Claim health', group: 'Health'),
    ];
    await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-group-Health')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wallet-search')), 'claim');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-card-a')), findsNothing);
    expect(find.byKey(const Key('wallet-card-b')), findsOneWidget);
  });

  testWidgets('a search with no matches shows the empty-result state', (
    tester,
  ) async {
    _SeededCheatsheets.seed = [card('a', title: 'Claim')];
    await mount(tester);

    await tester.enterText(find.byKey(const Key('wallet-search')), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-no-matches')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-a')), findsNothing);
  });

  testWidgets('a tag filter shows only cards carrying that tag', (
    tester,
  ) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim', tags: const ['legal']),
      card('b', title: 'Doctor', group: 'Health', tags: const ['medical']),
    ];
    await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-tag-legal')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-card-a')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-b')), findsNothing);
  });

  testWidgets('title and tag filters intersect', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim', tags: const ['legal']),
      card('b', title: 'Claim backup', tags: const ['medical']),
    ];
    await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-tag-legal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wallet-search')), 'claim');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-card-a')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-b')), findsNothing);
  });

  testWidgets('tag chips are trimmed and de-duplicated case-insensitively', (
    tester,
  ) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim', tags: const ['Legal', 'legal ']),
      card('b', title: 'Doctor', tags: const ['health']),
    ];
    await mount(tester);

    expect(find.byKey(const Key('wallet-tag-legal')), findsOneWidget);
    expect(find.byKey(const Key('wallet-tag-health')), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(2));
  });

  testWidgets('an empty wallet shows an empty state', (tester) async {
    await mount(tester);
    expect(find.byKey(const Key('wallet-empty')), findsOneWidget);
  });

  testWidgets('a load failure shows an error state, not a blank screen', (
    tester,
  ) async {
    await mount(tester, failing: true);
    expect(find.byKey(const Key('wallet-error')), findsOneWidget);
  });

  testWidgets('a load failure never shows the exception text', (tester) async {
    await mount(tester, failing: true);
    expect(find.text('Could not load your cheatsheets.'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('the wallet has a help button that explains tiles, chips and '
      'the lock badge', (tester) async {
    // An empty wallet: the only lock icon on screen is the help sheet's.
    await mount(tester);

    await tester.tap(find.byType(HelpButton));
    await tester.pumpAndSettle();

    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Group chips'), findsOneWidget);
    expect(find.text('Tag chips'), findsOneWidget);
    expect(find.text('Lock badge'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('phone-size tiles fit their content at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      _SeededCheatsheets.seed = [
        card(
          'a',
          title: 'A really long cheatsheet title ' * 4,
        ).copyWith(protected: true),
        card('b', title: 'Doctor', group: 'Reference'),
      ];

      await mount(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(CardTile), findsNWidgets(2));
      // The tile is tall enough for its icon, two title lines and subtitle,
      // so nothing is clipped mid-line either.
      final tile = tester.getRect(find.byKey(const Key('wallet-card-a')));
      final subtitle = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('wallet-card-a')),
          matching: find.byKey(const Key('card-tile-subtitle')),
        ),
      );
      expect(subtitle.bottom, lessThanOrEqualTo(tile.bottom));
    });
  }
}
