import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
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

CheatsheetCard card(
  String id, {
  required String title,
  String group = 'Vehicle',
  List<String> tags = const [],
}) =>
    CheatsheetCard(
      id: id,
      title: title,
      walletGroup: group,
      tags: tags,
      templateId: 'blank',
      rows: const [],
    );

void main() {
  setUp(() => _SeededCheatsheets.seed = const []);

  Future<List<String>> mount(
    WidgetTester tester, {
    bool failing = false,
  }) async {
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cheatsheetsStateProvider.overrideWith(
            failing ? _FailingCheatsheets.new : _SeededCheatsheets.new,
          ),
          cheatsheetOpenCardProvider
              .overrideWithValue((_, id) => opened.add(id)),
          cheatsheetCreateCardProvider
              .overrideWithValue((_) => opened.add('#create')),
        ],
        child: const MaterialApp(home: CheatsheetWalletScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('groups cards under their wallet group', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    expect(find.byKey(const Key('wallet-group-Vehicle')), findsOneWidget);
    expect(find.byKey(const Key('wallet-group-Health')), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
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

    double y(String id) =>
        tester.getTopLeft(find.byKey(Key('wallet-card-$id'))).dy;
    expect(y('a'), lessThan(y('b')));

    await tester.pump(); // rebuild
    expect(y('a'), lessThan(y('b')), reason: 'order is stable across builds');
  });

  testWidgets('groups and titles sort case-insensitively', (tester) async {
    _SeededCheatsheets.seed = [
      card('1', title: 'zebra', group: 'vehicle'),
      card('2', title: 'Apple', group: 'vehicle'),
    ];
    await mount(tester);

    double y(String id) =>
        tester.getTopLeft(find.byKey(Key('wallet-card-$id'))).dy;
    expect(y('2'), lessThan(y('1')), reason: 'Apple before zebra');
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

  testWidgets('a search with no matches shows the empty-result state',
      (tester) async {
    _SeededCheatsheets.seed = [card('a', title: 'Claim')];
    await mount(tester);

    await tester.enterText(find.byKey(const Key('wallet-search')), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-no-matches')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-a')), findsNothing);
  });

  testWidgets('a tag filter shows only cards carrying that tag',
      (tester) async {
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

  testWidgets('tag chips are trimmed and de-duplicated case-insensitively',
      (tester) async {
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

  testWidgets('a load failure shows an error state, not a blank screen',
      (tester) async {
    await mount(tester, failing: true);
    expect(find.byKey(const Key('wallet-error')), findsOneWidget);
  });
}
