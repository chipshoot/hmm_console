import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_resolver.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

/// Only [getNoteByUuid] is exercised by the resolver; everything else throws
/// via noSuchMethod so an accidental new dependency shows up loudly.
class _FakeNotes implements IHmmNoteRepository {
  _FakeNotes(this._byUuid);

  final Map<String, HmmNote> _byUuid;

  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => _byUuid[uuid];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  final auto = HmmNote(
    id: 1,
    uuid: 'auto1',
    subject: 'Auto',
    authorId: 1,
    createDate: DateTime(2026),
    content: '{"note":{"content":{"AutomobileInfo":{"plate":"ABC123"}}}}',
  );
  final doc = HmmNote(
    id: 2,
    uuid: 'doc1',
    subject: 'Doc',
    authorId: 1,
    createDate: DateTime(2026),
    description: '# Title\nintro\n## Shortcuts\n- dd delete line\n',
  );

  CheatsheetResolver resolver() =>
      CheatsheetResolver(_FakeNotes({'auto1': auto, 'doc1': doc}));

  test('field hit', () async {
    final v = await resolver().resolve(const CheatsheetRow(
      label: 'Plate',
      source: CheatsheetSource(
        noteUuid: 'auto1',
        kind: SourceGranularity.field,
        locator: 'AutomobileInfo.plate',
      ),
    ));
    expect(v.text, 'ABC123');
    expect(v.missing, isFalse);
    expect(v.unbound, isFalse);
  });

  test('section hit', () async {
    final v = await resolver().resolve(const CheatsheetRow(
      label: 'Shortcuts',
      source: CheatsheetSource(
        noteUuid: 'doc1',
        kind: SourceGranularity.section,
        locator: 'Shortcuts',
      ),
    ));
    expect(v.text, contains('dd delete line'));
  });

  test('whole hit', () async {
    final v = await resolver().resolve(const CheatsheetRow(
      label: 'All',
      source: CheatsheetSource(noteUuid: 'doc1', kind: SourceGranularity.whole),
    ));
    expect(v.text, contains('# Title'));
  });

  test('a deactivated non-contact entity resolves as missing', () async {
    final off = HmmNote(
      id: 3,
      uuid: 'off1',
      subject: 'Off',
      authorId: 1,
      createDate: DateTime(2026),
      content:
          '{"note":{"content":{"Thing":{"plate":"Z","isActivated":false}}}}',
    );
    final r = CheatsheetResolver(_FakeNotes({'off1': off}));
    for (final kind in [SourceGranularity.field, SourceGranularity.whole]) {
      final v = await r.resolve(CheatsheetRow(
        label: 'x',
        source: CheatsheetSource(
          noteUuid: 'off1',
          kind: kind,
          locator: 'Thing.plate',
        ),
      ));
      expect(v.missing, isTrue, reason: '$kind');
    }
  });

  test('unbound row', () async {
    final v =
        await resolver().resolve(const CheatsheetRow(label: 'x', source: null));
    expect(v.unbound, isTrue);
    expect(v.text, isNull);
  });

  test('missing note', () async {
    final v = await resolver().resolve(const CheatsheetRow(
      label: 'x',
      source: CheatsheetSource(noteUuid: 'nope', kind: SourceGranularity.whole),
    ));
    expect(v.missing, isTrue);
  });

  test('missing field', () async {
    final v = await resolver().resolve(const CheatsheetRow(
      label: 'x',
      source: CheatsheetSource(
        noteUuid: 'auto1',
        kind: SourceGranularity.field,
        locator: 'AutomobileInfo.vin',
      ),
    ));
    expect(v.missing, isTrue);
  });

  test('missing section', () async {
    final v = await resolver().resolve(const CheatsheetRow(
      label: 'x',
      source: CheatsheetSource(
        noteUuid: 'doc1',
        kind: SourceGranularity.section,
        locator: 'Nope',
      ),
    ));
    expect(v.missing, isTrue);
  });

  test('malformed source content degrades to missing, never throws', () async {
    final bad = HmmNote(
      id: 3,
      uuid: 'bad1',
      subject: 'Bad',
      authorId: 1,
      createDate: DateTime(2026),
      content: 'not json',
    );
    final v = await CheatsheetResolver(_FakeNotes({'bad1': bad})).resolve(
      const CheatsheetRow(
        label: 'x',
        source: CheatsheetSource(
          noteUuid: 'bad1',
          kind: SourceGranularity.field,
          locator: 'A.b',
        ),
      ),
    );
    expect(v.missing, isTrue);
  });

  group('image', () {
    const front = VaultRef(
      path: 'images/front.jpg',
      contentType: 'image/jpeg',
      byteSize: 10,
      sensitive: true,
    );
    final licence = HmmNote(
      id: 3,
      uuid: 'lic1',
      subject: 'Licence',
      authorId: 1,
      createDate: DateTime(2026),
      content: '{"note":{"content":{"DriverLicence":'
          '{"frontImagePath":"images/front.jpg"}}}}',
      attachments: NoteAttachments(images: const [front]),
    );

    CheatsheetResolver imageResolver() =>
        CheatsheetResolver(_FakeNotes({'lic1': licence}));

    test('resolves to the attachment, not its path text', () async {
      final v = await imageResolver().resolve(const CheatsheetRow(
        label: 'Licence (front)',
        source: CheatsheetSource(
          noteUuid: 'lic1',
          kind: SourceGranularity.image,
          locator: 'images/front.jpg',
        ),
      ));
      expect(v.image, front);
      expect(v.text, isNull);
      expect(v.missing, isFalse);
    });

    test('an image no longer on the note is missing', () async {
      final v = await imageResolver().resolve(const CheatsheetRow(
        label: 'Licence (back)',
        source: CheatsheetSource(
          noteUuid: 'lic1',
          kind: SourceGranularity.image,
          locator: 'images/back.jpg',
        ),
      ));
      expect(v.missing, isTrue);
      expect(v.image, isNull);
    });

    test('an image on a deactivated note reads as removed', () async {
      final removed = HmmNote(
        id: 4,
        uuid: 'lic2',
        subject: 'Licence',
        authorId: 1,
        createDate: DateTime(2026),
        content: '{"note":{"content":{"DriverLicence":'
            '{"frontImagePath":"images/front.jpg","isActivated":false}}}}',
        attachments: NoteAttachments(images: const [front]),
      );
      final v = await CheatsheetResolver(_FakeNotes({'lic2': removed}))
          .resolve(const CheatsheetRow(
        label: 'Licence (front)',
        source: CheatsheetSource(
          noteUuid: 'lic2',
          kind: SourceGranularity.image,
          locator: 'images/front.jpg',
        ),
      ));
      expect(v.missing, isTrue);
      expect(v.image, isNull);
    });
  });
}
