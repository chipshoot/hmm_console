import 'package:flutter_riverpod/misc.dart' show ProviderException;

import '../domain/entities/contact.dart';

/// Thrown by `contactRepositoryModeProvider` in `cloudApi` mode, where no
/// contacts repository exists yet (it ships with the backend plan).
///
/// A distinct type (still an [UnimplementedError], so nothing that caught the
/// plain error changes) so the UI layer can recognise it with
/// `error is ContactsCloudApiUnavailable` and show a friendly message instead
/// of a raw stack trace.
class ContactsCloudApiUnavailable extends UnimplementedError {
  ContactsCloudApiUnavailable()
    : super('contacts cloudApi repo ships in the backend plan');
}

/// True when [error] is, or is Riverpod's wrapper around, a
/// [ContactsCloudApiUnavailable]. Reading `contactRepositoryModeProvider`
/// surfaces the throw as a `ProviderException` (Riverpod 3), so a bare
/// `is ContactsCloudApiUnavailable` check would miss it; use this instead.
bool isContactsCloudApiUnavailable(Object error) {
  var e = error;
  while (e is ProviderException) {
    e = e.exception;
  }
  return e is ContactsCloudApiUnavailable;
}

/// No contact is stored under [id]. Thrown by a write that needs an existing
/// contact (deactivate, restore) so it cannot report success after writing
/// nothing.
class ContactNotFound implements Exception {
  const ContactNotFound(this.id);

  final String id;

  @override
  String toString() => 'ContactNotFound($id)';
}

/// A note is stored under [id]'s subject but its contact JSON cannot be
/// decoded. Distinct from absent: the data exists and must not be treated as
/// gone (or overwritten as if it were).
class ContactUnreadable implements Exception {
  const ContactUnreadable(this.id);

  final String id;

  @override
  String toString() => 'ContactUnreadable($id)';
}

/// CRUD over contacts, keyed by the contact's own stable [Contact.id] rather
/// than any storage-local identity.
abstract interface class IContactRepository {
  /// Active contacts only unless [includeDeactivated]; a deactivated contact
  /// still resolves by id so references to it degrade rather than dangle.
  Future<List<Contact>> getContacts({bool includeDeactivated = false});

  /// Null when nothing is stored under [id] (a blank [id] is always absent).
  /// Throws [ContactUnreadable] when a note is stored under [id] but cannot
  /// be decoded.
  Future<Contact?> getContact(String id);

  /// Upsert by [Contact.id]. A blank id means "create" and is minted here;
  /// that is the only path that mints. An id is never blank once stored.
  ///
  /// Setting `isSelf` clears it from every other contact: at most one may be
  /// self, and enforcing it at the collection owner is the only place that can
  /// see the whole collection.
  Future<Contact> saveContact(Contact contact);

  /// Soft delete. Throws [ContactNotFound] when nothing is stored under [id]
  /// (including a blank [id]) and [ContactUnreadable] when it cannot be
  /// decoded; it never returns without writing.
  Future<void> deactivateContact(String id);
}
