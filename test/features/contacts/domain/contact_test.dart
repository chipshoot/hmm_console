import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';

void main() {
  Contact person() => const Contact(
    id: 'c-1',
    contactType: ContactType.person,
    firstName: 'Ada',
    lastName: 'Lovelace',
  );

  group('displayName', () {
    test('a person reads First Last', () {
      expect(person().displayName, 'Ada Lovelace');
    });

    test('a person with only a first name does not trail a space', () {
      expect(
        const Contact(
          id: 'c',
          contactType: ContactType.person,
          firstName: 'Ada',
        ).displayName,
        'Ada',
      );
    });

    test('an organization reads its organization name', () {
      expect(
        const Contact(
          id: 'c',
          contactType: ContactType.organization,
          organizationName: 'Intact Insurance',
        ).displayName,
        'Intact Insurance',
      );
    });

    test('a nameless contact yields empty, never null', () {
      expect(
        const Contact(id: 'c', contactType: ContactType.person).displayName,
        '',
      );
    });
  });

  test('value equality covers the repeatable field lists', () {
    const a = ContactPhone(label: 'mobile', number: '555');
    const b = ContactPhone(label: 'mobile', number: '555');
    expect(a, b);
    expect(
      person().copyWith(phones: const [a]),
      person().copyWith(phones: const [b]),
    );
  });

  test('copyWith replaces only what it is given', () {
    final edited = person().copyWith(firstName: 'Grace');
    expect(edited.firstName, 'Grace');
    expect(edited.lastName, 'Lovelace');
    expect(edited.id, 'c-1');
  });

  test('copyWith(notes: null) clears notes', () {
    final withNotes = person().copyWith(notes: 'some note');
    expect(withNotes.notes, 'some note');
    final cleared = withNotes.copyWith(notes: null);
    expect(cleared.notes, isNull);
  });

  test('copyWith(firstName: null) clears firstName', () {
    final withFirst = person();
    final cleared = withFirst.copyWith(firstName: null);
    expect(cleared.firstName, isNull);
  });

  test('relationship defaults to other with no custom label', () {
    expect(person().relationship.category, RelationshipCategory.other);
    expect(person().relationship.customLabel, isNull);
  });

  test('relationship copyWith can clear customLabel', () {
    final rel = person().relationship.copyWith(
      customLabel: 'custom',
      category: RelationshipCategory.friend,
    );
    expect(rel.customLabel, 'custom');
    final cleared = rel.copyWith(customLabel: null);
    expect(cleared.customLabel, isNull);
  });

  group('photo', () {
    const ref = VaultRef(
      path: 'n/1/a.jpg',
      contentType: 'image/jpeg',
      byteSize: 10,
    );

    test('copyWith keeps photo when omitted and clears it with null', () {
      const c = Contact(
        id: 'a',
        contactType: ContactType.person,
        firstName: 'Jane',
        photo: ref,
      );
      expect(c.copyWith(firstName: 'Janet').photo, ref);
      expect(c.copyWith(photo: null).photo, isNull);
    });

    test('photo takes part in equality', () {
      expect(
        const Contact(id: 'a', contactType: ContactType.person, photo: ref) ==
            const Contact(id: 'a', contactType: ContactType.person),
        isFalse,
      );
    });
  });
}
