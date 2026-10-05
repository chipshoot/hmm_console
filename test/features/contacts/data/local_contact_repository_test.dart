import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/local_contact_repository.dart';
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
    await repo.deactivateContact(''); // no-op, must not throw or write
    expect(notes.stored, hasLength(1));
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
}
