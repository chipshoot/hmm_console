import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/local/note_purge_service.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/pending_remote_purge_store.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HmmDatabase db;
  late _RecordingVault vault;
  late _FakeProvider provider;
  final now = DateTime.utc(2026, 10, 18, 12);
  final old = now.subtract(const Duration(days: 31));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    vault = _RecordingVault();
    provider = _FakeProvider();
  });

  tearDown(() => db.close());

  NotePurgeService service(DataMode mode) => NotePurgeService(
    db: db,
    mode: mode,
    baseVaultStore: () async => vault,
    provider: mode == DataMode.local ? null : provider,
  );

  String withImages(List<String> paths) => NoteAttachmentsCodec.encode(
    NoteAttachments(
      images: [
        for (final p in paths)
          VaultRef(path: p, contentType: 'image/jpeg', byteSize: 1),
      ],
    ),
  )!;

  Future<int> insert(
    String uuid, {
    DateTime? deletedAt,
    String? attachments,
    int? parentId,
    int? catalogId,
  }) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          uuid: Value(uuid),
          subject: 'note $uuid',
          content: const Value('body'),
          authorId: 1,
          catalogId: Value(catalogId),
          createDate: Value(old.subtract(const Duration(days: 1))),
          lastModifiedDate: Value(deletedAt ?? old),
          deletedAt: Value(deletedAt),
          attachments: Value(attachments),
          parentNoteId: Value(parentId),
        ),
      );

  Future<Note?> byUuid(String uuid) => (db.select(
    db.notes,
  )..where((n) => n.uuid.equals(uuid))).getSingleOrNull();

  Future<void> addState(String uuid) => db
      .into(db.noteStates)
      .insert(
        NoteStatesCompanion.insert(
          noteUuid: uuid,
          isPinned: const Value(true),
          lastModifiedDate: old,
        ),
      );

  Future<List<String>> stateUuids() async =>
      (await db.select(db.noteStates).get()).map((s) => s.noteUuid).toList()
        ..sort();

  group('local mode', () {
    test(
      'purgeExpired hard-deletes notes deleted more than 30 days ago, '
      'with their tag refs, detaching children and releasing vault files',
      () async {
        final id = await insert(
          'gone',
          deletedAt: old,
          attachments: withImages(['note-1/a.jpg']),
        );
        await LocalTagRepository(db).setTagsForNote(id, ['work']);
        await insert('child', parentId: id);

        final purged = await service(DataMode.local).purgeExpired(now);

        expect(purged, 1);
        expect(await byUuid('gone'), isNull);
        expect(
          await (db.select(
            db.noteTagRefs,
          )..where((r) => r.noteId.equals(id))).get(),
          isEmpty,
        );
        expect(
          (await byUuid('child'))!.parentNoteId,
          isNull,
          reason: 'G12: unattached after purge',
        );
        expect(vault.deleted, ['note-1/a.jpg']);
      },
    );

    test('purge removes the note\'s state row', () async {
      await insert('gone', deletedAt: old);
      await insert('keeper');
      await addState('gone');
      await addState('keeper');

      await service(DataMode.local).purgeExpired(now);

      expect(await stateUuids(), ['keeper']);
    });

    test('notes deleted 30 days ago or less are kept', () async {
      await insert('recent', deletedAt: now.subtract(const Duration(days: 29)));
      await insert('edge', deletedAt: now.subtract(const Duration(days: 30)));
      await insert('live');

      expect(await service(DataMode.local).purgeExpired(now), 0);
      expect(await byUuid('recent'), isNotNull);
      expect(await byUuid('edge'), isNotNull);
      expect(await byUuid('live'), isNotNull);
    });

    test('applies to entity notes too (G11)', () async {
      final catalogId = await db
          .into(db.noteCatalogs)
          .insert(
            NoteCatalogsCompanion.insert(
              name: 'Hmm.AutomobileMan.GasLog',
              schema: '{}',
            ),
          );
      await insert('fuel', deletedAt: old, catalogId: catalogId);

      expect(await service(DataMode.local).purgeExpired(now), 1);
      expect(await byUuid('fuel'), isNull);
    });

    test('a vault file another note still references is kept', () async {
      await insert(
        'gone',
        deletedAt: old,
        attachments: withImages(['shared.jpg']),
      );
      await insert('keeper', attachments: withImages(['shared.jpg']));

      await service(DataMode.local).purgeExpired(now);

      expect(vault.deleted, isEmpty);
    });

    test(
      'purgeNow purges a recently deleted note and refuses a live one',
      () async {
        final recent = await insert(
          'recent',
          deletedAt: now.subtract(const Duration(days: 1)),
        );
        final live = await insert('live');

        expect(
          await service(DataMode.local).purgeNow(recent),
          PurgeOutcome.purged,
        );
        expect(
          await service(DataMode.local).purgeNow(live),
          PurgeOutcome.notEligible,
        );
        expect(await byUuid('live'), isNotNull);
      },
    );
  });

  group('cloudStorage mode', () {
    test('scrubs to a content-free tombstone, keeps uuid and timestamps, '
        'and queues the remote purge for the next sync', () async {
      final id = await insert(
        'gone',
        deletedAt: old,
        attachments: withImages(['note-1/a.jpg']),
      );
      await LocalTagRepository(db).setTagsForNote(id, ['work']);
      final before = (await byUuid('gone'))!;

      expect(await service(DataMode.cloudStorage).purgeExpired(now), 1);

      final stub = (await byUuid('gone'))!;
      expect(stub.subject, kTombstoneSubject);
      expect(stub.content, isNull);
      expect(stub.attachments, isNull);
      expect(stub.deletedAt, before.deletedAt);
      expect(
        stub.lastModifiedDate,
        before.lastModifiedDate,
        reason: 'not bumped: peers keep their own 30-day clock',
      );
      expect(
        await (db.select(
          db.noteTagRefs,
        )..where((r) => r.noteId.equals(id))).get(),
        isEmpty,
      );
      expect(
        provider.purged,
        isEmpty,
        reason: 'remote deletion is deferred into sync',
      );
      final pending = await PendingRemotePurgeStore().read('fake');
      expect(pending['gone'], {'note-1/a.jpg'});
      expect(vault.deleted, ['note-1/a.jpg']);
    });

    test('purge removes the note\'s state row', () async {
      await insert('gone', deletedAt: old);
      await addState('gone');

      await service(DataMode.cloudStorage).purgeExpired(now);

      expect(
        await stateUuids(),
        isEmpty,
        reason: 'the stub keeps no pin/flag; the merge drops the remote entry',
      );
      expect((await byUuid('gone'))!.subject, kTombstoneSubject);
    });

    test('an already scrubbed tombstone is not processed again', () async {
      await insert('gone', deletedAt: old);
      final s = service(DataMode.cloudStorage);

      expect(await s.purgeExpired(now), 1);
      expect(await s.purgeExpired(now.add(const Duration(days: 1))), 0);
    });
  });

  group('cloudApi mode', () {
    test(
      'calls the server purge, then deletes the row and its state',
      () async {
        await insert('gone', deletedAt: old);
        await addState('gone');

        expect(await service(DataMode.cloudApi).purgeExpired(now), 1);

        expect(provider.purged, ['gone']);
        expect(await byUuid('gone'), isNull);
        expect(
          await stateUuids(),
          isEmpty,
          reason: 'the server cascades its rows; the client drops its own',
        );
        expect(
          vault.deleted,
          isEmpty,
          reason: 'the server releases cloudApi vault bytes',
        );
      },
    );

    test('keeps the row when the server says the note is live', () async {
      final id = await insert('gone', deletedAt: old);
      await addState('gone');
      provider.liveOnServer = true;

      expect(
        await service(DataMode.cloudApi).purgeNow(id),
        PurgeOutcome.keptLiveOnServer,
      );
      expect(await byUuid('gone'), isNotNull);
      expect(await stateUuids(), ['gone'], reason: 'a live note keeps its pin');
    });

    test('keeps the row when the server purge fails', () async {
      final id = await insert('gone', deletedAt: old);
      provider.failure = StateError('offline');

      expect(
        await service(DataMode.cloudApi).purgeNow(id),
        PurgeOutcome.failed,
      );
      expect(await byUuid('gone'), isNotNull);
    });

    test('a restore that lands during the purge wins', () async {
      final id = await insert('gone', deletedAt: old);
      provider.duringPurge = () =>
          (db.update(db.notes)..where((n) => n.id.equals(id))).write(
            NotesCompanion(
              deletedAt: const Value(null),
              lastModifiedDate: Value(now),
            ),
          );

      expect(
        await service(DataMode.cloudApi).purgeNow(id),
        PurgeOutcome.notEligible,
      );
      final row = (await byUuid('gone'))!;
      expect(
        row.deletedAt,
        isNull,
        reason: 'the guarded delete matched nothing',
      );
    });
  });
}

class _RecordingVault implements IVaultStore {
  final deleted = <String>[];

  @override
  Future<void> putBytes(
    String relativePath,
    Uint8List bytes, {
    String? contentType,
  }) async {}
  @override
  Future<Uint8List> getBytes(String relativePath) async => Uint8List(0);
  @override
  Future<bool> exists(String relativePath) async => true;
  @override
  Future<void> delete(String relativePath) async => deleted.add(relativePath);
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

class _FakeProvider extends CloudSyncProvider {
  final purged = <String>[];
  bool liveOnServer = false;
  Object? failure;
  Future<void> Function()? duringPurge;

  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => null;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}

  @override
  Future<void> purgeNote(
    String uuid, {
    Set<String> releasedVaultPaths = const {},
  }) async {
    if (liveOnServer) throw const NoteLiveOnServerException();
    final f = failure;
    if (f != null) throw f;
    await duringPurge?.call();
    purged.add(uuid);
  }
}
