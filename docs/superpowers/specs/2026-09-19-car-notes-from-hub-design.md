# Car Notes from the Hub — Design

**Date:** 2026-09-19 (revised 2026-09-22: derived domains replace a per-domain catalog)
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

The first draft of this spec fixed that with a new
`Hmm.AutomobileMan.Note` catalog. That does not scale: health, book, cooking
and insurance notes would each need their own catalog, and each new catalog
costs a palette entry, a label case, l10n keys in two ARB files, and a
server-side catalog before cloudApi users see it. Rejected.

## Goals

- One tap from the hub to a car's notes, with "New note" the obvious action.
- A note attached to a car reads and filters as an **Automobile** note,
  derived — no new catalog, no new column, no migration.
- The same rule serves every future domain (health, books, insurance,
  cooking) the moment that domain has any catalog of its own.

## Non-goals

- Any change to note storage. No schema change, no data migration, no
  re-cataloguing of existing notes: they were never stored wrong.
- Changing which notes the notes list loads, or introducing paging.
- The `Hmm.AutomobileMan.Note` catalog from the first draft. Dropped.

## Design

### 1. Effective domain: a note takes its parent's domain

One expression widens, in `NotesListData`:

```dart
/// Note id -> the domain key its own catalog implies, for every note the
/// list loaded. A note attached to one of these — a car, a policy, a book —
/// takes that note's domain, because the parent IS what the note is about.
final Map<int, String> noteDomainById;
```

built in `NotesListState.build()` beside the existing maps:

```dart
final noteDomainById = {
  for (final n in visibleNotes)
    if (n.catalogId != null && catalogDomainById[n.catalogId] != null)
      n.id: catalogDomainById[n.catalogId]!,
};
```

(Anchor notes are excluded from `visibleNotes`, which is why
`anchorDomainById` stays a separate map rather than being folded in.)

`NotesListData` gains the resolver both the filter and the row use:

```dart
/// The domain a note belongs to: the domain of the thing it is attached to
/// — a subsystem anchor, or any typed record such as a car — falling back
/// to its own catalog's domain when it is attached to nothing.
String? effectiveDomain(HmmNote n) {
  final p = n.parentNoteId;
  if (p != null) {
    final d = anchorDomainById[p] ?? noteDomainById[p];
    if (d != null) return d;
  }
  final c = n.catalogId;
  return c == null ? null : catalogDomainById[c];
}
```

and `visible`'s per-note predicate becomes:

```dart
items = items.where((n) {
  // Its own catalog selected: always a match. Checked first so selecting a
  // single catalog (Insurance, Gas Log) never loses its own notes.
  if (n.catalogId != null && f.contains(n.catalogId)) return true;
  // Otherwise it belongs to whatever it is attached to.
  final p = n.parentNoteId;
  final parentDomain =
      p == null ? null : (anchorDomainById[p] ?? noteDomainById[p]);
  return parentDomain != null && selectedDomains.contains(parentDomain);
});
```

**Consequences, accepted:**
- Selecting one catalog inside a domain (e.g. only *Insurance*) also shows
  General notes attached to that domain's records. This is exactly today's
  behaviour for anchor-attached notes, now applied to cars; the drawer's
  domain groups are the primary filter and select a whole domain anyway.
- Nothing that matches today stops matching: the catalog check runs first,
  so the change is strictly additive.
- Existing car notes are fixed retroactively — they were always attached to
  the car; only the derivation was too narrow. This supersedes the earlier
  "leave existing notes" decision, which assumed a migration that no longer
  exists.
- One hop is enough. A note under a service record resolves through that
  record's own catalog (`Hmm.AutomobileMan.ServiceRecord`); no recursion.

### 2. The row says what the note is about

`note_list_tile.dart:39` labels a row by its catalog, so a car note would
read "General · 12 Sep" while filtering under Automobile. The row shows the
effective context instead:

`NoteListTile` gains two optional parameters — `String? contextLabel` and
`Color? contextColor` — used when non-null:
- secondary line: `'${contextLabel ?? catalogLabel(catalog?.name, l)} · $date'`
- leading dot: `contextColor ?? CatalogPalette.styleFor(catalog?.name).color`

The call site (`notes_list_screen.dart:160-165`) supplies them from
`NotesListData`, via two new helpers there:
- `contextLabelFor(note)` — the parent note's subject when the parent is in
  `noteDomainById` (e.g. *2019 Honda Civic*); for an anchor parent, the
  anchor's domain label (`domainLabel(key, l)`, e.g. *Automobile*); `null`
  when unattached. The subject comes from the already-loaded `all` list, so
  no extra query.
- `contextColorFor(note)` — `CatalogPalette.domainStyle(domain).color` for
  that same domain, `null` when unattached.

So a car note reads **"2019 Honda Civic · 12 Sep"** with the Automobile dot,
and an unattached note is unchanged.

### 3. Hub row: notes button + badge

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

### 4. Vehicle notes screen: New note first

`VehicleNotesScreen` (`vehicle_notes_screen.dart`):
- AppBar title: the car's `displayName` from `automobilesStateProvider`,
  falling back to `recordsVehicleNotes` while loading or if not found.
- Under it, a caption `Automobile · {displayName}`
  (`vehicleNotesDomainCaption`) in `CatalogPalette.domainStyle('AutomobileMan').color`
  — the mockup's chip — so it is clear where a new note lands.
- A full-width `FilledButton.icon` **New note** that pushes
  `/notes/new?parent=$automobileId` and invalidates
  `attachedNotesProvider(automobileId)` on return.
- Below it, `AttachedNotesSection(parentId:, title:, showAdd: false)` — a new
  optional flag (default `true`) hiding the section's own `+` so the screen
  has one add control. The attach (📎) action stays.

`attachedNotesProvider` is unchanged: car notes remain General-catalogue
notes with the car as parent, which is exactly what it already queries.
`MutateNote` is unchanged — no `catalogForParent`, no re-cataloguing on
attach.

### 5. l10n

New keys in `app_en.arb` and `app_zh.arb`, then regenerate `lib/l10n/gen/`:
- `automobileHubNotesFor` — placeholder `name`; en "Notes for {name}"
- `vehicleNotesNew` — en "New note", zh "新建笔记"
- `vehicleNotesDomainCaption` — placeholder `name`; en "Automobile · {name}",
  zh "汽车 · {name}"

## Data flow

Creation: hub 📝 → `/automobiles/manage/{id}/notes` → **New note** →
`/notes/new?parent={id}` → the editor saves a General note with
`parentNoteId = carId` (unchanged code). The notes list then derives
Automobile from the parent. Nothing about the note's storage encodes a
domain, so no future domain needs a storage change either.

## Error handling

- `effectiveDomain` with a parent id that resolves to nothing falls back to
  the note's own catalog domain — a dangling parent must not hide a note.
- The hub badge treats loading and error alike as "no badge"; the notes
  screen shows its own error.

## Testing

- `notes_list_domain_test.dart` (new, unit on `NotesListData`):
  a General note under a car → Automobile, and it survives the Automobile
  domain filter; a General note under a General note → General; an
  unattached General note → General; a note under a dangling parent id →
  its own catalog domain; selecting only the Insurance catalog still shows
  insurance notes (the catalog-first branch).
- `note_list_tile_test.dart` (new or extend): with `contextLabel` the
  secondary line reads "2019 Honda Civic · <date>"; without it, the catalog
  label as before.
- `automobile_hub_screen_test.dart` (extend): the notes button navigates to
  `/automobiles/manage/1/notes`; the badge shows `2` for two attached notes
  and is absent for none.
- `vehicle_notes_screen_test.dart` (new): title is the car name; New note
  pushes `/notes/new?parent=1`; the section's own `+` is absent.

## Files

New: the four tests above.
Changed: `notes_list_state.dart` (map, resolver, predicate, context
helpers), `note_list_tile.dart` (two optional params),
`notes_list_screen.dart` (call site), `automobile_hub_screen.dart`,
`vehicle_notes_screen.dart`, `attached_notes_section.dart` (`showAdd`),
`app_en.arb`, `app_zh.arb`, `lib/l10n/gen/*`.

No new catalog, no new provider, no schema change.
