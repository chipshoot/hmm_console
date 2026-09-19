# Car Notes from the Hub — Design

**Date:** 2026-09-19
**Status:** approved (layout reviewed on the mockup canvas, frames 4–5)
**Mockup:** https://claude.ai/artifact/96in5gAvn7SUbJHMQcL8TC
**Builds on:** `2026-09-19-automobile-hub-design.md`

## Problem

A car's notes are three taps deep (hub → car → scroll to Notes → list) and,
once written, file under **General** in the notes list rather than under
**Automobile**. Both follow from how car notes are stored today: a plain
General-catalog note whose `parentNoteId` is the car's note id. The parent
link is right — it is what ties a note to *this* car — but the catalog is
wrong, and the entry point is buried.

The notes list already treats "attached to the Automobile *subsystem anchor*"
as Automobile-domain (`notes_list_state.dart`, `anchorDomainById`). That rule
covers the anchor only, not individual cars, so car notes fall through to
their catalog's domain: General.

## Goals

- One tap from the hub to a car's notes, with "New note" the obvious action.
- A note created for a car is an **automobile** note tied to **that car**,
  with nothing for the user to pick.
- No new "automobile id" field: the car *is* a note and `parentNoteId`
  already carries the relation.

## Non-goals

- Reclassifying notes already attached to cars. They stay General-with-parent
  (user decision 2026-09-19); they still appear under the car and still file
  under General in the notes list.
- Any change to the subsystem-anchor domain rule in the notes list.
- A cloudApi migration: the local DB creates catalogs on demand (the
  `ensureGeneralCatalog` pattern); the Hmm API would need the catalog
  server-side before cloudApi users see it. Out of scope here.

## Design

### 1. Catalog `Hmm.AutomobileMan.Note`

New file `lib/features/automobile_records/data/automobile_note_catalog.dart`
with `const automobileNoteCatalogName = 'Hmm.AutomobileMan.Note'` and
`Future<NoteCatalog> ensureAutomobileNoteCatalog(Ref ref)` — the same
get-or-create shape as `ensureGeneralCatalog`, markdown schema, markdown
format type. Plus `automobileNoteCatalogProvider` (a `FutureProvider`).

Presentation registrations, following the existing entries for
`Hmm.AutomobileMan.GasLog`:
- `CatalogPalette` (`lib/core/notes/catalog_palette.dart`): a
  `CatalogStyle('Car Note', <colour>)` entry. Its domain key is derived from
  the middle segment, so it is already `AutomobileMan`.
- `catalogLabel` (`lib/features/notes/presentation/catalog_labels.dart`): a
  case returning a new l10n key `catalogAutomobileNote` — en "Car note", zh
  "车辆笔记".

### 2. Creation picks the catalog from the parent

`MutateNote` (`lib/features/notes/states/mutate_note_state.dart`) gains

```dart
/// The catalog a new note attached to [parentNoteId] belongs in: a note
/// under a car is an automobile note; anything else is General.
Future<NoteCatalog> catalogForParent(int? parentNoteId)
```

which loads the parent note (when non-null) and returns
`ensureAutomobileNoteCatalog` when the parent's catalog name is
`Hmm.AutomobileMan.AutomobileInfo`, else `ensureGeneralCatalog`.
`createGeneral` calls it instead of `ensureGeneralCatalog` directly. Nothing
in the editor changes: `/notes/new?parent=<carId>` already presets the parent,
and the rule runs at save. `updateGeneral` never touches the catalog.

**Attach existing:** `attachExisting(noteId, parentNoteId)` sets the parent
and then, when `catalogForParent` yields a different catalog than the note
has, moves the note into it. The picker (`getUnattachedNotes(general.id)`)
is unchanged — it offers standalone General notes, which is what "attach
one I wrote earlier" means. `detachNote` / `setParent` (the editor's
subsystem strip, which offers anchors, never cars) are unchanged.

### 3. Listing a car's notes

`attachedNotesProvider(parentId)` (`attached_notes_state.dart`) queries
`getNotes(parentNoteId:, catalogId: general.id)` today. It becomes the union
of that and the same query for the automobile-note catalog, sorted newest
first by `effectiveNoteDate`. So old General car notes and new automobile
notes appear together under the car; gas logs and records (other catalogs,
same parent) stay excluded as they are now.

The notes list needs no change: an `Hmm.AutomobileMan.Note` note has
`catalogDomainById == 'AutomobileMan'` and the filter sheet lists the new
catalog under Automobile once it exists.

### 4. Hub row: notes button + badge

In `AutomobileHubScreen._VehicleRow`, `trailing` becomes a `Row` of two
44-px buttons: **notes** (`Icons.sticky_note_2_outlined`, tooltip
`automobileHubNotesFor(name)` → "Notes for {name}") then the existing
**fuel** button, followed by the chevron (three controls per row, user
decision). The notes button pushes `/automobiles/manage/{id}/notes`.

Badge: the button watches `attachedNotesProvider(automobile.id)`; when the
value is a non-empty list it wraps the icon in `Badge(label: Text('$n'))`;
loading, error and empty show no badge. `AutomobileListTile` needs no
further change (it already takes `trailing`); its chevron is suppressed when
`trailing` is given, so the row supplies its own chevron after the buttons.

### 5. Vehicle notes screen: New note first

`VehicleNotesScreen` (`vehicle_notes_screen.dart`):
- AppBar title: the car's `displayName` (from `automobilesStateProvider`;
  falls back to `recordsVehicleNotes` while loading or if not found).
- Under the title, a caption line `Automobile · {displayName}` in the domain
  colour — the mockup's chip — via a small `Text` with the existing
  `CatalogPalette.domainStyle('AutomobileMan').color`.
- A full-width `FilledButton.icon` **New note** (`Icons.add`,
  `notesNewNote` if such a key exists, else new key `vehicleNotesNew` = "New
  note") that pushes `/notes/new?parent=$automobileId` and invalidates
  `attachedNotesProvider(automobileId)` on return.
- Below it, `AttachedNotesSection(parentId:, title:, showAdd: false)` — a new
  optional flag (default `true`) that hides the section's own `+` icon so the
  screen has one add control. The attach (📎) icon stays in the section.

### 6. l10n

New keys in `app_en.arb` and `app_zh.arb`: `catalogAutomobileNote`,
`automobileHubNotesFor` (placeholder `name`), `vehicleNotesNew`,
`vehicleNotesDomainCaption` (placeholder `name`, en "Automobile · {name}",
zh "汽车 · {name}"). Regenerate `lib/l10n/gen/`.

## Data flow

Creation: hub 📝 → `/automobiles/manage/{id}/notes` → **New note** →
`/notes/new?parent={id}` → editor save → `MutateNote.createGeneral` →
`catalogForParent(id)` → parent is `AutomobileInfo` → automobile-note
catalog → `createNote(catalogId:, parentNoteId: id)`.

No schema change: `Notes.catalogId` and `Notes.parentNoteId` already exist;
the catalog row is created on first use like General.

## Error handling

- `catalogForParent` with a parent id that no longer resolves falls back to
  General (a dangling parent is not a reason to refuse the note).
- The badge treats a failed count as "no badge"; the notes screen shows its
  own error.

## Testing

- `mutate_note_catalog_test.dart` (new, unit with a fake note repo):
  `catalogForParent(null)` → General; parent in `AutomobileInfo` → automobile
  note; parent in General → General; `createGeneral(parentNoteId: car)`
  creates with the automobile-note catalog; `attachExisting` onto a car
  re-catalogues a General note.
- `attached_notes_state_test.dart` (new or extend): a car with one General
  and one automobile-note child returns both; a gas-log child is excluded.
- `automobile_hub_screen_test.dart` (extend): notes button navigates to
  `/automobiles/manage/1/notes`; badge shows `2` when two notes are attached
  and is absent when none.
- `vehicle_notes_screen_test.dart` (new): title is the car name; New note
  pushes `/notes/new?parent=1`; the section's own `+` is absent.
- Catalog label test if one exists for `catalogLabel`: the new name maps to
  "Car note".

## Files

New: `automobile_note_catalog.dart`, the four tests above.
Changed: `mutate_note_state.dart`, `attached_notes_state.dart`,
`attached_notes_section.dart` (flag), `automobile_hub_screen.dart`,
`vehicle_notes_screen.dart`, `catalog_palette.dart`, `catalog_labels.dart`,
`app_en.arb`, `app_zh.arb`, `lib/l10n/gen/*`.
