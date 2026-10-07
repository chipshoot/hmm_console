// test/features/contacts/states/contact_edit_state_name_options_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contact_edit_state.dart';

import '../data/contact_repository_fakes.dart';

const _zh = Contact(
  id: '',
  contactType: ContactType.person,
  lastName: '张',
  firstName: '伟',
);

(ProviderContainer, InMemoryContactRepository) _setup(Contact initial) {
  final repo = InMemoryContactRepository();
  final c = ProviderContainer(
    overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  final sub = c.listen(contactEditStateProvider(initial), (_, _) {});
  addTearDown(sub.close);
  return (c, repo);
}

void main() {
  test('an invalid phonetic refuses save without sending', () async {
    final (c, repo) = _setup(_zh);
    final n = c.read(contactEditStateProvider(_zh).notifier);
    n.setPhoneticFamily('zh4ng');
    expect(n.phoneticInvalid, isTrue);
    expect(await n.save(), isFalse);
    expect(repo.saveCalls, 0);
    n.setPhoneticFamily('Zhāng');
    expect(n.phoneticInvalid, isFalse);
  });

  test(
    'an invalid phonetic does not block saving once switched to organization',
    () async {
      final (c, repo) = _setup(_zh);
      final n = c.read(contactEditStateProvider(_zh).notifier);
      n.setPhoneticFamily('zh4ng');
      n.setType(ContactType.organization);
      n.setOrganizationName('人民医院');
      expect(n.phoneticInvalid, isFalse);
      expect(await n.save(), isTrue);
      final saved = (await repo.getContacts()).single;
      expect(saved.phoneticFamily, isNull);
      expect(saved.phoneticGiven, isNull);
    },
  );

  test('phonetics are trimmed; blank phonetics are not stored', () async {
    final (c, repo) = _setup(_zh);
    final n = c.read(contactEditStateProvider(_zh).notifier);
    n.setPhoneticFamily('  Tsang ');
    n.setPhoneticGiven('   ');
    n.setNameOrder(ContactNameOrder.givenFirst);
    expect(await n.save(), isTrue);
    final saved = (await repo.getContacts()).single;
    expect(saved.phoneticFamily, 'Tsang');
    expect(saved.phoneticGiven, isNull);
    expect(saved.nameOrder, ContactNameOrder.givenFirst);
  });

  test('saving an organization drops the hidden name options', () async {
    final (c, repo) = _setup(_zh);
    final n = c.read(contactEditStateProvider(_zh).notifier);
    n.setPhoneticFamily('Zhang');
    n.setNameOrder(ContactNameOrder.familyFirst);
    n.setType(ContactType.organization);
    n.setOrganizationName('人民医院');
    expect(await n.save(), isTrue);
    final saved = (await repo.getContacts()).single;
    expect(saved.phoneticFamily, isNull);
    expect(saved.nameOrder, ContactNameOrder.auto);
  });

  test(
    'R4: an unedited contact with padded name parts saves field-for-field',
    () async {
      const padded = Contact(
        id: 'pad',
        contactType: ContactType.person,
        firstName: 'Ada ',
        lastName: ' Lovelace',
        phoneticFamily: ' Lovelace ',
        storedDisplayName: 'Ada  Lovelace',
      );
      final (c, repo) = _setup(padded);
      final n = c.read(contactEditStateProvider(padded).notifier);
      expect(await n.save(), isTrue);
      final saved = (await repo.getContacts()).single;
      expect(saved, padded);
      expect(saved.firstName, 'Ada ');
      expect(saved.lastName, ' Lovelace');
      expect(saved.phoneticFamily, ' Lovelace ');
      expect(saved.storedDisplayName, 'Ada  Lovelace');
    },
  );

  test(
    'R4: editing only lastName trims it and keeps firstName verbatim',
    () async {
      const padded = Contact(
        id: 'pad',
        contactType: ContactType.person,
        firstName: 'Ada ',
        lastName: ' Lovelace',
        storedDisplayName: 'Ada  Lovelace',
      );
      final (c, repo) = _setup(padded);
      final n = c.read(contactEditStateProvider(padded).notifier);
      n.setLastName(' Byron ');
      expect(await n.save(), isTrue);
      final saved = (await repo.getContacts()).single;
      expect(saved.lastName, 'Byron');
      expect(saved.firstName, 'Ada ');
      expect(saved.storedDisplayName, isNull);
    },
  );

  test(
    'R4: re-typing a part to its trimmed value keeps the stored bytes',
    () async {
      const padded = Contact(
        id: 'pad',
        contactType: ContactType.person,
        firstName: 'Ada ',
        lastName: 'Lovelace',
      );
      final (c, repo) = _setup(padded);
      final n = c.read(contactEditStateProvider(padded).notifier);
      n.setFirstName('Ada');
      expect(await n.save(), isTrue);
      expect((await repo.getContacts()).single.firstName, 'Ada ');
    },
  );
}
