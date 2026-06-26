// Phase 2a regression: the editable `noteDate` must survive the
// cloudStorage (OneDrive) sync round-trip — both directions. Before this
// fix the orchestrator serialized `createDate` but never `noteDate`, so an
// edited note date was silently lost across devices.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'onedrive_test_fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late HmmDatabase db;
  late _FakeCloudSyncProvider provider;
  late SyncOrchestrator orchestrator;
  late SyncMetaRepository meta;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'tester'),
        );
    provider = _FakeCloudSyncProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(provider: provider, db: db, meta: meta, vaultStore: noopVaultStore);
  });

  tearDown(() async => db.close());

  test('outbound: pushed note body carries noteDate distinct from createDate',
      () async {
    final created = DateTime.utc(2026, 1, 1, 9);
    final edited = DateTime.utc(2025, 6, 15, 14, 30); // user moved it earlier
    final id = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'trip',
          authorId: 1,
          createDate: Value(created),
          noteDate: Value(edited),
          lastModifiedDate: Value(created),
        ));
    final note =
        await (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: created, deviceId: 'test',
      notes: const [], attachments: const [],
    );

    final result = await orchestrator.syncNow();
    expect(result.errors, isEmpty, reason: result.errors.join('\n'));

    final body = provider.pushedBodies[note.uuid];
    expect(body, isNotNull);
    expect(DateTime.parse(body!['noteDate'] as String).isAtSameMomentAs(edited),
        isTrue);
    // createDate still serialized independently and unchanged.
    expect(
        DateTime.parse(body['createDate'] as String).isAtSameMomentAs(created),
        isTrue);
  });

  test('inbound insert: a remote note body applies its noteDate locally',
      () async {
    final created = DateTime.utc(2026, 2, 2, 8);
    final edited = DateTime.utc(2024, 12, 31, 23);
    const uuid = 'remote-note-1';
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: created, deviceId: 'other',
      notes: [ManifestEntry(id: uuid, updatedAt: created, deleted: false)],
      attachments: const [],
    );
    provider.remoteBodies[uuid] = {
      'uuid': uuid,
      'subject': 'from other device',
      'createDate': created.toIso8601String(),
      'noteDate': edited.toIso8601String(),
      'lastModifiedDate': created.toIso8601String(),
      'tags': const <String>[],
    };

    final result = await orchestrator.syncNow();
    expect(result.errors, isEmpty, reason: result.errors.join('\n'));

    final note = await (db.select(db.notes)..where((n) => n.uuid.equals(uuid)))
        .getSingleOrNull();
    expect(note, isNotNull);
    expect(note!.noteDate, isNotNull);
    expect(note.noteDate!.isAtSameMomentAs(edited), isTrue);
  });

  test('inbound update: a remote body omitting noteDate preserves local value',
      () async {
    final localNoteDate = DateTime.utc(2023, 3, 3, 10);
    final localMtime = DateTime.utc(2026, 1, 1);
    final id = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'mine',
          authorId: 1,
          uuid: const Value('n1'),
          createDate: Value(localMtime),
          noteDate: Value(localNoteDate),
          lastModifiedDate: Value(localMtime),
        ));

    // Remote has a NEWER edit (so the pull applies) but, being an older
    // client, omits noteDate entirely.
    final remoteMtime = localMtime.add(const Duration(days: 1));
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: remoteMtime, deviceId: 'other',
      notes: [ManifestEntry(id: 'n1', updatedAt: remoteMtime, deleted: false)],
      attachments: const [],
    );
    provider.remoteBodies['n1'] = {
      'uuid': 'n1',
      'subject': 'mine (edited elsewhere)',
      'createDate': localMtime.toIso8601String(),
      'lastModifiedDate': remoteMtime.toIso8601String(),
      'tags': const <String>[],
    };

    final result = await orchestrator.syncNow();
    expect(result.errors, isEmpty, reason: result.errors.join('\n'));

    final note =
        await (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();
    expect(note.subject, 'mine (edited elsewhere)'); // the edit applied
    expect(note.noteDate, isNotNull);
    expect(note.noteDate!.isAtSameMomentAs(localNoteDate), isTrue,
        reason: 'omitted noteDate must not zero the stored value');
  });
}

class _FakeCloudSyncProvider extends CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> pushedBodies = {};
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  SyncManifest? lastPushedManifest;

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
  Future<void> pushManifest(SyncManifest manifest) async =>
      lastPushedManifest = manifest;
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async =>
      remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async =>
      pushedBodies[id] = body;
  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;
  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullTags() async => null;
  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {}
}
