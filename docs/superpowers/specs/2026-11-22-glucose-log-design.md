# Glucose log with Apple Health import: design

Status: draft for owner review, 2026-11-22.

- **Roadmap:** `docs/superpowers/specs/2026-11-17-health-and-home-assistant-roadmap-design.md`. This is the blood sugar half of stage 2. Rules R1–R10 there bind this design.
- **Pattern:** Activity log, `docs/superpowers/specs/2026-11-21-activity-log-design.md`, shipped in 856c7da.

## 1. Intent

The owner has diabetes and tests by finger prick a few times a day with a Contour meter.
Readings sync to the Contour Diabetes app, which writes them to Apple Health (owner confirmed 2026-11-21).
The owner wants those readings in Hmm without typing, so that:

- they sit next to the Activity log;
- the future assistant (roadmap stages 4–5) can review them.

Readings must be typed, self-describing notes from day one, because the assistant reads notes, not the app.

## 2. Goals, non-goals, anti-goals

**Goals (this project)**

- Import blood glucose readings from Apple Health on the iPhone, one note per reading (R2). A repeated import never duplicates a reading.
- The first import brings in all past readings.
- Typed entry for readings that didn't sync, or that came from another meter.
- An optional, owner-set tag per reading: fasting / before meal / after meal / bedtime / other.
- One owner-set target range, with readings coloured below / in / above it.
- Screens:
  - a Glucose list and an entry/edit form;
  - a range setting;
  - a dashboard tile showing the last reading;
  - launcher destinations.
- A JSON Schema, a repository contract test suite, and entries that follow R1.

**Non-goals.** Each of these is a later step:

- Food logging, a combined Today view, trends and charts.
- "Check 2 hours after a meal" reminders.
- Reading Contour's meal markers or any other Health metadata beyond value, time, source name and sample id. The owner chose to tag manually instead (2026-11-22).
- Separate ranges per tag.
- Continuous glucose monitor (CGM) data. When the owner gets a sensor, it gets day-bundle notes per R2, as a separate step.
- Writing anything to Apple Health.
- Android Health Connect. Android gets typed entry only.
- Background import while the app is closed.
- Cloud API mode. It is unavailable, as for Activity and the calendar.

**Anti-goals.** Each of these would be a failure even if the feature works:

- Duplicate readings after repeated imports, reinstalls or two devices.
- A reading the owner deleted coming back while Hmm still remembers it (see §5.3 for the accepted gap).
- Medical defaults or advice. The range is the owner's own (R6).
- Health data leaving the owner's devices or OneDrive (R4).
- Embeddings or model-derived data in notes.

## 3. Constraints (facts about the project today)

- **Nothing reads Apple Health yet.** No HealthKit package or entitlement exists. `ios/Runner/Runner.entitlements` holds only the time-sensitive key. iOS builds use automatic signing with a paid team, which HealthKit requires.
- **Copy Activity.** Activity shows the pattern to follow, file for file:
  - `lib/features/activity/` with `contract/`, `data/` (codec that keeps unknown keys, local repository over notes, catalog get-or-create), `domain/` (including `OffsetDateTime`), `presentation/` and `states/`;
  - the contract test suite;
  - `docs/schemas/activity.activity.schema.json`;
  - Cloud API "unavailable" handling;
  - the note display registry entry;
  - dashboard tile and launcher registry entries;
  - help entries.
- **Synced settings.** `SyncableSettings` (`lib/features/settings/domain/syncable_settings.dart`) holds owner settings that sync. Per-device settings live in prefs, as "Remind on this device" does.
- **Platform rules.** CLAUDE.md: `HmmIconButton`, `HelpButton`, `showUndoableAction`, Cupertino widgets on iOS.
- **iOS hides read denial.** HealthKit never tells an app that read access was refused. A refused read just returns no samples.

## 4. Approaches

| | Approach | Trade-off |
|---|---|---|
| **A (chosen by owner)** | Glucose is its own feature and catalog, built like Activity. The pub.dev `health` package reads HealthKit on the iPhone. | Copies a just-shipped, tested pattern. The package handles permission and querying, and covers Android later. |
| B | A general "health measurements" store, with glucose as one kind. | Ready for weight or blood pressure, but a bigger design now. Stage 3 uses day bundles anyway, so it wouldn't reuse it. |
| C | Like A, with a hand-written native channel instead of the package. | No dependency, but native code to maintain. |

## 5. Decisions

### 5.1 Owner decisions (2026-11-22)

- **Scope:** the glucose log (option 2): import, typed entry, optional tag, target range, dashboard tile. Food, the Today view, trends and reminders come later.
- **Tagging:** the owner marks readings in the Contour app, but Hmm will **not** read those marks. The tag is set manually in Hmm and is **optional**. "Don't introduce hard stuff."
- **Approach:** A.
- **Deleted readings:** accept the narrow gap. A deleted imported reading can come back only after its note is permanently gone (30-day purge, "Delete now", "Empty", or cloud cleanup) and a later import still covers it. No separate skip list is kept (§5.3).

### 5.2 The reading (note content, catalog `Hmm.GlucoseMan.Reading`)

Note uuid = reading id. Note subject is `Glucose:<id>`.

```json
{
  "schemaVersion": 1,
  "id": "…",
  "takenAt": "2026-11-22T07:41:00-05:00",
  "glucose": { "value": 112, "unit": "mg/dL" },
  "context": "fasting",
  "notes": "",
  "source": "appleHealth",
  "appleHealth": { "sampleId": "9C1E…", "sourceName": "CONTOUR DIABETES" },
  "draft": false,
  "updatedAt": "2026-11-22T12:42:10Z"
}
```

- **Required fields:** `schemaVersion`, `id`, `takenAt`, `glucose`, `source`, `updatedAt`.
- **`takenAt`** is ISO 8601 with offset (R1). For imported readings the offset is the device's current time zone's offset **at the sample's instant**, i.e. the instant converted with `toLocal()` (my call, after the builder check). HealthKit stores no zone, and this keeps readings from the other daylight-saving season at the right wall time; a reading taken while travelling shows home-zone time.
- **`glucose`** is a number plus a unit, `mg/dL` or `mmol/L`. It is stored **exactly as it arrived**:
  - imported readings are stored in the unit the package returns (mg/dL), never rounded through a conversion;
  - typed readings are stored in the unit the owner typed in (my call).
- **Conversion** happens only for display: mmol/L = mg/dL ÷ 18.016 (my call; the common clinical factor). Shown to 1 decimal in mmol/L, whole numbers in mg/dL.
- **`context`** is optional: `fasting | beforeMeal | afterMeal | bedtime | other`. Imported readings arrive without one.
- **`appleHealth`** is present only when `source` is `appleHealth`:
  - `sampleId` is the HealthKit sample UUID;
  - `sourceName` is the writing app's name, kept so the assistant can tell meters apart.
- **`source`** is `manual | appleHealth | assistant` (R1). `draft` follows R5, as in Activity.
- The codec keeps unknown keys and wrong-typed known values, like `ActivityCodec`.

### 5.3 Import

- **Who imports.** A per-device, unsynced setting, "Import from Apple Health on this device". It is shown only on iOS and is on by default on an iPhone, off on an iPad (R10; mirrors R7). The iPad still shows imported readings via sync.
- **When.** After the first import (see Permission), on app open and on resume, at most once every 15 minutes (my call), plus an "Import now" action on the Glucose screen.
- **Permission.** Nothing is asked on app open (my call, after the builder check). The first import, and the permission request with it, happens only when the owner taps "Import from Apple Health" (empty state) or Import now on the Glucose screen. A per-device flag records that it has run; only then do the automatic on-open and on-resume imports start. The request is for read access to blood glucose only. Because iOS hides refusal (§3), an import that finds nothing shows: "No readings found. If you use a meter app, check Health → Sharing → Apps → Hmm." It never says "permission denied".
- **What window it reads:**
  - The first import reads all history.
  - Later imports read from the last successful import's end time **minus 7 days** (my call). This catches meter apps that write late without re-reading years.
  - The end time is stored per device in prefs.
- **No duplicates.** An imported reading's id is derived from its HealthKit sample UUID: a UUID v5 over `appleHealth:<sampleId>` in a fixed namespace. This holds across reinstalls and devices. If a note with that id exists (live **or deleted**), the sample is skipped, so a reading the owner deleted stays deleted.
- **Wait for the first sync (cloudStorage).** In cloudStorage mode a device imports only after it has completed at least one sync since install (my call, after the builder check). Otherwise a fresh install could re-create readings deleted on another device, and last-write-wins would let the new notes beat the remote tombstones. In local mode there is no wait.
- **Accepted gap (owner decision).** "Deleted stays deleted" holds only while the deleted note still exists. In local mode `NotePurgeService` hard-deletes after 30 days, and "Delete now" or "Empty" does it at once; cloud cleanup can drop tombstones after 30 days (sync_contract §7). A reading can come back only if a later import window still covers it: a purge within the 7-day overlap, or a first import on a fresh install. The owner accepts this; no skip list is kept.
- **Already imported readings are never changed by a later import** (my call). The owner's tag and notes are safe, and nothing would change anyway since Hmm reads only value and time.
- **Removed from Health:** a reading removed from Apple Health stays in Hmm.
- **Results:**
  - an import that adds readings shows "Imported N readings";
  - errors show a short message and never block the screen.

### 5.4 Target range

- **Fields.** One range: low and high, stored in `SyncableSettings` with its unit.
- **No default.** Until the owner sets it, readings show no colour and the list shows a one-line prompt "Set your target range" that opens the setting. No medical default is suggested (R6).
- **Colouring.** A reading is below (value < low), in, or above (value > high), compared after converting to the range's unit.
- **Display unit.** A synced setting, `mmol/L` or `mg/dL` (my call). The default is mg/dL when the device region is US, otherwise mmol/L.

### 5.5 Repository (contract)

`IGlucoseRepository` in `lib/features/glucose/contract/`, mirroring `IActivityRepository`:

- `readingsBetween(from, to)`: by `takenAt`, newest first.
- `getReading(id)`: null when absent or deleted. Throws "unreadable" when stored but undecodable.
- `existsIncludingDeleted(id)`: used by import to skip.
- `saveReading(r)`: upsert. Sets `updatedAt`.
- `deleteReading(id)`: soft delete.
- `changes()`: no emission for the initial snapshot.

A local implementation over notes serves `local` and `cloudStorage`. Cloud API mode throws `GlucoseCloudApiUnavailable`, and the screens show "not available in this mode". The HealthKit reading sits behind a small `GlucoseSampleSource` interface, so import logic is tested with a fake.

### 5.6 Screens

```
Glucose                         [?] [⟳] [+]
Target 4.0–7.0 mmol/L
Today
  6.2 mmol/L   fasting       ● in      07:41  ♥
  9.8 mmol/L   after meal    ● above   13:05  ♥
Yesterday
  5.4 mmol/L                 ● in      21:30  ✎
```

(♥ = from Apple Health, ✎ = typed; the colour dot follows the range.)

- **List** at `/glucose`:
  - grouped by the reading's own recorded date (the Activity R1 ruling);
  - the top bar has Import now (iOS with import on) and Add;
  - swipe or long-press deletes with `showUndoableAction`; tap opens edit.
  - **Empty state:** "Log a reading", plus an "Import from Apple Health" button on iOS.
- **Form** at `/glucose/new` and `/glucose/<id>`:
  - value with a unit toggle, time (default now), tag (optional segmented choice with a clear option), notes;
  - for imported readings, value and time are read-only, with "From Apple Health · CONTOUR DIABETES";
  - Save is enabled once a value is set. The valid value range is 20–600 mg/dL (1.1–33.3 mmol/L) (my call; it covers meter limits).
- **Range setting:** reached from the list's prompt and from Settings. Low, high and display unit.
- **Dashboard tile** "Glucose" shows "Last: 6.2 mmol/L · 2 h ago", with a colour dot when a range is set. It opens the list.
- **Launcher:** "Glucose" and "Log glucose reading", local-only like Activity.
- **Notes list display:** "Glucose 6.2 mmol/L".
- Help entries for the list, the form and the range setting.

### 5.7 Schema

`docs/schemas/glucose.reading.schema.json` (JSON Schema 2020-12), kept in step with `schemaVersion` by a test (R3).

### 5.8 iOS setup

- Add the HealthKit entitlement to `Runner.entitlements`, and enable the HealthKit capability for the Runner target.
- Add `NSHealthShareUsageDescription` to Info.plist: "Hmm reads your blood glucose readings so they appear in your glucose log."
- No write usage string, since nothing is written.

## 6. Left to the builder

- Folder layout inside `lib/features/glucose/`, provider names, route wiring.
- The `health` package version (latest stable that builds with the project's Flutter), and its configuration.
- Icons, exact colours for below / in / above (they must work in light and dark), form layout.
- Wording of help text and messages. English; Chinese marked unreviewed as usual.
- Test split, as long as the contract suite, codec round-trip (including unknown keys), and the import rules in §5.3 are covered with a fake sample source:
  - no duplicates;
  - deleted stays deleted (while the deleted note exists);
  - no import before the first sync in cloudStorage, and none before the first manual import;
  - imported offsets follow the zone at the sample's instant;
  - the overlap window;
  - existing readings untouched.
