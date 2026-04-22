# Progress Log

## Session: 2026-04-20

### Task: Client-Side Data Storage Modes (Local / Cloud Storage / Cloud API)

**Branch:** `feature/client-side-data`
**Phase:** 1 — Scope & Design Decisions (in_progress)

#### Done
- Planning files initialized (`task_plan.md`, `findings.md`, `progress.md`)
- Confirmed mode model = **three modes** (Local / CloudStorage / CloudApi)
- Captured current state of `lib/core/data/` (untracked scaffolding on branch)
- Identified that gas_log currently uses Hive, not the new SQLite store — migration is non-trivial

#### Environment
- iOS simulator (iPhone 15 Pro Max) running current branch build in background task `buu8ia2r1`
- DevTools at http://127.0.0.1:54154/0PGcHxyxnSM=/devtools/

#### Decisions captured
- Q1: three-mode enum (Local / CloudStorage / CloudApi)
- Q2: scope is all data-backed features (gas_log, message_management, future)
- Q3: CloudStorage v1 provider = OneDrive only (iCloud/Drive/Dropbox deferred)
- Q4: OneDrive layout = per-entity JSON blobs + manifest.json
- Q5: Conflict resolution = LWW via `updated_at` only (no version field, no ETag CAS)
- Q6: gas_log local store = migrate Hive → SQLite
- Q7 (user-initiated): Data model is note-centric — gas_log is a NoteCatalog; planned catalogs include todo, memo, book_note, health_info. Client mirrors backend `/notes` + `/notecatalogs`.
- Q8 (user-initiated): Automobile is a first-class domain with children (gas_log, maintenance, insurance, accident, photos). Modeled as Path C — everything is a note with `parent_note_id` hierarchy + typed Dart views + separate `attachments` table for binaries.

#### Architectural shift
- This task is no longer just "storage modes" — it's the foundation for a generic Note/NoteCatalog model that every feature screen sits on
- Plan has a dedicated Phase 3 for note-centric SQLite schema ahead of the DataMode rework
- Phase 6 migrates gas_log + automobile onto NoteRepository; other catalogs (maintenance, insurance, accident, todo, memo, book_note, health_info) are post-branch

#### Pending user input
- Azure AD app registration — instructions written to `docs/cloud_storage_setup.md` §1; user to register app and provide client ID

#### Artifacts added
- `docs/cloud_storage_setup.md` — full OneDrive (Azure AD / Entra ID) setup walkthrough with platform-specific redirect URIs, plus reference sections for iCloud, Google Drive, and Dropbox for future providers

#### Next
- User review of updated plan. If approved, Phase 1 closes and work begins on Phase 2 (OneDrive prototype) and Phase 3 (schema design) in parallel.
