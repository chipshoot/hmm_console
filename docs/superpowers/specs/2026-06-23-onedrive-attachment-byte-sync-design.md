# OneDrive Graph Attachment Byte Sync (cloudStorage) — Design

**Date:** 2026-06-23
**Status:** Approved (brainstorm) — pending implementation plan
**Repo:** `hmm_console` (Flutter client) only. No backend change — OneDrive *is* the cloud here; bytes move via Microsoft Graph.

## Goal

Make attachment **bytes** (images, PDFs, voice recordings) replicate across devices in `cloudStorage`/OneDrive mode via the Microsoft Graph API, so a second device (e.g. an iPad) shows and plays a note's media — like Apple Journal. This re-introduces the in-app byte transport that Phase 11.5 removed, but done through Graph (not a desktop OneDrive folder-sync client), so it works uniformly on iOS / iPadOS / Android / desktop.

## Background: why this is needed

Today (`cloudStorage`/OneDrive):
- **Metadata + attachment refs** sync via Graph (note bodies + manifest → `approot/users/{sub}/…`). Phase 3a wired the `attachments` JSON column into the synced note body, so refs propagate.
- **Bytes do not.** Phase 11.5 removed byte transport from the sync layer on the assumption that "the vault root sits inside the user's OneDrive folder; the OS-level sync client moves the bytes." That holds on Windows/macOS (real OneDrive folder mirroring) but **not on iOS/iPadOS**, which has no background folder-mirroring into an app sandbox. Result on an iPad: the note and its attachment cards appear, but `resolve()` finds no local bytes → images error, audio/PDF show "not available."

This design moves the bytes through Graph so they actually arrive.

## Core model — immutable, content-addressed, set-difference

Vault files are **write-once and path-unique**: every attachment path embeds a fresh UUID (`attachments/note-N/<uuid>.<ext>`); an edit creates a new path, never mutating an existing file. Therefore cross-device byte sync needs **no hashing, no conflict resolution, no last-writer-wins** — it is pure set reconciliation by path:

- **Reachable set** = `collectReferencedVaultPaths(db)` (the existing GC helper) — every vault path referenced by the notes currently in the local DB. Run *after* the metadata pull, so it already includes refs that arrived from other devices.
- **Remote layout** = `approot/users/{sub}/vault/{relativePath}` — mirrors the local vault, under the same per-user-scoped Graph subtree the note blobs already use (`OneDriveGraphClient._userPath`).
- **Push** = reachable paths present in the local vault but absent remotely → upload.
- **Pull (eager)** = reachable paths absent locally but present remotely → download into the local vault.

Eager pull (locked in brainstorm): the device downloads *all* referenced bytes it's missing during sync, so media is present offline and "just appears," matching Journal.

## Components

### 1. `CloudSyncProvider` contract (`lib/core/data/sync/cloud_sync_provider.dart`)

Add provider-agnostic byte methods with safe defaults (providers that don't support attachments inherit no-ops, so `local`/api paths are unaffected):

```dart
/// Whether this provider transfers attachment bytes (cloudStorage→OneDrive: true).
bool get supportsAttachments => false;

/// Upload raw bytes for a vault-relative [path]. Overwrites are fine (paths are
/// immutable, so an overwrite is byte-identical).
Future<void> pushAttachment(String path, Uint8List bytes) async {}

/// Download raw bytes for a vault-relative [path], or null if not present remotely.
Future<Uint8List?> pullAttachment(String path) async => null;

/// The set of vault-relative paths currently present in the remote vault.
Future<Set<String>> listAttachmentPaths() async => const {};
```

### 2. `OneDriveGraphClient` (`lib/core/data/sync/onedrive_graph_client.dart`)

Re-add the Phase-11.5-removed helpers, scoped under `…/users/{sub}/vault/`:

- `Future<void> putAttachment(String path, Uint8List bytes)` — `PUT …/vault/{path}:/content` (binary body; content-type `application/octet-stream`).
- `Future<Uint8List?> getAttachment(String path)` — `GET …/vault/{path}:/content`; 404 → null.
- `Future<Set<String>> listAttachments()` — enumerate `…/vault/` children recursively (Graph `children` listing with paging via `@odata.nextLink`), returning vault-relative paths.
- `Future<void> deleteAttachment(String path)` — `DELETE …/vault/{path}` (added for completeness/future remote-GC; **not called by the orchestrator in this phase**).

Reuse the existing `_userPath` scoping, Dio instance, and `OneDriveGraphException` (404 handling).

### 3. `OneDriveSyncProvider` (`lib/core/data/sync/onedrive_sync_provider.dart`)

- `bool get supportsAttachments => true;`
- Implement `pushAttachment` / `pullAttachment` / `listAttachmentPaths` by delegating to the new Graph client methods.

### 4. Orchestrator (`lib/core/data/sync/sync_orchestrator.dart`)

- **Inject an `IVaultStore`.** `SyncOrchestrator` currently takes `{provider, db, meta}`; add a `required IVaultStore vault`. The provider that builds the orchestrator resolves it from `vaultStoreProvider.future`.
- **New `_reconcileVault()`** run inside `syncNow()` **after** the note metadata push/pull pass, **only** when `provider.supportsAttachments`:

  ```
  final referenced = await collectReferencedVaultPaths(_db);   // post-pull reachable set
  final remote = await provider.listAttachmentPaths();
  var pushed = 0, pulled = 0;
  for (final path in referenced) {
    final localHas = await _vault.exists(path);
    final remoteHas = remote.contains(path);
    if (localHas && !remoteHas) {
      try { await provider.pushAttachment(path, await _vault.getBytes(path)); pushed++; }
      catch (e) { errors.add(SyncError(...'push attachment $path'...)); }
    } else if (!localHas && remoteHas) {
      try { final b = await provider.pullAttachment(path);
            if (b != null) { await _vault.putBytes(path, b, contentType: _ctFor(path)); pulled++; } }
      catch (e) { errors.add(SyncError(...'pull attachment $path'...)); }
    }
  }
  ```

- Populate the existing `SyncResult.pushedAttachments` / `pulledAttachments` (currently always 0).
- Content-type for `putBytes` on pull: derive from the path extension (`.jpg`→`image/jpeg`, `.pdf`→`application/pdf`, `.m4a`→`audio/mp4`, …) — a small `_contentTypeForPath` helper; the byte content is what matters, the stored content-type is metadata.

### 5. Failure handling

Per-file isolation: a push/pull failure for one attachment is collected into `SyncResult.errors` and **does not abort** the sync (matches the orchestrator's existing note-level error collection). A referenced path missing from *both* local and remote is skipped (not fatal — a transient state that resolves once the owning device pushes). Reconciliation is **idempotent**: a re-run re-attempts only still-missing files.

## Remote cleanup — deferred (out of scope this phase)

When an attachment is removed or a note deleted, local GC reclaims local bytes; on other devices the updated note arrives with the ref gone, and their local GC reclaims too. The **remote** `…/vault/{path}` file lingers as an orphan. This phase does **not** delete remote bytes: remote GC is risky (a device syncing with stale metadata could delete a file another device still references → data loss) and orphans are harmless beyond storage. `deleteAttachment` is added to the Graph client for a future conservative remote-GC phase but is not called here.

## Scope notes

- **cloudStorage / OneDrive only.** The contract methods are provider-agnostic so Drive/Dropbox/iCloud can implement later; only OneDrive is wired now. `local` mode never syncs; `cloudApi` has its own (future) `ApiVaultStore` byte path and is unaffected (`supportsAttachments` stays false on `ApiSyncProvider`).
- **No backend change.** This is entirely client ↔ OneDrive via Graph.
- **Bytes are AOT-safe / platform-uniform** — pure Dart + Dio over Graph REST; works on every platform including iPad.

## Testing

- **Graph client** (mocked Dio): `putAttachment`/`getAttachment` hit `…/users/{sub}/vault/{path}:/content`, round-trip bytes, `getAttachment` 404 → null; `listAttachments` parses children + follows `@odata.nextLink` paging → vault-relative path set.
- **Orchestrator `_reconcileVault`** (fake `CloudSyncProvider` with in-memory remote map + in-memory `IVaultStore` + in-memory db):
  - local-only referenced file → pushed (remote gains it; `pushedAttachments == 1`).
  - remote-only referenced file → eagerly pulled (local vault gains it; `pulledAttachments == 1`).
  - unreferenced local file → neither pushed nor pulled.
  - a `pushAttachment`/`pullAttachment` that throws → error collected, sync still succeeds, other files still processed.
  - idempotent: a second `syncNow` with everything in place pushes/pulls 0.
  - `supportsAttachments == false` provider → `_reconcileVault` is skipped entirely.
- **Two-device round-trip** (two dbs + two vaults sharing one fake remote): attach media on "A" + sync; sync "B"; assert B's vault now has the bytes and the note's ref resolves to non-null bytes.

## Out of scope

- Remote orphan GC / deletion (deferred; `deleteAttachment` added but uncalled).
- Lazy / on-demand download (chose eager).
- `cloudApi` byte transport (separate `ApiVaultStore` track).
- Other cloud providers (contract is ready; only OneDrive implemented).
- Progress UI / per-file download indicators (counts surface in the existing sync result; no new UI).
