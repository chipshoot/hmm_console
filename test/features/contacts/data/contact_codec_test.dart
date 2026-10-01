import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';

void main() {
  const full = Contact(
    id: 'c-1',
    contactType: ContactType.person,
    firstName: 'Ada',
    lastName: 'Lovelace',
    phones: [ContactPhone(label: 'mobile', number: '555-0100')],
    emails: [ContactEmail(label: 'work', address: 'ada@example.com')],
    addresses: [ContactAddress(label: 'home', value: '1 Analytical Way')],
    relationship: ContactRelationship(category: RelationshipCategory.insurer),
    notes: 'agent for policy 123',
  );

  test('round-trips a fully populated contact', () {
    expect(ContactCodec.fromMap(ContactCodec.toMap(full)), full);
  });

  test('round-trips an organization', () {
    const org = Contact(
      id: 'c-2',
      contactType: ContactType.organization,
      organizationName: 'Intact',
    );
    expect(ContactCodec.fromMap(ContactCodec.toMap(org)), org);
  });

  test('stores the relationship by enum name, not by a translated label', () {
    // Localizing this would write display copy into saved data.
    expect(ContactCodec.toMap(full)['relationship']['category'], 'insurer');
  });

  test('an unknown relationship category falls back rather than throwing', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c',
      'contactType': 'person',
      'relationship': {'category': 'astrologer'},
    });
    expect(decoded.relationship.category, RelationshipCategory.other);
  });

  test('an unknown contactType falls back to person', () {
    final decoded = ContactCodec.fromMap({'id': 'c', 'contactType': 'alien'});
    expect(decoded.contactType, ContactType.person);
  });

  group('losslessness', () {
    test('unknown top-level fields survive a save', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c-1',
        'contactType': 'person',
        'firstName': 'Ada',
        'favouriteColour': 'green',
        'futureBlock': {'a': 1},
      });

      expect(decoded.extraFields['favouriteColour'], 'green');

      final resaved = ContactCodec.toMap(decoded.copyWith(firstName: 'Grace'));
      expect(resaved['favouriteColour'], 'green');
      expect(resaved['futureBlock'], {'a': 1});
      expect(resaved['firstName'], 'Grace');
    });

    test('a known key never leaks into extraFields', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'firstName': 'Ada',
      });
      expect(decoded.extraFields.containsKey('firstName'), isFalse);
      expect(decoded.extraFields.containsKey('id'), isFalse);
    });

    test('a malformed phones list does not take the contact down', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'phones': 'not-a-list',
      });
      expect(decoded.id, 'c');
      expect(decoded.phones, isEmpty);
    });

    test('a malformed entry inside phones is skipped, not fatal', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'phones': [
          {'label': 'mobile', 'number': '555'},
          'garbage',
        ],
      });
      expect(decoded.phones, hasLength(1));
      expect(decoded.phones.single.number, '555');
    });

    test('unknown nested fields in phones survive a save', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c-1',
        'contactType': 'person',
        'phones': [
          {'label': 'mobile', 'number': '555', 'primary': true},
        ],
      });

      expect(decoded.phones.single.extraFields['primary'], true);

      final resaved = ContactCodec.toMap(decoded);
      expect(resaved['phones'][0]['primary'], true);
    });

    test('unknown nested fields in relationship survive a save', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c-1',
        'contactType': 'person',
        'relationship': {
          'category': 'doctor',
          'note': 'family friend',
        },
      });

      expect(decoded.relationship.extraFields['note'], 'family friend');

      final resaved = ContactCodec.toMap(decoded);
      expect(resaved['relationship']['note'], 'family friend');
    });
  });

  test('unknown contactType enum value round-trips unchanged', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c',
      'contactType': 'pet',
      'firstName': 'Fluffy',
    });
    expect(decoded.contactType, ContactType.person); // fallback
    final resaved = ContactCodec.toMap(decoded);
    expect(resaved['contactType'], 'pet'); // but raw value preserved
  });

  test('unknown contactType changes to new value after explicit copyWith', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c',
      'contactType': 'pet',
    });
    final edited = decoded.copyWith(contactType: ContactType.organization);
    final resaved = ContactCodec.toMap(edited);
    expect(resaved['contactType'], 'organization'); // new value written
  });

  test('unknown relationship category round-trips unchanged', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c',
      'contactType': 'person',
      'relationship': {'category': 'dentist'},
    });
    expect(decoded.relationship.category, RelationshipCategory.other); // fallback
    final resaved = ContactCodec.toMap(decoded);
    expect(resaved['relationship']['category'], 'dentist'); // raw value preserved
  });

  test('unknown relationship category changes to new value after explicit copyWith', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c',
      'contactType': 'person',
      'relationship': {'category': 'dentist'},
    });
    final edited = decoded.copyWith(
      relationship: decoded.relationship.copyWith(category: RelationshipCategory.doctor),
    );
    final resaved = ContactCodec.toMap(edited);
    expect(resaved['relationship']['category'], 'doctor'); // new value written
  });

  test('isSelf: true round-trips', () {
    const contact = Contact(
      id: 'c-1',
      contactType: ContactType.person,
      firstName: 'Self',
      isSelf: true,
    );
    expect(ContactCodec.fromMap(ContactCodec.toMap(contact)), contact);
  });

  test('isActivated: false round-trips', () {
    const contact = Contact(
      id: 'c-1',
      contactType: ContactType.person,
      firstName: 'Inactive',
      isActivated: false,
    );
    expect(ContactCodec.fromMap(ContactCodec.toMap(contact)), contact);
  });
}
