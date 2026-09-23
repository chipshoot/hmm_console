# Car Notes from the Hub — Design

**Date:** 2026-09-19
**Revised:** 2026-09-22 — derived domains replace a per-domain catalog; a note
attached to a car lives under Automobile *only*; the row names the car.
**Status:** approved (layout reviewed on the mockup canvas, frames 4–5)
**Mockup:** https://claude.ai/artifact/96in5gAvn7SUbJHMQcL8TC
**Builds on:** `2026-09-19-automobile-hub-design.md`

## Problem

A car's notes are three taps deep (hub → car → scroll to Notes → list) and,
once written, file under **General** in the notes list rather than under
**Automobile**.

The storage is not the problem. A car note is a General note whose
`parentNoteId` is the car's note id, and that link is exactly right: the car
*is* a note, so the relation is already modelled and needs no "automobile id"
field. What is too narrow is how the list *derives* a note's domain
(`notes_list_state.dart`, `NotesListData.visible`):

```dart
final attachedDomain = p == null ? null : anchorDomainById[p];
```

A note takes its parent's domain only when that parent is a **subsystem
anchor**. A car is not an anchor, so a car note falls through to its own
catalog's domain: General.

The first draft of this spec fixed that with a new `Hmm.AutomobileMan.Note`
catalog. That does not scale — health, book, cooking and insurance notes
would each need their own catalog, and each one costs a palette entry, a
label case, l10n keys in two ARB files, and a server-side catalog before
cloudApi users see it. Rejected.

## Goals

- One tap from the hub to a car's notes, with "New note" the obvious action.
- A note attached to a car reads and filters as an **Automobile** note,
  derived — no new catalog, no new column, no migration.
- The same rule serves every future domain (health, books, insurance,
  cooking) the moment that domain has any catalog of its own.

## Non-goals

- Any change to note storage. No schema change, no data migration, no
  re-cataloguing: notes were never stored wrong. A car note stays a
  General-catalog note with the car as its parent.
- Changing which notes the list loads, or introducing paging.
- The `Hmm.AutomobileMan.Note` catalog from the first draft. Dropped.

## Design

### 1. A note lives where it is attached

`NotesListState.build()` already computes `catalogDomainById` (catalog id →
domain key) and `anchorDomainById` (subsystem-anchor note id → domain). Add
one more map, built from the notes the list already loaded:

```dart
/// What a note needs to know about the note it is attached to: the domain
/// that note belongs to, and what to call it on screen. Every typed record
/// — a car, a policy, a book — carries its domain in its own catalog name,
/// so this map needs no per-domain knowledge.
typedef AttachTarget = ({String domain, String subject});

final targetsById = {
  for (final n in visibleNotes)
    if (n.catalogId != null && catalogDomainById[n.catalogId] != null)
      n.id: (domain: catalogDomainById[n.catalogId]!, subject: n.subject),
};
```

(Anchor notes are excluded from `visibleNotes`, which is why
`anchorDomainById` stays a separate map rather than being folded in.)

`NotesListData` exposes what the filter and the row both need:

```dart
/// The domain of the thing this note is attached to, when that thing
/// carries one: a subsystem anchor, or any typed record such as a car.
String? parentDomainOf(HmmNote n) {
  final p = n.parentNoteId;
  if (p == null) return null;
  return anchorDomainById[p] ?? targetsById[p]?.domain;
}

String? ownDomainOf(HmmNote n) =>
    n.catalogId == null ? null : catalogDomainById[n.catalogId];

/// Where the note lives: what it is attached to, falling back to its own
/// catalog. A dangling parent resolves to neither, so the note keeps its
/// catalog's domain rather than disappearing.
String? effectiveDomain(HmmNote n) => parentDomainOf(n) ?? ownDomainOf(n);

/// The parent's subject, for rows and search. Null when unattached, or when
/// the parent is an anchor (anchors are not in the loaded set).
String? contextSubjectOf(HmmNote n) =>
    n.parentNoteId == null ? null : targetsById[n.parentNoteId]?.subject;
```

`visible`'s per-note predicate becomes:

```dart
items = items.where((n) {
  final own = ownDomainOf(n);
  final parent = parentDomainOf(n);
  // Attached to something in ANOTHER domain — a General note under a car.
  // It lives there and nowhere else, so General keeps meaning "attached to
  // nothing in particular". This is what the code already did for notes
  // attached to a subsystem anchor; cars now count too.
  if (parent != null && parent != own) return selectedDomains.contains(parent);
  // Otherwise the note is a record of its own domain, so it filters by its
  // exact catalog: picking "Insurance" must not drag in every car note.
  return n.catalogId != null && f.contains(n.catalogId);
});
```

Worked through:

| Note | Own domain | Parent | Automobile filter | General filter |
|---|---|---|---|---|
| General note under a car | General | AutomobileMan | shown | hidden |
| General note under the Automobile anchor | General | AutomobileMan | shown | hidden (unchanged) |
| Service record under a car | AutomobileMan | AutomobileMan | shown (exact catalog) | hidden |
| Gas log under a car | AutomobileMan | AutomobileMan | shown (exact catalog) | hidden |
| The car itself | AutomobileMan | — | shown | hidden |
| Unattached General note | General | — | hidden | shown |
| General note under a General note | General | General | hidden | shown |
| Note under a deleted/unloaded parent | General | — | hidden | shown |

Selecting a single catalog inside a domain (only *Insurance* in the filter
sheet) still shows General notes attached to that domain's records, because
`selectedDomains` is derived from the chosen catalogs. That is the existing
behaviour for anchor-attached notes and is accepted.

### 2. The row names what the note is about

The subject line is what people scan, and it is what travels to search
results and pickers, so the context goes there:

```
● Oil change receipt (2019 Honda Civic)
  Replaced filter and wipers, 84,210 km
  Automobile · 12 Sep 2026
```

Rules:
- **Rendered, never stored.** `note.subject` stays `"Oil change receipt"`.
  The parenthetical is composed at draw time; writing it into the subject
  would duplicate on the next render and pollute sync and the editor.
- **Never truncated.** A concatenated string ellipsizes exactly where the
  context is, so the title is a `Row`: `Flexible(Text(subject, overflow:
  ellipsis))` then `Text(' ($context)')` in a muted style. The subject loses
  characters; the car never does.
- **Ellipsized source.** The context is the parent's subject, trimmed to 20
  characters with a trailing `…` — no per-domain cleverness, so a health
  note reads `(Dr. Chen)` and a book note `(The Pragmatic Prog…)`. For an
  anchor parent there is no subject, so the localized domain label is used
  (`domainLabel(key, l)` → "Automobile").
- Shown whenever the note has a resolvable parent, including typed records
  (a gas log reads `(2019 Honda Civic)`, which is how you tell two cars
  apart). If that proves noisy, restricting it to `parent != own` is a
  one-line change.

The title and the secondary line carry different things: the title names the
specific parent ("2019 Honda Civic"), the secondary names the domain
("Automobile"), which is the filter the note now appears under — showing
"General" there is the inconsistency being fixed.

`NoteListTile` gains three optional parameters, each replacing existing
behaviour only when non-null:
- `String? titleContext` — the parenthetical after the subject.
- `String? contextLabel` — replaces the catalog label on the secondary line:
  `'${contextLabel ?? catalogLabel(catalog?.name, l)} · $date'`.
- `Color? contextColor` — replaces the leading dot's catalog colour.

The call site (`notes_list_screen.dart:160-165`) supplies them from
`NotesListData`, and passes all three as null for an unattached note, which
therefore renders exactly as it does today:
- `titleContext` — `contextSubjectOf(note)` trimmed to 20 characters, else
  the localized domain label when the parent is an anchor.
- `contextLabel` — `domainLabel(effectiveDomain(note), l)` when the note has
  a domain-bearing parent.
- `contextColor` — `CatalogPalette.domainStyle(effectiveDomain(note)).color`
  for the same case.

### 3. Search matches the context

`visible` filters on `n.subject` alone, so typing "Honda" would find nothing
even though the rows say Honda. The query matches the subject **or** the
parent's subject:

```dart
items = items.where((n) =>
    n.subject.toLowerCase().contains(q) ||
    (contextSubjectOf(n)?.toLowerCase().contains(q) ?? false));
```

### 4. Hub row: notes button + badge

In `AutomobileHubScreen._VehicleRow`, `trailing` becomes a `Row` of two
44-px buttons — **notes** (`Icons.sticky_note_2_outlined`, tooltip
`automobileHubNotesFor(name)` → "Notes for {name}") then the existing
**fuel** button — followed by the chevron: three controls per row, per the
2026-09-19 decision. The notes button pushes
`/automobiles/manage/{id}/notes`.

Badge: the button watches `attachedNotesProvider(automobile.id)` and wraps
its icon in `Badge(label: Text('$n'))` when the value is a non-empty list;
loading, error and empty show no badge. `AutomobileListTile` needs no
change — it already takes `trailing` and suppresses its own chevron when one
is given, so the row supplies the chevron after the buttons.

### 5. Vehicle notes screen: New note first

`VehicleNotesScreen` (`vehicle_notes_screen.dart`):
- AppBar title: the car's `displayName` from `automobilesStateProvider`,
  falling back to `recordsVehicleNotes` while loading or if not found.
- Under it, a caption `Automobile · {displayName}`
  (`vehicleNotesDomainCaption`) in
  `CatalogPalette.domainStyle('AutomobileMan').color` — the mockup's chip —
  so it is clear where a new note lands.
- A full-width `FilledButton.icon` **New note** that pushes
  `/notes/new?parent=$automobileId` and invalidates
  `attachedNotesProvider(automobileId)` on return.
- Below it, `AttachedNotesSection(parentId:, title:, showAdd: false)` — a new
  optional flag (default `true`) hiding the section's own `+` so the screen
  has one add control. The attach (📎) action stays.

`attachedNotesProvider` and `MutateNote` are unchanged: car notes remain
General-catalog notes with the car as parent, which is exactly what the
provider already queries and what the editor already writes from
`?parent=<id>`.

### 6. l10n

New keys in `app_en.arb` and `app_zh.arb`, then regenerate `lib/l10n/gen/`:
- `automobileHubNotesFor` — placeholder `name`; en "Notes for {name}"
- `vehicleNotesNew` — en "New note", zh "新建笔记"
- `vehicleNotesDomainCaption` — placeholder `name`; en "Automobile · {name}",
  zh "汽车 · {name}"

## Data flow

Creation: hub 📝 → `/automobiles/manage/{id}/notes` → **New note** →
`/notes/new?parent={id}` → the editor saves a General note with
`parentNoteId = carId` (unchanged code). The list derives Automobile from
the parent. Nothing about a note's storage encodes a domain, so no future
domain needs a storage change either.

## Error handling

- A parent id that resolves to neither map falls back to the note's own
  catalog domain — a dangling parent must never hide a note.
- The hub badge treats loading and error alike as "no badge"; the notes
  screen shows its own error.

## Testing

- `notes_list_domain_test.dart` (new, unit on `NotesListData` — it is a
  plain data class, so no widgets): every row of the table in §1, plus
  search matching the parent's subject.
- `note_list_tile_test.dart` (new): with a title context the row reads
  "Oil change receipt (2019 Honda Civic)"; a long subject ellipsizes while
  the parenthetical stays; without a context the row is unchanged.
- `automobile_hub_screen_test.dart` (extend): the notes button navigates to
  `/automobiles/manage/1/notes`; the badge shows `2` for two attached notes
  and is absent for none.
- `vehicle_notes_screen_test.dart` (new): title is the car name; New note
  pushes `/notes/new?parent=1`; the section's own `+` is absent.

## Files

New: the four tests above.
Changed: `notes_list_state.dart` (map, resolvers, predicate, search),
`note_list_tile.dart` (title row + two optional params),
`notes_list_screen.dart` (call site), `automobile_hub_screen.dart`,
`vehicle_notes_screen.dart`, `attached_notes_section.dart` (`showAdd`),
`app_en.arb`, `app_zh.arb`, `lib/l10n/gen/*`.

No new catalog, no new provider, no schema change.
