import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_codec.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';

/// decode -> encode -> the exact same JSON text.
String _roundTrip(String json, {NoteAttachments? attachments}) =>
    jsonEncode(CheatsheetCodec.toMap(CheatsheetCodec.fromMap(
        (jsonDecode(json) as Map).cast<String, dynamic>(),
        attachments: attachments)));

void main() {
  const cover = VaultRef(
    path: 'attachments/note-7/cover.jpg',
    contentType: 'image/jpeg',
    byteSize: 1234,
  );

  group('byte identity', () {
    test('a card written before this feature round-trips byte-identical', () {
      // Exactly what the pre-feature codec wrote: no style, no emoji.
      const before = '{"schemaVersion":1,"id":"c1","title":"Claim",'
          '"walletGroup":"Vehicle","tags":["legal"],'
          '"templateId":"accidentClaim","protected":false,"rows":['
          '{"label":"Plate","valueAction":"call","openSource":true,'
          '"source":{"noteUuid":"auto1","kind":"field",'
          '"locator":"AutomobileInfo.plate"}},'
          '{"label":"Unbound","valueAction":"none","openSource":true}]}';
      expect(_roundTrip(before), before);
    });

    test('a styled card with unknown keys everywhere round-trips byte-identical',
        () {
      const styled = '{"schemaVersion":1,"id":"c1","title":"Vim",'
          '"walletGroup":"Reference","tags":[],"templateId":"document",'
          '"protected":false,"rows":['
          '{"label":"Motions","valueAction":"none","openSource":true,'
          '"emoji":"\u{1F440}","hint":{"x":1}}],'
          '"style":{"theme":"turquoise","pattern":"dots","sparkle":[1,2]},'
          '"future":42}';
      expect(_roundTrip(styled), styled);
    });

    test('a card with a cover round-trips byte-identical and projects the ref',
        () {
      const withCover = '{"schemaVersion":1,"id":"c1","title":"T",'
          '"walletGroup":"Ungrouped","tags":[],"templateId":"blank",'
          '"protected":false,"rows":[],'
          '"style":{"cover":"attachments/note-7/cover.jpg"}}';
      final attachments = NoteAttachments(images: const [cover]);
      expect(_roundTrip(withCover, attachments: attachments), withCover);

      final card = CheatsheetCodec.fromMap(
          (jsonDecode(withCover) as Map).cast<String, dynamic>(),
          attachments: attachments);
      expect(card.cover, cover);
    });
  });

  group('style', () {
    test('an unstyled card writes no style key', () {
      const c = CheatsheetCard(
        id: 'c1',
        title: 'T',
        walletGroup: 'Ungrouped',
        tags: [],
        templateId: 'blank',
        rows: [],
      );
      expect(CheatsheetCodec.toMap(c).containsKey('style'), isFalse);
    });

    test('a style that differs from the template is written', () {
      final c = const CheatsheetCard(
        id: 'c1',
        title: 'T',
        walletGroup: 'Ungrouped',
        tags: [],
        templateId: 'blank',
        rows: [],
      ).copyWith(
          style: CardStyle.empty
              .withTheme(CardThemeId.red, templateId: 'blank')
              .withPattern(CardPattern.waves));
      expect(CheatsheetCodec.toMap(c)['style'],
          {'theme': 'red', 'pattern': 'waves'});
    });

    test('unknown theme, pattern, layout and style keys are preserved', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'templateId': 'document',
        'rows': [],
        'style': {
          'theme': 'turquoise',
          'pattern': 'hexagons',
          'layout': 'timeline',
          'icon': 'not an emoji',
          'sparkle': {'a': 1},
        },
      });
      final look = decoded.look;
      expect(look.theme, CardThemeId.orange);
      expect(look.pattern, CardPattern.none);
      expect(look.layout, CardLayout.keyPoints);
      expect(look.icon, '\u{1F4D6}');
      expect(CheatsheetCodec.toMap(decoded)['style'], {
        'theme': 'turquoise',
        'pattern': 'hexagons',
        'layout': 'timeline',
        'icon': 'not an emoji',
        'sparkle': {'a': 1},
      });
    });

    test('mutating the source map after decode does not change the style',
        () {
      final nested = <String, dynamic>{'a': 1};
      final rawStyle = <String, dynamic>{'theme': 'red', 'sparkle': nested};
      final decoded = CheatsheetCodec.fromMap(
          {'id': 'x', 'templateId': 'blank', 'rows': [], 'style': rawStyle});
      rawStyle['theme'] = 'blue';
      rawStyle['pattern'] = 'dots';
      nested['a'] = 2;
      expect(decoded.look.theme, CardThemeId.red);
      expect(decoded.look.pattern, CardPattern.none);
      expect(CheatsheetCodec.toMap(decoded)['style'], {
        'theme': 'red',
        'sparkle': {'a': 1},
      });
    });

    test('a non-map style is kept verbatim as an unknown key', () {
      final decoded = CheatsheetCodec.fromMap(
          {'id': 'x', 'rows': [], 'style': 'from-the-future'});
      expect(decoded.style.isEmpty, isTrue);
      expect(CheatsheetCodec.toMap(decoded)['style'], 'from-the-future');
    });

    test('setting a style replaces a preserved non-map style', () {
      final decoded = CheatsheetCodec.fromMap(
          {'id': 'x', 'rows': [], 'style': 'from-the-future'});
      final edited = decoded.copyWith(
          style: decoded.style.withPattern(CardPattern.grid));
      expect(CheatsheetCodec.toMap(edited)['style'], {'pattern': 'grid'});
    });

    test('a cover path with no matching attachment yields no cover but keeps '
        'the path', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'rows': [],
        'style': {'cover': 'attachments/note-9/gone.jpg'},
      }, attachments: NoteAttachments.empty);
      expect(decoded.cover, isNull);
      expect(CheatsheetCodec.toMap(decoded)['style'],
          {'cover': 'attachments/note-9/gone.jpg'});
    });

    test('content records the cover PATH, never the ref', () {
      final c = const CheatsheetCard(
        id: 'c1',
        title: 'T',
        walletGroup: 'Ungrouped',
        tags: [],
        templateId: 'blank',
        rows: [],
      ).withCover(cover);
      final json = jsonEncode(CheatsheetCodec.toMap(c));
      expect(json, contains('"cover":"attachments/note-7/cover.jpg"'));
      expect(json, isNot(contains('contentType')));
      expect(json, isNot(contains('byteSize')));
    });
  });

  group('top-level and row unknown keys', () {
    test('unknown top-level keys survive an edit', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'title': 'T',
        'rows': [],
        'quickAccess': {'pinned': true},
      });
      final edited = decoded.copyWith(title: 'Renamed');
      expect(CheatsheetCodec.toMap(edited)['quickAccess'], {'pinned': true});
    });

    test('row emoji round-trips and unknown row keys are kept beside it', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'rows': [
          {'label': 'A', 'emoji': '\u{1F440}', 'hint': 'keep me'},
        ],
      });
      expect(decoded.rows.single.emoji, '\u{1F440}');
      final row = (CheatsheetCodec.toMap(decoded)['rows'] as List).single;
      expect(row['emoji'], '\u{1F440}');
      expect(row['hint'], 'keep me');
    });

    test('a non-string row emoji is preserved verbatim, not dropped', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'rows': [
          {'label': 'A', 'emoji': 42},
        ],
      });
      expect(decoded.rows.single.emoji, isNull);
      final row = (CheatsheetCodec.toMap(decoded)['rows'] as List).single;
      expect(row['emoji'], 42);
    });
  });

  group('reset semantics', () {
    test('an empty style and cleared row emoji leave no trace', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'rows': [
          {'label': 'A', 'emoji': '\u{1F440}'},
        ],
        'style': {'theme': 'red'},
      });
      final reset = decoded.copyWith(
        style: CardStyle.empty,
        rows: [
          for (final r in decoded.rows) r.copyWith(clearEmoji: true),
        ],
      );
      final map = CheatsheetCodec.toMap(reset);
      expect(map.containsKey('style'), isFalse);
      expect((map['rows'] as List).single.containsKey('emoji'), isFalse);
    });

    test('withCover(null) clears both the ref and the stored path', () {
      final c = const CheatsheetCard(
        id: 'c1',
        title: 'T',
        walletGroup: 'Ungrouped',
        tags: [],
        templateId: 'blank',
        rows: [],
      ).withCover(cover).withCover(null);
      expect(c.cover, isNull);
      expect(c.style.isEmpty, isTrue);
    });
  });

  group('equality', () {
    const base = CheatsheetCard(
      id: 'c1',
      title: 'T',
      walletGroup: 'Ungrouped',
      tags: [],
      templateId: 'blank',
      rows: [CheatsheetRow(label: 'A', source: null)],
    );

    test('style, cover, extras and row emoji are part of the value', () {
      expect(base.copyWith(style: const CardStyle({'theme': 'red'})),
          isNot(base));
      expect(base.withCover(cover), isNot(base));
      expect(base.copyWith(extraFields: const {'x': 1}), isNot(base));
      expect(
          base.copyWith(rows: [base.rows.single.copyWith(emoji: '⭐')]),
          isNot(base));
      expect(base.copyWith(), base);
      expect(base.copyWith().hashCode, base.hashCode);
    });
  });
}
