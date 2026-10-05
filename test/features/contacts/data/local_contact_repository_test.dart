import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_contact_repository.dart';
import 'package:hmm_console/features/contacts/data/i_contact_repository.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';

import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

import 'contact_repository_fakes.dart';

HmmNote _rawNote(int id, String subject, String content) => HmmNote(
      id: id,
      uuid: 'raw$id',
      subject: subject,
      authorId: 1,
      createDate: DateTime(2026),
      catalogId: 7,
      content: content,
    );

void main() {
  late LocalContactRepository repo;
  late FakeNoteRepository notes;

  setUp(() {
    notes = FakeNoteRepository();
    repo = LocalContactRepository(notes, FakeCatalogRepository());
  });

  Contact person(String name, {bool isSelf = false}) => Contact(
        id: '',
        contactType: ContactType.person,
        firstName: name,
        isSelf: isSelf,
      );

  test('saving mints an id when the caller supplies none', () async {
    final saved = await repo.saveContact(person('Ada'));
    expect(saved.id, isNotEmpty);
  });

  test('saving stores under the subject identity, not the name', () async {
    final saved = await repo.saveContact(person('Ada'));
    expect(notes.stored.single.subject, contactSubjectFor(saved.id));
  });

  test('renaming updates in place rather than creating a second note', () async {
    final saved = await repo.saveContact(person('Ada'));
    await repo.saveContact(saved.copyWith(firstName: 'Grace'));

    expect(notes.stored, hasLength(1));
    expect((await repo.getContact(saved.id))!.firstName, 'Grace');
  });

  test('getContacts hides deactivated contacts by default', () async {
    final saved = await repo.saveContact(person('Ada'));
    await repo.deactivateContact(saved.id);

    expect(await repo.getContacts(), isEmpty);
    expect(await repo.getContacts(includeDeactivated: true), hasLength(1));
  });

  test('a deactivated contact still resolves by id, so references degrade', () async {
    final saved = await repo.saveContact(person('Ada'));
    await repo.deactivateContact(saved.id);

    final found = await repo.getContact(saved.id);
    expect(found, isNotNull);
    expect(found!.isActivated, isFalse);
  });

  test('setting isSelf clears it from every other contact', () async {
    final ada = await repo.saveContact(person('Ada', isSelf: true));
    final grace = await repo.saveContact(person('Grace', isSelf: true));

    expect((await repo.getContact(grace.id))!.isSelf, isTrue);
    expect((await repo.getContact(ada.id))!.isSelf, isFalse);
  });

  test('saving a non-self contact leaves the existing self alone', () async {
    final ada = await repo.saveContact(person('Ada', isSelf: true));
    await repo.saveContact(person('Grace'));

    expect((await repo.getContact(ada.id))!.isSelf, isTrue);
  });

  test('an unreadable note is omitted from the list, not fatal', () async {
    await repo.saveContact(person('Ada'));
    notes.stored.add(_rawNote(99, 'Contact:broken', 'not json'));

    expect(await repo.getContacts(), hasLength(1));
  });

  test('a decoded contact with a blank id is skipped, never an identity', () async {
    notes.stored.add(_rawNote(
      50,
      'Contact:',
      jsonEncode({
        'note': {
          'content': {
            'Contact': {'id': '', 'contactType': 'person', 'firstName': 'X'},
          },
        },
      }),
    ));

    expect(await repo.getContacts(includeDeactivated: true), isEmpty);
    expect(await repo.getContact(''), isNull);
    // Blank id is never an identity: deactivating it is "not found", and it
    // writes nothing.
    await expectLater(
      repo.deactivateContact(''),
      throwsA(isA<ContactNotFound>()),
    );
    expect(notes.stored, hasLength(1));
    expect(notes.stored.single.content, contains('"firstName":"X"'));
  });

  test('saving over an unreadable note updates it, not a duplicate', () async {
    notes.stored.add(_rawNote(60, contactSubjectFor('abc'), 'not json'));
    await repo.saveContact(Contact(
      id: 'abc',
      contactType: ContactType.person,
      firstName: 'Ada',
    ));

    expect(notes.stored, hasLength(1));
    expect((await repo.getContact('abc'))!.firstName, 'Ada');
  });

  test('lists beyond one page', () async {
    for (var i = 0; i < 105; i++) {
      await repo.saveContact(person('P$i'));
    }
    expect(await repo.getContacts(), hasLength(105));
  });

  test(
    'a malformed "isActivated": "false" stays hidden from getContacts',
    () async {
      notes.stored.add(
        _rawNote(
          70,
          contactSubjectFor('m1'),
          jsonEncode({
            'note': {
              'content': {
                'Contact': {
                  'id': 'm1',
                  'contactType': 'person',
                  'firstName': 'Gone',
                  'isActivated': 'false',
                },
              },
            },
          }),
        ),
      );

      expect(await repo.getContacts(), isEmpty);
      expect(await repo.getContacts(includeDeactivated: true), hasLength(1));
    },
  );

  test('an update keeps every other key in the note envelope', () async {
    notes.stored.add(_rawNote(
      80,
      contactSubjectFor('e1'),
      jsonEncode({
        'note': {
          'content': {
            'Contact': {'id': 'e1', 'contactType': 'person', 'firstName': 'A'},
            'ContactPhoto': {'x': 1},
          },
          'schemaVersion': 2,
        },
        'top': true,
      }),
    ));

    final existing = (await repo.getContact('e1'))!;
    await repo.saveContact(existing.copyWith(firstName: 'B'));

    final json = jsonDecode(notes.stored.single.content!) as Map;
    expect(json['top'], true);
    expect(json['note']['schemaVersion'], 2);
    expect(json['note']['content']['ContactPhoto'], {'x': 1});
    expect(json['note']['content']['Contact']['firstName'], 'B');
  });

  test('an update over unparsable content writes a fresh envelope', () async {
    notes.stored.add(_rawNote(81, contactSubjectFor('e2'), '{broken'));
    await repo.saveContact(const Contact(
      id: 'e2',
      contactType: ContactType.person,
      firstName: 'C',
    ));
    final json = jsonDecode(notes.stored.single.content!) as Map;
    expect(json['note']['content']['Contact']['firstName'], 'C');
  });

  group('not found and unreadable are reported, never silent', () {
    test('deactivating an unknown id throws ContactNotFound', () async {
      await expectLater(
        repo.deactivateContact('nope'),
        throwsA(isA<ContactNotFound>().having((e) => e.id, 'id', 'nope')),
      );
      expect(notes.stored, isEmpty);
    });

    test('getContact on an unreadable note throws ContactUnreadable', () async {
      notes.stored.add(_rawNote(90, contactSubjectFor('u1'), 'not json'));
      await expectLater(
        repo.getContact('u1'),
        throwsA(isA<ContactUnreadable>().having((e) => e.id, 'id', 'u1')),
      );
    });

    test('getContact on a note with no Contact payload throws unreadable',
        () async {
      notes.stored.add(_rawNote(
          91, contactSubjectFor('u2'), jsonEncode({'note': {'content': {}}})));
      await expectLater(
          repo.getContact('u2'), throwsA(isA<ContactUnreadable>()));
    });

    test('getContact on an absent id still returns null', () async {
      expect(await repo.getContact('absent'), isNull);
    });

    test('deactivating an unreadable contact throws and writes nothing',
        () async {
      notes.stored.add(_rawNote(92, contactSubjectFor('u3'), 'not json'));
      await expectLater(
          repo.deactivateContact('u3'), throwsA(isA<ContactUnreadable>()));
      expect(notes.stored.single.content, 'not json');
    });
  });

  test('an unreadable note is logged by id, never by its JSON', () async {
    final logs = <String>[];
    final saved = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
    addTearDown(() => debugPrint = saved);

    notes.stored.add(
        _rawNote(95, contactSubjectFor('p1'), '{"phone":"555-SECRET"'));
    await repo.getContacts();

    expect(logs.join('\n'), contains('95'));
    expect(logs.join('\n'), isNot(contains('555-SECRET')));
  });
}
