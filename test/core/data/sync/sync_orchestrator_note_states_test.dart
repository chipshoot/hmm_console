import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;
  late SyncMetaRepository meta;
  late SyncOrchestrator orchestrator;
  late LocalNoteStateRepository states;

  final t0 = DateTime.utc(2026, 10, 1, 9);
  final t1 = t0.add(const Duration(hours: 1));
  final t2 = t0.add(const Duration(hours: 2));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: meta,
      vaultStore: noopVaultStore,
    );
    states = LocalNoteStateRepository(db);
  });

  tearDown(() => db.close());

  Future<int> insertNote(
    String uuid, {
    String subject = 'mine',
    required DateTime modified,
    DateTime? deletedAt,
    String? content = 'body',
  }) => db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          uuid: Value(uuid),
          subject: subject,
          content: Value(content),
          authorId: 1,
          createDate: Value(t0),
          lastModifiedDate: Value(modified),
          deletedAt: Value(deletedAt),
        ),
      );

  Future<Note> row(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

  SyncManifest manifest(List<ManifestEntry> notes) => SyncManifest(
    version: 1,
    generatedAt: t2,
    deviceId: 'other',
    notes: notes,
    attachments: const [],
  );

  Map<String, dynamic>? pushedState(String uuid) =>
      (provider.pushedStates!['states'] as List)
          .cast<Map<String, dynamic>>()
          .where((s) => s['noteUuid'] == uuid)
          .firstOrNull;

  test(
    'a pin on this device and a text edit on another both survive',
    () async {
      final id = await insertNote('n1', modified: t0);
      // This device already synced the note; then it only pinned it.
      await meta.setLastPushedAt('fake', t0.add(const Duration(minutes: 1)));
      await states.setPinned('n1', true);
      // The other device edited the text later and never pinned.
      provider.remoteManifest = manifest([
        ManifestEntry(id: 'n1', updatedAt: t2, deleted: false),
      ]);
      provider.remoteBodies['n1'] = {
        'uuid': 'n1',
        'subject': 'edited on B',
        'content': 'new body',
        'lastModifiedDate': t2.toIso8601String(),
        'tags': const <String>[],
      };
      provider.remoteStates = {'version': 1, 'states': const []};

      final result = await orchestrator.syncNow();

      expect(result.errors, isEmpty, reason: result.errors.join('\n'));
      final r = await row(id);
      expect(r.subject, 'edited on B', reason: 'the text edit applied');
      expect(
        (await states.getState('n1')).isPinned,
        isTrue,
        reason: 'the pin survived',
      );
      expect(
        provider.pushedBodies.containsKey('n1'),
        isFalse,
        reason:
            'pinning never re-pushes the note, so it cannot overwrite the edit',
      );
      expect(pushedState('n1')!['isPinned'], isTrue);
      expect(provider.pushedChanged, {'n1'});
    },
  );

  test('a remote pin applies without touching the local note row', () async {
    final id = await insertNote('n1', modified: t2);
    await meta.setLastPushedAt('fake', t2.add(const Duration(minutes: 1)));
    final before = await row(id);
    provider.remoteManifest = manifest([
      ManifestEntry(id: 'n1', updatedAt: t2, deleted: false),
    ]);
    provider.remoteStates = {
      'version': 1,
      'states': [
        {
          'noteUuid': 'n1',
          'isPinned': true,
          'flagColor': 3,
          'lastModified': t1.toIso8601String(),
        },
      ],
    };

    await orchestrator.syncNow();

    final s = await states.getState('n1');
    expect(s.isPinned, isTrue);
    expect(s.flagColor, 3);
    final after = await row(id);
    expect(after.lastModifiedDate, before.lastModifiedDate);
    expect(after.version, before.version);
    expect(provider.pushedBodies, isEmpty);
  });

  test('an old server keeps local state and sets the unsupported flag', () async {
    await insertNote('n1', modified: t0);
    await states.putState(
      NoteState(noteUuid: 'n1', isPinned: true, lastModifiedDate: t1),
    );
    provider.remoteManifest = manifest([
      ManifestEntry(id: 'n1', updatedAt: t0, deleted: false),
    ]);
    provider.unsupported = true;

    final result = await orchestrator.syncNow();

    expect(
      result.errors,
      isEmpty,
      reason: 'an old server is not a sync failure',
    );
    expect((await states.getState('n1')).isPinned, isTrue);
    expect(provider.pushCalls, 0);
    expect(await meta.getNoteStatesUnsupported('fake'), isTrue);

    // The server is upgraded: it has no states yet, so every local one goes up.
    provider.unsupported = false;
    provider.remoteStates = null;
    await orchestrator.syncNow();

    expect(await meta.getNoteStatesUnsupported('fake'), isFalse);
    expect(provider.pushedChanged, {'n1'});
  });

  test(
    'a state for a purged note is dropped and never revives the note',
    () async {
      // Purged on this device: a content-free tombstone (Task 8) plus a stale
      // state row; a peer that has not purged yet still pushes a newer pin.
      final id = await insertNote(
        'n1',
        subject: kTombstoneSubject,
        content: null,
        modified: t0,
        deletedAt: t0,
      );
      await states.putState(
        NoteState(noteUuid: 'n1', isPinned: true, lastModifiedDate: t0),
      );
      provider.remoteManifest = manifest([
        ManifestEntry(id: 'n1', updatedAt: t0, deleted: true),
      ]);
      provider.remoteStates = {
        'version': 1,
        'states': [
          {
            'noteUuid': 'n1',
            'isPinned': true,
            'flagColor': null,
            'lastModified': t2.toIso8601String(),
          },
        ],
      };

      final result = await orchestrator.syncNow();

      expect(result.errors, isEmpty, reason: result.errors.join('\n'));
      expect(await states.getAllStates(), isEmpty);
      expect(pushedState('n1'), isNull);
      final r = await row(id);
      expect(r.deletedAt, isNotNull);
      expect(r.subject, kTombstoneSubject);
    },
  );

  test(
    'a failed state pull is a non-fatal error and advances the cursor',
    () async {
      await insertNote('n1', modified: t0);
      provider.remoteManifest = manifest([
        ManifestEntry(id: 'n1', updatedAt: t0, deleted: false),
      ]);
      provider.failPull = true;

      final result = await orchestrator.syncNow();

      expect(result.errors.map((e) => e.recordType), ['noteStates']);
      expect(await meta.getLastPushedAt('fake'), isNotNull);
    },
  );

  test(
    'an absent tags key keeps membership; a present empty list clears it',
    () async {
      final id = await insertNote('n1', modified: t0);
      final tags = LocalTagRepository(db);
      await tags.setTagsForNote(id, ['work']);

      provider.remoteManifest = manifest([
        ManifestEntry(id: 'n1', updatedAt: t1, deleted: false),
      ]);
      provider.remoteBodies['n1'] = {
        'uuid': 'n1',
        'subject': 'mine',
        'lastModifiedDate': t1.toIso8601String(),
      }; // no 'tags' key: an older client, or a server without note tags
      await orchestrator.syncNow();
      expect(await tags.tagNamesForNote(id), ['work']);

      provider.remoteManifest = manifest([
        ManifestEntry(id: 'n1', updatedAt: t2, deleted: false),
      ]);
      provider.remoteBodies['n1'] = {
        'uuid': 'n1',
        'subject': 'mine',
        'lastModifiedDate': t2.toIso8601String(),
        'tags': const <String>[],
      };
      await orchestrator.syncNow();
      expect(await tags.tagNamesForNote(id), isEmpty);
    },
  );
}

class _FakeProvider extends CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  final Map<String, Map<String, dynamic>> pushedBodies = {};
  Map<String, dynamic>? remoteStates;
  Map<String, dynamic>? pushedStates;
  Set<String>? pushedChanged;
  int pushCalls = 0;
  bool unsupported = false;
  bool failPull = false;

  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => remoteManifest;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async =>
      remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async =>
      pushedBodies[id] = body;

  @override
  Future<Map<String, dynamic>?> pullNoteStates() async {
    if (unsupported) throw const NoteStatesUnsupportedException();
    if (failPull) throw StateError('offline');
    return remoteStates;
  }

  @override
  Future<void> pushNoteStates(
    Map<String, dynamic> doc, {
    required Set<String> changed,
  }) async {
    pushCalls++;
    pushedStates = doc;
    pushedChanged = changed;
  }
}
