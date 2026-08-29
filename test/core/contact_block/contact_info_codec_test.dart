import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/contact_block/contact_info.dart';
import 'package:hmm_console/core/contact_block/contact_info_codec.dart';

void main() {
  const agent = ContactInfo(
    name: 'Ada Lovelace',
    organization: 'Intact',
    phone: '555-0100',
    mobile: '555-0111',
    fax: '555-0122',
    email: 'ada@example.com',
    address: ContactAddress(
      street: '1 Analytical Way',
      city: 'Ottawa',
      region: 'ON',
      postalCode: 'K1A 0B1',
      country: 'Canada',
    ),
    notes: 'policy 123',
  );

  test('round-trips a fully populated block', () {
    expect(ContactInfoCodec.fromMap(ContactInfoCodec.toMap(agent)), agent);
  });

  test('round-trips a block holding only a phone', () {
    const minimal = ContactInfo(phone: '911');
    expect(ContactInfoCodec.fromMap(ContactInfoCodec.toMap(minimal)), minimal);
  });

  group('losslessness', () {
    test('unknown fields survive an edit', () {
      final decoded = ContactInfoCodec.fromMap({
                'name': 'Dr Grace',
        'pager': '555-0199',
        'future': {'a': 1},
      });

      final resaved =
          ContactInfoCodec.toMap(decoded.copyWith(name: 'Dr Hopper'));
      expect(resaved['pager'], '555-0199');
      expect(resaved['future'], {'a': 1});
      expect(resaved['name'], 'Dr Hopper');
    });

    test('a known key never leaks into extraFields', () {
      final decoded = ContactInfoCodec.fromMap({'phone': '1'});
      expect(decoded.extraFields, isEmpty);
    });
  });

  group('list handling', () {
    test('reads several blocks, so one note can hold main and emergency', () {
      final list = ContactInfoCodec.listFrom([
        {'name': 'General', 'phone': '555-1000'},
        {'phone': '911'},
      ]);

      expect(list, hasLength(2));
      expect(list.first.name, 'General');
      expect(list.last.phone, '911');
    });

    test('a non-list does not take the owning record down', () {
      expect(ContactInfoCodec.listFrom('nope'), isEmpty);
    });

    test('a malformed entry is skipped, not fatal', () {
      final list = ContactInfoCodec.listFrom([
        {'name': 'Grace'},
        'garbage',
      ]);
      expect(list, hasLength(1));
    });

    test('an untouched empty block is not persisted', () {
      expect(ContactInfoCodec.listTo([const ContactInfo()]), isEmpty);
    });

    test('a block with only a phone IS persisted', () {
      expect(
          ContactInfoCodec.listTo([const ContactInfo(phone: '911')]), hasLength(1));
    });
  });

  test('displayName falls back to the organization when unnamed', () {
    const hospital = ContactInfo(organization: 'General');
    expect(hospital.displayName, 'General');
  });

  test('a block carrying ONLY unknown fields is not dropped on save', () {
    // isEmpty is a save-time filter, so ignoring extraFields would destroy
    // exactly the data extraFields exists to preserve.
    final onlyExtras = ContactInfoCodec.fromMap({'futureThing': 'keep me'});

    expect(onlyExtras.isEmpty, isFalse);
    expect(ContactInfoCodec.listTo([onlyExtras]), hasLength(1));
    expect(ContactInfoCodec.listTo([onlyExtras]).single['futureThing'], 'keep me');
  });

  test('extraFields cannot be edited through the getter', () {
    final c = ContactInfoCodec.fromMap({'pager': '1'});
    expect(() => c.extraFields['pager'] = '2', throwsUnsupportedError);
  });

  test('the wire key is literally "contacts"', () {
    // Pinned because the backend note shape and cheatsheet leaf-path binding
    // (AutoInsurancePolicy.contacts.0.phone) both depend on this exact string;
    // every other test round-trips through the constant and would not notice.
    expect(ContactInfoCodec.contactsKey, 'contacts');
  });

  group('address', () {
    test('a legacy plain-string address is read as the street', () {
      // Every contact saved before the address became structured holds a
      // String here. Dropping it would silently erase real user data.
      final decoded = ContactInfoCodec.fromMap({
                'address': '1 Analytical Way',
      });

      expect(decoded.address!.street, '1 Analytical Way');
      expect(decoded.address!.city, isNull);
    });

    test('a structured address round-trips field by field', () {
      const a = ContactAddress(
        street: '1 Main St',
        city: 'Ottawa',
        region: 'ON',
        postalCode: 'K1A 0B1',
        country: 'Canada',
      );
      final decoded =
          ContactInfoCodec.fromMap(ContactInfoCodec.toMap(const ContactInfo(address: a)));

      expect(decoded.address, a);
    });

    test('unknown keys INSIDE the address survive an edit', () {
      // The block's own losslessness contract has to hold one level down too,
      // or nesting the address opens a hole exactly where it did not exist.
      final decoded = ContactInfoCodec.fromMap({
                'address': {'city': 'Ottawa', 'unit': '4B'},
      });

      final resaved = ContactInfoCodec.toMap(decoded);
      expect((resaved['address'] as Map)['unit'], '4B');
      expect((resaved['address'] as Map)['city'], 'Ottawa');
    });

    test('an empty address is not written at all', () {
      const c = ContactInfo(phone: '911', address: ContactAddress());
      expect(ContactInfoCodec.toMap(c).containsKey('address'), isFalse);
    });

    test('a garbage address does not take the block down', () {
      final decoded =
          ContactInfoCodec.fromMap({'name': 'Ada', 'address': 42});
      expect(decoded.address, isNull);
      expect(decoded.name, 'Ada');
    });

    test('singleLine composes what a maps app can search for', () {
      const a = ContactAddress(
        street: '1 Main St',
        city: 'Ottawa',
        region: 'ON',
        postalCode: 'K1A 0B1',
        country: 'Canada',
      );
      expect(a.singleLine, '1 Main St, Ottawa, ON K1A 0B1, Canada');
    });

    test('singleLine skips the parts that are absent', () {
      const a = ContactAddress(city: 'Ottawa', country: 'Canada');
      expect(a.singleLine, 'Ottawa, Canada');
    });
  });

  group('cell and fax', () {
    test('both round-trip as typed', () {
      const c = ContactInfo(phone: '555-0100', mobile: '555-0111', fax: '555-0122');
      final decoded = ContactInfoCodec.fromMap(ContactInfoCodec.toMap(c));

      expect(decoded.mobile, '555-0111');
      expect(decoded.fax, '555-0122');
    });

    test('a fax already stored as an unknown key becomes the typed field', () {
      // Real notes may carry `fax` from before this version modelled it.
      final decoded = ContactInfoCodec.fromMap({'fax': '555-0122'});

      expect(decoded.fax, '555-0122');
      expect(decoded.extraFields, isEmpty);
    });

    test('a block holding ONLY a fax is persisted, not dropped as empty', () {
      const onlyFax = ContactInfo(fax: '555-0122');

      expect(onlyFax.isEmpty, isFalse);
      expect(ContactInfoCodec.listTo([onlyFax]), hasLength(1));
    });

    test('a block holding ONLY an address is persisted, not dropped as empty', () {
      const onlyAddress = ContactInfo(address: ContactAddress(city: 'Ottawa'));

      expect(onlyAddress.isEmpty, isFalse);
      expect(ContactInfoCodec.listTo([onlyAddress]), hasLength(1));
    });
  });

  test('a role written by an earlier version is preserved, not destroyed', () {
    // `role` used to be a modelled field. It is gone, so it falls through to
    // extraFields and is written back verbatim: invisible in the UI, still in
    // the data, and a cheatsheet row bound to contacts.0.role still resolves.
    final decoded =
        ContactInfoCodec.fromMap({'role': 'agent', 'name': 'Ada'});

    expect(decoded.extraFields['role'], 'agent');
    expect(ContactInfoCodec.toMap(decoded)['role'], 'agent');
  });
}
