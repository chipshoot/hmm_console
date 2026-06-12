// Regression tests for the Phase-D.1 self-healing push fix:
// a local note that has fallen below the cursor (so the existing
// `mtime > cursor` filter wouldn't pick it up) but is missing from the
// remote manifest MUST still be pushed. Symmetric to the pull leg's
// LWW which already handles "remote has it, local stale-or-missing".
//
// User-reported symptom: "Click Sync Now. Only the gas log I just
// updated reaches OneDrive. The automobile note never gets there."
// See `findings.md` 2026-05-25 for the diagnosis.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
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

    // One author is required for note inserts.
    await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'tester'),
        );

    provider = _FakeCloudSyncProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(provider: provider, db: db, meta: meta);
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'local note with mtime BELOW cursor still gets pushed when remote '
      'manifest is empty', () async {
    // Cursor at "now" — strictly AFTER the note we're about to insert.
    final cursor = DateTime.utc(2026, 5, 25, 12);
    await meta.setLastPushedAt(provider.providerId, cursor);

    // Insert a note that was created an hour BEFORE the cursor (so the
    // legacy `mtime > cursor` filter would skip it).
    final oldMtime = cursor.subtract(const Duration(hours: 1));
    final noteId = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'My automobile',
          authorId: 1,
          createDate: Value(oldMtime),
          lastModifiedDate: Value(oldMtime),
        ));
    final note = await (db.select(db.notes)
          ..where((n) => n.id.equals(noteId)))
        .getSingle();

    // Remote manifest is empty — the note exists locally but cloud
    // doesn't know about it. This is exactly the cursor-drift state
    // the user reported.
    provider.remoteManifest = SyncManifest(
      version: 1,
      generatedAt: cursor,
      deviceId: 'test',
      notes: const [],
      attachments: const [],
    );

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(provider.pushedBodies, containsPair(note.uuid, anything),
        reason: 'self-healing push should fire even though mtime < cursor');
    expect(result.pushedNotes, equals(1));
  });

  test(
      'local note ALREADY in remote manifest is NOT re-pushed '
      '(no churn)', () async {
    final cursor = DateTime.utc(2026, 5, 25, 12);
    await meta.setLastPushedAt(provider.providerId, cursor);

    final oldMtime = cursor.subtract(const Duration(hours: 1));
    final noteId = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'My automobile',
          authorId: 1,
          createDate: Value(oldMtime),
          lastModifiedDate: Value(oldMtime),
        ));
    final note = await (db.select(db.notes)
          ..where((n) => n.id.equals(noteId)))
        .getSingle();

    // Remote ALREADY has this note (mtime same as local — stable).
    provider.remoteManifest = SyncManifest(
      version: 1,
      generatedAt: cursor,
      deviceId: 'test',
      notes: [
        ManifestEntry(
          id: note.uuid!,
          updatedAt: oldMtime,
          deleted: false,
        ),
      ],
      attachments: const [],
    );

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(provider.pushedBodies, isEmpty,
        reason: 'no missing-from-remote backfill should fire when '
            'remote already knows about the note');
    expect(result.pushedNotes, equals(0));
  });

  test(
      'mixes correctly: one note changed-since-cursor + one '
      'missing-from-remote → both pushed', () async {
    final cursor = DateTime.utc(2026, 5, 25, 12);
    await meta.setLastPushedAt(provider.providerId, cursor);

    // Note A: locally modified AFTER cursor — caught by the existing
    // `mtime > cursor` filter.
    final freshMtime = cursor.add(const Duration(hours: 1));
    final aId = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'gas log',
          authorId: 1,
          createDate: Value(freshMtime),
          lastModifiedDate: Value(freshMtime),
        ));
    final noteA = await (db.select(db.notes)..where((n) => n.id.equals(aId)))
        .getSingle();

    // Note B: locally modified BEFORE cursor + missing from remote —
    // only the new self-healing path picks it up.
    final oldMtime = cursor.subtract(const Duration(hours: 1));
    final bId = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'automobile',
          authorId: 1,
          createDate: Value(oldMtime),
          lastModifiedDate: Value(oldMtime),
        ));
    final noteB = await (db.select(db.notes)..where((n) => n.id.equals(bId)))
        .getSingle();

    provider.remoteManifest = SyncManifest(
      version: 1,
      generatedAt: cursor,
      deviceId: 'test',
      notes: const [],
      attachments: const [],
    );

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(provider.pushedBodies.keys, containsAll([noteA.uuid, noteB.uuid]));
    expect(result.pushedNotes, equals(2));
  });

  test(
      'a note already collected by the changed-since-cursor path is NOT '
      'double-queued by the missing-from-remote path', () async {
    final cursor = DateTime.utc(2026, 5, 25, 12);
    await meta.setLastPushedAt(provider.providerId, cursor);

    final freshMtime = cursor.add(const Duration(hours: 1));
    final aId = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'changed + missing',
          authorId: 1,
          createDate: Value(freshMtime),
          lastModifiedDate: Value(freshMtime),
        ));
    final note = await (db.select(db.notes)..where((n) => n.id.equals(aId)))
        .getSingle();

    provider.remoteManifest = SyncManifest(
      version: 1,
      generatedAt: cursor,
      deviceId: 'test',
      notes: const [],
      attachments: const [],
    );

    final result = await orchestrator.syncNow();

    expect(result.pushedNotes, equals(1),
        reason: 'should be pushed once, not twice');
    expect(provider.pushedBodies.keys, equals([note.uuid]));
  });
}

/// Minimal CloudSyncProvider fake. Captures pushes into a map so the
/// tests can assert on what would have hit the cloud.
class _FakeCloudSyncProvider implements CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> pushedBodies = {};
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
  Future<void> pushManifest(SyncManifest manifest) async {
    lastPushedManifest = manifest;
  }

  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async {
    // For these tests we never need to actually return a body — the
    // remoteManifest is empty in every scenario or contains entries
    // that match local LWW already.
    return null;
  }

  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {
    pushedBodies[id] = body;
  }

  // Settings (Phase D.2) — these tests don't exercise the settings
  // leg, so just stub them out.
  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;

  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}

  // Tags (Phase D.3) — not exercised by these tests.
  @override
  Future<Map<String, dynamic>?> pullTags() async => null;

  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {}
}
