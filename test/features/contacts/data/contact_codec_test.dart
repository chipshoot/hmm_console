import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/domain/address_format.dart';
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

  test('a stored schemaVersion newer than current round-trips unchanged', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c-9',
      'contactType': 'person',
      'schemaVersion': 2,
    });
    expect(ContactCodec.toMap(decoded)['schemaVersion'], 2);
    expect(ContactCodec.toMap(full)['schemaVersion'],
        ContactCodec.currentSchemaVersion);
  });

  test('toMap writes the derived displayName', () {
    expect(ContactCodec.toMap(full)['displayName'], 'Ada Lovelace');
  });

  test('a stale stored displayName survives an untouched save only', () {
    final decoded = ContactCodec.fromMap({
      'id': 'c-8',
      'contactType': 'person',
      'firstName': 'New',
      'lastName': 'Name',
      'displayName': 'Old Name',
    });
    expect(decoded.firstName, 'New');
    expect(decoded.extraFields.containsKey('displayName'), isFalse);
    // Untouched: the stored bytes are kept (spec: no bulk rewrite).
    expect(ContactCodec.toMap(decoded)['displayName'], 'Old Name');
    // A no-op copy is still untouched.
    expect(
      ContactCodec.toMap(decoded.copyWith(firstName: 'New'))['displayName'],
      'Old Name',
    );
    // Any edit re-derives it.
    expect(
      ContactCodec.toMap(decoded.copyWith(notes: 'x'))['displayName'],
      'New Name',
    );
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

  group('wrong-typed known values survive a save', () {
    Map<String, dynamic> roundTrip(Map<String, dynamic> m) =>
        ContactCodec.toMap(ContactCodec.fromMap(m));

    test('a string isActivated "false" reads as deactivated and is kept', () {
      final m = {'id': 'c', 'contactType': 'person', 'isActivated': 'false'};
      expect(ContactCodec.fromMap(m).isActivated, isFalse);
      expect(roundTrip(m)['isActivated'], 'false');
    });

    test('isActivated 0 and "0" read as deactivated and are kept', () {
      for (final raw in [0, '0']) {
        final m = {'id': 'c', 'contactType': 'person', 'isActivated': raw};
        expect(ContactCodec.fromMap(m).isActivated, isFalse, reason: '$raw');
        expect(roundTrip(m)['isActivated'], raw);
      }
    });

    test('any other malformed isActivated stays active and is kept', () {
      final m = {'id': 'c', 'contactType': 'person', 'isActivated': 'yes'};
      expect(ContactCodec.fromMap(m).isActivated, isTrue);
      expect(roundTrip(m)['isActivated'], 'yes');
    });

    test(
      'changing isActivated writes the typed value over a malformed one',
      () {
        final decoded = ContactCodec.fromMap({
          'id': 'c',
          'contactType': 'person',
          'isActivated': 'false',
        });
        expect(
          ContactCodec.toMap(
            decoded.copyWith(isActivated: true),
          )['isActivated'],
          true,
        );
      },
    );

    test('a numeric phone number is kept verbatim', () {
      final m = {
        'id': 'c',
        'contactType': 'person',
        'phones': [
          {'label': 'mobile', 'number': 5551234},
        ],
      };
      expect(roundTrip(m)['phones'], [
        {'label': 'mobile', 'number': 5551234},
      ]);
    });

    test(
      'a wrong-typed entry label, email address and address value are kept',
      () {
        final m = {
          'id': 'c',
          'contactType': 'person',
          'emails': [
            {'label': 3, 'address': true},
          ],
          'addresses': [
            {
              'label': 'home',
              'value': {'street': '1 Main'},
            },
          ],
        };
        final out = roundTrip(m);
        expect(out['emails'], [
          {'label': 3, 'address': true},
        ]);
        expect(out['addresses'], [
          {
            'label': 'home',
            'value': {'street': '1 Main'},
          },
        ]);
      },
    );

    test('editing the number replaces the malformed raw value', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'phones': [
          {'label': 'mobile', 'number': 5551234},
        ],
      });
      final edited = decoded.copyWith(
        phones: [decoded.phones.single.copyWith(number: '555-1234')],
      );
      expect(ContactCodec.toMap(edited)['phones'][0]['number'], '555-1234');
    });

    test('a non-Map relationship is kept verbatim', () {
      final m = {'id': 'c', 'contactType': 'person', 'relationship': 'doctor'};
      expect(roundTrip(m)['relationship'], 'doctor');
    });

    test('choosing a relationship replaces a non-Map one', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'relationship': 'doctor',
      });
      final edited = decoded.copyWith(
        relationship: decoded.relationship.copyWith(
          category: RelationshipCategory.doctor,
        ),
      );
      expect(ContactCodec.toMap(edited)['relationship'], {
        'category': 'doctor',
      });
    });

    test(
      'wrong-typed category and customLabel inside relationship are kept',
      () {
        final m = {
          'id': 'c',
          'contactType': 'person',
          'relationship': {'category': 4, 'customLabel': 9},
        };
        expect(roundTrip(m)['relationship'], {'category': 4, 'customLabel': 9});
      },
    );

    test('a non-List phones/emails/addresses is kept verbatim', () {
      final m = {
        'id': 'c',
        'contactType': 'person',
        'phones': 'not-a-list',
        'emails': {'a': 1},
        'addresses': 7,
      };
      final out = roundTrip(m);
      expect(out['phones'], 'not-a-list');
      expect(out['emails'], {'a': 1});
      expect(out['addresses'], 7);
    });

    test('adding a phone replaces a non-List phones value', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'phones': 'not-a-list',
      });
      final edited = decoded.copyWith(
        phones: const [ContactPhone(label: 'mobile', number: '1')],
      );
      expect(ContactCodec.toMap(edited)['phones'], [
        {'label': 'mobile', 'number': '1'},
      ]);
    });

    test('wrong-typed scalar fields are kept verbatim', () {
      final m = {
        'id': 'c',
        'contactType': 5,
        'firstName': 42,
        'lastName': ['x'],
        'organizationName': false,
        'notes': {'n': 1},
        'isSelf': 'true',
        'schemaVersion': '2',
      };
      final decoded = ContactCodec.fromMap(m);
      expect(decoded.firstName, isNull);
      expect(decoded.isSelf, isFalse);
      final out = ContactCodec.toMap(decoded);
      for (final k in m.keys) {
        expect(out[k], m[k], reason: k);
      }
    });

    test('typing a first name replaces a wrong-typed one', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'firstName': 42,
      });
      expect(
        ContactCodec.toMap(decoded.copyWith(firstName: 'Ada'))['firstName'],
        'Ada',
      );
    });
  });

  group('malformed list entries are never dropped', () {
    test('non-Map entries are re-emitted after the readable ones', () {
      final m = {
        'id': 'c',
        'contactType': 'person',
        'phones': [
          'garbage',
          {'label': 'mobile', 'number': '555'},
          42,
        ],
        'emails': [null],
        'addresses': [
          ['nested'],
        ],
      };
      final decoded = ContactCodec.fromMap(m);
      expect(decoded.phones.single.number, '555');
      final out = ContactCodec.toMap(decoded);
      expect(out['phones'], [
        {'label': 'mobile', 'number': '555'},
        'garbage',
        42,
      ]);
      expect(out['emails'], [null]);
      expect(out['addresses'], [
        ['nested'],
      ]);
    });

    test('unreadable entries survive an edit of the readable ones', () {
      final decoded = ContactCodec.fromMap({
        'id': 'c',
        'contactType': 'person',
        'phones': ['garbage'],
      });
      final edited = decoded.copyWith(
        phones: const [ContactPhone(label: 'home', number: '1')],
      );
      expect(ContactCodec.toMap(edited)['phones'], [
        {'label': 'home', 'number': '1'},
        'garbage',
      ]);
    });

    test('logs the contact id and list name, never the entry', () {
      final logs = <String>[];
      final saved = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      addTearDown(() => debugPrint = saved);

      ContactCodec.fromMap({
        'id': 'c-77',
        'contactType': 'person',
        'phones': ['555-SECRET', 'x'],
        'emails': ['secret@example.com'],
      });

      expect(logs, hasLength(1));
      expect(logs.single, contains('c-77'));
      expect(logs.single, contains('phones'));
      expect(logs.single, contains('emails'));
      expect(logs.single, isNot(contains('SECRET')));
      expect(logs.single, isNot(contains('secret@')));
    });
  });

  group('structured addresses', () {
    Map<String, dynamic> stored(List<Object?> addresses) => {
      'schemaVersion': 1,
      'id': 'c-9',
      'contactType': 'person',
      'firstName': 'Ada',
      'addresses': addresses,
    };

    String roundTrip(Map<String, dynamic> m) =>
        jsonEncode(ContactCodec.toMap(ContactCodec.fromMap(m))['addresses']);

    test('an old {label, value} entry is free-form and byte-identical', () {
      final m = stored([
        {'label': 'home', 'value': '1 Main St\nSpringfield'},
      ]);
      final a = ContactCodec.fromMap(m).addresses.single;
      expect(a.country, isNull);
      expect(a.isStructured, isFalse);
      expect(a.value, '1 Main St\nSpringfield');
      expect(roundTrip(m), jsonEncode(m['addresses']));
      expect(
        ContactCodec.toMap(ContactCodec.fromMap(m))['addresses'][0].keys,
        ['label', 'value'],
        reason: 'no structured key is invented for a free-form address',
      );
    });

    test('a structured entry decodes every part and round-trips', () {
      final m = stored([
        {
          'label': 'home',
          'value': '1 Main St, Springfield, IL 62701, United States',
          'country': 'US',
          'street1': '1 Main St',
          'city': 'Springfield',
          'region': 'IL',
          'postalCode': '62701',
        },
        {
          'label': 'work',
          'value': '中国 广东省 深圳市 南山区 科技园路1号',
          'country': 'CN',
          'street1': '科技园路1号',
          'city': '深圳市',
          'district': '南山区',
          'region': 'GD',
        },
      ]);
      final c = ContactCodec.fromMap(m);
      final us = c.addresses[0];
      expect(us.country, 'US');
      expect(us.street1, '1 Main St');
      expect(us.street2, isNull);
      expect(us.city, 'Springfield');
      expect(us.region, 'IL');
      expect(us.postalCode, '62701');
      expect(us.extraFields, isEmpty, reason: 'structured keys are known');
      final cn = c.addresses[1];
      expect(cn.district, '南山区');
      expect(roundTrip(m), jsonEncode(m['addresses']));
    });

    test('unknown keys inside a structured address are preserved', () {
      final m = stored([
        {
          'geo': {'lat': 1.5, 'lng': 2.5},
          'label': 'home',
          'value': 'x',
          'country': 'CA',
          'city': 'Ottawa',
        },
      ]);
      final a = ContactCodec.fromMap(m).addresses.single;
      expect(a.extraFields, {
        'geo': {'lat': 1.5, 'lng': 2.5},
      });
      expect(roundTrip(m), jsonEncode(m['addresses']));
    });

    test('wrong-typed structured keys are kept verbatim until edited', () {
      final m = stored([
        {'label': 'home', 'value': 'x', 'country': 'US', 'postalCode': 62701},
      ]);
      final a = ContactCodec.fromMap(m).addresses.single;
      expect(a.postalCode, isNull);
      expect(roundTrip(m), jsonEncode(m['addresses']));
    });

    test('an edited structured address writes its derived value', () {
      final a = withDerivedValue(
        const ContactAddress(
          label: 'home',
          value: 'stale',
          country: 'US',
          street1: '1 Main St',
          city: 'Springfield',
          region: 'IL',
          postalCode: '62701',
        ),
      );
      expect(a.value, formatSingleLine(a));
      final out =
          ContactCodec.toMap(
                const Contact(
                  id: 'c',
                  contactType: ContactType.person,
                ).copyWith(addresses: [a]),
              )['addresses']
              as List;
      expect(out.single, {
        'label': 'home',
        'value': '1 Main St, Springfield, IL 62701, United States',
        'country': 'US',
        'street1': '1 Main St',
        'city': 'Springfield',
        'region': 'IL',
        'postalCode': '62701',
      });
    });

    test('withDerivedValue leaves a free-form address alone', () {
      const a = ContactAddress(label: 'home', value: 'as typed');
      expect(withDerivedValue(a).value, 'as typed');
    });
  });

  group('name order and phonetics', () {
    const legacyZh =
        '{"schemaVersion":1,"displayName":"伟 张","id":"c-zh",'
        '"contactType":"person","firstName":"伟","lastName":"张",'
        '"phones":[],"emails":[],"addresses":[],'
        '"relationship":{"category":"family"},"isSelf":false,'
        '"isActivated":true}';

    String roundTrip(String json) => jsonEncode(
      ContactCodec.toMap(
        ContactCodec.fromMap(jsonDecode(json) as Map<String, dynamic>),
      ),
    );

    test('an untouched legacy Chinese contact is byte-identical', () {
      expect(roundTrip(legacyZh), legacyZh);
    });

    test('an untouched padded Latin displayName is byte-identical', () {
      // ContactName trims padded parts, so a re-derived name would differ.
      const padded =
          '{"schemaVersion":1,"displayName":"Ada  Lovelace ","id":"c-pad",'
          '"contactType":"person","firstName":"Ada ","lastName":"Lovelace ",'
          '"phones":[],"emails":[],"addresses":[],'
          '"relationship":{"category":"other"},"isSelf":false,'
          '"isActivated":true}';
      expect(roundTrip(padded), padded);
      final decoded = ContactCodec.fromMap(
        jsonDecode(padded) as Map<String, dynamic>,
      );
      expect(decoded.displayName, isNot('Ada  Lovelace '));
      // Survives a no-op copy (e.g. the repository's copyWith(id: sameId)).
      expect(
        jsonEncode(ContactCodec.toMap(decoded.copyWith(id: 'c-pad'))),
        padded,
      );
    });

    test('a wrong-typed stored displayName is kept verbatim untouched', () {
      final decoded = ContactCodec.fromMap({
        'id': 'd',
        'contactType': 'person',
        'firstName': 'Ada',
        'displayName': 42,
      });
      expect(ContactCodec.toMap(decoded)['displayName'], 42);
      expect(
        ContactCodec.toMap(decoded.copyWith(firstName: 'Bea'))['displayName'],
        'Bea',
      );
    });

    test('an edited legacy contact gets the ordered displayName', () {
      final decoded = ContactCodec.fromMap(
        jsonDecode(legacyZh) as Map<String, dynamic>,
      );
      expect(decoded.displayName, '张伟');
      final edited = ContactCodec.toMap(decoded.copyWith(notes: 'n'));
      expect(edited['displayName'], '张伟');
      expect(edited.containsKey('nameOrder'), isFalse);
    });

    test('new keys are written only when non-default', () {
      const plain = Contact(
        id: 'p',
        contactType: ContactType.person,
        firstName: 'Wei',
        lastName: 'Zhang',
      );
      final m = ContactCodec.toMap(plain);
      expect(m.containsKey('nameOrder'), isFalse);
      expect(m.containsKey('phoneticFamily'), isFalse);
      expect(m.containsKey('phoneticGiven'), isFalse);

      final set = ContactCodec.toMap(
        plain.copyWith(
          nameOrder: ContactNameOrder.familyFirst,
          phoneticFamily: 'Zhāng',
          phoneticGiven: 'Wei',
        ),
      );
      expect(set['nameOrder'], 'familyFirst');
      expect(set['phoneticFamily'], 'Zhāng');
      expect(set['phoneticGiven'], 'Wei');
      expect(set['displayName'], 'Zhang Wei');
      final back = ContactCodec.fromMap(set);
      expect(back.nameOrder, ContactNameOrder.familyFirst);
      expect(back.phoneticFamily, 'Zhāng');
      expect(jsonEncode(ContactCodec.toMap(back)), jsonEncode(set));
    });

    test('an unknown nameOrder reads as auto and is preserved', () {
      for (final raw in <Object>['surnameLast', 'auto', 3]) {
        final decoded = ContactCodec.fromMap({
          'id': 'u',
          'contactType': 'person',
          'firstName': 'Wei',
          'lastName': 'Zhang',
          'nameOrder': raw,
        });
        expect(decoded.nameOrder, ContactNameOrder.auto, reason: '$raw');
        expect(decoded.rawKnownValues['nameOrder'], raw);
        expect(decoded.extraFields.containsKey('nameOrder'), isFalse);
        expect(ContactCodec.toMap(decoded)['nameOrder'], raw);
        // Still preserved after an unrelated edit...
        expect(
          ContactCodec.toMap(decoded.copyWith(notes: 'x'))['nameOrder'],
          raw,
        );
        // ...and replaced once the user picks an order.
        expect(
          ContactCodec.toMap(
            decoded.copyWith(nameOrder: ContactNameOrder.givenFirst),
          )['nameOrder'],
          'givenFirst',
        );
      }
    });

    test('a wrong-typed phonetic is kept verbatim until edited', () {
      final decoded = ContactCodec.fromMap({
        'id': 'w',
        'contactType': 'person',
        'firstName': '伟',
        'phoneticGiven': 7,
      });
      expect(decoded.phoneticGiven, isNull);
      expect(ContactCodec.toMap(decoded)['phoneticGiven'], 7);
      expect(
        ContactCodec.toMap(decoded.copyWith(phoneticGiven: 'Wei'))[
            'phoneticGiven'],
        'Wei',
      );
    });

    test('a stored nameOrder round-trips byte-identical', () {
      const stored =
          '{"schemaVersion":1,"displayName":"Zhang Wei","id":"k",'
          '"contactType":"person","firstName":"Wei","lastName":"Zhang",'
          '"nameOrder":"familyFirst","phoneticFamily":"Zhang",'
          '"phones":[],"emails":[],"addresses":[],'
          '"relationship":{"category":"other"},"isSelf":false,'
          '"isActivated":true}';
      expect(roundTrip(stored), stored);
    });
  });
}
