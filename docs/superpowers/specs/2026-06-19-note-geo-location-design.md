# Note Geo Location (Phase 2b) — Design

**Date:** 2026-06-19
**Status:** Approved (brainstorm) — pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-06-18-note-media-and-metadata-design.md` (this details **Phase 2 / N1 — Geo location**). Dates (N2) shipped as Phase 2a.
**Repos touched:** `hmm_console` (Flutter client) **and** `hmm` (`Hmm.ServiceApi` backend).

## Goal

Optionally capture a note's location (latitude/longitude + a reverse-geocoded label) at create time, show it as a Journal-style **location card**, and let the user remove it per-note (✕) or disable it globally (a Settings toggle). Capture is **opt-in** (off by default), **non-blocking** (never delays save, never shows a blocking prompt), and **best-effort** (no fix ⇒ store/show nothing). The location syncs across devices, including `cloudStorage`.

## Decisions (locked during brainstorm)

1. **Capture trigger — auto on save, removable card.** For a **new** note, when the global toggle is on, the editor fetches a fix in the background and shows a removable location card; the fix is attached on save. No auto-capture when editing an existing note.
2. **Opt-in.** Global setting "Add location to new notes" defaults to **off**. Nothing is fetched (and no OS permission prompt fires) until the user enables it.
3. **Storage — three discrete nullable columns** (`latitude`, `longitude`, `locationLabel`) on the client `Notes` table and backend `HmmNote`. All-null = no location. Chosen over a JSON blob so the backend maps by AutoMapper convention (no codec), the data stays queryable, and there's no codec to write on either side. A client-side `NoteLocation` value object gives all-or-none atomicity at the create/update boundary.
4. **Label captured once.** The reverse-geocoded label is denormalized at capture time and never re-geocoded.
5. **Backend + sync included up front.** Add the columns to the serviceAPI EF layer and serialize them through the `cloudStorage` sync engine with a round-trip test (the gap that bit Phase 2a).
6. **No map / picker** in 2b (YAGNI). The card is display + remove only.

## Reused infrastructure

`lib/features/gas_log/providers/location_provider.dart` already provides:
- `currentPositionProvider` — `FutureProvider<Position?>`; handles permission request and returns `null` on denied / `deniedForever` / services-off / timeout (10s, medium accuracy).
- `reverseGeocodeProvider` — `FutureProvider.family<Placemark?, ({double latitude, double longitude})>`; returns `null` on failure.

Phase 2b reuses both. (These currently live under `gas_log/`; the plan may relocate or re-export them to a shared `core/services/` location, but no behavior change.)

---

## Part A — Backend (`hmm` / `Hmm.ServiceApi`)

Mirrors the Phase 2a `NoteDate` shape. All three fields are nullable; existing rows stay null (no backfill).

### Data model (DAO + domain)

- `Hmm.Core.Map/DbEntity/HmmNoteDao.cs`: add
  - `[Column("latitude")] public double? Latitude { get; set; }`
  - `[Column("longitude")] public double? Longitude { get; set; }`
  - `[Column("locationlabel")] [MaxLength(500)] public string? LocationLabel { get; set; }`
- `Hmm.Core.Map/DomainEntity/HmmNote.cs`: add `double? Latitude`, `double? Longitude`, `string? LocationLabel`.

### DTOs (`Hmm.ServiceApi.DtoEntity/HmmNote/`)

- `ApiNote.cs` (read): add the three properties.
- `ApiNoteForCreate.cs`: add the three (`double?` / `double?` / `string?`).
- `ApiNoteForUpdate.cs`: add the three.

### AutoMapper (`ApiMappingProfile` + `HmmMappingProfile`)

- Read/create map **by name convention** — no edits (like `NoteDate`).
- On the `ApiNoteForUpdate → HmmNote` map, add **null-preserve conditions** so a `PUT` that omits a field doesn't zero the stored value (the controller `Put` maps the DTO onto the loaded note):
  - `.ForMember(d => d.Latitude, o => o.Condition(s => s.Latitude.HasValue))`
  - `.ForMember(d => d.Longitude, o => o.Condition(s => s.Longitude.HasValue))`
  - `.ForMember(d => d.LocationLabel, o => o.Condition(s => s.LocationLabel != null))`
  - **Clearing semantics:** because of these conditions, the API cannot clear a location by sending nulls. Clearing is a client-local concern in 2b (the `cloudApi` note repo doesn't exist yet). If/when the API path lands, clearing will need an explicit signal; out of scope here. Document this limitation in the DTO comments.

### Manager (`Hmm.Core/DefaultManager/HmmNoteManager.cs`)

- No defaulting logic (unlike `NoteDate`). Location is purely client-supplied; `CreateAsync`/`UpdateAsync` pass the three fields through the mapper unchanged. `CreateDate`/`NoteDate` logic is untouched.

### EF migration (`Hmm.Core.Dal.EF/Migrations/`)

- Hand-written `..._AddNoteLocationColumns.cs` (follow the `AddNoteDateColumn` pattern):
  - `AddColumn<double>("latitude", "notes", nullable: true)`
  - `AddColumn<double>("longitude", "notes", nullable: true)`
  - `AddColumn<string>("locationlabel", "notes", type: "character varying(500)", maxLength: 500, nullable: true)`
  - No backfill.
  - `Down`: drop the three columns.
- Update `HmmDataContextModelSnapshot.cs` with the three properties (alphabetical placement, matching column types).

### Backend tests

- Mapping: the three fields round-trip Dao↔Domain↔Dto (Create/Update/Read).
- Manager/controller: a `PUT` omitting a location field preserves the stored value (the `.Condition`); a create with a location persists all three.

---

## Part B — Client (`hmm_console`)

### Drift migration (`lib/core/data/local/database.dart` + `database.g.dart`)

- Add to `Notes`:
  - `RealColumn get latitude => real().nullable()();`
  - `RealColumn get longitude => real().nullable()();`
  - `TextColumn get locationLabel => text().withLength(min: 0, max: 500).nullable()();`
- Bump `schemaVersion` 7 → 8; add migration step `if (from < 8)` that `addColumn`s the three. No backfill.

### Value object + model + inputs

- New `NoteLocation` (`lib/core/data/note_location.dart`):
  ```dart
  class NoteLocation {
    const NoteLocation({this.latitude, this.longitude, this.label});
    final double? latitude;
    final double? longitude;
    final String? label;
    bool get isEmpty => latitude == null && longitude == null;
    static const empty = NoteLocation();
  }
  ```
- `HmmNote` (`features/notes/data/models/hmm_note.dart`): add `double? latitude`, `double? longitude`, `String? locationLabel`, plus a convenience `NoteLocation? get location` (null when all are null).
- `HmmNoteMapper.fromDriftRow`: map the three columns.
- `HmmNoteCreate` (`core/data/hmm_note_input.dart`): add optional `NoteLocation? location` (null/empty ⇒ no location).
- `HmmNoteUpdate`: add `NoteLocation? location` with attachments-style patch semantics — **null = don't touch**, **`NoteLocation.empty` = clear (write SQL NULL ×3)**, **populated = set**. Include in `isEmpty`.

### Repository (`core/data/local/local_hmm_note_repository.dart`)

- `createNote`: when `input.location` is non-null and non-empty, write the three columns; else leave them absent (NULL).
- `updateNote`: `location == null` → all three `Value.absent()`; `location.isEmpty` → all three `Value(null)` (clear); populated → `Value(lat/lng/label)`.

### Settings toggle

- New `geoCaptureEnabledProvider` — a `Notifier<bool>` persisted via `shared_preferences` (key e.g. `geo_capture_enabled`, **default false**), following the `DataModeNotifier` pattern in `lib/core/data/data_mode.dart`.
- Surface as a switch tile "Add location to new notes" on the settings screen (`lib/features/settings/presentation/...`), following the existing settings-row pattern.

### Editor (`features/notes/presentation/screens/note_editor_screen.dart`)

- Add `NoteLocation? _pendingLocation` editor state (mirrors `_pendingPicks`).
- In `initState`/first build, **only for a new note** (`widget.noteId == null`) **and** when `geoCaptureEnabledProvider` is true: kick off a background fetch — `currentPositionProvider` → on success `reverseGeocodeProvider` for the label → `setState(_pendingLocation = NoteLocation(lat, lng, label))`. Non-blocking; failures leave `_pendingLocation` null.
- For an **existing** note, `_loadExisting` seeds `_pendingLocation` from `note.location` (so the card shows and can be removed).
- Render a **location card** (new widget `NoteLocationCard`) when `_pendingLocation != null && !_pendingLocation!.isEmpty`, with a ✕ that clears it (`setState(_pendingLocation = null)` for a new note; for an existing note the card stays until save persists the clear).
- `_save`:
  - **Create:** pass `location: _pendingLocation` into `createGeneral`.
  - **Update:** compute the location patch — if the note had a location and the card was removed → `NoteLocation.empty` (clear); if unchanged → don't send (`null`); (no edit-to-a-new-place path in 2b). Pass via `updateGeneral`.
- `MutateNote.createGeneral`/`updateGeneral` gain a `NoteLocation? location` parameter flowing to the repo input/patch.

### Location card UI (`features/notes/presentation/widgets/note_location_card.dart`)

- Small Journal-style card: a pin icon + the label, or `"<lat>, <lng>"` (trimmed precision) when label is null. Optional ✕ (hidden in read-only contexts). Shown in the editor and in the note **detail** view (read-only there).

### Detail view (`features/notes/presentation/screens/note_detail_screen.dart`)

- If `note.location != null`, render `NoteLocationCard(..., readOnly: true)`.

### Sync engine (`lib/core/data/sync/sync_orchestrator.dart`)

- **Outbound** (`_noteRowToBlob`): add `'latitude'`, `'longitude'`, `'locationLabel'` to the blob body.
- **Inbound** (`_applyNote…`): parse the three keys. On **insert**, write them (NULL when absent). On **update**, preserve-on-omit (write `Value` only when the key is present; otherwise `Value.absent()`), mirroring the `noteDate` fix.
- Round-trip test (out + in + preserve-on-omit), like `sync_orchestrator_note_date_test.dart`.

### Permissions & edge cases

- Toggle off ⇒ never fetch, never prompt.
- Denied / `deniedForever` / services-off / timeout ⇒ `currentPositionProvider` returns null ⇒ no card, no crash, no retry loop.
- Reverse-geocode failure ⇒ store lat/lng with a null label; card shows coordinates.
- All-or-none invariant: the repo writes lat+lng together; label may be null independently.

### Client tests

- Repo: create writes the trio; update clears (empty) vs sets vs leaves-absent.
- Settings: `geoCaptureEnabledProvider` defaults false and persists.
- Editor: with the toggle on + a stubbed position provider, a new note attaches `_pendingLocation` on save; ✕ clears it; toggle off ⇒ no fetch/card.
- Sync: round-trip + preserve-on-omit.
- Card widget: renders label, falls back to coordinates, hides ✕ when read-only.

## Sequencing

Backend first (column ready for `cloudApi` later), then client. The client local + `cloudStorage` work ships independently of the backend.

## Out of scope (Phase 2b)

- Map view / location picker / editing to a different place.
- "Notes near here" / proximity queries (the discrete columns leave this open for later).
- API-side clearing of a location (the `cloudApi` note repo doesn't exist yet).
- Voice/PDF media (Phase 3).
