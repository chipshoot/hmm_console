# Automobile Hub — Design

**Date:** 2026-09-19
**Status:** approved (design agreed 2026-09-04; layout reviewed on the
mockup canvas 2026-09-19)
**Mockup:** https://claude.ai/artifact/96in5gAvn7SUbJHMQcL8TC

## Problem

Everything automobile-related is reachable, but from three unrelated places.
The dashboard has a **Gas Log** tile (which opens a vehicle *picker* whose only
job is "choose a vehicle, then open its gas log") and a separate **Licence**
tile; a vehicle's insurance, services and notes are only reachable through
Manage → edit. There is no screen that shows the automobile domain as one
thing.

The user wants one hub per life domain, not a "Documents" bucket — a passport
does not belong on an automobile screen. This spec covers the Automobile hub
only; the Health hub is a later, separate piece of work.

## Goals

- One **Automobile** entry on the dashboard that opens a hub showing the
  licence, then the vehicles.
- Fuel logging stays two taps from the dashboard, as it is today.
- No existing screen moves, no storage changes; the hub is a thin
  navigation-and-summary screen over what already exists.

## Non-goals

- The Health hub.
- Changing the dashboard's icon scheme (emoji tiles stay; a Material-icon
  switch was discussed and deferred as its own change).
- Any change to the launcher registry — `/gas log`, `/vehicles`, `/licence`
  keep jumping straight to their screens.
- Ownership. In `local` and `cloudStorage` there is one workspace and one
  signed-in user; every record is theirs. The licence sits at the top of the
  hub because it describes the person rather than a vehicle — a layout
  decision, not a data-model one.

## Design

### 1. The hub screen

`AutomobileHubScreen` in
`lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart`,
a `ConsumerWidget` on `CommonScreenScaffold`, title **Automobile**, toolbar
action **Manage** → `/automobiles/manage` (the existing vehicle list, where
archive/reorder/add already live).

Body, top to bottom:

1. **Licence card** — reads `driverLicenceStateProvider`.
   - Saved licence: title *Driver's licence*, subtitle
     `{class} · {jurisdiction} · expires {date}` (each part omitted when
     null); tap → `/licence` (the details screen the old tile opened;
     `/licence/show` is the photo-only hand-over view, not a landing).
   - No licence: title *Add your driver's licence*, subtitle *Scan the card
     or type it in*; tap → `/licence`.
   - Loading: the card renders with the title only. Error: same as "no
     licence" (the licence screen shows its own error).
   - **Hidden entirely when `dataModeProvider == DataMode.cloudApi`** —
     `driverLicenceRepositoryModeProvider` throws there. This is the same
     rule the dashboard applies to the Licence tile today; it moves into the
     hub with the tile.
2. **Vehicles** section header.
3. **Vehicle rows** — `automobilesStateProvider`, filtered to `isActive`
   (exactly as the picker does). Each row is the existing
   `AutomobileListTile` (`onTap` → `/automobiles/manage/{id}/edit`) with a
   trailing **fuel button** (44 px target, tooltip (VoiceOver's accessible
   name) *Gas log for {name}*) that does what the picker's row does today:
   `selectedAutomobileIdProvider.notifier.select(id)` then push `/gas-logs`.
   `AutomobileListTile` gains an optional `trailing` widget for this; nothing
   else about it changes.
4. **Add vehicle** row → `/automobiles/manage/new`.
5. Loading, error and empty states mirror the picker: spinner; error text
   with Retry (`automobilesStateProvider.notifier.refresh()`); empty state
   *No vehicles yet* with an **Add vehicle** button. Pull-to-refresh on the
   list, as the picker has.

Text through `AppLocalizations` (new keys in `en` and `zh`; zh unreviewed
like the rest): hub title, vehicles header, add vehicle, licence card titles
and subtitle, empty-state title and body, fuel button label.

### 2. Routing

The hub is mounted at `/automobiles` under the existing route name
`automobileSelector`, replacing `AutomobileSelectorScreen`, which is deleted
(its only caller is the router). Every child route
(`/automobiles/manage/...`) is untouched.

The route name is kept so nothing that navigates by name changes; renaming it
to `automobileHub` is a cosmetic follow-up if wanted.

### 3. Dashboard

In `dashboard_screen.dart`, the `Gas Log` and `Licence` entries in
`_allFunctions` are replaced by one:

```
AppFunction(icon: "🚗", title: "Automobile",
            description: "Licence, vehicles, gas log", route: "automobile")
```

`_navigateToFunction` maps `automobile` → `context.push('/automobiles')`. The
`gas-log` and `driverLicence` cases go, and so does `_visibleFunctions`'
cloudApi filter (the hub now applies that rule to its licence card). The
Automobile tile shows in every mode.

### 4. Vehicle screen: Gas log card

`AutomobileRecordsSummary` gains a `_GasLogSummaryCard` alongside
Insurance / Service history / Scheduled service / Notes, using the same
`_SummaryCard` frame: title *Gas log*; tap → select the vehicle, push
`/gas-logs`. Subtitle is the most recent fill's date when one exists (via
the existing gas-log state for that vehicle), else *No fills yet*. If wiring
a subtitle needs a new provider, ship the card with the title only — the
link is the point.

### 5. Deep-link fix (prerequisite)

`AutomobileEditScreen._populateFromOriginal()` runs once in `initState`
and reads `automobilesStateProvider` synchronously; if the list is still
loading, `_original` stays null and the screen shows *vehicle not found*
forever. Today you always arrive from a loaded list; a hub with pushable
routes makes a cold arrival normal (launcher, app relaunch onto a deep
route).

Fix: in `build`, `ref.listen(automobilesStateProvider, ...)` and call
`_populateFromOriginal()` when data arrives while `_original == null`.
Nothing else in the screen changes.

## Data flow

No new state. The hub composes three existing providers
(`driverLicenceStateProvider`, `automobilesStateProvider`,
`dataModeProvider`) and one existing notifier
(`selectedAutomobileIdProvider`). All navigation is `context.push` on
paths that already exist.

## Error handling

Each card handles its own provider's `AsyncValue`; a licence error never
blanks the vehicle list and vice versa. The cloudApi rule is a mode check,
not a try/catch around the throwing provider.

## Testing

Widget tests with a bare `GoRouter` (the pattern `driver_licence_routes`
tests use), providers overridden:

- `automobile_hub_screen_test.dart`
  - licence card: saved → subtitle and `/licence`; none → *Add your
    driver's licence* and `/licence`; cloudApi → absent.
  - vehicles: active rows only; row tap → `/automobiles/manage/{id}/edit`;
    fuel button → `selectedAutomobileIdProvider` holds the id and location
    is `/gas-logs`; Add vehicle → `/automobiles/manage/new`.
  - empty state and error/Retry.
- `automobile_records_summary_test.dart` (extend or add): Gas log card
  present, tap selects the vehicle and pushes `/gas-logs`.
- `automobile_edit_screen_test.dart` (extend or add): mount with
  `automobilesStateProvider` still loading, resolve it, expect the form
  populated — fails before the fix.
- Dashboard test: one Automobile tile, no Gas Log / Licence tiles, tile
  visible in cloudApi.
- Existing picker tests, if any, are removed with the screen.

## Files

New: `automobile_hub_screen.dart`, its test, ARB keys.
Changed: `router_config.dart`, `dashboard_screen.dart`,
`automobile_list_tile.dart` (trailing slot), `automobile_records_summary.dart`,
`automobile_edit_screen.dart`, `app_en.arb`, `app_zh.arb`.
Deleted: `automobile_selector_screen.dart`.
