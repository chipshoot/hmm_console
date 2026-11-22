# Activity log (shared service) — design

Status: draft for owner review, 2026-11-21.
Roadmap: `docs/superpowers/specs/2026-11-17-health-and-home-assistant-roadmap-design.md`
(this is the activity half of stage 2, built first as its own project; rules
R1–R10 there bind this design).

## 1. Intent

The owner has diabetes and wants to record daily activity with little effort,
so it can sit next to blood sugar later and an AI can review it and suggest
changes. Activity is not only a health thing: book reading and development work
are activities too, and future subsystems for them should log into the same
place in the same shape.

So the activity log is a **shared service**, like the calendar: one catalog of
activity notes, one repository interface, one entry format that every area
uses. Health is the first consumer; reading and development get basic kinds
now and their own fields later.

Why the shape matters now: the future AI (roadmap stages 4–5) reads notes, not
the app. Entries written from day one must be typed, self-describing and
comparable across areas, so the AI can answer "how did walking after dinner
affect my readings" or "how much did I read this month" without guessing.

## 2. Goals, non-goals, anti-goals

**Goals (v1)**
- Log an activity **after the fact** in a few taps: kind, duration, done.
- Health kinds with full detail: walk, run, cycling, gym, swim, yoga, other
  (intensity, duration, optional distance).
- Reading and coding kinds with the basics: duration, a free note, and a link to
  a book note or project note.
- One Activity list, filterable by area; a dashboard tile and a launcher
  destination with quick add.
- An entry can link to a calendar event occurrence; logging against it marks
  that occurrence done.
- A JSON Schema for the entry, a repository contract test suite, and entries
  that follow roadmap R1 (schemaVersion, offset times, explicit units, source).

**Non-goals (v1)** — each is a later step:
- Live start/stop timer, lock-screen widget.
- Apple Health / automatic import (roadmap stage 3; `source: appleHealth`
  is reserved in the schema now).
- Reading or development specific fields (pages, chapter, commits).
- Food, blood sugar, the diabetes "today" view and trends (rest of stage 2).
- AI review, suggestions, actions (stage 4/5). The format supports drafts
  (R5), but no approve flow ships in v1.
- Cloud API mode (unavailable, like the calendar).
- Charts, streaks, goals.

**Anti-goals** — would be a failure even if it works:
- Logging takes more than a few taps for the common case.
- An area's own data changes or breaks the shared fields.
- Data the AI needs lives only in prefs or only on one device.
- **Embeddings or other model-derived data stored in notes.** Indexes belong to
  the home assistant (roadmap 4.1 A) and are rebuilt from notes.

## 3. Constraints (facts about the project today)

- Everything is a note in the Drift `Notes` table; subsystem entries are notes
  in their own catalog with JSON content (calendar: `Hmm.CalendarMan.Event`,
  `local_calendar_repository.dart`, note uuid = event id).
- Calendar is the pattern to copy: `ICalendarRepository` in `contract/`, a
  local implementation over notes, a codec that keeps unknown keys
  (`CalendarEventCodec`), a shared contract test
  (`test/features/calendar/contract/calendar_repository_contract.dart`), a schema
  at `docs/schemas/calendar.event.schema.json`, and `CalendarCloudApiUnavailable`
  in Cloud API mode.
- `setOccurrence` on the calendar repository marks an occurrence done/skipped.
- New screens need a `HelpId` + help entry + `HelpButton`; icon buttons use
  `HmmIconButton`; deletes use `showUndoableAction`; iOS uses Cupertino widgets
  (CLAUDE.md).
- The launcher registry (`launcher_registry.dart`) and the dashboard tile list
  are where new destinations go.
- The codec rule for every catalog: unknown keys and unknown list entries are
  kept and written back, so an older build never strips a newer build's data.

## 4. Approaches

| | Approach | Trade-off |
|---|---|---|
| **A (chosen by owner)** | Activity is its own feature and catalog, built like the calendar, with a code **kind registry**; areas add kinds, and area-only fields live in a per-area section. | New storage and screens to build, but one format for everything, which the AI needs. |
| B | Activities are calendar events marked done. | Calendar view for free, but clutters the calendar, mixes reminders/repeat rules into logs, and the AI must separate logs from appointments. The event link in A keeps the useful part. |
| C | Each area stores its own activity notes; a shared contract gathers them (like linked dates). | Fits the "kind of" idea, but reading/dev have no feature to store them yet, and the AI would learn one format per area, against the "same shape" goal. |

## 5. Decisions

### 5.1 Owner decisions (2026-11-21)
- Manual logging first; automatic tracking later.
- Activity is shared across subsystems (health first; reading, development and
  others later), not part of diabetes.
- An LLM will later review activities, suggest, and maybe act.
- No embeddings in notes (owner agreed with the reasoning).
- Log afterwards, not a timer, in v1.
- Scope as in §2 Goals.
- Activity is built before the diabetes logs.
- Food stays out of Activity (belongs to diabetes logs; an activity may link to
  a meal).
- Approach A.
- The dashboard tile counts health activities only.

### 5.2 The entry (note content, catalog `Hmm.ActivityMan.Activity`)

Note uuid = activity id; note subject `Activity:<id>` (same convention as
`Event:<id>`).

```json
{
  "schemaVersion": 1,
  "id": "6f1c…",
  "kind": "health.walk",
  "start": "2026-11-21T18:40:00-05:00",
  "durationMinutes": 30,
  "intensity": "moderate",
  "measurements": [ { "name": "distance", "value": 2.4, "unit": "km" } ],
  "links": [ { "noteUuid": "…", "role": "meal" } ],
  "plannedEvent": { "eventId": "…", "occurrence": "floating:2026-11-21T18:30", "at": "2026-11-21T18:30:00-05:00" },
  "notes": "after dinner, felt fine",
  "details": { "health": { } },
  "source": "manual",
  "draft": false,
  "updatedAt": "2026-11-21T19:12:03Z"
}
```

- **Required:** `schemaVersion`, `id`, `kind`, `start`, `durationMinutes`,
  `source`, `updatedAt`. Everything else optional.
- **`start`** is ISO 8601 with the UTC offset (R1). The list groups by the
  start's local calendar day. Duration is whole minutes, 1 to 1440 (my call);
  an activity may cross midnight and stays under its start day.
- **`intensity`**: `light | moderate | vigorous` (the common exercise
  guidance scale; my call), optional, defaulted per kind.
- **`measurements`**: each has a `name`, a number `value` and an explicit
  `unit` (R1). v1 uses only `distance` (`km` or `mi`, following the device
  locale's default, the unit stored with each value; my call).
- **`links`**: notes this activity relates to, each with a free `role` string
  (`book`, `project`, `meal`, …). A link to a deleted note stays and shows as
  "removed".
- **`plannedEvent`**: optional link to one calendar occurrence (see 5.5).
  `occurrence` is the calendar's own occurrence key (`EventTime.wireKey` of the
  occurrence's original start: `fixed:…`, `floating:…` or `allDay:…`), so it
  matches the calendar exactly even for repeating floating events after travel
  or a clock change; `at` is the same moment as an ISO time with offset, kept
  only so the AI can read it without knowing calendar internals (my call,
  after the builder check).
- **`details`**: per-area sections keyed by area id. Shared fields never move
  into it; area fields never move out. v1 writes none but keeps any it finds.
- **`source`**: `manual | appleHealth | assistant` (R1). v1 writes `manual`.
- **`draft`**: true only for entries the assistant proposes (R5). v1 shows a
  "Draft" label on such entries; approve / discard ships with the assistant.
- Codec keeps unknown keys, unknown measurement/link entries, and wrong-typed
  known values, exactly like `CalendarEventCodec`.

### 5.3 Kind registry (code, not data)

A kind is `{id, area, label (l10n), icon, defaultIntensity?, measurements}`.
Ids are `<area>.<name>`. v1 kinds:

| Area | Kinds | Distance offered |
|---|---|---|
| `health` | walk, run, cycling, gym, swim, yoga, other | walk, run, cycling, swim |
| `reading` | reading | — |
| `development` | coding | — |

Areas register kinds through one registration list, so a future subsystem adds
its kinds without editing Activity code beyond that list (my call; mirrors
`datedNoteSourcesProvider`). An entry whose kind this build doesn't know shows
as "Other" with its stored id, is editable for shared fields only, and keeps its
kind when saved.

### 5.4 Repository (contract)

`IActivityRepository` in `lib/features/activity/contract/`:
- `activitiesBetween(from, to, {Set<String>? areas})` — by start, newest first.
- `getActivity(id)` — null when absent/deleted; throws an "unreadable" error
  when stored but undecodable (same rule as calendar).
- `saveActivity(a)` — upsert by id, sets `updatedAt`.
- `deleteActivity(id)` — soft delete; missing id is a no-op.
- `changes()` — emits on local edits and sync pulls; **no emission for the
  initial snapshot** (lesson from calendar stage 1).

A local implementation over notes for `local` and `cloudStorage`; Cloud API
throws an `ActivityCloudApiUnavailable` and the screens show the same kind of
"not available in this mode" state as the calendar. A shared contract test suite
runs against the local implementation (and any future API one).

### 5.5 Calendar link

- On the activity form, "Planned session" offers today's and yesterday's
  calendar occurrences (my call: recent ones only; enough for "log what I just
  did"), **timed occurrences only, not cancelled or already done/skipped, and
  never linked events** (birthdays, expiries and other events owned by a
  `DatedNoteSource` subsystem are dates, not sessions; my call). Owner-made
  events and future health-plan events qualify. Picking one sets the start to
  the occurrence's start (or its moved time) and stores `plannedEvent`.
- Saving marks that occurrence done via `setOccurrence`. Removing the link or
  deleting the activity does **not** un-mark it (my call: the owner may have
  marked it done themselves; undoing is one tap in the calendar).
- The event detail screen shows "Logged: Walk · 30 min" when an activity links
  to the occurrence.

### 5.6 Screens

```
Activity                      [?] [+]
[All] [Health] [Reading] [Dev]
Today
  🚶 Walk · 30 min · moderate · 2.4 km     18:40
  📖 Reading · 40 min · "Dune"              21:00
Yesterday
  🏋 Gym · 45 min · vigorous               07:10
```

- **List** at `/activity`: grouped by day, area filter chips, swipe/long-press
  delete with `showUndoableAction`, tap to edit. Empty state with "Log
  activity".
- **Form** at `/activity/new` and `/activity/<id>`: kind picker (recent kinds
  first), duration (quick chips 15/30/45/60 + custom), "ended" time (default
  now; start = ended − duration), intensity, distance when the kind offers it,
  linked note (uses the existing note picker), planned session, notes. Save is
  enabled once kind and duration are set.
- **Dashboard** tile "Activity" showing **health activities only**: "Active
  today: 45 min" (sum of today's `health.*` durations by local start day;
  reading and coding are not counted; owner decision 2026-11-21), opening the
  list;
  **launcher** destination "Activity" plus "Log activity".
- Help entries for both screens. Platform rules from CLAUDE.md.
- Activity notes in the Notes list display as "Walk · 30 min" via the note
  display registry, like calendar notes.

### 5.7 Schema

`docs/schemas/activity.activity.schema.json` (JSON Schema 2020-12) describing
5.2, kept in step with `schemaVersion` by a test, as R3 requires.

## 6. Left to the builder

- Folder layout inside `lib/features/activity/`, provider names, route wiring.
- Exact icons, chip values beyond those listed, form layout details.
- How the Notes-list display and help text are worded (English; Chinese marked
  unreviewed as usual).
- Catalog creation mechanics (follow how the calendar catalog is created).
- Test split, as long as the contract suite and codec round-trip (incl. unknown
  keys) are covered.
