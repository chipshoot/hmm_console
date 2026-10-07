import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_resolver.dart';
import 'package:hmm_console/features/cheatsheet/domain/derived_field_registry.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/data/contact_derived_fields.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

class _FakeNotes implements IHmmNoteRepository {
  _FakeNotes(this._byUuid);
  final Map<String, HmmNote> _byUuid;

  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => _byUuid[uuid];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

/// The envelope `LocalContactRepository._serialize` writes.
HmmNote contactNote(Contact c) => HmmNote(
      id: 1,
      uuid: 'doc-uuid',
      subject: 'Contact:${c.id}',
      authorId: 1,
      createDate: DateTime(2026),
      content: jsonEncode({
        'note': {
          'content': {'Contact': ContactCodec.toMap(c)},
        },
      }),
    );

const _row = CheatsheetRow(
  label: 'Family doctor phone',
  source: CheatsheetSource(
    noteUuid: 'doc-uuid',
    kind: SourceGranularity.field,
    locator: 'Contact.phones.0.number',
  ),
);

void main() {
  const doctor = Contact(
    id: 'c1',
    contactType: ContactType.person,
    firstName: 'Lee',
    phones: [ContactPhone(label: 'work', number: '555-0100')],
  );

  test('a contact phone resolves through a field row', () async {
    final r = CheatsheetResolver(_FakeNotes({'doc-uuid': contactNote(doctor)}));
    final v = await r.resolve(_row);
    expect(v.text, '555-0100');
    expect(v.missing, isFalse);
  });

  test('a deactivated contact resolves as missing', () async {
    final r = CheatsheetResolver(_FakeNotes({
      'doc-uuid': contactNote(doctor.copyWith(isActivated: false)),
    }));
    final v = await r.resolve(_row);
    expect(v.missing, isTrue);
    expect(v.text, isNull);
  });

  test('Contact.displayName resolves to the full name', () async {
    const named = Contact(
      id: 'c2',
      contactType: ContactType.person,
      firstName: 'First',
      lastName: 'Last',
    );
    final r = CheatsheetResolver(_FakeNotes({'doc-uuid': contactNote(named)}));
    final v = await r.resolve(const CheatsheetRow(
      label: 'Name',
      source: CheatsheetSource(
        noteUuid: 'doc-uuid',
        kind: SourceGranularity.field,
        locator: 'Contact.displayName',
      ),
    ));
    expect(v.text, 'First Last');
  });

  test('an absent contact note is missing', () async {
    final r = CheatsheetResolver(_FakeNotes({}));
    expect((await r.resolve(_row)).missing, isTrue);
  });

  group('derived Contact.displayName', () {
    const nameRow = CheatsheetRow(
      label: 'Name',
      source: CheatsheetSource(
        noteUuid: 'doc-uuid',
        kind: SourceGranularity.field,
        locator: 'Contact.displayName',
      ),
    );

    /// A note saved by the pre-order client: displayName "伟 张".
    HmmNote legacy(Map<String, dynamic> contact) => HmmNote(
      id: 1,
      uuid: 'doc-uuid',
      subject: 'Contact:c-zh',
      authorId: 1,
      createDate: DateTime(2026),
      content: jsonEncode({
        'note': {
          'content': {'Contact': contact},
        },
      }),
    );

    const legacyZh = {
      'schemaVersion': 1,
      'displayName': '伟 张',
      'id': 'c-zh',
      'contactType': 'person',
      'firstName': '伟',
      'lastName': '张',
    };

    test('an unsaved legacy contact shows 张伟 through the registry',
        () async {
      final r = CheatsheetResolver(
        _FakeNotes({'doc-uuid': legacy(legacyZh)}),
        const DerivedFieldRegistry(contactDerivedFields),
      );
      expect((await r.resolve(nameRow)).text, '张伟');
    });

    test('without the registry the stored value is used', () async {
      final r = CheatsheetResolver(_FakeNotes({'doc-uuid': legacy(legacyZh)}));
      expect((await r.resolve(nameRow)).text, '伟 张');
    });

    test('a nameless contact falls back to the stored value', () async {
      final r = CheatsheetResolver(
        _FakeNotes({
          'doc-uuid': legacy({
            'id': 'c-x',
            'contactType': 'person',
            'displayName': 'Kept',
          }),
        }),
        const DerivedFieldRegistry(contactDerivedFields),
      );
      expect((await r.resolve(nameRow)).text, 'Kept');
    });

    test('other Contact paths are untouched', () async {
      final r = CheatsheetResolver(
        _FakeNotes({'doc-uuid': contactNote(doctor)}),
        const DerivedFieldRegistry(contactDerivedFields),
      );
      expect((await r.resolve(_row)).text, '555-0100');
    });
  });
}
