// Regression: a pulled note must belong to the SIGNED-IN author.
//
// Every read in LocalHmmNoteRepository filters `authorId == currentAuthor.id`,
// but _buildManifest reads every row regardless of author. So attaching a pull
// to the wrong author made the notes invisible in the app while still being
// counted in the manifest pushed back to the cloud — sync reported success,
// the cloud copy stayed intact, and the user saw an empty app after a
// reinstall. The old fallback ("whichever author row is first, else invent
// local-user") did exactly that whenever a sync ran before sign-in had created
// the real author row.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late HmmDatabase db;
  late _FakeCloudSyncProvider provider;

  const uuid = 'remote-note-1';
  final at = DateTime.utc(2026, 5, 5, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());

    // Two authors, in this order. The first is the stale row a previous
    // sync would have latched onto; the second is the signed-in user.
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'local-user'));
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'signed-in-user'));

    provider = _FakeCloudSyncProvider()
      ..remoteManifest = SyncManifest(
        version: 1,
        generatedAt: at,
        deviceId: 'other-device',
        notes: [ManifestEntry(id: uuid, updatedAt: at, deleted: false)],
        attachments: const [],
      )
      ..remoteBodies[uuid] = {
        'uuid': uuid,
        'subject': 'from the cloud',
        'createDate': at.toIso8601String(),
        'lastModifiedDate': at.toIso8601String(),
        'tags': const <String>[],
      };
  });

  tearDown(() async => db.close());

  test('a pulled note is owned by the signed-in author, not the first row',
      () async {
    final signedIn = await (db.select(db.authors)
          ..where((a) => a.accountName.equals('signed-in-user')))
        .getSingle();

    final orchestrator = SyncOrchestrator(
      provider: provider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
      currentAuthorId: () async => signedIn.id,
    );

    final result = await orchestrator.syncNow();
    expect(result.errors, isEmpty, reason: result.errors.join('\n'));

    final note = await (db.select(db.notes)..where((n) => n.uuid.equals(uuid)))
        .getSingleOrNull();
    expect(note, isNotNull, reason: 'the note was pulled');
    expect(note!.authorId, signedIn.id,
        reason: 'anything else and the app renders an empty list while the '
            'manifest still counts this note');
  });

  test('adopts notes already stranded on another author', () async {
    // The live incident: a pull on an older build attached notes to the
    // wrong author. They render nowhere, and _maybePullNote's LWW check
    // sees them as present and declines to re-pull — so the insert-side
    // fix alone never reaches them. Only an explicit repair does.
    final stale = await (db.select(db.authors)
          ..where((a) => a.accountName.equals('local-user')))
        .getSingle();
    final signedIn = await (db.select(db.authors)
          ..where((a) => a.accountName.equals('signed-in-user')))
        .getSingle();

    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'stranded before the fix',
          authorId: stale.id,
          uuid: const Value('old-note'),
          createDate: Value(at),
          lastModifiedDate: Value(at),
        ));

    await SyncOrchestrator(
      provider: provider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
      currentAuthorId: () async => signedIn.id,
    ).syncNow();

    final adopted = await (db.select(db.notes)
          ..where((n) => n.uuid.equals('old-note')))
        .getSingle();
    expect(adopted.authorId, signedIn.id,
        reason: 'an orphaned row must be reachable again, not left invisible');
    expect(adopted.subject, 'stranded before the fix',
        reason: 'adoption changes ownership only, never content');
  });

  test('no stray local-user author is invented when a resolver is supplied',
      () async {
    final signedIn = await (db.select(db.authors)
          ..where((a) => a.accountName.equals('signed-in-user')))
        .getSingle();
    final before = (await db.select(db.authors).get()).length;

    await SyncOrchestrator(
      provider: provider,
      db: db,
      meta: SyncMetaRepository(),
      vaultStore: noopVaultStore,
      currentAuthorId: () async => signedIn.id,
    ).syncNow();

    expect((await db.select(db.authors).get()).length, before);
  });
}
