import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/contact_block/contact_info.dart';
import 'package:hmm_console/core/contact_block/contact_info_codec.dart';

void main() {
  const agent = ContactInfo(
    role: ContactRoles.agent,
    name: 'Ada Lovelace',
    organization: 'Intact',
    phone: '555-0100',
    email: 'ada@example.com',
    address: '1 Analytical Way',
    notes: 'policy 123',
  );

  test('round-trips a fully populated block', () {
    expect(ContactInfoCodec.fromMap(ContactInfoCodec.toMap(agent)), agent);
  });

  test('round-trips a block holding only a phone', () {
    const minimal = ContactInfo(role: ContactRoles.emergency, phone: '911');
    expect(ContactInfoCodec.fromMap(ContactInfoCodec.toMap(minimal)), minimal);
  });

  test('stores the role as a literal, not as display copy', () {
    expect(ContactInfoCodec.toMap(agent)['role'], 'agent');
  });

  test('a role this version does not know survives untouched', () {
    final decoded = ContactInfoCodec.fromMap({'role': 'veterinarian'});
    expect(decoded.role, 'veterinarian');
    expect(ContactInfoCodec.toMap(decoded)['role'], 'veterinarian');
  });

  test('a missing role falls back rather than throwing', () {
    expect(ContactInfoCodec.fromMap({'name': 'x'}).role, ContactRoles.other);
  });

  group('losslessness', () {
    test('unknown fields survive an edit', () {
      final decoded = ContactInfoCodec.fromMap({
        'role': 'doctor',
        'name': 'Dr Grace',
        'fax': '555-0199',
        'future': {'a': 1},
      });

      final resaved =
          ContactInfoCodec.toMap(decoded.copyWith(name: 'Dr Hopper'));
      expect(resaved['fax'], '555-0199');
      expect(resaved['future'], {'a': 1});
      expect(resaved['name'], 'Dr Hopper');
    });

    test('a known key never leaks into extraFields', () {
      final decoded = ContactInfoCodec.fromMap({'role': 'doctor', 'phone': '1'});
      expect(decoded.extraFields, isEmpty);
    });
  });

  group('list handling', () {
    test('reads several blocks, so one note can hold main and emergency', () {
      final list = ContactInfoCodec.listFrom([
        {'role': 'hospital', 'name': 'General', 'phone': '555-1000'},
        {'role': 'emergency', 'phone': '911'},
      ]);

      expect(list, hasLength(2));
      expect(list.first.role, 'hospital');
      expect(list.last.phone, '911');
    });

    test('a non-list does not take the owning record down', () {
      expect(ContactInfoCodec.listFrom('nope'), isEmpty);
    });

    test('a malformed entry is skipped, not fatal', () {
      final list = ContactInfoCodec.listFrom([
        {'role': 'doctor', 'name': 'Grace'},
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
    const hospital = ContactInfo(role: 'hospital', organization: 'General');
    expect(hospital.displayName, 'General');
  });
}
