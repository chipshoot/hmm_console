import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/contacts/data/i_contact_repository.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/states/contacts_state.dart';

import '../data/contact_repository_fakes.dart';

const _ada = Contact(
  id: 'c-1',
  contactType: ContactType.person,
  firstName: 'Ada',
);

ProviderContainer _container(InMemoryContactRepository repo) {
  final c = ProviderContainer(
    overrides: [contactRepositoryModeProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('build reads the address book from the repository', () async {
    final container = _container(InMemoryContactRepository()..seed(_ada));
    expect(await container.read(contactsStateProvider.future), hasLength(1));
  });

  test(
    'save writes through and re-reads rather than patching in memory',
    () async {
      final repo = InMemoryContactRepository();
      final container = _container(repo);

      await container.read(contactsStateProvider.future);
      await container.read(contactsStateProvider.notifier).save(_ada);

      expect(repo.saveCalls, 1);
      expect(await container.read(contactsStateProvider.future), hasLength(1));
    },
  );

  test('deactivate removes the contact from the list', () async {
    final container = _container(InMemoryContactRepository()..seed(_ada));

    await container.read(contactsStateProvider.future);
    await container.read(contactsStateProvider.notifier).deactivate('c-1');

    expect(await container.read(contactsStateProvider.future), isEmpty);
  });

  test('restore brings a deactivated contact back', () async {
    final repo = InMemoryContactRepository()..seed(_ada);
    final container = _container(repo);

    await container.read(contactsStateProvider.future);
    final notifier = container.read(contactsStateProvider.notifier);
    await notifier.deactivate('c-1');
    expect(await container.read(contactsStateProvider.future), isEmpty);

    await notifier.restore('c-1');
    final list = await container.read(contactsStateProvider.future);
    expect(list.single.id, 'c-1');
    expect(list.single.isActivated, isTrue);
  });

  test('restore of a missing contact throws ContactNotFound', () async {
    final container = _container(InMemoryContactRepository());
    await container.read(contactsStateProvider.future);
    await expectLater(
      container.read(contactsStateProvider.notifier).restore('gone'),
      throwsA(isA<ContactNotFound>()),
    );
  });

  test('deactivate of a missing contact throws ContactNotFound', () async {
    final container = _container(InMemoryContactRepository());
    await container.read(contactsStateProvider.future);
    await expectLater(
      container.read(contactsStateProvider.notifier).deactivate('gone'),
      throwsA(isA<ContactNotFound>()),
    );
  });

  test(
    'a save that fails after a partial write still re-reads the list',
    () async {
      final repo = InMemoryContactRepository();
      final container = _container(repo);
      expect(await container.read(contactsStateProvider.future), isEmpty);

      repo.throwAfterSave = StateError('second write failed');
      await expectLater(
        container.read(contactsStateProvider.notifier).save(_ada),
        throwsStateError,
      );

      expect(await container.read(contactsStateProvider.future), hasLength(1));
    },
  );

  test(
    'a restore that fails after a partial write still re-reads the list',
    () async {
      final repo = InMemoryContactRepository()
        ..seed(_ada.copyWith(isActivated: false));
      final container = _container(repo);
      expect(await container.read(contactsStateProvider.future), isEmpty);

      repo.throwAfterSave = StateError('second write failed');
      await expectLater(
        container.read(contactsStateProvider.notifier).restore('c-1'),
        throwsStateError,
      );

      expect(await container.read(contactsStateProvider.future), hasLength(1));
    },
  );
}
