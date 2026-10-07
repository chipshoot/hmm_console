// lib/features/contacts/states/contact_list_entries.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/contact_sort_provider.dart';
import '../domain/contact_sort.dart';
import '../domain/contact_sort_by.dart';
import '../domain/entities/contact.dart';
import '../domain/pinyin_transcriber.dart';
import 'contacts_state.dart';
import 'pinyin_transcriber_provider.dart';

/// One contact with its sort key and search terms, computed once per list
/// load (and per sort-setting change), never per frame or keystroke.
class ContactListEntry {
  const ContactListEntry({
    required this.contact,
    required this.sortKey,
    required this.terms,
  });

  final Contact contact;
  final String sortKey;
  final ContactSearchTerms terms;
}

/// "Me" first, then [compareContactKeys]. A transcriber failure degrades the
/// affected contacts to raw-text keys and no pinyin terms; it is logged once,
/// by error type only (names never reach the log).
List<ContactListEntry> buildContactListEntries(
  List<Contact> contacts,
  ContactSortBy by,
  PinyinTranscriber? t,
) {
  Object? firstError;
  void onError(Object e) => firstError ??= e;
  final entries = [
    for (final c in contacts)
      ContactListEntry(
        contact: c,
        sortKey: sortKey(c, by, t, onError: onError),
        terms: searchTerms(c, t, onError: onError),
      ),
  ];
  final error = firstError;
  if (error != null) {
    debugPrint(
      'Contacts: pinyin unavailable (${error.runtimeType}); '
      'affected contacts sort by raw text.',
    );
  }
  entries.sort((a, b) {
    if (a.contact.isSelf != b.contact.isSelf) return a.contact.isSelf ? -1 : 1;
    return compareContactKeys(a.contact, a.sortKey, b.contact, b.sortKey);
  });
  return entries;
}

final contactListEntriesProvider =
    Provider<AsyncValue<List<ContactListEntry>>>((ref) {
  final by = ref.watch(contactSortByProvider);
  PinyinTranscriber? t;
  try {
    t = ref.watch(pinyinTranscriberProvider);
  } catch (e) {
    // Dictionary failed to load: the list still renders without pinyin.
    debugPrint('Contacts: pinyin unavailable (${e.runtimeType})');
  }
  return ref
      .watch(contactsStateProvider)
      .whenData((all) => buildContactListEntries(all, by, t));
});
