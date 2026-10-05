import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/data/contact_codec.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contact_edit_state.dart';

import 'package:hmm_console/features/contacts/presentation/widgets/labeled_field_editor.dart';

import '../data/contact_repository_fakes.dart';

const _p = Contact(id: '', contactType: ContactType.person, firstName: 'Ann');

ProviderContainer _container(InMemoryContactRepository repo) {
  final c = ProviderContainer(
    overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('switching isSelf on sets the relationship category to self', () {
    final c = _container(InMemoryContactRepository());
    final n = c.read(contactEditStateProvider(_p).notifier);
    n.setIsSelf(true);
    final contact = c.read(contactEditStateProvider(_p)).contact;
    expect(contact.isSelf, isTrue);
    expect(contact.relationship.category, RelationshipCategory.self);
  });

  test('switching isSelf off leaves the relationship category alone', () {
    final c = _container(InMemoryContactRepository());
    final n = c.read(contactEditStateProvider(_p).notifier);
    n.setIsSelf(true);
    n.setIsSelf(false);
    final contact = c.read(contactEditStateProvider(_p)).contact;
    expect(contact.isSelf, isFalse);
    expect(contact.relationship.category, RelationshipCategory.self);
  });

  test(
    'an unknown stored contact type keeps both sets of names on save',
    () async {
      final repo = InMemoryContactRepository();
      final c = _container(repo);
      final future = ContactCodec.fromMap({
        'id': 'x',
        'contactType': 'robot',
        'firstName': 'R',
        'organizationName': 'Org',
      });
      final n = c.read(contactEditStateProvider(future).notifier);
      expect(await n.save(), isTrue);
      final saved = (await repo.getContacts()).single;
      expect(saved.firstName, 'R');
      expect(saved.organizationName, 'Org');
      expect(saved.storedContactTypeName, 'robot');
    },
  );

  group('a wrong-typed entry value survives the edit form', () {
    final stored = ContactCodec.fromMap({
      'id': 'w',
      'contactType': 'person',
      'firstName': 'W',
      'phones': [
        {'label': 'mobile', 'number': 5551234},
      ],
    });

    test('saving without touching phones keeps it', () async {
      final repo = InMemoryContactRepository();
      final c = _container(repo);
      final n = c.read(contactEditStateProvider(stored).notifier);
      n.setFirstName('Wanda');
      expect(await n.save(), isTrue);
      final saved = (await repo.getContacts()).single;
      expect(ContactCodec.toMap(saved)['phones'], [
        {'label': 'mobile', 'number': 5551234},
      ]);
    });

    test('a phones edit that leaves the row alone keeps it', () async {
      final repo = InMemoryContactRepository();
      final c = _container(repo);
      final n = c.read(contactEditStateProvider(stored).notifier);
      final p = stored.phones.single;
      // What LabeledFieldEditor emits when another row is added.
      n.setPhones([
        LabeledFieldEntry(
          label: p.label,
          value: p.number,
          extraFields: p.extraFields,
          rawKnownValues: p.rawKnownValues,
        ),
        const LabeledFieldEntry(label: 'home', value: '1'),
      ]);
      expect(await n.save(), isTrue);
      final saved = (await repo.getContacts()).single;
      expect(ContactCodec.toMap(saved)['phones'], [
        {'label': 'mobile', 'number': 5551234},
        {'label': 'home', 'number': '1'},
      ]);
    });
  });
}
