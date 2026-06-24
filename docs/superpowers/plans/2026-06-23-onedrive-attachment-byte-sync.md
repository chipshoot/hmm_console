# OneDrive Graph Attachment Byte Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replicate attachment bytes (images, PDFs, voice) across devices in cloudStorage/OneDrive mode via Microsoft Graph, so a second device (iPad) shows and plays a note's media — like Apple Journal.

**Architecture:** Vault files are immutable and path-unique, so cross-device byte sync is pure set-difference by path. A new orchestrator `_reconcileVault()` pass (after the metadata sync) diffs `collectReferencedVaultPaths(db)` against a Graph listing of the remote vault, pushing local-only referenced files and eagerly pulling remote-only referenced files. New byte methods on the `CloudSyncProvider` contract (safe no-op defaults) keep `local`/api modes untouched; only OneDrive implements them, against `approot/users/{sub}/vault/{path}`.

**Tech Stack:** Flutter, Dio over Graph REST, `http_mock_adapter` (tests), Drift, Riverpod. Client-only — no backend change.

**Repo:** `/Users/fchy/projects/hmm_console`, branch off `main` (e.g. `feat/onedrive-byte-sync`).

---

## File Structure
- Modify: `lib/core/data/sync/onedrive_graph_client.dart` — `putAttachment`/`getAttachment`/`listAttachments`/`deleteAttachment`
- Modify: `lib/core/data/sync/cloud_sync_provider.dart` — `supportsAttachments` + 3 byte methods (defaults)
- Modify: `lib/core/data/sync/onedrive_sync_provider.dart` — implement the byte methods
- Modify: `lib/core/data/sync/sync_orchestrator.dart` — inject vault store, `_reconcileVault()`, wire into `syncNow()`, builder provider
- Tests: `test/core/data/sync/onedrive_graph_attachment_test.dart` (new), `test/core/data/sync/sync_orchestrator_vault_reconcile_test.dart` (new)

---

## Task 1: Graph client — `putAttachment` / `getAttachment`

**Files:**
- Modify: `lib/core/data/sync/onedrive_graph_client.dart`
- Test: `test/core/data/sync/onedrive_graph_attachment_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/core/data/sync/onedrive_graph_attachment_test.dart` (mirror `onedrive_graph_client_path_test.dart`'s harness: `Dio(BaseOptions(validateStatus: (_) => true))` + `DioAdapter` + a `_FakeOneDriveAuth`). Copy the `_FakeOneDriveAuth` class from that file verbatim.

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

// _FakeOneDriveAuth is defined at the bottom of this file (copied from
// onedrive_graph_client_path_test.dart — see the note after this block).

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late _FakeOneDriveAuth auth;

  setUp(() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
    auth = _FakeOneDriveAuth();
  });

  OneDriveGraphClient client({String? sub = 'SUB-1'}) =>
      OneDriveGraphClient(auth, () async => sub, dio: dio);

  test('putAttachment PUTs bytes to the scoped vault content path', () async {
    var captured = false;
    adapter.onPut(
      '/me/drive/special/approot:/users/SUB-1/vault/attachments/note-1/a.jpg:/content',
      (server) {
        captured = true;
        server.reply(201, {'id': 'x'});
      },
      data: Uint8List.fromList([1, 2, 3]),
    );
    await client().putAttachment(
        'attachments/note-1/a.jpg', Uint8List.fromList([1, 2, 3]));
    expect(captured, isTrue);
  });

  test('getAttachment returns bytes on 200', () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/vault/attachments/note-1/a.jpg:/content',
      (server) => server.reply(200, [9, 9, 9]),
    );
    final bytes = await client().getAttachment('attachments/note-1/a.jpg');
    expect(bytes, isNotNull);
    expect(bytes!.toList(), [9, 9, 9]);
  });

  test('getAttachment returns null on 404', () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/vault/missing.jpg:/content',
      (server) => server.reply(404, null),
    );
    expect(await client().getAttachment('missing.jpg'), isNull);
  });
}
```

NOTE: rather than a shared-helpers import, copy the `_FakeOneDriveAuth` fake directly into this test file (it's a small class — open `test/core/data/sync/onedrive_graph_client_path_test.dart`, copy its `_FakeOneDriveAuth` definition to the bottom of this new file, and delete the helpers import line). Do not create a helpers file.

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/sync/onedrive_graph_attachment_test.dart`
Expected: FAIL — `putAttachment`/`getAttachment` don't exist.

- [ ] **Step 3: Implement** — in `lib/core/data/sync/onedrive_graph_client.dart`, replace the Phase-11.5 removal comment block (the `// Attachment-byte uploads / downloads were removed in Phase 11.5.` comment) with:

```dart
  // ---- Attachments (vault bytes) ----
  //
  // Re-introduced for cloudStorage byte sync: the orchestrator's
  // _reconcileVault pushes/pulls individual vault files here so media
  // replicates across devices via Graph (works on iOS, unlike the
  // OS-folder-sync assumption Phase 11.5 made). Paths are immutable
  // (UUID in the name), so a PUT is always an idempotent overwrite.

  Future<void> putAttachment(String relativePath, Uint8List bytes) async {
    final path = await _userPath('vault/$relativePath', action: 'content');
    final resp = await _dio.put(
      path,
      data: Stream.fromIterable([bytes]),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {Headers.contentLengthHeader: bytes.length},
      ),
    );
    _throwIfBad(resp);
  }

  Future<Uint8List?> getAttachment(String relativePath) async {
    final path = await _userPath('vault/$relativePath', action: 'content');
    final resp = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data == null ? null : Uint8List.fromList(resp.data!);
  }
```

(If `Uint8List` isn't imported, add `import 'dart:typed_data';` at the top.)

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/core/data/sync/onedrive_graph_attachment_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/core/data/sync/onedrive_graph_client.dart
git add lib/core/data/sync/onedrive_graph_client.dart test/core/data/sync/onedrive_graph_attachment_test.dart
git commit -m "feat(sync): Graph put/get attachment bytes (scoped vault path)"
```

Expected analyze: No issues.

## Task 2: Graph client — recursive `listAttachments` + `deleteAttachment`

`listAttachments` enumerates the remote vault tree (folders nested as `vault/attachments/note-N/`) and returns vault-relative file paths. Uses Graph `:/children` listings, recursing into folder children and following `@odata.nextLink` paging.

**Files:**
- Modify: `lib/core/data/sync/onedrive_graph_client.dart`
- Test: `test/core/data/sync/onedrive_graph_attachment_test.dart` (extend)

- [ ] **Step 1: Write the failing test** — append to the test file. A two-level tree: `vault/` has a folder `attachments`; `vault/attachments` has a folder `note-1`; `vault/attachments/note-1` has a file `a.jpg`. (Graph `children` items carry a `folder` object for folders, a `file` object for files, and a `name`.)

```dart
  test('listAttachments returns vault-relative file paths recursively',
      () async {
    void folder(String atPath, List<Map<String, dynamic>> children) {
      adapter.onGet(
        '/me/drive/special/approot:/users/SUB-1/$atPath:/children',
        (server) => server.reply(200, {'value': children}),
      );
    }

    folder('vault', [
      {'name': 'attachments', 'folder': {'childCount': 1}},
    ]);
    folder('vault/attachments', [
      {'name': 'note-1', 'folder': {'childCount': 1}},
    ]);
    folder('vault/attachments/note-1', [
      {'name': 'a.jpg', 'file': {'mimeType': 'image/jpeg'}},
    ]);

    final paths = await client().listAttachments();
    expect(paths, {'attachments/note-1/a.jpg'});
  });

  test('listAttachments returns empty set when the vault folder is absent',
      () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/vault:/children',
      (server) => server.reply(404, null),
    );
    expect(await client().listAttachments(), isEmpty);
  });
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/sync/onedrive_graph_attachment_test.dart`
Expected: FAIL — `listAttachments` doesn't exist.

- [ ] **Step 3: Implement** — add to `onedrive_graph_client.dart`, after `getAttachment`:

```dart
  /// Vault-relative file paths currently present under the remote
  /// `vault/` subtree. Recurses folders; follows @odata.nextLink paging.
  /// Returns empty when the vault folder doesn't exist yet (first sync).
  Future<Set<String>> listAttachments() async {
    final out = <String>{};
    await _listInto(out, 'vault', '');
    return out;
  }

  Future<void> _listInto(
      Set<String> out, String graphRel, String vaultRel) async {
    var url = await _userPath(graphRel, action: 'children');
    while (true) {
      final resp = await _dio.get<Map<String, dynamic>>(url);
      if (resp.statusCode == 404) return; // folder absent → nothing here
      _throwIfBad(resp);
      final value = (resp.data?['value'] as List?) ?? const [];
      for (final raw in value) {
        final item = raw as Map<String, dynamic>;
        final name = item['name'] as String;
        final childVaultRel = vaultRel.isEmpty ? name : '$vaultRel/$name';
        if (item['folder'] != null) {
          await _listInto(out, '$graphRel/$name', childVaultRel);
        } else {
          out.add(childVaultRel);
        }
      }
      final next = resp.data?['@odata.nextLink'] as String?;
      if (next == null) break;
      url = next; // absolute follow-up URL from Graph
    }
  }

  Future<void> deleteAttachment(String relativePath) async {
    final path = await _userPath('vault/$relativePath');
    final resp = await _dio.delete<void>(path);
    if (resp.statusCode == 404) return; // already gone
    _throwIfBad(resp);
  }
```

NOTE: `deleteAttachment` is added for a future remote-GC phase and is intentionally NOT called anywhere in this plan.

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/core/data/sync/onedrive_graph_attachment_test.dart`
Expected: PASS (all attachment tests).

- [ ] **Step 5: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/core/data/sync/onedrive_graph_client.dart
git add lib/core/data/sync/onedrive_graph_client.dart test/core/data/sync/onedrive_graph_attachment_test.dart
git commit -m "feat(sync): Graph recursive listAttachments + deleteAttachment"
```

Expected analyze: No issues.

## Task 3: Contract methods + OneDrive provider impl

**Files:**
- Modify: `lib/core/data/sync/cloud_sync_provider.dart`
- Modify: `lib/core/data/sync/onedrive_sync_provider.dart`
- Test: `test/core/data/sync/onedrive_sync_provider_attachment_test.dart` (new)

- [ ] **Step 1: Add the contract methods** — in `lib/core/data/sync/cloud_sync_provider.dart`, replace the Phase-11.5 removal comment block at the end of the class with:

```dart
  // ---- Attachments (vault bytes) ----
  //
  // Re-introduced for cloudStorage byte sync. Default impls make this a
  // no-op so providers that don't move bytes (local-backed, or the
  // cloudApi ApiSyncProvider for now) stay transparent — the
  // orchestrator only runs the vault-reconcile pass when
  // [supportsAttachments] is true.

  /// Whether this provider transfers attachment bytes.
  bool get supportsAttachments => false;

  /// Upload raw bytes for a vault-relative [path]. Overwrite-safe.
  Future<void> pushAttachment(String path, Uint8List bytes) async {}

  /// Download raw bytes for a vault-relative [path], or null if absent.
  Future<Uint8List?> pullAttachment(String path) async => null;

  /// The set of vault-relative paths present in the remote vault.
  Future<Set<String>> listAttachmentPaths() async => const {};
```

Add `import 'dart:typed_data';` at the top of the file.

- [ ] **Step 2: Write the failing provider test** — create `test/core/data/sync/onedrive_sync_provider_attachment_test.dart`. Build a real `OneDriveSyncProvider` wrapping a `OneDriveGraphClient` with a mocked Dio (same harness as Task 1), assert the provider delegates:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:hmm_console/core/data/sync/onedrive_sync_provider.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

// Copy _FakeOneDriveAuth + a _FakeTokenService stub from the existing
// onedrive_sync_provider tests (or onedrive_graph_client_path_test).

void main() {
  test('supportsAttachments is true and pull delegates to Graph', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/vault/x.m4a:/content',
      (server) => server.reply(200, [7, 7]),
    );
    final graph = OneDriveGraphClient(_FakeOneDriveAuth(), () async => 'SUB-1',
        dio: dio);
    final provider =
        OneDriveSyncProvider(_FakeOneDriveAuth(), graph, _FakeTokenService());

    expect(provider.supportsAttachments, isTrue);
    final bytes = await provider.pullAttachment('x.m4a');
    expect(bytes!.toList(), [7, 7]);
  });
}
```

NOTE: copy the `_FakeOneDriveAuth` and `_FakeTokenService` fakes from the existing `test/core/data/sync/` OneDrive provider test (whichever constructs `OneDriveSyncProvider`) so the constructor args match exactly. Do not invent their shapes.

- [ ] **Step 3: Run it to verify it fails** — Run: `flutter test test/core/data/sync/onedrive_sync_provider_attachment_test.dart`
Expected: FAIL — `supportsAttachments`/`pullAttachment` not overridden (inherited defaults: false / null).

- [ ] **Step 4: Implement the provider overrides** — in `lib/core/data/sync/onedrive_sync_provider.dart`, add (near the other `@override`s; add `import 'dart:typed_data';` if needed):

```dart
  @override
  bool get supportsAttachments => true;

  @override
  Future<void> pushAttachment(String path, Uint8List bytes) =>
      _graph.putAttachment(path, bytes);

  @override
  Future<Uint8List?> pullAttachment(String path) => _graph.getAttachment(path);

  @override
  Future<Set<String>> listAttachmentPaths() => _graph.listAttachments();
```

- [ ] **Step 5: Run it to verify it passes** — Run: `flutter test test/core/data/sync/onedrive_sync_provider_attachment_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/core/data/sync/cloud_sync_provider.dart lib/core/data/sync/onedrive_sync_provider.dart
git add lib/core/data/sync/cloud_sync_provider.dart lib/core/data/sync/onedrive_sync_provider.dart test/core/data/sync/onedrive_sync_provider_attachment_test.dart
git commit -m "feat(sync): attachment byte methods on contract + OneDrive provider"
```

Expected analyze: No issues.

## Task 4: Orchestrator `_reconcileVault` + wiring

**Files:**
- Modify: `lib/core/data/sync/sync_orchestrator.dart`
- Test: `test/core/data/sync/sync_orchestrator_vault_reconcile_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/core/data/sync/sync_orchestrator_vault_reconcile_test.dart`. Use an in-memory db (seed a note whose `attachments` JSON references a vault path), an in-memory `IVaultStore` fake, and a fake `CloudSyncProvider` whose remote is a `Map<String, Uint8List>`. Drive `syncNow()` and assert push/pull.

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _attJson(String path) =>
    '{"images":[],"files":[{"kind":"vault","path":"$path",'
    '"contentType":"audio/mp4","byteSize":3}]}';

class _MemVault implements IVaultStore {
  final Map<String, Uint8List> files = {};
  @override
  Future<void> putBytes(String relativePath, Uint8List bytes,
      {String? contentType}) async => files[relativePath] = bytes;
  @override
  Future<Uint8List> getBytes(String relativePath) async => files[relativePath]!;
  @override
  Future<bool> exists(String relativePath) async =>
      files.containsKey(relativePath);
  @override
  Future<void> delete(String relativePath) async => files.remove(relativePath);
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

class _MemProvider extends CloudSyncProvider {
  final Map<String, Uint8List> remote = {};
  bool throwOnPush = false;
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
  Future<void> pushManifest(SyncManifest m) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}
  @override
  bool get supportsAttachments => true;
  @override
  Future<Set<String>> listAttachmentPaths() async => remote.keys.toSet();
  @override
  Future<void> pushAttachment(String path, Uint8List bytes) async {
    if (throwOnPush) throw Exception('boom');
    remote[path] = bytes;
  }
  @override
  Future<Uint8List?> pullAttachment(String path) async => remote[path];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _MemVault vault;
  late _MemProvider provider;
  late SyncOrchestrator orchestrator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    vault = _MemVault();
    provider = _MemProvider();
    orchestrator = SyncOrchestrator(
      provider: provider, db: db, meta: SyncMetaRepository(),
      vaultStore: () async => vault,
    );
  });

  tearDown(() async => db.close());

  Future<void> seedNote(String vaultPath) async {
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 's', authorId: 1, uuid: const Value('n1'),
          attachments: Value(_attJson(vaultPath)),
        ));
  }

  test('pushes a local-only referenced file to remote', () async {
    await seedNote('attachments/note-1/a.m4a');
    vault.files['attachments/note-1/a.m4a'] = Uint8List.fromList([1, 2, 3]);

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    expect(provider.remote['attachments/note-1/a.m4a']!.toList(), [1, 2, 3]);
    expect(r.pushedAttachments, 1);
  });

  test('eagerly pulls a remote-only referenced file into the vault', () async {
    await seedNote('attachments/note-1/b.m4a');
    provider.remote['attachments/note-1/b.m4a'] = Uint8List.fromList([4, 5]);

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    expect(vault.files['attachments/note-1/b.m4a']!.toList(), [4, 5]);
    expect(r.pulledAttachments, 1);
  });

  test('a push failure is collected, sync still succeeds', () async {
    await seedNote('attachments/note-1/a.m4a');
    vault.files['attachments/note-1/a.m4a'] = Uint8List.fromList([1]);
    provider.throwOnPush = true;

    final r = await orchestrator.syncNow();
    expect(r.errors.where((e) => e.recordType == 'attachment'), isNotEmpty);
    expect(provider.remote, isEmpty);
  });

  test('idempotent: a second sync pushes/pulls nothing new', () async {
    await seedNote('attachments/note-1/a.m4a');
    vault.files['attachments/note-1/a.m4a'] = Uint8List.fromList([1]);
    await orchestrator.syncNow();
    final r2 = await orchestrator.syncNow();
    expect(r2.pushedAttachments, 0);
    expect(r2.pulledAttachments, 0);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/sync/sync_orchestrator_vault_reconcile_test.dart`
Expected: FAIL — `SyncOrchestrator` has no `vaultStore` param / no reconcile.

- [ ] **Step 3: Add the vault-store dependency** — in `lib/core/data/sync/sync_orchestrator.dart`:

Add an import: `import '../vault/vault_store.dart';` and `import '../vault/vault_gc.dart';` (for `collectReferencedVaultPaths`) and `import 'dart:typed_data';` if not present.

In the constructor (`SyncOrchestrator({required this.provider, required HmmDatabase db, required SyncMetaRepository meta, ...})`), add a required named param `required Future<IVaultStore> Function() vaultStore,` and store it: `_vaultStore = vaultStore` with a field `final Future<IVaultStore> Function() _vaultStore;`.

- [ ] **Step 4: Add `_reconcileVault`** — add this method to the orchestrator:

```dart
  /// Push local-only referenced vault files up and eagerly pull
  /// remote-only referenced files down. Only runs for providers that
  /// move bytes (cloudStorage/OneDrive). Per-file failures are collected,
  /// never fatal. Returns (pushed, pulled).
  Future<(int, int)> _reconcileVault(List<SyncError> errors) async {
    if (!provider.supportsAttachments) return (0, 0);
    final vault = await _vaultStore();
    final referenced = await collectReferencedVaultPaths(_db);
    final remote = await provider.listAttachmentPaths();
    var pushed = 0, pulled = 0;
    for (final path in referenced) {
      final localHas = await vault.exists(path);
      final remoteHas = remote.contains(path);
      if (localHas && !remoteHas) {
        try {
          await provider.pushAttachment(path, await vault.getBytes(path));
          pushed++;
        } catch (e) {
          errors.add(SyncError(
              recordType: 'attachment', recordId: path,
              message: 'push failed: $e'));
        }
      } else if (!localHas && remoteHas) {
        try {
          final bytes = await provider.pullAttachment(path);
          if (bytes != null) {
            await vault.putBytes(path, bytes,
                contentType: _contentTypeForPath(path));
            pulled++;
          }
        } catch (e) {
          errors.add(SyncError(
              recordType: 'attachment', recordId: path,
              message: 'pull failed: $e'));
        }
      }
    }
    return (pushed, pulled);
  }

  static String? _contentTypeForPath(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'm4a' => 'audio/mp4',
      _ => null,
    };
  }
```

- [ ] **Step 5: Call it in `syncNow` and surface counts** — in `syncNow()`, after the note metadata push/pull pass and before building the final `SyncResult` (the success-path `return SyncResult(...)`), add:

```dart
    final (pushedAtt, pulledAtt) = await _reconcileVault(errors);
```

Then in the final `SyncResult(...)` constructor in the success path, set `pushedAttachments: pushedAtt` and `pulledAttachments: pulledAtt` (they're currently hardcoded `0`). If the local variable names in the existing success-path SyncResult differ, wire `pushedAtt`/`pulledAtt` into those two fields.

- [ ] **Step 6: Wire the builder provider** — in the `syncOrchestratorProvider` (bottom of `sync_orchestrator.dart`), add to the `SyncOrchestrator(...)` construction:

```dart
    vaultStore: () => ref.read(vaultStoreProvider.future),
```

Add the import `import '../attachments/attachment_providers.dart';` (for `vaultStoreProvider`).

- [ ] **Step 7: Run it to verify it passes** — Run: `flutter test test/core/data/sync/sync_orchestrator_vault_reconcile_test.dart`
Expected: PASS (all four).

- [ ] **Step 8: Analyze + sync regression** — Run: `flutter analyze lib/core/data/sync/sync_orchestrator.dart` and `flutter test test/core/data/sync/`
Expected: No issues; all pass. (Other orchestrator tests construct `SyncOrchestrator(...)` without `vaultStore` — they will now fail to compile. Add `vaultStore: () async => _NoopVault()` to each, where `_NoopVault` is a minimal `IVaultStore` whose `exists` returns false and other methods no-op/throw `UnimplementedError`. Identify them from the analyzer/compile errors and fix each. List of likely files: `sync_orchestrator_note_date_test.dart`, `sync_orchestrator_location_test.dart`, `sync_orchestrator_attachments_test.dart`, `sync_orchestrator_missing_from_remote_test.dart`, `sync_orchestrator_tags_test.dart`, `sync_orchestrator_settings_test.dart`, `sync_controller_test.dart`, `sync_controller_restart_test.dart`. Their fake providers default `supportsAttachments` to false (they extend/implement `CloudSyncProvider` without overriding it), so `_reconcileVault` early-returns and the noop vault is never used.)

- [ ] **Step 9: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/sync/sync_orchestrator.dart test/core/data/sync/
git commit -m "feat(sync): orchestrator vault byte reconcile pass (push + eager pull)"
```

## Task 5: Two-device round-trip test

Proves the end-to-end goal: media attached on device A appears (bytes resolvable) on device B.

**Files:**
- Test: `test/core/data/sync/vault_two_device_roundtrip_test.dart` (new)

- [ ] **Step 1: Write the test** — create `test/core/data/sync/vault_two_device_roundtrip_test.dart`. Two dbs + two `_MemVault`s sharing one `_MemProvider` whose `remote` map AND a shared note-body map simulate the cloud. Simplest faithful version: reuse the `_MemVault` + a provider that also stores note bodies/manifest in memory so device B pulls the note (with its attachments JSON) and then the vault reconcile pulls the bytes.

```dart
// Construct two orchestrators over a shared in-memory "cloud":
//   - shared Map<String, Map<String,dynamic>> noteBodies
//   - shared Map<String, Uint8List> remoteVault
//   - shared SyncManifest holder
// Device A: seed note + vault bytes locally → syncNow() → cloud has body + bytes.
// Device B: empty db + empty vault → syncNow() → B's db has the note AND
//   B's vault has the bytes; assert:
//     expect(bVault.files['attachments/note-1/a.m4a'], isNotNull);
//     final row = await bDb.select(bDb.notes).getSingle();
//     expect(NoteAttachmentsCodec.decode(row.attachments).files, isNotEmpty);
```

Build the shared-cloud `_MemProvider` so `pushNoteBody`/`pullNoteBody`/`pushManifest`/`pullManifest` read/write the shared maps (so B actually pulls A's note), and `pushAttachment`/`pullAttachment`/`listAttachmentPaths` read/write the shared `remoteVault`. Model it on the existing `sync_orchestrator_attachments_test.dart` `_FakeProvider` (which already round-trips note bodies) plus the `_MemProvider` vault behavior from Task 4. Each device gets its own `SyncMetaRepository` (distinct `SharedPreferences` device id) — call `SharedPreferences.setMockInitialValues({})` once in setup; the orchestrators get distinct device ids via the meta repo automatically.

- [ ] **Step 2: Run it** — Run: `flutter test test/core/data/sync/vault_two_device_roundtrip_test.dart`
Expected: PASS — B's vault has the bytes and B's note row decodes a non-empty `files` list.

- [ ] **Step 3: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add test/core/data/sync/vault_two_device_roundtrip_test.dart
git commit -m "test(sync): two-device vault byte round-trip"
```

## Task 6: Full verification

- [ ] **Step 1: Analyze** — Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Full test suite** — Run: `flutter test`
Expected: All pass.

- [ ] **Step 3: Manual smoke (optional, two real devices in cloudStorage/OneDrive mode)** — On device A (signed into OneDrive, cloudStorage mode): create a note, attach a photo + record a voice note, Sync Now. On device B (same account, cloudStorage/OneDrive): Sync Now → the note appears with its image and audio cards, and both open/play (bytes pulled). Remove the attachment on A + Sync; on B after Sync the card is gone (ref removed) — note the remote OneDrive file remains (orphan; remote GC is out of scope).

---

## Notes on scope / sequencing

- **Client-only.** No backend change — OneDrive is the cloud; bytes move via Graph.
- **Modes:** only `cloudStorage`/OneDrive runs the reconcile (`supportsAttachments`); `local` never syncs; `cloudApi`'s `ApiSyncProvider` keeps the default `supportsAttachments == false` and is unaffected.
- **Out of scope:** remote orphan GC (deleteAttachment added but uncalled), lazy download (chose eager), other providers (contract ready), progress UI.
```
