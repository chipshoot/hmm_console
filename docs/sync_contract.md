# Sync Contract

Defines how the Hmm Console app syncs local SQLite state with a remote cloud provider. The contract is **provider-agnostic** — the same semantics apply to OneDrive (v1), the Hmm API, iCloud, Google Drive, and Dropbox.

Related: `docs/task_plan.md`, `docs/findings.md`, `docs/cloud_storage_setup.md`.

---

## 1. Scope

A `CloudSyncProvider` syncs two kinds of records:

- **Notes** — rows from the `notes` table, serialized as one JSON blob per note
- **Attachments** — rows from the `attachments` table plus the binary file they reference

Everything else (note catalogs, tags, authors) is either client-local (catalogs seeded at app start) or synced as a side-effect of note sync (tag rows fetched on demand from the note's tag references).

---

## 2. Core Invariants

1. **Local is source of truth during offline use.** Writes always hit SQLite first, then push to cloud.
2. **Last-write-wins by `updated_at`** for both notes and attachments. No version field, no ETag CAS in v1.
3. **Soft-delete via tombstones.** `deleted_at` NOT NULL → record is a tombstone. Tombstones sync like any other record so every device converges to the deleted state.
4. **Clock consistency.** All timestamps are UTC. `updated_at` is set by the writing device using `DateTime.now().toUtc()`. A device with a badly skewed clock can lose conflict resolutions — acceptable trade-off for v1.
5. **Idempotency.** Push and pull operations must be safe to retry. The manifest + per-record storage makes this natural.
6. **Atomicity at the record level only.** A sync pass that is interrupted may leave some records synced and others not; the next pass reconciles. No transactional guarantees across multiple records.

---

## 3. Manifest

A `manifest.json` at the root of the cloud namespace is the index the sync engine reads first.

### 3.1 Shape

```json
{
  "version": 1,
  "generated_at": "2026-04-21T14:03:12Z",
  "device_id": "<uuid of writing device>",
  "notes": [
    { "id": "note-uuid-1", "updated_at": "2026-04-20T09:15:00Z", "deleted": false },
    { "id": "note-uuid-2", "updated_at": "2026-04-20T11:40:03Z", "deleted": true }
  ],
  "attachments": [
    { "id": "att-uuid-1", "note_id": "note-uuid-1", "filename": "car-front.jpg", "updated_at": "2026-04-20T09:15:01Z", "deleted": false }
  ]
}
```

### 3.2 Rules

- Manifest is **fully rewritten** on every push — no partial patches. Keeps providers with no conditional-write support honest.
- `device_id` is informational (diagnostics) and does NOT gate merges.
- A note's blob at `/notes/<id>.json` may exist even when the manifest entry is `deleted: true` — that's expected during the tombstone window. Hard-delete of blob only after GC (see §7).
- If a blob is missing but the manifest claims it exists (non-deleted), treat it as corrupted: log, skip this record, continue the sync pass.

---

## 4. Push (local → cloud)

Triggered when:
- User taps **Sync now** in Settings
- App resumes from background **and** the local store has pending changes since last successful push
- Optionally: after each local write, debounced (configurable per provider)

Algorithm:

```
1. Gather local records with updated_at > lastPushedAt (per record, not per-sync-run)
2. For each changed note:
     PUT /notes/<id>.json with full JSON body
3. For each changed attachment:
     PUT /attachments/<id>.<ext> with binary body
4. Re-read local record set → build new manifest
5. PUT /manifest.json last (atomicity pivot — older clients still see old state until this succeeds)
6. On success: set lastPushedAt = now()
7. On failure at any step: abort, retain lastPushedAt, surface error to UI. Next push retries from the same cursor.
```

The push **never deletes blobs**. Tombstones in the manifest are enough; GC is a separate, rare operation (§7).

---

## 5. Pull (cloud → local)

Triggered when:
- App cold-start (after sign-in)
- User taps **Sync now**
- Optionally: periodic timer while app is foreground

Algorithm:

```
1. GET /manifest.json
     - 404 → cloud is empty; push everything local (first-sync bootstrap)
2. For each entry in manifest.notes:
     - If local has no row with this id: PULL (fetch blob, insert locally)
     - Else compare updated_at:
         remote > local → PULL
         remote <= local → skip (local is newer; push will fix cloud)
3. Same for manifest.attachments (PULL binary file to local storage path, insert/update row)
4. For any local record whose id does NOT appear in manifest AND whose updated_at < manifest.generated_at: leave as-is (assume locally created, not yet pushed). Do NOT delete.
5. Apply pulled tombstones: if manifest says deleted=true and local row is not a tombstone, set deleted_at = manifest.updated_at.
```

### 5.1 PULL details

- Note PULL: `GET /notes/<id>.json` → decode → `UPSERT` into `notes` with manifest's `updated_at`.
- Attachment PULL: `GET /attachments/<id>.<ext>` → write binary to local attachments dir → `UPSERT` into `attachments`.

### 5.2 Partial pulls

If the pull fails midway, the next pass restarts from the manifest. Because every step is idempotent and LWW, partial pulls cannot corrupt state — they just delay convergence.

---

## 6. Merge Semantics (LWW detail)

Given a local record `L` and a remote record `R` for the same id:

| Condition | Action |
|---|---|
| `R.updated_at > L.updated_at` | Replace L with R (including tombstone state) |
| `R.updated_at < L.updated_at` | Ignore R (next push will fix cloud) |
| `R.updated_at == L.updated_at` | Treat as equal; no write |

**Deletion takes priority when timestamps match** (defensive): if either side says `deleted=true` at the same `updated_at`, the merged record is deleted. (Edge case; unlikely in practice.)

---

## 7. Garbage Collection

Tombstones accumulate forever without GC. Run GC:

- Locally: purge `notes` and `attachments` rows with `deleted_at < now() - 30 days`, remove their blobs from the local attachments dir.
- Cloud: during push, if a local tombstone is older than 30 days AND the manifest already has it as `deleted`, drop the manifest entry and `DELETE /notes/<id>.json` (or the attachment blob).

GC runs on manual trigger only in v1 (Settings → "Compact sync data"). Not automatic — keeps the sync path simple.

---

## 8. Conflict: Two Devices Push Back-to-Back

Scenario: device A pushes a full manifest, then device B (which pulled A's manifest two minutes ago) pushes its own.

Outcome: B's push overwrites A's manifest (LWW at the blob level). B's manifest only reflects records B knows about. Records A added that B didn't pull yet are **lost from the manifest but still exist as blobs in storage**.

Mitigation in v1: manifest rebuild on every push walks the cloud listing (`ls /notes/` + `ls /attachments/`) and merges discovered blobs into the local view on the next pull. This recovers the "orphan" records on the next sync pass.

This is crude but acceptable. A future version can use OneDrive ETag / conditional updates to prevent the overwrite entirely.

---

## 9. CloudSyncProvider Interface (Dart sketch)

```dart
abstract class CloudSyncProvider {
  String get providerId; // 'onedrive' | 'hmm_api' | 'icloud' | ...

  /// True after successful sign-in; tokens cached in secure storage.
  Future<bool> isAuthenticated();

  Future<void> signIn();
  Future<void> signOut();

  /// Full sync = pull then push. Returns telemetry for UI.
  Future<SyncResult> sync(SyncRequest request);
}

class SyncRequest {
  final DateTime lastPushedAt; // cursor from local meta table
  final List<NoteBlob> locallyChangedNotes;
  final List<AttachmentBlob> locallyChangedAttachments;
}

class SyncResult {
  final int pulledNotes;
  final int pulledAttachments;
  final int pushedNotes;
  final int pushedAttachments;
  final DateTime completedAt;
  final List<SyncError> errors; // per-record failures; sync as a whole may still have succeeded
}
```

---

## 10. Open Items (not blocking v1)

- **Large attachments:** no chunked upload path yet. OneDrive supports resumable upload sessions for files >4 MB; revisit if we need video or large document support.
- **Encryption at rest on the cloud side:** blobs are plaintext JSON/binaries. User's OneDrive is already encrypted server-side by Microsoft. If users want client-side E2E, that's a v2 feature.
- **Multi-account per provider:** v1 allows only one OneDrive account at a time. Switching accounts wipes local state.
- **Bandwidth throttling:** no backoff for rate-limited responses. If Graph throttles us, surface the error; the next manual sync retries.
