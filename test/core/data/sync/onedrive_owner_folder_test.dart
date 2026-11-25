import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/auth/current_author_account_name_provider.dart';
import 'package:hmm_console/core/auth/owner_id.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_author_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:hmm_console/core/data/sync/onedrive_owner_folder.dart';
import 'package:hmm_console/core/data/sync/onedrive_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

const _users = '/me/drive/special/approot:/users';

Map<String, dynamic> _folder(String name, {String? modified}) => {
  'name': name,
  'folder': {'childCount': 1},
  'lastModifiedDateTime': ?modified,
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late HmmDatabase db;
  late ProviderContainer container;
  late OwnerIdStore store;

  Future<void> setUpWith({
    required String ownerId,
    Map<String, Object> prefs = const {},
    OwnerIdStore Function(SharedPreferences)? makeStore,
    bool renameThrows = false,
  }) async {
    SharedPreferences.setMockInitialValues({'hmm.ownerId': ownerId, ...prefs});
    final sp = await SharedPreferences.getInstance();
    store = makeStore?.call(sp) ?? OwnerIdStore(sp);
    container = ProviderContainer(
      overrides: [
        hmmDatabaseProvider.overrideWithValue(db),
        if (renameThrows)
          localAuthorRepositoryProvider.overrideWith(
            (ref) => _RenameThrowsAuthors(LocalAuthorRepository(db)),
          ),
        ownerIdStoreProvider.overrideWith((ref) async => store),
        ownerIdProvider.overrideWith(
          (ref) async =>
              (await ref.watch(ownerIdStoreProvider.future)).ownerId!,
        ),
        oneDriveGraphClientProvider.overrideWith(
          (ref) => OneDriveGraphClient(
            FakeOneDriveAuth(),
            () => ref.read(oneDriveOwnerFolderProvider).resolve(),
            dio: dio,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<int> insertAuthor(String accountName) => db
      .into(db.authors)
      .insert(AuthorsCompanion.insert(accountName: accountName));

  Future<int> addNotes(int authorId, int n, {bool deleted = false}) async {
    final catalogId = await db
        .into(db.noteCatalogs)
        .insert(NoteCatalogsCompanion.insert(name: 'Cat', schema: '{}'));
    for (var i = 0; i < n; i++) {
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              subject: 'n$i',
              catalogId: Value(catalogId),
              authorId: authorId,
              deletedAt: deleted
                  ? Value(DateTime.utc(2026))
                  : const Value.absent(),
            ),
          );
    }
    return catalogId;
  }

  Future<int> visibleNotes(int catalogId) async =>
      (await LocalHmmNoteRepository(
        db,
        () => container.read(currentAuthorProvider.future),
      ).getNotes(catalogId: catalogId)).items.length;

  void ownFolder(String id, {required bool exists}) {
    adapter.onGet(
      '$_users/$id',
      (server) => exists
          ? server.reply(200, _folder(id))
          : server.reply(404, {
              'error': {'code': 'itemNotFound'},
            }),
    );
  }

  void listing(List<Map<String, dynamic>> items) {
    adapter.onGet(
      '$_users:/children',
      (server) => server.reply(200, {'value': items}),
    );
  }

  setUp(() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
    db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('own folder exists → used, nothing renamed', () async {
    await setUpWith(ownerId: 'NEW');
    await insertAuthor('NEW');
    ownFolder('NEW', exists: true);

    final folder = container.read(oneDriveOwnerFolderProvider);
    expect(await folder.resolve(), 'NEW');
    expect(store.ownerId, 'NEW');
    final rows = await db.select(db.authors).get();
    expect(rows.single.accountName, 'NEW');
  });

  test('no own folder, one other folder, device has no notes → adopted '
      'silently, link cleared', () async {
    await setUpWith(
      ownerId: 'NEW',
      prefs: {'hmm.linkedHmmSub': 'SUB', 'hmm.linkedHmmEmail': 'a@b.c'},
    );
    final authorId = await insertAuthor('NEW');
    ownFolder('NEW', exists: false);
    listing([_folder('IPHONE')]);

    final folder = container.read(oneDriveOwnerFolderProvider);
    expect(await folder.resolve(), 'IPHONE');
    expect(store.ownerId, 'IPHONE');
    expect(store.linkedHmmSub, isNull);
    expect(store.linkedHmmEmail, isNull);

    final row = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    expect(row.accountName, 'IPHONE');
    expect(await db.select(db.authors).get(), hasLength(1));
    expect(await container.read(ownerIdProvider.future), 'IPHONE');
    expect(container.read(oneDriveFolderChoiceProvider), isNull);
  });

  test('only deleted notes on the device still counts as no notes → '
      'adopted', () async {
    await setUpWith(ownerId: 'NEW');
    final authorId = await insertAuthor('NEW');
    await addNotes(authorId, 2, deleted: true);
    ownFolder('NEW', exists: false);
    listing([_folder('IPHONE')]);

    final folder = container.read(oneDriveOwnerFolderProvider);
    expect(await folder.resolve(), 'IPHONE');
    expect(store.ownerId, 'IPHONE');
  });

  test('one other folder but the device has notes → choice required with '
      'that folder; choose() adopts and the notes stay visible', () async {
    await setUpWith(
      ownerId: 'NEW',
      prefs: {'hmm.linkedHmmSub': 'SUB', 'hmm.linkedHmmEmail': 'a@b.c'},
    );
    final authorId = await insertAuthor('NEW');
    final catalogId = await addNotes(authorId, 3);
    ownFolder('NEW', exists: false);
    listing([_folder('IPHONE')]);

    final folder = container.read(oneDriveOwnerFolderProvider);
    await expectLater(
      folder.resolve(),
      throwsA(
        isA<OneDriveFolderChoiceRequired>().having(
          (e) => e.folders.map((f) => f.name),
          'folders',
          ['IPHONE'],
        ),
      ),
    );
    expect(store.ownerId, 'NEW');
    expect(store.linkedHmmSub, 'SUB', reason: 'nothing adopted yet');
    expect(container.read(oneDriveFolderChoiceProvider)!.map((f) => f.name), [
      'IPHONE',
    ]);

    await folder.choose('IPHONE');

    expect(store.ownerId, 'IPHONE');
    expect(store.linkedHmmSub, isNull);
    expect(store.linkedHmmEmail, isNull);
    final row = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    expect(row.accountName, 'IPHONE');
    expect((await container.read(currentAuthorProvider.future)).id, authorId);
    expect(await visibleNotes(catalogId), 3);
  });

  test(
    'rename throws → owner id and author row unchanged, notes visible',
    () async {
      await setUpWith(ownerId: 'NEW', renameThrows: true);
      final authorId = await insertAuthor('NEW');
      final catalogId = await addNotes(authorId, 2);
      final folder = container.read(oneDriveOwnerFolderProvider);

      await expectLater(folder.choose('IPHONE'), throwsA(isA<StateError>()));

      expect(store.ownerId, 'NEW');
      expect((await db.select(db.authors).get()).single.accountName, 'NEW');
      expect((await container.read(currentAuthorProvider.future)).id, authorId);
      expect(await visibleNotes(catalogId), 2);
    },
  );

  test('storing the owner id throws → the rename is rolled back, notes '
      'visible', () async {
    await setUpWith(ownerId: 'NEW', makeStore: _AdoptThrowsStore.new);
    final authorId = await insertAuthor('NEW');
    final catalogId = await addNotes(authorId, 2);
    final folder = container.read(oneDriveOwnerFolderProvider);

    await expectLater(folder.choose('IPHONE'), throwsA(isA<StateError>()));

    expect(store.ownerId, 'NEW');
    expect((await db.select(db.authors).get()).single.accountName, 'NEW');
    container.invalidate(ownerIdProvider);
    expect((await container.read(currentAuthorProvider.future)).id, authorId);
    expect(await visibleNotes(catalogId), 2);
  });

  test('folder name differing only by case → row renamed to the exact '
      'casing, notes visible', () async {
    await setUpWith(ownerId: 'iphone');
    final authorId = await insertAuthor('iphone');
    final catalogId = await addNotes(authorId, 2);
    final folder = container.read(oneDriveOwnerFolderProvider);

    await folder.choose('IPHONE');

    expect(store.ownerId, 'IPHONE');
    final rows = await db.select(db.authors).get();
    expect(rows.single.accountName, 'IPHONE');
    expect((await container.read(currentAuthorProvider.future)).id, authorId);
    expect(await visibleNotes(catalogId), 2);
  });

  test('no folders → own id, nothing renamed', () async {
    await setUpWith(ownerId: 'NEW');
    await insertAuthor('NEW');
    ownFolder('NEW', exists: false);
    listing([]);

    final folder = container.read(oneDriveOwnerFolderProvider);
    expect(await folder.resolve(), 'NEW');
    expect(store.ownerId, 'NEW');
    expect((await db.select(db.authors).get()).single.accountName, 'NEW');
  });

  test('several folders → OneDriveFolderChoiceRequired', () async {
    await setUpWith(ownerId: 'NEW');
    await insertAuthor('NEW');
    ownFolder('NEW', exists: false);
    listing([
      _folder('IPHONE', modified: '2026-11-01T10:00:00Z'),
      _folder('IPAD', modified: '2026-11-02T10:00:00Z'),
    ]);

    final folder = container.read(oneDriveOwnerFolderProvider);
    await expectLater(
      folder.resolve(),
      throwsA(
        isA<OneDriveFolderChoiceRequired>().having(
          (e) => e.folders.map((f) => f.name),
          'folders',
          ['IPHONE', 'IPAD'],
        ),
      ),
    );
    final choice = container.read(oneDriveFolderChoiceProvider);
    expect(choice!.map((f) => f.name), ['IPHONE', 'IPAD']);
    expect(choice.first.modified, DateTime.utc(2026, 11, 1, 10));
    expect(store.ownerId, 'NEW');
  });

  test('after reset(), a single foreign folder on a newly signed-in '
      'account is adopted', () async {
    await setUpWith(ownerId: 'NEW');
    final authorId = await insertAuthor('NEW');
    // First (wrong) Microsoft account: no folders → the owner id.
    ownFolder('NEW', exists: false);
    listing([]);
    final folder = container.read(oneDriveOwnerFolderProvider);
    expect(await folder.resolve(), 'NEW');

    // Signed out and in to the right account, which holds the iPhone's
    // folder (a fresh mock adapter stands in for the other account).
    adapter = DioAdapter(dio: dio);
    ownFolder('NEW', exists: false);
    listing([_folder('IPHONE')]);
    container.read(oneDriveFolderChoiceProvider.notifier).set([]);
    folder.reset();

    expect(await folder.resolve(), 'IPHONE');
    expect(store.ownerId, 'IPHONE');
    final row = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    expect(row.accountName, 'IPHONE');
    expect(container.read(oneDriveFolderChoiceProvider), isNull);
  });

  test('OneDrive sign-out through oneDriveAuthProvider resets the folder, '
      'so the next account\'s single folder is adopted', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await setUpWith(ownerId: 'NEW');
    await insertAuthor('NEW');
    ownFolder('NEW', exists: false);
    listing([]);
    final folder = container.read(oneDriveOwnerFolderProvider);
    expect(await folder.resolve(), 'NEW');

    await container.read(oneDriveAuthProvider).signOut();
    adapter = DioAdapter(dio: dio);
    ownFolder('NEW', exists: false);
    listing([_folder('IPHONE')]);

    expect(await folder.resolve(), 'IPHONE');
  });

  test('reset() clears a pending folder choice', () async {
    await setUpWith(ownerId: 'NEW');
    await insertAuthor('NEW');
    ownFolder('NEW', exists: false);
    listing([_folder('IPHONE'), _folder('IPAD')]);
    final folder = container.read(oneDriveOwnerFolderProvider);
    await expectLater(
      folder.resolve(),
      throwsA(isA<OneDriveFolderChoiceRequired>()),
    );
    expect(container.read(oneDriveFolderChoiceProvider), isNotNull);

    folder.reset();

    expect(container.read(oneDriveFolderChoiceProvider), isNull);
  });

  test('choose(name) adopts and clears the choice', () async {
    await setUpWith(ownerId: 'NEW');
    final authorId = await insertAuthor('NEW');
    ownFolder('NEW', exists: false);
    listing([_folder('IPHONE'), _folder('IPAD')]);

    final folder = container.read(oneDriveOwnerFolderProvider);
    await expectLater(
      folder.resolve(),
      throwsA(isA<OneDriveFolderChoiceRequired>()),
    );
    expect(container.read(oneDriveFolderChoiceProvider), isNotNull);

    await folder.choose('IPAD');

    expect(container.read(oneDriveFolderChoiceProvider), isNull);
    expect(store.ownerId, 'IPAD');
    final row = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    expect(row.accountName, 'IPAD');
    // Memoised: no further Graph calls needed to resolve.
    expect(await folder.resolve(), 'IPAD');
    expect(await container.read(ownerIdProvider.future), 'IPAD');
  });

  test('choose a folder whose author row already exists → adopted, '
      'no rename, choice cleared', () async {
    await setUpWith(ownerId: 'NEW');
    final newId = await insertAuthor('NEW');
    final ipadId = await insertAuthor('IPAD');
    ownFolder('NEW', exists: false);
    listing([_folder('IPHONE'), _folder('IPAD')]);

    final folder = container.read(oneDriveOwnerFolderProvider);
    await expectLater(
      folder.resolve(),
      throwsA(isA<OneDriveFolderChoiceRequired>()),
    );

    await folder.choose('IPAD');

    expect(container.read(oneDriveFolderChoiceProvider), isNull);
    expect(store.ownerId, 'IPAD');
    final rows = {
      for (final a in await db.select(db.authors).get()) a.id: a.accountName,
    };
    expect(rows, {newId: 'NEW', ipadId: 'IPAD'});
    expect((await container.read(currentAuthorProvider.future)).id, ipadId);
  });

  test('clash: the device has notes, so the single folder needs a choice; '
      'once chosen it is adopted without rename and the orphan step moves '
      'the old owner\'s notes onto the adopted row', () async {
    await setUpWith(ownerId: 'OLD');
    final oldId = await insertAuthor('OLD');
    final iphoneId = await insertAuthor('IPHONE');
    final catalogId = await db
        .into(db.noteCatalogs)
        .insert(NoteCatalogsCompanion.insert(name: 'Cat', schema: '{}'));
    for (var i = 0; i < 2; i++) {
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              subject: 'n$i',
              catalogId: Value(catalogId),
              authorId: oldId,
            ),
          );
    }
    ownFolder('OLD', exists: false);
    listing([_folder('IPHONE')]);
    await store.setLink('SUB', 'a@b.c');

    SyncOrchestrator orchestrator() => SyncOrchestrator(
      provider: _EmptyRemoteOneDrive(
        container.read(oneDriveGraphClientProvider),
      ),
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
      currentAuthorId: () async =>
          (await container.read(currentAuthorProvider.future)).id,
    );

    // The device has notes: joining is the person's choice.
    final first = await orchestrator().syncNow();
    expect(first.errors.single.recordId, 'onedrive-folder');
    expect(store.ownerId, 'OLD');
    expect(await db.select(db.authors).get(), hasLength(2));

    await container.read(oneDriveOwnerFolderProvider).choose('IPHONE');
    final result = await orchestrator().syncNow();

    expect(result.errors, isEmpty);
    expect(store.ownerId, 'IPHONE');
    expect(store.linkedHmmSub, isNull, reason: 'joining clears the link');
    final rows = {
      for (final a in await db.select(db.authors).get()) a.id: a.accountName,
    };
    expect(rows, {oldId: 'OLD', iphoneId: 'IPHONE'}, reason: 'no rename');
    final author = await container.read(currentAuthorProvider.future);
    expect(author.id, iphoneId);
    final notes = await LocalHmmNoteRepository(
      db,
      () => container.read(currentAuthorProvider.future),
    ).getNotes(catalogId: catalogId);
    expect(notes.items, hasLength(2));
  });

  test('.legacy_migrated.json is not counted as a folder', () async {
    await setUpWith(ownerId: 'NEW');
    await insertAuthor('NEW');
    ownFolder('NEW', exists: false);
    listing([
      {
        'name': '.legacy_migrated.json',
        'file': {'mimeType': 'application/json'},
      },
      {
        'name': '.hidden',
        'folder': {'childCount': 0},
      },
      _folder('IPHONE'),
    ]);

    final folder = container.read(oneDriveOwnerFolderProvider);
    expect(await folder.resolve(), 'IPHONE');
  });

  test('listUserFolders follows @odata.nextLink', () async {
    await setUpWith(ownerId: 'NEW');
    adapter
      ..onGet(
        '$_users:/children',
        (server) => server.reply(200, {
          'value': [_folder('A')],
          '@odata.nextLink': 'https://graph.example/next-page',
        }),
      )
      ..onGet(
        'https://graph.example/next-page',
        (server) => server.reply(200, {
          'value': [_folder('B')],
        }),
      );

    final graph = container.read(oneDriveGraphClientProvider);
    final folders = await graph.listUserFolders();
    expect(folders.map((f) => f.name), ['A', 'B']);
  });
}

/// OneDrive with the real owner-folder resolution but an empty, healthy
/// remote for everything else.
class _EmptyRemoteOneDrive extends OneDriveSyncProvider {
  _EmptyRemoteOneDrive(OneDriveGraphClient graph)
    : super(FakeOneDriveAuth(), graph);

  @override
  Future<int> migrateLegacyIfNeeded() async => 0;
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<SyncManifest?> pullManifest() async => null;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;
  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullTags() async => null;
  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteStates() async => null;
  @override
  Future<void> pushNoteStates(
    Map<String, dynamic> doc, {
    required Set<String> changed,
  }) async {}
  @override
  bool get supportsAttachments => false;
  @override
  bool get supportsLargeFiles => false;
}

class _RenameThrowsAuthors implements IAuthorRepository {
  _RenameThrowsAuthors(this._inner);
  final IAuthorRepository _inner;

  @override
  Future<Author> updateAuthor(int id, AuthorsCompanion author) =>
      throw StateError('disk full');

  @override
  Future<Author?> getAuthorByAccountName(String accountName) =>
      _inner.getAuthorByAccountName(accountName);

  @override
  Future<Author> getOrCreateDefaultAuthor(
    String accountName, {
    String? description,
    String? avatarUrl,
  }) => _inner.getOrCreateDefaultAuthor(accountName);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _AdoptThrowsStore extends OwnerIdStore {
  _AdoptThrowsStore(super.prefs);

  @override
  Future<void> adoptOwnerId(String id) async => throw StateError('prefs');
}
