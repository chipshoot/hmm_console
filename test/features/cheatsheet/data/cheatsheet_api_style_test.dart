import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/datasources/cheatsheet_remote_datasource.dart';
import 'package:hmm_console/features/cheatsheet/data/mappers/cheatsheet_api_mapper.dart';
import 'package:hmm_console/features/cheatsheet/data/repositories/cheatsheet_api_repository.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';

class _FakeRemote implements CheatsheetRemoteDataSource {
  _FakeRemote(this.existing);

  Map<String, dynamic>? existing;
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>?> getCard(String id) async => existing;

  @override
  Future<void> updateCard(String id, Map<String, dynamic> body) async {
    lastBody = body;
  }

  @override
  Future<Map<String, dynamic>> createCard(Map<String, dynamic> body) async {
    lastBody = body;
    return body;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  const eyes = '\u{1F440}';
  final styled =
      const CheatsheetCard(
        id: 'c-1',
        title: 'Vim',
        walletGroup: 'Reference',
        tags: [],
        templateId: 'document',
        rows: [CheatsheetRow(label: 'Motions', source: null, emoji: eyes)],
      ).copyWith(
        style: const CardStyle({
          'theme': 'turquoise',
          'pattern': 'dots',
          'sparkle': {'a': 1},
        }),
      );

  test('toApi sends Style verbatim, unknown keys included, and row Emoji', () {
    final json = CheatsheetApiMapper.toApi(styled);
    expect(json['Style'], {
      'theme': 'turquoise',
      'pattern': 'dots',
      'sparkle': {'a': 1},
    });
    expect((json['Rows'] as List).single['Emoji'], eyes);
    expect(json.containsKey('style'), isFalse);
  });

  test(
    'an unstyled card sends Style: null so a reset clears the server copy',
    () {
      final json = CheatsheetApiMapper.toApi(
        styled.copyWith(
          style: CardStyle.empty,
          rows: [styled.rows.single.copyWith(clearEmoji: true)],
        ),
      );
      expect(json.containsKey('Style'), isTrue);
      expect(json['Style'], isNull);
      expect((json['Rows'] as List).single.containsKey('Emoji'), isFalse);
    },
  );

  test('fromApi reads Style and Emoji back into an equal card', () {
    expect(
      CheatsheetApiMapper.fromApi(CheatsheetApiMapper.toApi(styled)),
      styled,
    );
  });

  test('a null or non-map Style reads as unstyled', () {
    final base = CheatsheetApiMapper.toApi(styled);
    expect(
      CheatsheetApiMapper.fromApi({...base, 'Style': null}).style.isEmpty,
      isTrue,
    );
    expect(
      CheatsheetApiMapper.fromApi({...base, 'Style': 'odd'}).style.isEmpty,
      isTrue,
    );
  });

  test(
    'unknown style keys survive a get-then-save through the repository',
    () async {
      final stored = CheatsheetApiMapper.toApi(styled);
      final remote = _FakeRemote(stored);
      final repo = CheatsheetApiRepository(remote);

      final card = await repo.getCard('c-1');
      await repo.saveCard(card!.copyWith(title: 'Vim 2'));

      expect(remote.lastBody!['Style'], stored['Style']);
      expect((remote.lastBody!['Rows'] as List).single['Emoji'], eyes);
    },
  );

  test('the API repository has no note ids, so no covers', () async {
    expect(
      await CheatsheetApiRepository(_FakeRemote(null)).noteIdFor('c-1'),
      isNull,
    );
  });

  group('non-conforming values are preserved', () {
    final base = CheatsheetApiMapper.toApi(styled);

    test('a non-object Style round-trips verbatim', () {
      for (final raw in <Object>[
        'odd',
        7,
        [1, 2],
        true,
      ]) {
        final card = CheatsheetApiMapper.fromApi({...base, 'Style': raw});
        expect(card.style.isEmpty, isTrue);
        expect(CheatsheetApiMapper.toApi(card)['Style'], raw);
      }
    });

    test('a non-string Emoji round-trips verbatim', () {
      final rows = [
        {'Label': 'x', 'Emoji': 5},
      ];
      final card = CheatsheetApiMapper.fromApi({...base, 'Rows': rows});
      expect(card.rows.single.emoji, isNull);
      expect(
        (CheatsheetApiMapper.toApi(card)['Rows'] as List).single['Emoji'],
        5,
      );
    });

    test('a typed style replaces the raw one', () {
      final card = CheatsheetApiMapper.fromApi({
        ...base,
        'Style': 'odd',
      }).copyWith(style: const CardStyle({'theme': 'red'}));
      expect(CheatsheetApiMapper.toApi(card)['Style'], {'theme': 'red'});
    });

    test('a typed emoji replaces the raw one', () {
      final card = CheatsheetApiMapper.fromApi({
        ...base,
        'Rows': [
          {'Label': 'x', 'Emoji': 5},
        ],
      });
      final row = card.rows.single.copyWith(emoji: eyes);
      expect(
        (CheatsheetApiMapper.toApi(card.copyWith(rows: [row]))['Rows'] as List)
            .single['Emoji'],
        eyes,
      );
    });

    test('reset (typed style empty AND raw cleared) sends Style: null', () {
      final card = CheatsheetApiMapper.fromApi({
        ...base,
        'Style': 'odd',
      }).copyWith(style: CardStyle.empty, extraFields: const {});
      final json = CheatsheetApiMapper.toApi(card);
      expect(json.containsKey('Style'), isTrue);
      expect(json['Style'], isNull);
    });

    test('an unstyled card with no raw still sends Style: null', () {
      final json = CheatsheetApiMapper.toApi(
        CheatsheetApiMapper.fromApi({...base, 'Style': null}),
      );
      expect(json['Style'], isNull);
    });
  });
}
