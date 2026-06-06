# Note Subsystem — Foundation (A + D) — Design

**Date:** 2026-06-06
**Repo:** `hmm_console` (Flutter client)
**Status:** Approved design, ready for implementation planning

## Overview

The dashboard has a "Notes" tile, and the note **data layer** already exists
(`Notes` Drift table with sync metadata, `LocalHmmNoteRepository` with full
CRUD, `HmmNote` model + mapper) — but there is **no UI**. This project builds the
foundational note UI plus a debug raw-content viewer.

The guiding idea: **to the user, every note — domain entity or not — is just
content shown on screen.** In read mode, all notes render as a markdown string
through a universal renderer. Editing dispatches to the appropriate editor:
free-form notes use a generic markdown editor; domain notes (e.g. gas logs) open
their existing domain form, which loads the entity and applies domain business
logic.

This is the first of three specs. Two follow-on specs are explicitly out of
scope here:

- **B — Cross-subsystem surfacing:** free-form notes discoverable by domain
  managers (e.g. a car-photo note appearing in the automobile manager's list).
- **C — Tag cloud sync:** the `Tags`/`NoteTagRefs` tables lack `uuid`/`version`/
  `deletedAt`, and `repository_providers` throws `UnimplementedError` for an API
  tag repository.

## Scope

### In scope (A + D)

1. **General (free-form) note CRUD** — create, read, edit, soft-delete a note
   with **subject + markdown body + image attachments**.
2. **Universal read renderer** — every note renders read-only as markdown.
   Domain notes render via a registered renderer; unknown catalogs fall back to
   a readable JSON dump.
3. **Notes list** — quick-filter chips + a funnel→filter-sheet (promoted to a
   sidebar on iPad), a sort sheet (Date / Last modified / Subject), subject
   search, and catalog color-coding.
4. **Edit dispatch** — General notes → generic markdown editor; domain notes →
   their existing domain editor (where wired). The **Gas Log** renderer + edit
   dispatch ship in this foundation as the proof-of-pattern.
5. **Raw content viewer (D)** — always available in the detail `⋯` menu;
   read-only JSON content + metadata (catalog, uuid, version) with a copy action.

### Non-goals (deferred, but designed to slot in cleanly)

- Cross-subsystem surfacing (B) and tag cloud sync (C).
- The calendar view (colored dots per note type). The catalog→color palette is
  built now so the calendar is a clean later addition.
- A note `priority` field and sort-by-priority.
- HTML `formatType` rendering (markdown + plain text only for now).
- A `color` column on `NoteCatalogs` (client-side palette used instead).

## Architecture

Two small extension-point registries plus a palette, placed in
`lib/core/notes/` so domain features register into them **without** the `notes`
feature depending on each domain feature (avoids circular dependencies).

### Render registry

- `NoteRenderer` — interface: `String render(HmmNote note)` returning markdown.
- `renderRegistryProvider` — Riverpod provider keyed by **catalog name**.
- `GeneralNoteRenderer` — renders the note's `content` as markdown directly
  (used when the catalog's `formatType` is Markdown/PlainText).
- `GenericJsonRenderer` — fallback for any catalog without a registered
  renderer: pretty key/value dump of the JSON. Also powers the raw viewer's
  readability formatting.
- Domain features register their own renderer (e.g. `gas_log` registers
  `GasLogNoteRenderer`).

### Edit-dispatch registry

- Maps **catalog name → an editor navigation target**.
- General → the generic editor route (`/notes/:id/edit`).
- A domain catalog → its existing domain form route (Gas Log wired in this
  foundation).
- A catalog with **no** registered editor renders **read-only** — the Edit
  action is hidden until an editor is wired.

### Catalog palette

- `catalog_palette.dart` — a client-side `catalog name → Color` map with a
  default for unknown catalogs. Initial mapping:

  | Catalog | Color |
  |---------|-------|
  | General | `#34C759` (green) |
  | Gas Log | `#FFD60A` (yellow) |
  | Automobile | `#0A84FF` (blue) |
  | Insurance | `#FF9F0A` (orange) |
  | Scheduled service | `#BF5AF2` (purple) |
  | Service record | `#FF453A` (red) |
  | _default / unknown_ | `#8E8E93` (gray) |

- Calendar-ready: the same palette drives the future colored-dot calendar.
- No schema change; a `NoteCatalogs.color` column can replace it later (and
  would then sync) without touching call sites.

## Data model

**No Drift schema change is required for the foundation.** The `Notes` table
already provides `subject`, `content`, `description`, `catalogId`,
`attachments`, and the sync metadata (`uuid`, `version`, `deletedAt`).

- **General note storage:** the markdown body is stored in `content` as a plain
  markdown string (not JSON). The note's `catalogId` points at a seeded
  **"General"** `NoteCatalog` with `formatType = Markdown`. `description` remains
  optional (reserved for a future list snippet/summary).
- **Render decision:** the renderer uses the catalog's `formatType` to decide
  "render `content` as markdown directly" (General) vs "hand to a domain
  renderer" (domain catalogs) vs "generic JSON fallback" (unregistered).
- **General catalog seeding:** ensured on first use via the existing
  `getOrCreateCatalog(name, schema)`. Idempotent; no migration.
- **Images:** picked via `image_picker`, written through
  `vaultStoreProvider.putBytes(...)`, and recorded as a `VaultRef` appended to
  the note's `NoteAttachments` (the existing `attachments` JSON column + codec).
  The read view resolves them via `attachmentResolverProvider`. The vault/
  attachments stack is reused unchanged.

The only data-layer work is read/sort/search composition in the state layer atop
the repository methods that already exist (`getNotes(catalogId: …)`,
`getNoteById`).

## Components & file layout

Follows the existing `features/<name>/{data,domain,presentation,states}`
convention and Riverpod-only DI.

```
lib/core/notes/                         ← shared, domain-agnostic
  rendering/note_renderer.dart          (interface)
  rendering/render_registry.dart        (provider)
  rendering/general_note_renderer.dart
  rendering/generic_json_renderer.dart  (fallback + raw-view formatter)
  editing/edit_dispatch.dart            (catalog → editor target)
  catalog_palette.dart

lib/features/notes/
  data/models/hmm_note.dart             ← exists
  data/mappers/hmm_note_mapper.dart     ← exists
  states/notes_list_state.dart          (filter + sort + search)
  states/mutate_note_state.dart         (create/update/delete General)
  states/catalogs_state.dart            (catalogs + counts for filter sheet)
  presentation/screens/notes_list_screen.dart
  presentation/screens/note_detail_screen.dart
  presentation/screens/note_editor_screen.dart   (General create/edit)
  presentation/screens/raw_content_screen.dart   (D)
  presentation/widgets/note_list_tile.dart
  presentation/widgets/catalog_filter_sheet.dart
  presentation/widgets/sort_sheet.dart
  presentation/widgets/catalog_chip.dart
  presentation/widgets/markdown_view.dart
  presentation/widgets/attachment_picker.dart
  presentation/widgets/attachment_gallery.dart

lib/features/gas_log/                   ← registers GasLogNoteRenderer
                                          + edit dispatch target
```

### Routing

Added to `router_config.dart` under the existing `notes` tile target:

- `/notes` — list
- `/notes/new` — create (General)
- `/notes/:id` — detail (read)
- `/notes/:id/edit` — generic editor (General)
- `/notes/:id/raw` — raw content viewer (D)

### New dependency

- `flutter_markdown` — read-view rendering and the editor's markdown preview.

## UI design (validated via mockups)

### Notes list

- Top bar: search, **sort** (↑↓), **filter** (funnel), add (+).
- A wrapping **quick-chip row** with an "All" default for common catalogs; each
  chip carries the catalog color.
- A unified, scrollable list below; each row shows a catalog color dot, subject,
  and a `catalog · date` subtitle.
- **Filter sheet** (funnel tapped): "Frequently used" + "All catalogs" sections,
  each catalog with color dot and count.
- **iPad:** the filter sheet becomes a permanent left **sidebar** (master), the
  list is the middle pane, and the detail/read view is the right pane.
- **Sort sheet:** Date — newest first (default), Date — oldest first, Last
  modified, Subject A→Z. (No priority sort; deferred.)

### Note detail (read)

- Renders the note read-only as markdown via the registry; General notes show
  their markdown body + inline images, domain notes show their rendered view.
- **Edit** button dispatches via the edit registry (hidden for unwired catalogs).
- **⋯ menu:** Edit, **View raw content**, Delete. (Share/Export is deferred — not
  part of this foundation.)

### Note editor (General)

- Fields: subject (required), markdown body, image attachments (add/remove).
- Optional markdown preview using the same `MarkdownView`.

### Raw content viewer (D)

- Always reachable from the `⋯` menu.
- Shows `content` pretty-printed if JSON, else verbatim; footer with catalog,
  uuid, and version. Copy-to-clipboard action.

## Data flow

- **Create (General):** editor collects subject + markdown + images → images
  written to vault → `mutateNoteProvider.create(HmmNoteCreate{subject,
  content: markdown, catalogId: General, attachments})` → local repo insert →
  list invalidates → note appears.
- **Read/render:** detail loads `HmmNote` →
  `renderRegistryProvider.rendererFor(catalog)` → markdown → `MarkdownView`;
  attachments resolved and shown. Unknown catalog → `GenericJsonRenderer`.
- **List:** `notesListProvider` watches `dataMode` → repository, loads notes,
  then applies the active filter (catalog set or "All"), sort, and search in the
  state layer. Chips/sheets only mutate that state.
- **Edit dispatch:** Edit → `editDispatch.targetFor(catalog)` → General opens
  `:id/edit`; a wired domain catalog routes to its form; an unwired catalog hides
  Edit (read-only).
- **Raw view (D):** `⋯` → "View raw content" → `:id/raw`.

## Error handling

- Reuse the sealed `AppException` hierarchy; surface via Riverpod `AsyncValue`
  error states (matches the auth and gas_log features).
- **Renderer isolation:** a renderer that throws never crashes the read screen —
  it falls back to `GenericJsonRenderer` and shows a small "couldn't render this
  note's format" banner. This doubles as a debugging aid alongside the raw
  viewer.
- Vault/image failures (picker cancelled, write error) surface as an inline
  snackbar; the note still saves without the failed attachment.
- Missing or null catalog is treated as the generic fallback, never an error.

## Testing

Follows the repo's existing `test/` patterns.

- **Unit:**
  - `GeneralNoteRenderer` (markdown passthrough) and `GasLogNoteRenderer`
    (JSON→markdown).
  - Render registry lookup + fallback to `GenericJsonRenderer`.
  - `editDispatch` mapping (General, Gas Log, unwired).
  - `notesListState` filter/sort/search logic.
  - `mutateNoteState` create/update/soft-delete against a fake repository.
  - Attachment-add flow against a fake `IVaultStore`.
- **Widget:**
  - List screen: chips, filter sheet, sort sheet, and search render and drive
    state.
  - Detail screen: renders markdown, `⋯` menu, navigates to raw view.
  - Editor: subject validation, image add/remove.

## Open items for the implementation plan

- The dashboard "Notes" tile currently targets `notes`; the plan confirms whether
  the routes attach as a top-level `/notes` branch or nest under the dashboard
  shell route, matching the pattern used by `/automobiles`.
- Confirm whether the Gas Log edit target can be reached directly from a gas-log
  note (resolving the owning automobile context) or needs a small lookup helper;
  this affects only the Gas Log edit-dispatch wiring, not the read path.
