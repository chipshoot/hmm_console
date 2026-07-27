import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/cheatsheet/data/i_cheatsheet_repository.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';

class _FakeRepo implements ICheatsheetRepository {
  _FakeRepo([Iterable<CheatsheetCard> seed = const []]) {
    for (final c in seed) {
      _cards[c.id] = c;
    }
  }

  final Map<String, CheatsheetCard> _cards = {};
  int getCardsCalls = 0;

  @override
  Future<List<CheatsheetCard>> getCards() async {
    getCardsCalls++;
    return _cards.values.toList();
  }

  @override
  Future<CheatsheetCard?> getCard(String id) async => _cards[id];

  @override
  Future<CheatsheetCard> saveCard(CheatsheetCard card) async {
    _cards[card.id] = card;
    return card;
  }

  @override
  Future<void> deleteCard(String id) async => _cards.remove(id);
}

class _ThrowingRepo implements ICheatsheetRepository {
  @override
  Future<List<CheatsheetCard>> getCards() async => throw Exception('boom');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

CheatsheetCard card(String id, {String title = 'Claim'}) => CheatsheetCard(
      id: id,
      title: title,
      walletGroup: 'Vehicle',
      tags: const [],
      templateId: 'blank',
      rows: const [
        CheatsheetRow(
          label: 'Plate',
          source: CheatsheetSource(
            noteUuid: 'n',
            kind: SourceGranularity.whole,
          ),
        ),
      ],
    );

void main() {
  ProviderContainer containerWith(ICheatsheetRepository repo) {
    final c = ProviderContainer(
      overrides: [cheatsheetRepositoryModeProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('build returns the repository cards', () async {
    final container = containerWith(_FakeRepo([card('c1'), card('c2')]));

    final cards = await container.read(cheatsheetsStateProvider.future);

    expect(cards.map((c) => c.id), containsAll(['c1', 'c2']));
  });

  test('build on an empty repository yields an empty list, not an error',
      () async {
    final container = containerWith(_FakeRepo());
    expect(await container.read(cheatsheetsStateProvider.future), isEmpty);
  });

  test('save adds a card and the next read sees it', () async {
    final container = containerWith(_FakeRepo());
    await container.read(cheatsheetsStateProvider.future);

    await container.read(cheatsheetsStateProvider.notifier).save(card('c1'));

    final cards = await container.read(cheatsheetsStateProvider.future);
    expect(cards.map((c) => c.id), ['c1']);
  });

  test('saving an existing id updates in place, it does not duplicate',
      () async {
    final container = containerWith(_FakeRepo([card('c1')]));
    await container.read(cheatsheetsStateProvider.future);

    await container
        .read(cheatsheetsStateProvider.notifier)
        .save(card('c1', title: 'Renamed'));

    final cards = await container.read(cheatsheetsStateProvider.future);
    expect(cards.length, 1);
    expect(cards.single.title, 'Renamed');
    expect(cards.single.id, 'c1');
  });

  test('remove deletes the card', () async {
    final container = containerWith(_FakeRepo([card('c1'), card('c2')]));
    await container.read(cheatsheetsStateProvider.future);

    await container.read(cheatsheetsStateProvider.notifier).remove('c1');

    final cards = await container.read(cheatsheetsStateProvider.future);
    expect(cards.map((c) => c.id), ['c2']);
  });

  test('refresh re-reads the repository', () async {
    final repo = _FakeRepo();
    final container = containerWith(repo);
    await container.read(cheatsheetsStateProvider.future);
    final before = repo.getCardsCalls;

    container.read(cheatsheetsStateProvider.notifier).refresh();
    await container.read(cheatsheetsStateProvider.future);

    expect(repo.getCardsCalls, greaterThan(before));
  });

  test('a repository failure surfaces as an error state', () async {
    final container = containerWith(_ThrowingRepo());

    // Subscribe so the notifier builds, then let the async build settle.
    // Awaiting `.future` here would hang: with no listener the provider stays
    // in its loading state and only completes (with a StateError) on dispose.
    container.listen(cheatsheetsStateProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = container.read(cheatsheetsStateProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<Exception>());
  });
}
