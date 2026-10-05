import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
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

const contactNote = '{"note":{"content":{"Contact":{"firstName":"Ann","phones":['
    '{"label":"work","number":"555-0100"},{"label":"mobile","number":"555-0199"}],'
    '"tags":["a"]}}}}';

void main() {
  group('lists of maps (contacts)', () {
    test('fieldPaths walks list-of-map elements by index', () {
      final paths = NotePieceExtractor.fieldPaths(contactNote);
      expect(
        paths,
        containsAll([
          'Contact.phones.0.number',
          'Contact.phones.0.label',
          'Contact.phones.1.number',
          'Contact.firstName',
        ]),
      );
      expect(paths, isNot(contains('Contact.tags')));
      expect(paths, isNot(contains('Contact.tags.0')));
    });

    test('field steps into list elements by index', () {
      expect(NotePieceExtractor.field(contactNote, 'Contact.phones.1.number'),
          '555-0199');
    });

    test('field returns null for bad list segments', () {
      expect(NotePieceExtractor.field(contactNote, 'Contact.phones.9.number'),
          isNull);
      expect(NotePieceExtractor.field(contactNote, 'Contact.phones.x.number'),
          isNull);
      expect(NotePieceExtractor.field(contactNote, 'Contact.phones.-1.number'),
          isNull);
    });

    test('whole includes list-element fields', () {
      expect(NotePieceExtractor.whole(contactNote, null),
          contains('phones.0.number: 555-0100'));
    });
  });

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

    test('summarises a list-of-maps entity (service record parts)', () {
      const rec = '{"note":{"content":{"ServiceRecord":{"title":"Brakes",'
          '"parts":[{"name":"Pad","cost":40},{"name":"Rotor","cost":90}]}}}}';
      final result = NotePieceExtractor.whole(rec, null);
      expect(result, contains('title: Brakes'));
      expect(result, contains('parts.0.name: Pad'));
      expect(result, contains('parts.1.cost: 90'));
    });

    test('a contact summary omits schemaVersion, isSelf and isActivated', () {
      const c = '{"note":{"content":{"Contact":{"schemaVersion":1,'
          '"firstName":"Ann","isSelf":true,"isActivated":true}}}}';
      final result = NotePieceExtractor.whole(c, null);
      expect(result, contains('firstName: Ann'));
      for (final k in ['schemaVersion', 'isSelf', 'isActivated']) {
        expect(result, isNot(contains(k)));
      }
      // Offer filter only: an explicit path still resolves.
      expect(NotePieceExtractor.field(c, 'Contact.isSelf'), 'true');
    });

    test('isDeactivated reads isActivated:false and never throws', () {
      expect(NotePieceExtractor.isDeactivated(
          '{"note":{"content":{"X":{"isActivated":false}}}}'), isTrue);
      expect(NotePieceExtractor.isDeactivated(
          '{"note":{"content":{"X":{"isActivated":true}}}}'), isFalse);
      expect(NotePieceExtractor.isDeactivated(
          '{"note":{"content":{"X":{"a":1}}}}'), isFalse);
      expect(NotePieceExtractor.isDeactivated('not json'), isFalse);
      expect(NotePieceExtractor.isDeactivated(null), isFalse);
    });

    test('empty when neither is present', () {
      expect(NotePieceExtractor.whole(null, null), '');
    });

    test('empty for content that has no readable fields', () {
      expect(NotePieceExtractor.whole('not json', null), '');
    });
  });

  group('images', () {
    const primary = VaultRef(
        path: 'images/p.jpg', contentType: 'image/jpeg', byteSize: 1);
    const gallery = VaultRef(
        path: 'images/g.png', contentType: 'image/png', byteSize: 1);
    const scan = VaultRef(
        path: 'files/back.jpg', contentType: 'image/jpeg', byteSize: 1);
    const pdf = VaultRef(
        path: 'files/a.pdf', contentType: 'application/pdf', byteSize: 1);

    test('offers every image attachment, primary first, and no PDFs', () {
      final a = NoteAttachments(
        primaryImage: primary,
        images: const [gallery],
        files: const [scan, pdf],
      );
      expect(NotePieceExtractor.images(a), [primary, gallery, scan]);
    });

    test('no attachments yields no images', () {
      expect(NotePieceExtractor.images(null), isEmpty);
    });

    test('labels an image by the content key that points at it', () {
      const content = '{"note":{"content":{"DriverLicence":'
          '{"frontImagePath":"images/p.jpg"}}}}';
      expect(NotePieceExtractor.imageLabel(content, primary), 'frontImage');
      expect(NotePieceExtractor.imageLabel(content, gallery), 'g.png');
    });

    test('image path fields are not offered as text fields', () {
      const content = '{"note":{"content":{"DriverLicence":'
          '{"number":"D123","frontImagePath":"images/p.jpg"}}}}';
      expect(NotePieceExtractor.fieldPaths(content), ['DriverLicence.number']);
    });
  });

  test('isDeactivated follows the contact codec for malformed values', () {
    for (final raw in ['"false"', '0', '"0"']) {
      expect(
        NotePieceExtractor.isDeactivated(
            '{"note":{"content":{"Contact":{"isActivated":$raw}}}}'),
        isTrue,
        reason: raw,
      );
    }
    for (final raw in ['"yes"', '1', '"true"', 'null']) {
      expect(
        NotePieceExtractor.isDeactivated(
            '{"note":{"content":{"Contact":{"isActivated":$raw}}}}'),
        isFalse,
        reason: raw,
      );
    }
  });
}
