# Tag Cloud Sync (C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make tags sync in cloudStorage (OneDrive) mode — tag definitions via a small `tags.json`, tag membership embedded in each note's synced body — without bloating any file.

**Architecture:** Drift v6 adds `lastModified`/`deletedAt` to `Tags` (the `NoteTagRefs` join is untouched — membership is reconstructed from note bodies on pull). A `TagSyncService` merges tag *definitions* per-name (last-writer-wins + tombstones); the `SyncOrchestrator` runs it as a `_syncTags` leg and embeds/expands each note's tag-name list in the existing incremental note sync. The relational join stays the query model; only the OneDrive wire denormalizes. `cloudApi` `ApiTagRepository` is out of scope.

**Tech Stack:** Flutter + Dart, Drift (SQLite), Riverpod, Dio (OneDrive Graph). Tests: `flutter_test` + in-memory Drift (`NativeDatabase.memory()`) + `http_mock_adapter` + hand-written fakes.

**Reused, already in the codebase (do not recreate):**
- `Tags` table: `id` (autoinc), `name` (unique, 1–200), `description` (nullable), `isActivated` (default true). `NoteTagRefs`: `(noteId, tagId)` composite PK referencing `Notes`/`Tags`.
- `LocalTagRepository` / `ITagRepository` + `localTagRepositoryProvider` in `lib/core/data/local/local_tag_repository.dart`. Existing methods: `getTags`, `getTagById`, `getTagByName` (normalizes via `name.lower().equals(name.toLowerCase().trim())`), `createTag(TagsCompanion)`, `updateTag`, `deactivateTag`, `getTagsForNote`, `applyTagToNote` (insertOnConflictUpdate), `removeTagFromNote`.
- `HmmDatabase` (`lib/core/data/local/database.dart`), `@DriftDatabase(tables: [Authors, NoteCatalogs, Notes, Tags, NoteTagRefs])`, `schemaVersion => 5`, `onUpgrade` with `if (from < N)` `m.addColumn(...)` blocks. `currentDateAndTime` is the Drift default constant (used by `Notes.createDate`).
- `CloudSyncProvider` (`lib/core/data/sync/cloud_sync_provider.dart`): abstract; has `pullSettings() async => null` / `pushSettings(body) async {}` default no-ops to mirror.
- `OneDriveSyncProvider` (`lib/core/data/sync/onedrive_sync_provider.dart`): `pullSettings() => _graph.getSettings()`, `pushSettings(b) => _graph.putSettings(b)`. Field `final OneDriveGraphClient _graph;`.
- `OneDriveGraphClient` (`lib/core/data/sync/onedrive_graph_client.dart`): `getSettings()` / `putSettings(body)` use `await _userPath('settings.json', action: 'content')` then `_dio.get`/`_dio.put`, `_throwIfBad(resp)`, returning null on 404. Field `_dio`.
- `SyncOrchestrator` (`lib/core/data/sync/sync_orchestrator.dart`): constructor `({required this.provider, required HmmDatabase db, required SyncMetaRepository meta, SyncableSettingsRepository? settingsRepo, void Function()? onSettingsApplied})` with initializer `: _db = db, _meta = meta, ...`. `syncNow()` calls `await _syncSettings(p, errors);` at line ~110. `_meta.getOrCreateDeviceId()` returns the device id. `SyncError({required recordType, required recordId, required message})`.
- `_collectChangedNotes(cursor)` builds `NoteBlob`s via `_noteRowToBlob(n, catalogNames, parentUuids)`; `_noteRowToBlob` returns `NoteBlob(id: uuid, body: {...}, updatedAt, deleted)`. `_applyPulledNote(uuid, entry, body, existing, pendingParents)` resolves a local `childId` (insert or update) — the place to rebuild membership.
- `TagsCompanion.insert({required String name, Value<String?> description, Value<bool> isActivated, ...})`; `NoteTagRefsCompanion.insert({required int noteId, required int tagId})`.

---

## Task 1: Drift v6 — add `lastModified` + `deletedAt` to `Tags`

**Files:**
- Modify: `lib/core/data/local/database.dart` (Tags table, `schemaVersion`, `onUpgrade`)
- Regenerate: `lib/core/data/local/database.g.dart` (via build_runner)
- Test: `test/core/data/local/tags_schema_v6_test.dart`

- [ ] **Step 1: Add the two columns to the `Tags` table**

In `lib/core/data/local/database.dart`, change the `Tags` class to:

```dart
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withLength(min: 0, max: 1000).nullable()();
  BoolColumn get isActivated => boolean().withDefault(const Constant(true))();
  // v6: sync metadata. lastModified drives per-name last-writer-wins;
  // deletedAt is the sync tombstone (distinct from the isActivated flag).
  DateTimeColumn get lastModified => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{name}];
}
```

- [ ] **Step 2: Bump `schemaVersion` and add the migration step**

Change `int get schemaVersion => 5;` to `=> 6;`. In `onUpgrade`, after the existing `if (from < 5) { ... }` block and before the closing `}` of the migration callback, add:

```dart
      if (from < 6) {
        // v6: tag sync metadata. Existing rows get currentDateAndTime as
        // lastModified and NULL deletedAt (live).
        await m.addColumn(tags, tags.lastModified);
        await m.addColumn(tags, tags.deletedAt);
      }
```

- [ ] **Step 3: Regenerate Drift code**

Run: `cd ~/projects/hmm_console && dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `lib/core/data/local/database.g.dart` now has `lastModified`/`deletedAt` on the generated `Tag` data class and `TagsCompanion`.

- [ ] **Step 4: Write the schema test**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';

void main() {
  test('v6 schema: Tags carries lastModified + deletedAt', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 6);

    final id = await db.into(db.tags).insert(
          TagsCompanion.insert(name: 'work'),
        );
    final fresh = await (db.select(db.tags)..where((t) => t.id.equals(id)))
        .getSingle();
    expect(fresh.deletedAt, isNull);
    expect(fresh.lastModified, isA<DateTime>());

    final when = DateTime.utc(2026, 6, 1);
    await (db.update(db.tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(deletedAt: Value(when), lastModified: Value(when)),
    );
    final after = await (db.select(db.tags)..where((t) => t.id.equals(id)))
        .getSingle();
    expect(after.deletedAt, when);
    expect(after.lastModified, when);
  });
}
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/core/data/local/tags_schema_v6_test.dart`
Expected: PASS

- [ ] **Step 6: Run analyze (codegen sanity) + commit**

Run: `flutter analyze lib/core/data/local`
Expected: No issues.

```bash
git add lib/core/data/local/database.dart lib/core/data/local/database.g.dart test/core/data/local/tags_schema_v6_test.dart
git commit -m "feat(tags): Drift v6 adds lastModified + deletedAt to Tags"
```

---

## Task 2: `LocalTagRepository` sync methods

Add five sync-oriented methods to the concrete `LocalTagRepository` (the sync layer uses the concrete class, like it uses `_db` directly). Leave `ITagRepository` and existing methods unchanged.

**Files:**
- Modify: `lib/core/data/local/local_tag_repository.dart`
- Test: `test/core/data/local/local_tag_repository_sync_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';

void main() {
  late HmmDatabase db;
  late LocalTagRepository repo;

  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalTagRepository(db);
  });
  tearDown(() => db.close());

  Future<int> _note() async => db.into(db.notes).insert(
        NotesCompanion.insert(subject: 's', authorId: await _author(db)),
      );

  test('getTagsWithMeta returns all tags including inactive/deleted', () async {
    await repo.upsertTagByName('a',
        isActivated: true, lastModified: DateTime.utc(2026, 1, 1));
    await repo.upsertTagByName('b',
        isActivated: false, lastModified: DateTime.utc(2026, 1, 1));
    await repo.tombstoneTagByName('b', DateTime.utc(2026, 1, 2));
    final all = await repo.getTagsWithMeta();
    expect(all.map((t) => t.name).toSet(), {'a', 'b'});
  });

  test('upsertTagByName creates then updates by normalized name', () async {
    await repo.upsertTagByName('  Work ',
        description: 'd1', isActivated: true,
        lastModified: DateTime.utc(2026, 1, 1));
    await repo.upsertTagByName('work',
        description: 'd2', isActivated: false,
        lastModified: DateTime.utc(2026, 1, 2));
    final tags = await repo.getTagsWithMeta();
    expect(tags.length, 1);
    expect(tags.single.description, 'd2');
    expect(tags.single.isActivated, false);
  });

  test('setTagsForNote set-replaces refs and auto-creates tags', () async {
    final noteId = await _note();
    await repo.setTagsForNote(noteId, ['work', 'urgent']);
    expect((await repo.tagNamesForNote(noteId)).toSet(), {'work', 'urgent'});

    // Drop 'urgent', add 'home'.
    await repo.setTagsForNote(noteId, ['work', 'home']);
    expect((await repo.tagNamesForNote(noteId)).toSet(), {'work', 'home'});
  });
}

Future<int> _author(HmmDatabase db) async =>
    db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/local/local_tag_repository_sync_test.dart`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Implement the methods**

In `lib/core/data/local/local_tag_repository.dart`, add these methods to the `LocalTagRepository` class (after `removeTagFromNote`):

```dart
  // ---- Sync support (cloudStorage tag sync) ----

  /// All tags including inactive and tombstoned ones (for definition merge).
  Future<List<Tag>> getTagsWithMeta() => _db.select(_db.tags).get();

  /// Create or update a tag by normalized name.
  Future<void> upsertTagByName(
    String name, {
    String? description,
    required bool isActivated,
    required DateTime lastModified,
    DateTime? deletedAt,
  }) async {
    final existing = await getTagByName(name);
    if (existing == null) {
      await _db.into(_db.tags).insert(TagsCompanion.insert(
            name: name.trim(),
            description: Value(description),
            isActivated: Value(isActivated),
            lastModified: Value(lastModified),
            deletedAt: Value(deletedAt),
          ));
    } else {
      await (_db.update(_db.tags)..where((t) => t.id.equals(existing.id)))
          .write(TagsCompanion(
        description: Value(description),
        isActivated: Value(isActivated),
        lastModified: Value(lastModified),
        deletedAt: Value(deletedAt),
      ));
    }
  }

  /// Set the sync tombstone for a tag by name (no-op if it doesn't exist).
  Future<void> tombstoneTagByName(String name, DateTime deletedAt) async {
    final existing = await getTagByName(name);
    if (existing == null) return;
    await (_db.update(_db.tags)..where((t) => t.id.equals(existing.id)))
        .write(TagsCompanion(
      deletedAt: Value(deletedAt),
      lastModified: Value(deletedAt),
    ));
  }

  /// Active (non-deleted, activated) tag names applied to a note.
  Future<List<String>> tagNamesForNote(int noteId) async {
    final tags = await getTagsForNote(noteId); // already filters isActivated
    return tags.where((t) => t.deletedAt == null).map((t) => t.name).toList();
  }

  /// Set-replace the note's tag refs to exactly [names], creating any missing
  /// tags by name. Membership has no sync metadata — the note body is the
  /// source of truth, so absence means removal.
  Future<void> setTagsForNote(int noteId, List<String> names) async {
    final desiredIds = <int>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final tag = await getTagByName(name) ??
          await createTag(TagsCompanion.insert(name: name));
      desiredIds.add(tag.id);
    }

    final currentRefs = await (_db.select(_db.noteTagRefs)
          ..where((r) => r.noteId.equals(noteId)))
        .get();
    final currentIds = currentRefs.map((r) => r.tagId).toSet();

    final toRemove = currentIds.difference(desiredIds);
    if (toRemove.isNotEmpty) {
      await (_db.delete(_db.noteTagRefs)
            ..where((r) => r.noteId.equals(noteId) & r.tagId.isIn(toRemove)))
          .go();
    }
    for (final tagId in desiredIds.difference(currentIds)) {
      await _db.into(_db.noteTagRefs).insertOnConflictUpdate(
            NoteTagRefsCompanion.insert(noteId: noteId, tagId: tagId),
          );
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/local/local_tag_repository_sync_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/local/local_tag_repository.dart test/core/data/local/local_tag_repository_sync_test.dart
git commit -m "feat(tags): add LocalTagRepository sync methods"
```

---

## Task 3: `TagSyncService.mergeDefinitions`

The testable definition-merge core: pull-side merge of remote tag definitions into local (per-name last-writer-wins + tombstones), returning the merged document to push.

**Files:**
- Create: `lib/core/data/sync/tag_sync_service.dart`
- Test: `test/core/data/sync/tag_sync_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/tag_sync_service.dart';

Map<String, dynamic> _tag(String name,
        {String? desc, bool active = true, required String lm, bool deleted = false}) =>
    {
      'name': name,
      'description': desc,
      'is_activated': active,
      'last_modified': lm,
      'deleted': deleted,
    };

void main() {
  late HmmDatabase db;
  late LocalTagRepository repo;
  late TagSyncService svc;

  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalTagRepository(db);
    svc = TagSyncService(repo);
  });
  tearDown(() => db.close());

  test('remote-newer definition is applied locally', () async {
    await repo.upsertTagByName('work',
        description: 'old', isActivated: true,
        lastModified: DateTime.utc(2026, 1, 1));
    await svc.mergeDefinitions(
      {'tags': [_tag('work', desc: 'new', lm: '2026-02-01T00:00:00Z')]},
      deviceId: 'dev', now: DateTime.utc(2026, 3, 1),
    );
    final tags = await repo.getTagsWithMeta();
    expect(tags.single.description, 'new');
  });

  test('local-newer definition is kept and pushed', () async {
    await repo.upsertTagByName('work',
        description: 'local', isActivated: true,
        lastModified: DateTime.utc(2026, 5, 1));
    final doc = await svc.mergeDefinitions(
      {'tags': [_tag('work', desc: 'remote', lm: '2026-01-01T00:00:00Z')]},
      deviceId: 'dev', now: DateTime.utc(2026, 6, 1),
    );
    expect((await repo.getTagsWithMeta()).single.description, 'local');
    final pushed = (doc['tags'] as List).single as Map;
    expect(pushed['description'], 'local');
  });

  test('remote tombstone propagates', () async {
    await repo.upsertTagByName('work',
        isActivated: true, lastModified: DateTime.utc(2026, 1, 1));
    await svc.mergeDefinitions(
      {'tags': [_tag('work', lm: '2026-02-01T00:00:00Z', deleted: true)]},
      deviceId: 'dev', now: DateTime.utc(2026, 3, 1),
    );
    expect((await repo.getTagsWithMeta()).single.deletedAt, isNotNull);
  });

  test('same name from two devices stays one tag', () async {
    await repo.upsertTagByName('work',
        isActivated: true, lastModified: DateTime.utc(2026, 1, 1));
    await svc.mergeDefinitions(
      {'tags': [_tag('WORK', lm: '2026-02-01T00:00:00Z')]},
      deviceId: 'dev', now: DateTime.utc(2026, 3, 1),
    );
    expect((await repo.getTagsWithMeta()).length, 1);
  });

  test('null/malformed remote doc does not throw and pushes local', () async {
    await repo.upsertTagByName('work',
        isActivated: true, lastModified: DateTime.utc(2026, 1, 1));
    final doc = await svc.mergeDefinitions(null,
        deviceId: 'dev', now: DateTime.utc(2026, 3, 1));
    expect((doc['tags'] as List).length, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/sync/tag_sync_service_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `TagSyncService`**

```dart
import '../local/local_tag_repository.dart';

/// Merges tag *definitions* for cloudStorage sync. Membership is handled
/// separately (it rides with the note sync — see SyncOrchestrator).
class TagSyncService {
  TagSyncService(this._repo);

  final LocalTagRepository _repo;

  String _norm(String s) => s.toLowerCase().trim();

  /// Apply remote-newer definitions to the local store, then return the merged
  /// document (every name at its winning version) to push back.
  Future<Map<String, dynamic>> mergeDefinitions(
    Map<String, dynamic>? remoteDoc, {
    required String deviceId,
    required DateTime now,
  }) async {
    final local = await _repo.getTagsWithMeta();
    final localByName = {for (final t in local) _norm(t.name): t};

    // Parse remote records defensively.
    final remote = <String, _RemoteTag>{};
    final rawTags = (remoteDoc?['tags'] as List?) ?? const [];
    for (final raw in rawTags) {
      if (raw is! Map) continue;
      final t = _RemoteTag.tryParse(raw.cast<String, dynamic>());
      if (t != null) remote[_norm(t.name)] = t;
    }

    // Apply remote-wins.
    for (final r in remote.values) {
      final l = localByName[_norm(r.name)];
      final isNewer = l == null || r.lastModified.isAfter(l.lastModified);
      if (!isNewer) continue;
      if (r.deleted) {
        if (l != null) await _repo.tombstoneTagByName(r.name, r.lastModified);
      } else {
        await _repo.upsertTagByName(
          r.name,
          description: r.description,
          isActivated: r.isActivated,
          lastModified: r.lastModified,
        );
      }
    }

    // Merged local state == every name at its winning version.
    final merged = await _repo.getTagsWithMeta();
    return {
      'version': 1,
      'device_id': deviceId,
      'generated_at': now.toUtc().toIso8601String(),
      'tags': [
        for (final t in merged)
          {
            'name': t.name,
            'description': t.description,
            'is_activated': t.isActivated,
            'last_modified': t.lastModified.toUtc().toIso8601String(),
            'deleted': t.deletedAt != null,
          },
      ],
    };
  }
}

class _RemoteTag {
  _RemoteTag({
    required this.name,
    required this.description,
    required this.isActivated,
    required this.lastModified,
    required this.deleted,
  });

  final String name;
  final String? description;
  final bool isActivated;
  final DateTime lastModified;
  final bool deleted;

  static _RemoteTag? tryParse(Map<String, dynamic> j) {
    final name = j['name'];
    final lm = DateTime.tryParse(j['last_modified'] as String? ?? '');
    if (name is! String || name.trim().isEmpty || lm == null) return null;
    return _RemoteTag(
      name: name,
      description: j['description'] as String?,
      isActivated: j['is_activated'] as bool? ?? true,
      lastModified: lm,
      deleted: j['deleted'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/sync/tag_sync_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/sync/tag_sync_service.dart test/core/data/sync/tag_sync_service_test.dart
git commit -m "feat(tags): add TagSyncService definition merge"
```

---

## Task 4: `CloudSyncProvider` tag hooks + OneDrive `tags.json`

**Files:**
- Modify: `lib/core/data/sync/cloud_sync_provider.dart` (default no-ops)
- Modify: `lib/core/data/sync/onedrive_sync_provider.dart` (delegate to graph)
- Modify: `lib/core/data/sync/onedrive_graph_client.dart` (`getTags`/`putTags`)
- Test: `test/core/data/sync/onedrive_tags_graph_test.dart`

- [ ] **Step 1: Add default no-ops to `CloudSyncProvider`**

In `lib/core/data/sync/cloud_sync_provider.dart`, immediately after the `pushSettings` default, add:

```dart
  /// Fetch the tag-definitions document (`tags.json`), or null if absent.
  /// No-op default so providers that don't sync tags stay transparent.
  Future<Map<String, dynamic>?> pullTags() async => null;

  /// Push the tag-definitions document. No-op default.
  Future<void> pushTags(Map<String, dynamic> doc) async {}
```

- [ ] **Step 2: Implement on `OneDriveSyncProvider`**

In `lib/core/data/sync/onedrive_sync_provider.dart`, after the `pushSettings` override, add:

```dart
  @override
  Future<Map<String, dynamic>?> pullTags() => _graph.getTags();

  @override
  Future<void> pushTags(Map<String, dynamic> doc) => _graph.putTags(doc);
```

- [ ] **Step 3: Add `getTags`/`putTags` to the graph client**

In `lib/core/data/sync/onedrive_graph_client.dart`, after `putSettings`, add (mirrors `getSettings`/`putSettings` exactly, with `tags.json`):

```dart
  /// Fetch the user's tag-definitions blob from `users/{sub}/tags.json`,
  /// or null when the file doesn't exist yet.
  Future<Map<String, dynamic>?> getTags() async {
    final path = await _userPath('tags.json', action: 'content');
    final resp = await _dio.get<Map<String, dynamic>>(path);
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data;
  }

  /// Push the user's tag-definitions blob to `users/{sub}/tags.json`.
  Future<void> putTags(Map<String, dynamic> body) async {
    final path = await _userPath('tags.json', action: 'content');
    final resp = await _dio.put(
      path,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }
```

- [ ] **Step 4: Write the graph round-trip test**

Create `test/core/data/sync/onedrive_tags_graph_test.dart`. The helper fakes
`_FakeOneDriveAuth` and `_NoopSecureStorage` already exist verbatim at the
bottom of `test/core/data/sync/onedrive_graph_client_path_test.dart` — **copy
those two classes verbatim** into the new file (they bypass real MS tokens /
Keychain), then add this `main()`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late _FakeOneDriveAuth auth;

  setUp(() {
    // validateStatus passthrough so 404 arrives as a Response (the client
    // branches on status manually), mirroring the path test.
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
    auth = _FakeOneDriveAuth();
  });

  OneDriveGraphClient client() =>
      OneDriveGraphClient(auth, () async => 'SUB-1', dio: dio);

  test('getTags returns the decoded body on 200', () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/tags.json:/content',
      (server) => server.reply(200, {
        'version': 1,
        'tags': [
          {'name': 'work', 'last_modified': '2026-05-01T00:00:00Z',
           'deleted': false}
        ],
      }),
    );
    final doc = await client().getTags();
    expect(doc, isNotNull);
    expect((doc!['tags'] as List).length, 1);
  });

  test('getTags returns null when tags.json is absent (404)', () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/tags.json:/content',
      (server) => server.reply(404, null),
    );
    expect(await client().getTags(), isNull);
  });

  test('putTags PUTs the document to the user-scoped tags.json', () async {
    Map<String, dynamic>? captured;
    adapter.onPut(
      '/me/drive/special/approot:/users/SUB-1/tags.json:/content',
      (server) => server.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'PUT' &&
          options.path.endsWith('tags.json:/content') &&
          options.data is Map) {
        captured = options.data as Map<String, dynamic>;
      }
      handler.next(options);
    }));

    await client().putTags({'version': 1, 'tags': const []});
    expect(captured, isNotNull);
    expect(captured!['version'], 1);
  });
}

// Paste _FakeOneDriveAuth and _NoopSecureStorage here, copied verbatim from
// test/core/data/sync/onedrive_graph_client_path_test.dart.
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/core/data/sync/onedrive_tags_graph_test.dart`
Expected: PASS

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib/core/data/sync`
Expected: No issues.

```bash
git add lib/core/data/sync/cloud_sync_provider.dart lib/core/data/sync/onedrive_sync_provider.dart lib/core/data/sync/onedrive_graph_client.dart test/core/data/sync/onedrive_tags_graph_test.dart
git commit -m "feat(tags): CloudSyncProvider pull/pushTags + OneDrive tags.json"
```

---

## Task 5: `SyncOrchestrator._syncTags` leg

Wire the definition leg into `syncNow()` after `_syncSettings`, non-fatal.

**Files:**
- Modify: `lib/core/data/sync/sync_orchestrator.dart`
- Test: `test/core/data/sync/sync_orchestrator_tags_test.dart`

- [ ] **Step 1: Add imports + a tag repo field**

At the top of `lib/core/data/sync/sync_orchestrator.dart`, add imports:

```dart
import '../local/local_tag_repository.dart';
import 'tag_sync_service.dart';
```

In the constructor initializer list (after `_onSettingsApplied = onSettingsApplied`), add:

```dart
        _tagRepo = LocalTagRepository(db),
```

And declare the field next to `_settingsRepo`:

```dart
  final LocalTagRepository _tagRepo;
```

- [ ] **Step 2: Call `_syncTags` after `_syncSettings`**

Find the `await _syncSettings(p, errors);` call in `syncNow()` and add immediately after it:

```dart
      // Tag definitions sync (independent of notes; non-fatal). Membership
      // rides with the note sync below.
      try {
        await _syncTags(p, errors);
      } catch (e) {
        errors.add(SyncError(
          recordType: 'tags',
          recordId: 'tags.json',
          message: 'Tag sync threw: $e',
        ));
      }
```

- [ ] **Step 3: Implement `_syncTags`**

Add this method to the `SyncOrchestrator` class (next to `_syncSettings`):

```dart
  Future<void> _syncTags(CloudSyncProvider p, List<SyncError> errors) async {
    Map<String, dynamic>? remote;
    try {
      remote = await p.pullTags();
    } catch (e) {
      errors.add(SyncError(
        recordType: 'tags',
        recordId: 'tags.json',
        message: 'Failed to pull tags: $e',
      ));
      return;
    }

    final deviceId = await _meta.getOrCreateDeviceId();
    final merged = await TagSyncService(_tagRepo)
        .mergeDefinitions(remote, deviceId: deviceId, now: DateTime.now());
    await p.pushTags(merged);
  }
```

- [ ] **Step 4: Write the test** (fake provider capturing the pushed doc)

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';

class _FakeProvider implements CloudSyncProvider {
  _FakeProvider(this.tagsToReturn);
  final Map<String, dynamic>? tagsToReturn;
  Map<String, dynamic>? pushedTags;
  bool throwOnPullTags = false;

  @override
  Future<Map<String, dynamic>?> pullTags() async {
    if (throwOnPullTags) throw Exception('boom');
    return tagsToReturn;
  }
  @override
  Future<void> pushTags(Map<String, dynamic> doc) async => pushedTags = doc;

  // Notes legs are no-ops for these tests (empty manifest).
  @override
  Future<SyncManifest?> pullManifest() async => SyncManifest(
        version: 1, generatedAt: DateTime.utc(2026), deviceId: 'remote',
        notes: const [], attachments: const []);
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> migrateLegacyIfNeeded() async {}
  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;
  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}
}

void main() {
  late HmmDatabase db;
  setUp(() => db = HmmDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  SyncOrchestrator orch(CloudSyncProvider p) => SyncOrchestrator(
        provider: p, db: db, meta: SyncMetaRepository(db));

  test('remote tag is merged locally and merged doc is pushed', () async {
    final provider = _FakeProvider({
      'tags': [
        {'name': 'work', 'description': 'd', 'is_activated': true,
         'last_modified': '2026-05-01T00:00:00Z', 'deleted': false}
      ]
    });
    await orch(provider).syncNow();

    final tags = await LocalTagRepository(db).getTagsWithMeta();
    expect(tags.map((t) => t.name), contains('work'));
    expect(provider.pushedTags, isNotNull);
  });

  test('a pullTags failure is non-fatal (sync still completes)', () async {
    final provider = _FakeProvider(null)..throwOnPullTags = true;
    final result = await orch(provider).syncNow();
    expect(result.errors.any((e) => e.recordType == 'tags'), isTrue);
  });
}
```

> If `SyncMetaRepository(db)` or `SyncManifest(...)`/`SyncResult` field names differ from the above, open those files and match the real constructors exactly (do not change orchestrator behavior). The fake must implement every `CloudSyncProvider` member — if the interface has members beyond those stubbed here, add them as throwing/no-op stubs and report the additions.

- [ ] **Step 5: Run the test**

Run: `flutter test test/core/data/sync/sync_orchestrator_tags_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/sync/sync_orchestrator.dart test/core/data/sync/sync_orchestrator_tags_test.dart
git commit -m "feat(tags): SyncOrchestrator _syncTags definition leg"
```

---

## Task 6: Embed membership in the note sync (push + pull hooks)

Carry each note's tag names in its synced body, and rebuild `NoteTagRefs` from the body on pull.

**Files:**
- Modify: `lib/core/data/sync/sync_orchestrator.dart` (`_collectChangedNotes` loop, `_noteRowToBlob`, `_applyPulledNote`)
- Test: `test/core/data/sync/note_tag_membership_sync_test.dart`

- [ ] **Step 1: Embed tag names when building a note blob**

In `_noteRowToBlob`, add a `tagNames` parameter and include it in the body. Change the signature and the `body` map:

```dart
  NoteBlob _noteRowToBlob(
    Note n,
    Map<int, String> catalogNames,
    Map<int, String> parentUuids,
    List<String> tagNames,
  ) {
    final updatedAt = (n.lastModifiedDate ?? n.createDate).toUtc();
    final uuid = n.uuid!;
    final catalogName =
        n.catalogId != null ? catalogNames[n.catalogId!] : null;
    final parentUuid =
        n.parentNoteId != null ? parentUuids[n.parentNoteId!] : null;
    return NoteBlob(
      id: uuid,
      body: {
        'uuid': uuid,
        'subject': n.subject,
        'content': n.content,
        'catalogName': catalogName,
        'parentNoteUuid': parentUuid,
        'description': n.description,
        'createDate': n.createDate.toUtc().toIso8601String(),
        'lastModifiedDate': updatedAt.toIso8601String(),
        'deletedAt': n.deletedAt?.toUtc().toIso8601String(),
        'tags': tagNames,
      },
      updatedAt: updatedAt,
      deleted: n.deletedAt != null,
    );
  }
```

- [ ] **Step 2: Resolve tag names in the `_collectChangedNotes` loop**

In `_collectChangedNotes`, change the final blob-building loop from:

```dart
    final blobs = <NoteBlob>[];
    for (final n in rows) {
      if (n.uuid == null) continue; // Shouldn't happen post-migration.
      blobs.add(_noteRowToBlob(n, catalogNames, parentUuids));
    }
    return blobs;
```

to:

```dart
    final blobs = <NoteBlob>[];
    for (final n in rows) {
      if (n.uuid == null) continue; // Shouldn't happen post-migration.
      final tagNames = await _tagRepo.tagNamesForNote(n.id);
      blobs.add(_noteRowToBlob(n, catalogNames, parentUuids, tagNames));
    }
    return blobs;
```

(`_tagRepo` was added in Task 5.)

- [ ] **Step 3: Rebuild membership when applying a pulled note**

In `_applyPulledNote`, after the block that adds to `pendingParents` (the end of the method), add:

```dart
    // Rebuild tag membership from the note body (set-replace). The body's
    // tag list is the complete current set; absence means removal.
    final tagNames = (body['tags'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    await _tagRepo.setTagsForNote(childId, tagNames);
```

- [ ] **Step 4: Write the round-trip test**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';

// Verifies the membership wire contract end-to-end at the repo level:
// names embedded in a body are reconstructed into NoteTagRefs via
// setTagsForNote, and dropping a name removes the ref.
void main() {
  late HmmDatabase db;
  late LocalTagRepository repo;
  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalTagRepository(db);
  });
  tearDown(() => db.close());

  test('note body tags expand into refs and set-replace on re-apply', () async {
    final authorId =
        await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'a'));
    final noteId = await db.into(db.notes).insert(
          NotesCompanion.insert(subject: 's', authorId: authorId),
        );

    // Simulate applying a pulled body {'tags': ['work','urgent']}.
    final body1 = {'tags': ['work', 'urgent']};
    await repo.setTagsForNote(
        noteId, (body1['tags'] as List).whereType<String>().toList());
    expect((await repo.tagNamesForNote(noteId)).toSet(), {'work', 'urgent'});

    // A later pull drops 'urgent'.
    final body2 = {'tags': ['work']};
    await repo.setTagsForNote(
        noteId, (body2['tags'] as List).whereType<String>().toList());
    expect((await repo.tagNamesForNote(noteId)).toSet(), {'work'});
  });
}
```

- [ ] **Step 5: Run the test + full suite + analyze**

Run: `flutter test test/core/data/sync/note_tag_membership_sync_test.dart`
Expected: PASS

Run: `flutter analyze && flutter test`
Expected: No analyzer issues; all tests pass. (If any pre-existing test outside the tag feature fails, report it but do not fix unrelated failures.)

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/sync/sync_orchestrator.dart test/core/data/sync/note_tag_membership_sync_test.dart
git commit -m "feat(tags): embed tag membership in note sync (push + pull)"
```

---

## Done

After Task 6: in cloudStorage mode, tag definitions sync via `tags.json` (per-name last-writer-wins + tombstones) and tag membership rides with the incremental note sync (no global association index). The local `Tags`/`NoteTagRefs` relational model and all queries are unchanged.

**Deferred (unchanged from the spec):** the `cloudApi` `ApiTagRepository` (ships with the API note/author/catalog repos), all tag UI, rename-tracking across devices, and tag UUIDs.
