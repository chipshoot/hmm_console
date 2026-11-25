import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_mode.dart';
import '../../../core/data/repository_providers.dart';
import '../data/i_contact_repository.dart';
import '../domain/entities/contact.dart';

/// The address book.
///
/// Mutations write through the repository and then invalidate, so the list is
/// always re-read from storage rather than patched in memory - the repository
/// owns the isSelf rule, and mirroring it here is how the two would drift.
class ContactsState extends AsyncNotifier<List<Contact>> {
  /// Watches the repository so a data-mode switch rebuilds the list (or
  /// surfaces the cloudApi "unavailable" error). Action methods `ref.read`.
  @override
  Future<List<Contact>> build() =>
      ref.watch(contactRepositoryModeProvider).getContacts();

  // Each mutation invalidates in `finally`: a write that fails part-way (the
  // isSelf rule touches several notes) must not leave a stale list.

  /// Returns the stored contact, carrying the id minted for a new one.
  Future<Contact> save(Contact contact) async {
    try {
      return await ref.read(contactRepositoryModeProvider).saveContact(contact);
    } finally {
      ref.invalidateSelf();
    }
  }

  /// Saves only the Remind me flag. Throws `ContactNotFound` if the contact
  /// no longer exists.
  Future<void> setRemindBirthday(String id, bool on) async {
    try {
      final repo = ref.read(contactRepositoryModeProvider);
      final contact = await repo.getContact(id);
      if (contact == null) throw ContactNotFound(id);
      await repo.saveContact(contact.copyWith(remindBirthday: on));
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

/// The device owner's own card ("Me"), or null: none yet, still loading,
/// failed to load, or cloudApi mode (no contacts there, so the address book
/// is never opened).
final selfContactProvider = Provider<Contact?>((ref) {
  if (ref.watch(dataModeProvider) == DataMode.cloudApi) return null;
  final contacts = ref.watch(contactsStateProvider).value;
  if (contacts == null) return null;
  for (final c in contacts) {
    if (c.isSelf) return c;
  }
  return null;
});
