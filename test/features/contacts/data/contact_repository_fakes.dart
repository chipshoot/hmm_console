import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/contacts/data/i_contact_repository.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

/// In-memory note store holding real [HmmNote]s so subject and content
/// assertions are meaningful. Unfaked members throw loudly.
class FakeNoteRepository implements IHmmNoteRepository {
  final List<HmmNote> stored = [];
  int _nextId = 1;

  @override
  Future<PageList<HmmNote>> getNotes({
    int? catalogId,
    int? parentNoteId,
    int page = 1,
    int pageSize = 20,
    bool includeDeleted = false,
  }) async {
    final all = stored.where((n) => n.catalogId == catalogId).toList();
    final start = (page - 1) * pageSize;
    final items = start >= all.length
        ? <HmmNote>[]
        : all.sublist(start, (start + pageSize).clamp(0, all.length));
    return PageList<HmmNote>(
      items: items,
      meta: PaginationMeta(
        totalCount: all.length,
        pageSize: pageSize,
        currentPage: page,
        totalPages: (all.length / pageSize).ceil(),
      ),
    );
  }

  @override
  Future<HmmNote> createNote(HmmNoteCreate input) async {
    final note = HmmNote(
      id: _nextId++,
      uuid: input.uuid ?? 'generated-$_nextId',
      subject: input.subject,
      authorId: 1,
      createDate: DateTime(2026),
      catalogId: input.catalogId,
      content: input.content,
    );
    stored.add(note);
    return note;
  }

  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    final i = stored.indexWhere((n) => n.id == id);
    final old = stored[i];
    final updated = HmmNote(
      id: old.id,
      uuid: old.uuid,
      subject: patch.subject ?? old.subject,
      authorId: old.authorId,
      createDate: old.createDate,
      catalogId: old.catalogId,
      content: patch.content ?? old.content,
    );
    stored[i] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

class FakeCatalogRepository implements INoteCatalogRepository {
  @override
  Future<NoteCatalog> getOrCreateCatalog(String name, String schema) async =>
      NoteCatalog(
        id: 7,
        name: name,
        schema: schema,
        formatType: 0,
        isDefault: false,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

/// In-memory [IContactRepository] for state and widget tests. Honours
/// `isActivated` and the single-`isSelf` rule, and counts saves.
class InMemoryContactRepository implements IContactRepository {
  final Map<String, Contact> _byId = {};
  int saveCalls = 0;
  int _nextId = 1;

  /// When set, the matching call throws it (after any write it would make
  /// for [throwAfterSave], to model a partially applied multi-write).
  Object? throwOnGet;
  Object? throwOnSave;
  Object? throwAfterSave;
  Object? throwOnDeactivate;

  void seed(Contact c) => _byId[c.id] = c;

  @override
  Future<List<Contact>> getContacts({bool includeDeactivated = false}) async =>
      _byId.values.where((c) => includeDeactivated || c.isActivated).toList();

  @override
  Future<Contact?> getContact(String id) async {
    if (throwOnGet != null) throw throwOnGet!;
    return _byId[id];
  }

  @override
  Future<Contact> saveContact(Contact contact) async {
    if (throwOnSave != null) throw throwOnSave!;
    saveCalls++;
    final saved = contact.id.isEmpty
        ? contact.copyWith(id: 'gen-${_nextId++}')
        : contact;
    if (saved.isSelf) {
      for (final e in _byId.entries.toList()) {
        if (e.key != saved.id && e.value.isSelf) {
          _byId[e.key] = e.value.copyWith(isSelf: false);
        }
      }
    }
    _byId[saved.id] = saved;
    if (throwAfterSave != null) throw throwAfterSave!;
    return saved;
  }

  @override
  Future<void> deactivateContact(String id) async {
    if (throwOnDeactivate != null) throw throwOnDeactivate!;
    final c = _byId[id];
    if (c == null) throw ContactNotFound(id);
    _byId[id] = c.copyWith(isActivated: false);
  }
}
