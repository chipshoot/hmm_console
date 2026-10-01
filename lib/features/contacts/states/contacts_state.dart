import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../domain/entities/contact.dart';

/// The address book.
///
/// Mutations write through the repository and then invalidate, so the list is
/// always re-read from storage rather than patched in memory - the repository
/// owns the isSelf rule, and mirroring it here is how the two would drift.
class ContactsState extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() =>
      ref.read(contactRepositoryModeProvider).getContacts();

  Future<void> save(Contact contact) async {
    await ref.read(contactRepositoryModeProvider).saveContact(contact);
    ref.invalidateSelf();
  }

  Future<void> deactivate(String id) async {
    await ref.read(contactRepositoryModeProvider).deactivateContact(id);
    ref.invalidateSelf();
  }

  /// Undo of [deactivate]: a deactivated contact still resolves by id, so it
  /// is re-saved as active.
  Future<void> restore(String id) async {
    final repo = ref.read(contactRepositoryModeProvider);
    final contact = await repo.getContact(id);
    if (contact == null) return;
    await repo.saveContact(contact.copyWith(isActivated: true));
    ref.invalidateSelf();
  }
}

final contactsStateProvider =
    AsyncNotifierProvider<ContactsState, List<Contact>>(ContactsState.new);
