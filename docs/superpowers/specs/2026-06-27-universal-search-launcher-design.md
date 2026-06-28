# Universal Search Launcher — Design

**Date:** 2026-06-27
**Status:** Approved (brainstorm) — pending implementation plan
**Repo:** `hmm_console` (Flutter client) only. No backend change.

## Goal

A search box on the home screen that fuzzy-matches a registry of **destinations** (features + sub-screens) and jumps you there — a Spotlight-style launcher. It **augments** the dashboard tiles (doesn't replace them) and fixes the discoverability asymmetry where some functions (e.g. service records) are buried under vehicle info while others (Gas Log) get a tile. Built-in fuzzy matching + synonyms work with zero setup; users can additionally **pin favorites** and add **custom aliases** (e.g. `cs` → Car Services) — the user-configurable "function keys".

## Decisions (locked during brainstorm)

1. **Fuzzy search, not exact slash-commands.** Plain typing matches; a leading `/` is stripped (so `/gaslog` still works) but never required. Mobile-correct: forgiving, no memorization.
2. **Destinations, not data.** v1 indexes screens/features. Searching a specific note/vehicle by name (data entities) is a logged future extension.
3. **Smart vehicle-context resolution.** A per-vehicle destination launched with no vehicle selected resolves: last-used vehicle → single vehicle → else the picker (which continues to the destination).
4. **Customization = favorites + aliases.** Pin/reorder favorites + add `alias → destination` rows, persisted and synced. Not a full user-defined keyword table.
5. **Recents are device-local** (not synced); favorites + aliases are synced.

## Components

### Destination registry

- `lib/features/launcher/domain/launcher_destination.dart` — `class LauncherDestination { final String id; final String title; final List<String> synonyms; final IconData icon; final String routeName; final bool needsVehicle; }`. `id` is a stable string (e.g. `'gasLog'`), `routeName` is a `RouterNames` value's `.name`.
- `lib/features/launcher/domain/launcher_registry.dart` — `const launcherDestinations = [ ... ]`, seeded from existing routes:
  - Automobile info/manage (`automobileManagement`), Gas Log (`gasLogList`, needsVehicle), Service log (`serviceRecords`, needsVehicle), Scheduled services (`scheduledServices`, needsVehicle), Insurance (`insurancePolicies`, needsVehicle), Vehicle notes (`vehicleNotes`, needsVehicle), Notes (`notesList`), Settings (`settings`).
  - Each carries synonyms (e.g. Gas Log → `['gas','fuel','fill-up','petrol','mileage']`; Service log → `['service','maintenance','repair','car service']`).
  - This becomes the single source of truth; the dashboard's `_allFunctions` list is refactored to derive from it (so tiles and search stay in sync).

### Matcher (pure, testable)

- `lib/features/launcher/domain/launcher_matcher.dart` — `List<LauncherDestination> match(String query, {required List<LauncherDestination> registry, required Map<String,String> aliases})`. Strips a leading `/`, lowercases. Ranking, highest first:
  1. **exact alias** hit (`aliases[query] == dest.id`),
  2. **title/synonym prefix**,
  3. **substring** in title/synonyms,
  4. **subsequence** (fuzzy) in title.
  Ties broken alphabetically by title. Empty query → returns `const []` (the screen shows favorites/recents instead). No Flutter imports — unit-tested in isolation.

### Vehicle-context resolution

- `lib/features/launcher/domain/resolve_vehicle_context.dart` — `Future<int?> resolveVehicleContext(WidgetRef ref)`: returns the `selectedAutomobileIdProvider` value if set; else if exactly one automobile exists, that id; else `null`. One helper, reused by every `needsVehicle` launch.
  - **Resolved id →** the launcher navigates straight to the destination: `goNamed(routeName, pathParameters: {'id': '$id'})`.
  - **Null →** the launcher routes to the **automobile selector** (`automobileSelector`, the existing `/automobiles` entry) so the user picks a vehicle, then proceeds through that feature's normal flow. v1 does **not** implement a generic "resume the exact destination after picking" — landing the user at the vehicle picker is sufficient and matches the current per-feature entry. (Resuming the exact sub-destination post-pick is a possible later refinement.)

### Prefs (favorites + aliases, synced)

- `lib/features/launcher/domain/launcher_prefs.dart` — `class LauncherPrefs { final List<String> favorites; final Map<String,String> aliases; toJson/fromJson/copyWith }` (ids + alias→id).
- Persisted **inside the existing `SyncableSettings` bundle**: add a `launcher` field to `SyncableSettings` (`toJson`/`fromJson`/`copyWith`), so it syncs across devices with the rest of the settings (whole-bundle LWW). Default = empty prefs; absent on the wire = empty (back-compat).
- `lib/features/launcher/providers/launcher_prefs_provider.dart` — a Notifier reading/writing through `SyncableSettingsRepository` (mirroring `gasLogSettingsProvider`), so pinning a favorite or adding an alias bumps `lastModified` and the settings bus.

### Recents (device-local)

- `lib/features/launcher/providers/launcher_recents_provider.dart` — a Notifier persisting a capped (8) list of destination ids in `shared_preferences` (a dedicated key, NOT the synced bundle). `record(id)` moves it to front, dedups, trims.

### UI

- `lib/features/launcher/presentation/launcher_search_screen.dart` — a focused full-screen search route: a top text field (autofocus, keyboard up) + a results list. Live results from `match(...)`; with an empty query, show **pinned favorites** then **recents** (resolved from ids → destinations, skipping unknown ids). Tapping a result: record it as a recent, then navigate via `resolveVehicleContext` for `needsVehicle` destinations or `goNamed` directly otherwise.
- Home-screen entry: a search bar / tap target on `dashboard_screen.dart` that opens the launcher search route.
- `lib/features/launcher/presentation/launcher_manage_screen.dart` — reached from Settings: pin/unpin + reorder favorites; add/edit/remove `alias → destination` rows with inline validation (non-empty alias, no duplicate alias, destination must exist).
- Routes added to `RouterNames` + `router_config.dart`: `launcherSearch`, `launcherManage`.

## Error handling / edge cases

- Unknown destination id in favorites/recents/aliases → skipped silently (registry is the source of truth; a removed destination just disappears).
- `needsVehicle` launch with **zero** vehicles → route to the automobile management/"add vehicle" screen with a hint snackbar.
- Alias collision in the manage screen → blocked with inline validation (last edit wins only via explicit overwrite).
- A `/`-prefixed query is normalized; an all-whitespace query is treated as empty.

## Testing

- **Matcher** (pure): exact-alias > prefix > substring > subsequence ordering; synonyms match; `/`-prefix stripped; empty/whitespace query → empty.
- **resolveVehicleContext**: last-used set → that id; none + single vehicle → that id; none + multiple → null; (fake automobiles + selected-id providers).
- **LauncherPrefs**: round-trips through `toJson`/`fromJson`; survives the `SyncableSettings` bundle round-trip; absent `launcher` field → empty prefs.
- **Recents**: `record` moves-to-front/dedups/caps at 8; persists across provider rebuilds.
- **Registry integrity**: every `LauncherDestination.routeName` is a real `RouterNames` value; `needsVehicle` destinations' routes accept an `id` path param.
- **Widgets**: search screen — type a query → matching results → tap navigates (and records a recent); empty query shows favorites then recents. Manage screen — add an alias, pin a favorite (assert prefs updated + persisted).

## Sequencing

Build inside-out: registry + matcher + prefs/recents (pure, fully tested) → vehicle-context helper → search screen + home entry → manage screen + Settings link → wire `SyncableSettings.launcher`. The dashboard-tile refactor (derive tiles from the registry) is a small follow-on once the registry exists.

## Out of scope

- **Data-entity search** (find a specific note/vehicle/gas-log by name/content) — logged as the natural next extension; the matcher + registry are designed so an entity provider can be layered in later.
- Full user-defined keyword→route table (chose favorites + aliases).
- Voice search, global full-text search, server-side search.
- Replacing the dashboard tiles (the launcher augments them).
