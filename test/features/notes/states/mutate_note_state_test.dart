import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

class _FakeNoteRepo implements IHmmNoteRepository {
  final List<HmmNote> created = [];
  HmmNote? lastUpdatedWith;
  int deletedId = -1;
  HmmNote stored = HmmNote(
      id: 7, uuid: 'u7', subject: 's', authorId: 1,
      createDate: DateTime(2026, 1, 1));

  @override
  Future<HmmNote> createNote(HmmNoteCreate input) async {
    final n = HmmNote(
      id: 7, uuid: 'u7', subject: input.subject, authorId: 1,
      catalogId: input.catalogId, content: input.content,
      createDate: DateTime(2026, 1, 1));
    created.add(n);
    return n;
  }

  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    stored = HmmNote(
      id: id, uuid: 'u$id', subject: patch.subject ?? stored.subject,
      authorId: 1, content: patch.content ?? stored.content,
      createDate: DateTime(2026, 1, 1), attachments: patch.attachments);
    lastUpdatedWith = stored;
    return stored;
  }

  @override
  Future<void> deleteNote(int id) async => deletedId = id;
  @override
  Future<HmmNote?> getNoteById(int id) async => stored;
  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => stored;
  @override
  Future<PageList<HmmNote>> getNotes(
          {int? catalogId, int? parentNoteId, int page = 1,
          int pageSize = 20, bool includeDeleted = false}) async =>
      PageList(items: const [],
          meta: const PaginationMeta(
              totalCount: 0, pageSize: 20, currentPage: 1, totalPages: 0));
  @override
  Stream<List<HmmNote>> watchNotes() => Stream.value(const []);
  @override
  Future<HmmNote> setParentNote(int id, int? parentNoteId) async =>
      throw UnimplementedError();
  @override
  Future<List<HmmNote>> getUnattachedNotes(int catalogId) async => const [];
}

class _FakeCatalogRepo implements INoteCatalogRepository {
  @override
  Future<NoteCatalog?> getCatalogByName(String name) async => null;
  @override
  Future<NoteCatalog> createCatalog(NoteCatalogsCompanion c) async =>
      NoteCatalog(id: 99, name: c.name.value, schema: c.schema.value,
          formatType: 3, isDefault: false);
  @override
  Future<List<NoteCatalog>> getCatalogs() async => [];
  @override
  Future<NoteCatalog?> getCatalogById(int id) async => null;
  @override
  Future<NoteCatalog> getOrCreateCatalog(String name, String schema) =>
      createCatalog(NoteCatalogsCompanion.insert(name: name, schema: schema));
  @override
  Future<NoteCatalog> updateCatalog(int id, NoteCatalogsCompanion c) =>
      createCatalog(c);
  @override
  Stream<List<NoteCatalog>> watchCatalogs() => Stream.value(const []);
}

class _FakePicker implements IImageAttachmentPicker {
  _FakePicker(this.result);
  final VaultRef? result;
  @override
  Future<VaultRef?> pickForNote(
          {required int noteId,
          AttachmentPickSource source = AttachmentPickSource.gallery}) async =>
      result;
}

VaultRef _ref(String path) =>
    VaultRef(path: path, contentType: 'image/jpeg', byteSize: 1);

ProviderContainer _container(_FakeNoteRepo repo, {VaultRef? picked}) =>
    ProviderContainer(overrides: [
      hmmNoteRepositoryProvider.overrideWithValue(repo),
      noteCatalogRepositoryProvider.overrideWithValue(_FakeCatalogRepo()),
      imageAttachmentPickerProvider
          .overrideWith((ref) async => _FakePicker(picked)),
    ]);

void main() {
  test('createGeneral uses the General catalog id and trims subject', () async {
    final repo = _FakeNoteRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    await c.read(mutateNoteProvider).createGeneral(
        subject: '  Hi  ', markdownBody: '# body');
    expect(repo.created.single.subject, 'Hi');
    expect(repo.created.single.catalogId, 99);
    expect(repo.created.single.content, '# body');
  });

  test('addImage appends a picked ref as primary image', () async {
    final repo = _FakeNoteRepo();
    final c = _container(repo, picked: _ref('a.jpg'));
    addTearDown(c.dispose);

    final out = await c.read(mutateNoteProvider).addImage(7);
    expect(out, isNotNull);
    expect(repo.lastUpdatedWith!.attachments!.primaryImage, _ref('a.jpg'));
  });

  test('addImage returns null and does not update when picker cancels',
      () async {
    final repo = _FakeNoteRepo();
    final c = _container(repo, picked: null);
    addTearDown(c.dispose);

    final out = await c.read(mutateNoteProvider).addImage(7);
    expect(out, isNull);
    expect(repo.lastUpdatedWith, isNull);
  });

  test('addImage appends to gallery when a primary image already exists',
      () async {
    final repo = _FakeNoteRepo();
    repo.stored = HmmNote(
      id: 7, uuid: 'u7', subject: 's', authorId: 1,
      createDate: DateTime(2026, 1, 1),
      attachments: NoteAttachments(
        primaryImage: _ref('primary.jpg'),
        images: [_ref('existing.jpg')],
      ),
    );
    final c = _container(repo, picked: _ref('new.jpg'));
    addTearDown(c.dispose);

    final out = await c.read(mutateNoteProvider).addImage(7);
    expect(out, isNotNull);
    final att = repo.lastUpdatedWith!.attachments!;
    expect(att.primaryImage, _ref('primary.jpg')); // unchanged
    expect(att.images, [_ref('existing.jpg'), _ref('new.jpg')]); // appended
  });

  test('delete calls through', () async {
    final repo = _FakeNoteRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    await c.read(mutateNoteProvider).delete(7);
    expect(repo.deletedId, 7);
  });
}
