import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/note_piece_extractor.dart';

const gasNote = '{"note":{"content":{"GasLog":{"station":"Shell","price":1.65,'
    '"nested":{"x":"y"},"id":7,"uuid":"u","_v":1,"createdDate":"2026-01-01",'
    '"modifiedAt":"2026-01-02","automobileId":3,"tags":["a","b"]}}}}';

const md = '# Title\n'
    'intro\n'
    '## Shortcuts\n'
    '- dd delete line\n'
    '- yy yank\n'
    '## Config\n'
    'set nu\n';

void main() {
  group('fieldPaths', () {
    test('flattens leaf scalars', () {
      expect(
        NotePieceExtractor.fieldPaths(gasNote),
        containsAll(['GasLog.station', 'GasLog.price', 'GasLog.nested.x']),
      );
    });

    test('hides internal and audit keys', () {
      final paths = NotePieceExtractor.fieldPaths(gasNote);
      expect(paths, isNot(contains('GasLog.id')));
      expect(paths, isNot(contains('GasLog.uuid')));
      expect(paths, isNot(contains('GasLog._v')));
      expect(paths, isNot(contains('GasLog.createdDate')));
      expect(paths, isNot(contains('GasLog.modifiedAt')));
      expect(paths, isNot(contains('GasLog.automobileId')));
    });

    test('skips list-valued leaves', () {
      expect(NotePieceExtractor.fieldPaths(gasNote),
          isNot(contains('GasLog.tags')));
    });

    test('malformed or empty content yields no paths', () {
      expect(NotePieceExtractor.fieldPaths('not json'), isEmpty);
      expect(NotePieceExtractor.fieldPaths(null), isEmpty);
      expect(NotePieceExtractor.fieldPaths('{"unexpected":1}'), isEmpty);
    });
  });

  group('field', () {
    test('reads a dotted path', () {
      expect(NotePieceExtractor.field(gasNote, 'GasLog.station'), 'Shell');
      expect(NotePieceExtractor.field(gasNote, 'GasLog.nested.x'), 'y');
      expect(NotePieceExtractor.field(gasNote, 'GasLog.price'), '1.65');
    });

    test('returns null for a missing path', () {
      expect(NotePieceExtractor.field(gasNote, 'GasLog.missing'), isNull);
      expect(NotePieceExtractor.field(gasNote, 'Nope.at.all'), isNull);
    });

    test('returns null for a non-scalar node', () {
      expect(NotePieceExtractor.field(gasNote, 'GasLog.nested'), isNull);
      expect(NotePieceExtractor.field(gasNote, 'GasLog.tags'), isNull);
    });

    test('still resolves an explicitly bound internal path', () {
      // Offer policy is not resolution policy: a binding made before the
      // filter tightened must keep working.
      expect(NotePieceExtractor.field(gasNote, 'GasLog.id'), '7');
      expect(
          NotePieceExtractor.field(gasNote, 'GasLog.createdDate'), '2026-01-01');
    });

    test('malformed content never throws', () {
      expect(NotePieceExtractor.field('not json', 'a.b'), isNull);
      expect(NotePieceExtractor.field(null, 'a.b'), isNull);
    });
  });

  group('section', () {
    test('lists headings', () {
      expect(NotePieceExtractor.sectionHeadings(md),
          containsAll(['Title', 'Shortcuts', 'Config']));
      expect(NotePieceExtractor.sectionHeadings(null), isEmpty);
    });

    test('extracts the block under a heading', () {
      expect(NotePieceExtractor.section(md, 'Shortcuts'),
          contains('dd delete line'));
      expect(NotePieceExtractor.section(md, 'Shortcuts'),
          isNot(contains('set nu')));
    });

    test('returns null for an absent heading', () {
      expect(NotePieceExtractor.section(md, 'Nope'), isNull);
      expect(NotePieceExtractor.section(null, 'Shortcuts'), isNull);
    });

    test('the last section runs to the end', () {
      expect(NotePieceExtractor.section(md, 'Config'), 'set nu');
    });
  });

  group('whole', () {
    test('prefers a non-blank description', () {
      expect(
          NotePieceExtractor.whole(gasNote, 'a description'), 'a description');
    });

    test('summarises an entity note instead of dumping the raw envelope', () {
      // A card is a user-facing surface. Falling back to the raw content
      // string put the whole JSON envelope on it — the same internal
      // plumbing fieldPaths exists to keep out of the binding list.
      for (final description in [null, '   ']) {
        final result = NotePieceExtractor.whole(gasNote, description);
        expect(result, isNot(contains('{"note"')));
        expect(result, isNot(contains('"content"')));
        expect(result, contains('station: Shell'));
        expect(result, contains('price: 1.65'));
        expect(result, contains('nested.x: y'));
      }
    });

    test('the summary leaks no internal or audit keys', () {
      final result = NotePieceExtractor.whole(gasNote, null);
      for (final key in ['uuid', 'createdDate', 'modifiedAt', 'automobileId']) {
        expect(result, isNot(contains(key)), reason: '$key must not appear');
      }
      expect(result, isNot(contains('_v')));
      expect(result, isNot(contains('id: 7')));
    });

    test('empty when neither is present', () {
      expect(NotePieceExtractor.whole(null, null), '');
    });

    test('empty for content that has no readable fields', () {
      expect(NotePieceExtractor.whole('not json', null), '');
    });
  });
}
