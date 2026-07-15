# Sync Safety & Persistent Home/Sync Access — Design

**Date:** 2026-07-15
**Status:** Approved (brainstorming); ready for planning (Phase 1 first).

## Problem

A user created notes and gas logs in **Cloud Storage (OneDrive)** mode, then a new
build was installed. On iOS, installing over an app **uninstalls the old app
first**, which deletes the app's sandbox container — **including the local Drift
(SQLite) database**. The new records had never synced to OneDrive, so they were
erased with the container and are unrecoverable.

Root causes (verified against the code):

1. **No sync on write.** `MutateNote.createGeneral`/`updateGeneral`
   (`lib/features/notes/states/mutate_note_state.dart`) and the gas-log
   create/update paths only write to local Drift and bump `lastModifiedDate`.
   Nothing triggers, enqueues, or flags a sync.
2. **Sync is coarse and lazy.** `SyncController`
   (`lib/core/data/sync/sync_controller.dart`) fires only on: the manual
   Settings button, app→foreground (250 ms debounce), app→background (immediate),
   or a **10-minute** periodic timer (only while resumed). Cold start does not
   sync until the timer or a lifecycle event.
3. **WiFi-only is a silent gate.** The network policy (`CanAutoSyncCheck`) can
   **block** an auto-trigger (e.g. on cellular) with no user-visible signal, so
   data can sit local-only indefinitely.
4. **No visibility.** There is no "unsynced/pending changes" indicator anywhere;
   nothing tells the user their data hasn't left the device.

**Gas logs are stored as notes**, so fixing note persistence fixes gas-log
persistence by the same mechanism.

## Goals

- Shrink the "created but not yet off-device" window from ~10 min to seconds.
- Make unsynced state **visible on every screen**, and sync **one-tap reachable**.
- Never silently strand data: when auto-sync is blocked or failing, **prompt**.
- Give **Home** one-tap access from anywhere.
- Address **all three data tiers**, honestly per tier (below).

## Non-goals

- Changing the WiFi-only default policy.
- Attachment bytes (they already ride the OS-level OneDrive folder sync).
- Merging the note editor's Save button into the Sync action (decided against —
  Save must be instant and offline-reliable; sync is async/best-effort).
- A general offline-first rewrite of the API tier.

## What "fix note loss" means per tier

The loss mechanism is *local-only data + destructive reinstall*. The remedy
depends on whether the tier has an off-device target:

| Tier | Off-device target | Fix |
|------|-------------------|-----|
| **Cloud Storage (OneDrive)** | OneDrive, via `SyncOrchestrator` | Auto-sync on save (debounced) + pending indicator + prompt when blocked/failed. **The incident tier — Phase 1.** |
| **Cloud API (Hmm server)** | REST `/v1/notes`, via `ApiSyncProvider` | Notes currently `throw UnimplementedError` in `hmmNoteRepositoryProvider` for this mode, so notes are unusable. Route notes through local Drift + the existing API sync orchestrator so cloudApi becomes usable **and** gets the same auto-sync protection. **Phase 2.** |
| **Local (offline)** | none | Cannot be saved by syncing. Make the risk unmissable: persistent "Not backed up" state, a one-time warning, a manual **Export/Backup**, and one-tap **Enable cloud backup**. **Phase 2.** |

## Architecture

Three cooperating pieces, layered on the existing sync engine (no rewrite):

### 1. Change signal → debounced auto-sync (Part A)

- Add `SyncController.notifyLocalChange()` and a new
  `SyncTriggerReason.localChange`.
- After a **successful local write**, the note mutate paths (and, since gas logs
  are notes, they are covered automatically) call `notifyLocalChange()` — only
  when a sync orchestrator is active (cloudStorage now; cloudApi in Phase 2).
- `notifyLocalChange()` (re)starts a short **debounce (~8 s)** that coalesces
  bursts, then calls `triggerAutoSync(SyncTriggerReason.localChange)`. The
  existing WiFi-only gate still applies.

### 2. Pending-changes signal (Part A visibility)

- New `pendingSyncCountProvider`: a cheap `COUNT` of local rows changed since the
  last-pushed cursor (the same "changed since cursor" the orchestrator already
  computes transiently in `_collectChangedNotes`, exposed as a standing query
  driven by the sync-meta cursor). Recomputes when the notes table changes or a
  sync completes.
- Drives the pill badge and the blocked/failed prompt threshold.

### 3. Blocked/failed safety net (Part A anti-loss)

- If `pendingSyncCount > 0` **and** (auto-sync is gated by the network policy, or
  the last sync failed), the persistent control enters a **warning** state, and
  on app-background (or when the count crosses a small threshold) shows a
  **prompt**: *"N changes haven't reached your cloud — Sync now (may use
  cellular) / Wait for WiFi."* Reuses the existing `confirmManualSyncIfOnCellular`.

### 4. Persistent Home + Sync overlay (Part B)

- There is no `ShellRoute` today and screens build their own scaffolds
  (`AppScaffold`, or a raw `Scaffold` on the Dashboard). To cover **every**
  screen with **no per-screen edits**, mount a single global `Overlay` entry
  above the router (at the `MaterialApp.router` `builder`).
- Two small controls, bottom-trailing, inside `SafeArea`, padded to clear bottom
  nav bars / FABs / the note editor's media toolbar:
  - **Home** → `context.go('/')` (Dashboard).
  - **Sync/Safety** — mode-adaptive:
    - cloudStorage / cloudApi: sync status (synced / syncing / *N* unsynced /
      error/blocked) + **tap = sync now** (cellular-confirm); long-press = mini
      sheet (last-synced, pending count, open Settings sync).
    - local: **"⚠ Not backed up"** + tap → Back up / Enable cloud backup.
- **Unobtrusive:** small; when everything is synced it collapses to a minimal
  low-opacity affordance; it never overlaps primary content and respects safe
  areas. (Draggable repositioning is out of scope for v1.)

### 5. Note editor: Save vs Sync

- Save is unchanged in spirit: it writes locally (instant, always succeeds
  offline) **and** triggers the debounced auto-sync via `notifyLocalChange()`.
- The persistent pill is visible on the editor, so sync progress shows there.
  Optional nicety: a brief "Saved · syncing…" hint after Save.

## Data flow (Cloud Storage, happy path)

```
user edits note → tap Save
  → MutateNote.updateGeneral writes Drift (lastModifiedDate bumped)
  → syncController.notifyLocalChange()  [orchestrator active]
  → 8s debounce (coalesces further edits)
  → triggerAutoSync(localChange)  → WiFi gate ok → SyncOrchestrator.syncNow()
  → push changed rows to OneDrive → cursor advances
  → pendingSyncCountProvider → 0 → pill shows "synced"
```

Blocked path: `triggerAutoSync` gated (cellular + WiFi-only) → pill shows
"⚠ N unsynced"; on background or threshold → prompt to Sync now / wait.

## Error handling

- Save always completes locally even if sync later fails; sync failures never
  fail the save.
- Repeated sync failures already surface via `SyncStatus.consecutiveFailures`;
  the pill reflects the error/blocked state and offers a retry (tap).
- A blocked auto-sync (network gate) is treated as "pending, at risk," not
  "done" — this is the core anti-loss behavior.

## Phasing

**Phase 1 (critical — fixes the incident, ships first):**
- `notifyLocalChange()` + `SyncTriggerReason.localChange` + debounced auto-sync,
  wired from the note mutate paths.
- `pendingSyncCountProvider`.
- Blocked/failed prompt.
- Persistent **Home + Sync** overlay (cloudStorage sync status + tap-to-sync;
  Home everywhere). In `local`/`cloudApi` modes for now the Sync control shows a
  neutral/disabled state (full per-tier behavior lands in Phase 2).

**Phase 2:**
- Cloud API: fix `hmmNoteRepositoryProvider` to route notes to local Drift +
  wire `ApiSyncProvider` so cloudApi notes sync (and get auto-sync).
- Local mode: "Not backed up" persistent state + one-time warning + Export/Backup
  + one-tap Enable-cloud.

## Testing

- **Unit:** debounce coalescing (N rapid edits → 1 sync); `notifyLocalChange`
  no-ops when no orchestrator active; `pendingSyncCountProvider` counts
  changed-since-cursor correctly; blocked-state → prompt decision.
- **Widget:** pill states (synced/syncing/pending/error) render; tap triggers
  sync (with cellular confirm); Home navigates to Dashboard; overlay appears over
  a raw-Scaffold screen (Dashboard) and an `AppScaffold` screen; hidden/neutral
  in local mode (Phase 1).

## Open questions for planning

- Exact debounce duration (proposed 8 s) and whether app-background should also
  flush the debounce immediately (recommended yes).
- Precise cheap query for pending count against the sync-meta cursor.
- Overlay z-order/insets vs. existing FABs and the editor media toolbar on each
  platform.
