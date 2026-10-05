import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../data/i_contact_repository.dart';
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

  // Each mutation invalidates in `finally`: a write that fails part-way (the
  // isSelf rule touches several notes) must not leave a stale list.

  Future<void> save(Contact contact) async {
    try {
      await ref.read(contactRepositoryModeProvider).saveContact(contact);
    } finally {
      ref.invalidateSelf();
    }
  }

  /// Throws `ContactNotFound` / `ContactUnreadable` rather than reporting a
  /// removal that wrote nothing.
  Future<void> deactivate(String id) async {
    try {
      await ref.read(contactRepositoryModeProvider).deactivateContact(id);
    } finally {
      ref.invalidateSelf();
    }
  }

  /// Undo of [deactivate]: a deactivated contact still resolves by id, so it
  /// is re-saved as active. Throws `ContactNotFound` if it no longer exists.
  Future<void> restore(String id) async {
    try {
      final repo = ref.read(contactRepositoryModeProvider);
      final contact = await repo.getContact(id);
      if (contact == null) throw ContactNotFound(id);
      await repo.saveContact(contact.copyWith(isActivated: true));
    } finally {
      ref.invalidateSelf();
    }
  }
}

final contactsStateProvider =
    AsyncNotifierProvider<ContactsState, List<Contact>>(ContactsState.new);
