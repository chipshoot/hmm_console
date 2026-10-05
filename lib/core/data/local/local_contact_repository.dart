import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/contacts/data/contact_codec.dart';
import '../../../features/contacts/data/i_contact_repository.dart';
import '../../../features/contacts/domain/entities/contact.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../../util/uuid.dart';
import '../hmm_note_input.dart';
import 'local_hmm_note_repository.dart';
import 'local_note_catalog_repository.dart';

/// Three segments so `CatalogPalette.domainKeyFor` reads `ContactMan` as the
/// domain key. The spec said `Hmm.Contact`; a two-segment name has no domain
/// key and would group and colour wrongly alongside every other catalog.
const contactCatalogName = 'Hmm.ContactMan.Contact';

/// The subject is identity, never a label: names are mutable and non-unique,
/// so they live only inside the contact JSON.
String contactSubjectFor(String contactId) => 'Contact:$contactId';

/// Stores each contact as an `HmmNote`'s content under a fixed catalog,
/// mirroring `LocalCheatsheetRepository`. Contact notes have no parent.
class LocalContactRepository implements IContactRepository {
  LocalContactRepository(this._notes, this._catalogs);

  final IHmmNoteRepository _notes;
  final INoteCatalogRepository _catalogs;

  static const _pageSize = 100;

  String _serialize(Contact c) => jsonEncode({
        'note': {
          'content': {'Contact': ContactCodec.toMap(c)},
        },
      });

  /// Replaces only `note.content.Contact` inside [existing]'s content, keeping
  /// every sibling: other entities under `note.content`, other keys under
  /// `note`, and top-level keys. A fresh envelope is written only when the
  /// stored content is not a JSON object at all - there is nothing to keep.
  String _serializeOver(Contact c, HmmNote existing) {
    final Object? decoded;
    try {
      decoded = jsonDecode(existing.content ?? '');
    } on FormatException {
      debugPrint('LocalContactRepository: note ${existing.id}/${existing.uuid} '
          'content is not JSON; writing a fresh envelope.');
      return _serialize(c);
    }
    if (decoded is! Map) {
      debugPrint('LocalContactRepository: note ${existing.id}/${existing.uuid} '
          'content is not a JSON object; writing a fresh envelope.');
      return _serialize(c);
    }
    final root = Map<String, dynamic>.from(decoded);
    final noteRaw = root['note'];
    final note = noteRaw is Map
        ? Map<String, dynamic>.from(noteRaw)
        : <String, dynamic>{};
    final contentRaw = note['content'];
    final content = contentRaw is Map
        ? Map<String, dynamic>.from(contentRaw)
        : <String, dynamic>{};
    if (noteRaw is! Map || contentRaw is! Map) {
      // A non-object `note` / `note.content` cannot hold the contact; it is
      // the only value replaced. Logged so the replacement is diagnosable.
      debugPrint('LocalContactRepository: note ${existing.id}/${existing.uuid} '
          'had no note.content object; rebuilt it, kept top-level keys.');
    } else {
      debugPrint('LocalContactRepository: note ${existing.id}/${existing.uuid} '
          'updated in place; sibling keys kept.');
    }
    content['Contact'] = ContactCodec.toMap(c);
    note['content'] = content;
    root['note'] = note;
    return jsonEncode(root);
  }

  Contact? _deserialize(HmmNote? note) {
    final content = note?.content;
    if (content == null) return null;
    try {
      final data = (jsonDecode(content) as Map)['note']?['content']?['Contact'];
      if (data is! Map) {
        debugPrint('LocalContactRepository: note ${note!.id}/${note.uuid} has '
            'no Contact payload; omitted from the address book.');
        return null;
      }
      final contact = ContactCodec.fromMap(data.cast<String, dynamic>());
      if (contact.id.isEmpty) {
        // A blank id is not an identity: it would collide on the subject
        // `Contact:` with every other blank-id contact.
        debugPrint('LocalContactRepository: note ${note!.id}/${note.uuid} has '
            'a contact with no id; omitted from the address book.');
        return null;
      }
      return contact;
    } catch (e) {
      // The contact vanishes from the list with nothing on screen to explain
      // it, so name the note - otherwise this is undiagnosable without
      // reproducing it locally.
      debugPrint('LocalContactRepository: note ${note!.id}/${note.uuid} has '
          'unreadable contact JSON ($e); omitted from the address book.');
      return null;
    }
  }

  Future<int> _catalogId() async =>
      (await _catalogs.getOrCreateCatalog(contactCatalogName, '{}')).id;

  /// Pages until exhausted. A fixed ceiling would silently hide contacts.
  Future<List<HmmNote>> _allNotes() async {
    final catalogId = await _catalogId();
    final out = <HmmNote>[];
    var page = 1;
    while (true) {
      final res = await _notes.getNotes(
        catalogId: catalogId,
        page: page,
        pageSize: _pageSize,
      );
      out.addAll(res.items);
      if (res.items.isEmpty || page >= res.meta.totalPages) break;
      page++;
    }
    return out;
  }

  Future<List<Contact>> _all() async =>
      (await _allNotes()).map(_deserialize).whereType<Contact>().toList();

  @override
  Future<List<Contact>> getContacts({bool includeDeactivated = false}) async {
    final all = await _all();
    final visible =
        includeDeactivated ? all : all.where((c) => c.isActivated).toList();
    visible.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return visible;
  }

  @override
  Future<Contact?> getContact(String id) async {
    // A blank id is never an identity, so it is always absent.
    if (id.isEmpty) return null;
    final subject = contactSubjectFor(id);
    for (final n in await _allNotes()) {
      if (n.subject == subject) {
        // Stored but undecodable is not "absent": callers must not treat the
        // data as gone (deactivate would otherwise report success).
        return _deserialize(n) ?? (throw ContactUnreadable(id));
      }
    }
    return null;
  }

  @override
  Future<Contact> saveContact(Contact contact) async {
    // Blank id == create; the only place an id is minted.
    final id = contact.id.isEmpty ? generateUuid() : contact.id;
    final toSave = contact.copyWith(id: id);

    if (toSave.isSelf) {
      // At most one self. Clearing the others here, at the only layer that can
      // see the whole collection, keeps the rule true no matter which screen
      // set the flag.
      for (final other in await _all()) {
        if (other.id != id && other.isSelf) {
          await _write(other.copyWith(isSelf: false));
        }
      }
    }

    await _write(toSave);
    return toSave;
  }

  Future<void> _write(Contact c) async {
    if (c.id.isEmpty) {
      throw ArgumentError.value(c.id, 'id', 'a stored contact needs an id');
    }
    final subject = contactSubjectFor(c.id);
    // Matched by subject, not decoded id, so a note whose JSON became
    // unreadable is updated in place rather than duplicated.
    HmmNote? existing;
    for (final n in await _allNotes()) {
      if (n.subject == subject) {
        existing = n;
        break;
      }
    }

    if (existing == null) {
      await _notes.createNote(HmmNoteCreate(
        subject: subject,
        catalogId: await _catalogId(),
        content: _serialize(c),
        // The note's uuid IS the contact id - see the identity constraint.
        uuid: c.id,
      ));
    } else {
      // Catalog and author are immutable after create; passing them to an
      // update throws. Only subject and content move.
      await _notes.updateNote(
        existing.id,
        HmmNoteUpdate(
          subject: subject,
          content: _serializeOver(c, existing),
        ),
      );
    }
  }

  @override
  Future<void> deactivateContact(String id) async {
    // Throws ContactUnreadable for an undecodable note; absent (including a
    // blank id) is ContactNotFound - never a silent success.
    final existing = await getContact(id);
    if (existing == null) throw ContactNotFound(id);
    await _write(existing.copyWith(isActivated: false));
  }
}

final localContactRepositoryProvider = Provider<IContactRepository>((ref) {
  return LocalContactRepository(
    ref.watch(localHmmNoteRepositoryProvider),
    ref.watch(localNoteCatalogRepositoryProvider),
  );
});
