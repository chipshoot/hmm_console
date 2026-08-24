import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/mappers/cheatsheet_api_mapper.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  CheatsheetCard card({
    List<CheatsheetRow> rows = const [],
    List<Map<String, dynamic>> unreadable = const [],
  }) =>
      CheatsheetCard(
        id: 'c-1',
        title: 'Passport',
        walletGroup: 'Travel',
        tags: const ['trip'],
        templateId: 'blank',
        rows: rows,
        unreadableRows: unreadable,
      );

  group('wire format', () {
    test('writes PascalCase keys, not the camelCase used by note content', () {
      final json = CheatsheetApiMapper.toApi(card());

      expect(json.keys, containsAll(<String>[
        'Id', 'Title', 'WalletGroup', 'Tags', 'TemplateId', 'Protected', 'Rows',
      ]));
      expect(json.containsKey('title'), isFalse);
      expect(json.containsKey('walletGroup'), isFalse);
    });

    test('reads PascalCase keys back', () {
      final decoded = CheatsheetApiMapper.fromApi({
        'Id': 'c-9',
        'Title': 'Alarm code',
        'WalletGroup': 'Home',
        'Tags': ['security'],
        'TemplateId': 'blank',
        'Protected': true,
        'Rows': const [],
      });

      expect(decoded.id, 'c-9');
      expect(decoded.title, 'Alarm code');
      expect(decoded.walletGroup, 'Home');
      expect(decoded.tags, ['security']);
      expect(decoded.protected, isTrue);
    });

    test('camelCase body reads back empty, which is why the case matters', () {
      // Guards the one mistake that fails silently rather than loudly.
      final decoded = CheatsheetApiMapper.fromApi({
        'id': 'c-9',
        'title': 'Alarm code',
      });

      expect(decoded.id, isEmpty);
      expect(decoded.title, isEmpty);
    });

    test('round-trips a fully populated card', () {
      final original = card(rows: [
        const CheatsheetRow(
          label: 'Number',
          valueAction: ValueAction.call,
          openSource: false,
          source: CheatsheetSource(
            noteUuid: 'note-1',
            kind: SourceGranularity.field,
            locator: 'passport.number',
          ),
        ),
      ]);

      final result = CheatsheetApiMapper.fromApi(
        CheatsheetApiMapper.toApi(original),
      );

      expect(result, original);
    });
  });

  group('losslessness', () {
    test('a row this version cannot decode is kept, not dropped', () {
      final decoded = CheatsheetApiMapper.fromApi({
        'Id': 'c-1',
        'Rows': [
          {'Label': 'Fine', 'ValueAction': 'none', 'OpenSource': true},
          {'Label': 'Broken', 'Source': 'not-an-object'},
        ],
      });

      expect(decoded.rows, hasLength(1));
      expect(decoded.unreadableRows, hasLength(1));
      expect(decoded.unreadableRows.single['Label'], 'Broken');
    });

    test('an unreadable row survives a save it was not involved in', () {
      // The save rewrites the whole card, so omitting it here would delete a
      // row the server deliberately preserved.
      final decoded = CheatsheetApiMapper.fromApi({
        'Id': 'c-1',
        'Rows': [
          {'Label': 'Broken', 'Source': 42},
        ],
      });

      final resent = CheatsheetApiMapper.toApi(
        decoded.copyWith(title: 'Renamed'),
      );

      expect(resent['Rows'], hasLength(1));
      expect((resent['Rows'] as List).single, {'Label': 'Broken', 'Source': 42});
    });

    test('a non-list Rows does not take the card down', () {
      final decoded = CheatsheetApiMapper.fromApi({'Id': 'c-1', 'Rows': 'nope'});

      expect(decoded.id, 'c-1');
      expect(decoded.rows, isEmpty);
    });

    test('an unknown ValueAction or Kind falls back rather than throwing', () {
      final decoded = CheatsheetApiMapper.fromApi({
        'Id': 'c-1',
        'Rows': [
          {
            'Label': 'Row',
            'ValueAction': 'teleport',
            'Source': {'NoteUuid': 'n-1', 'Kind': 'quantum'},
          },
        ],
      });

      expect(decoded.rows.single.valueAction, ValueAction.none);
      expect(decoded.rows.single.source!.kind, SourceGranularity.whole);
    });
  });
}
