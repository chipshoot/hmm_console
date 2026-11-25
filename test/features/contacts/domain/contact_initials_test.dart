import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/contact_initials.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';

void main() {
  test('a person reads given then family initial, uppercased', () {
    expect(
      contactInitials(
        const Contact(
          id: 'a',
          contactType: ContactType.person,
          firstName: 'jane',
          lastName: 'smith',
        ),
      ),
      'JS',
    );
  });

  test('a person with one name has one initial', () {
    expect(
      contactInitials(
        const Contact(
          id: 'a',
          contactType: ContactType.person,
          firstName: 'Jane',
        ),
      ),
      'J',
    );
  });

  test('a CJK name uses its first character', () {
    expect(
      contactInitials(
        const Contact(
          id: 'a',
          contactType: ContactType.person,
          lastName: '王',
          firstName: '小明',
        ),
      ),
      '王',
    );
  });

  test('an organization uses its name initial', () {
    expect(
      contactInitials(
        const Contact(
          id: 'a',
          contactType: ContactType.organization,
          organizationName: 'acme',
        ),
      ),
      'A',
    );
  });

  test('no name gives null', () {
    expect(
      contactInitials(const Contact(id: 'a', contactType: ContactType.person)),
      isNull,
    );
  });
}
