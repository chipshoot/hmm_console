# Health and home assistant roadmap

Date: 2026-11-17. Status: roadmap, awaiting the owner's approval.
Each stage gets its own design and plan when it starts. This document fixes the
stage order and the rules every stage must follow, nothing more.

## 1. Intent

The owner has diabetes and is building this for themselves. They want to:

- record blood sugar, food and activity with little effort;
- see it on a calendar, and get reminders such as training sessions and checks
  after a meal;
- have an AI that has read their records help them adjust their lifestyle,
  for example by drafting a training plan and reminding them of it.

Later, a **self-hosted AI assistant on a computer at home** will use *all* Hmm
notes (not only health) as its personal knowledge. The health work is the first
customer of that assistant, so the data written from day one must already be
fit for it. That is why this roadmap exists before any code: storage choices
are cheap now and expensive once there are months of entries.

Success looks like: the owner logs daily without friction, reminders arrive
reliably (even offline), and after a few months the AI can answer questions like
"which breakfasts push me highest?" from real numbers.

## 2. Goals, non-goals, anti-goals

**Goals**
- A shared calendar and reminder service any subsystem can use (stage 1).
- Diabetes logs: blood sugar, food, activity (stage 2).
- Read activity and glucose from Apple Health (stage 3).
- AI-drafted training plans and insights, approved by the owner before use
  (stage 4).
- A home-computer assistant over all notes (stage 5).

**Non-goals (for now)**
- Other users, sharing, or caregivers. One owner, one workspace
  (see the domain hub decision: ownership is never a design concern).
- Android Health Connect. The owner's devices are iPhone and iPad; Android can
  follow the same shape later.
- Cloud API mode. It is on hold; everything here works in `local` and
  `cloudStorage` modes. Cloud API support is a later port.
- Server push notifications (APNs).
- Showing events in Apple Calendar (EventKit). Hmm's calendar is its own
  (my call; can be added later).
- Migrating existing car-service or insurance dates into Events in stage 1.
  Other subsystems join through the stage 1 API when they choose to (my call).

**Anti-goals: failure even if it "works"**
- The AI gives medication or insulin dosing advice. Lifestyle only; dosing
  belongs with the owner's doctor.
- Health data reaches a third party without the owner's explicit, per-feature
  consent, or the owner can't see what was sent.
- Reminders that need the server or the internet to fire.
- The AI guesses numbers from loose text instead of computing them from the
  records.
- AI-created items (plans, events) take effect without the owner approving them.

## 3. Constraints (facts about the project today)

- Flutter app, Riverpod, Drift, GoRouter, gen-l10n (en/zh). Platform UI rules,
  `HmmIconButton`, screen help (`HelpId` + `HelpButton`) and
  `showUndoableAction` apply to every new screen (see `CLAUDE.md`).
- Every domain entity is JSON content in a note under a catalog (the GasLog
  pattern). Subsystem anchors live under the `Hmm.System.Subsystem` catalog
  (`lib/features/notes/data/subsystem_anchor.dart`). New features follow the
  interface-plus-two-impls repository pattern.
- In `cloudStorage` mode each note syncs to OneDrive as plaintext JSON at
  `/notes/<id>.json`, indexed by `/manifest.json` (`docs/sync_contract.md`).
  Sensitive attachments are encrypted (AES-256-GCM) and stay unreadable without
  the vault key.
- Runtime plugin loading is permanently unavailable (AOT, App Store 2.5.2).
  The subsystems-as-plugins refactor is design only
  (`docs/plugin-architecture-spike-2026-09-07.md`).
- No notification, HealthKit, calendar or chart package is in `pubspec.yaml`
  yet; each stage adds what it needs.
- iOS keeps at most 64 pending local notifications per app.
- The backend has a swappable AI engine (Claude today, self-hosting ready),
  already used by receipt scan with a one-time consent in Settings.
- `Hmm.BigCalendar` in the backend is an early stub (about 210 lines, the
  manager commented out, not wired into the API). Its useful idea is the shape:
  an event with a time and a list of notification actions.

## 4. Approaches

### 4.1 How the home assistant reads the notes (decides stage 5, constrains 1–4)

| | Approach | Trade-off |
|---|---|---|
| **A (chosen)** | The home computer runs the OneDrive desktop client and reads the synced Hmm folder **read-only** (`manifest.json` + `notes/*.json`). | No new sync path and no app changes beyond documenting entry formats. Always up to date while the computer is on. Depends on the OneDrive client. Sensitive attachments stay encrypted, which is the right default. |
| B | Run the Hmm backend at home and switch the app to Cloud API mode. | Needs the on-hold Cloud API work finished, and moves the owner off the mode they use daily. |
| C | The app pushes notes to the home computer over the home network. | A third sync target to build and keep correct, and it only updates while the phone is at home. |

A is chosen (my call) because it reuses what already syncs and needs nothing
from stages 1–4 except well-described entries. The consequence that binds every
stage: **anything the assistant should know must be in notes**. Data that lives
only in Apple Health or only in prefs is invisible to it.

### 4.2 Where calendar and reminders live (decides stage 1)

| | Approach | Trade-off |
|---|---|---|
| **A (chosen)** | In-app Calendar subsystem; events are notes; the phone schedules local notifications. | Works offline and in local/cloudStorage modes. No server needed. |
| B | Finish `Hmm.BigCalendar` on the server as the source of events. | Only sees Cloud API data (on hold), and can't reach the phone without APNs. |

A is chosen (my call). BigCalendar can later become the server copy of the same
events when Cloud API resumes; stage 1 borrows its shape.

## 5. Shared rules (binding on every stage)

**R1. Entry format.** Every entry is a note in its subsystem's catalog with JSON
content that carries:
- `schemaVersion` (integer, starting at 1);
- times as ISO 8601 with the UTC offset (e.g. `2026-11-17T07:45:00-05:00`), so
  a reading keeps its local time of day after travel;
- explicit units on every measured value (`{"value": 6.4, "unit": "mmol/L"}`),
  never an implied unit;
- `source`: `manual`, `appleHealth`, or `assistant`.

**R2. Granularity.** Things the owner enters by hand (a meal, a reading, a walk)
are one note each. Imported high-frequency data (sensor glucose every few
minutes, step counts) is stored as **one note per source per day** holding an
array of samples, so a year of sensor data is about 365 notes, not 100,000.

**R3. Described data.** Each subsystem ships a JSON Schema per entry type at
`docs/schemas/<catalog-name>.<entry-type>.schema.json`, kept in step with
`schemaVersion` by a test. The assistant uses these to query typed entries as
data. When the plugin refactor happens, this becomes part of what a feature
declares (`FeatureContribution`).

**R4. Privacy.** Health data may go only to: the owner's devices, the owner's
OneDrive (existing sync), the owner's home computer, and the server AI engine
**only** with explicit opt-in per feature, showing what will be sent. Sensitive
items are never sent to any AI. The engine choice can point at a self-hosted
model.

**R5. Approval.** Anything the AI creates (a plan, events, a suggested change)
is saved as a draft marked `source: assistant` and does nothing until the owner
approves it.

**R6. Safety.** Lifestyle advice only, never dosing. Exercise reminders prompt a
blood sugar check before the session and suggest one afterwards. Plans start
modest.

**R7. Reminders.** Local notifications only, fired on one device rather than
every synced device. The setting is **per device, not synced**: "Remind on this
device", on by default on a phone and off on a tablet, so a fresh install never
double-fires or goes silent (my call). A phone only schedules what it has
synced: events made on the iPad reach the iPhone at its next sync (on open,
plus iOS background refresh when the system allows it, best effort). The owner
logs on the phone daily, so a sync per day is the expected case; if the phone
isn't opened for 14 days the scheduled window runs dry, and the app tops it up
on the next open (my call).

**R8. Time of day.** One-off times are stored with their offset (R1). Repeating
events keep **wall-clock time in the device's current time zone**, like an iOS
alarm: "training at 07:00" stays 07:00 after travel and across daylight-saving
changes (my call).

**R9. Health notes are plaintext.** Glucose, food and activity entries are
ordinary notes, plaintext JSON on OneDrive like every other note, so the home
assistant can read them (4.1 A). Only attachments the owner explicitly marks
sensitive are encrypted; those, and only those, are invisible to the assistant
and never sent to any AI (R4). Food photos are normal attachments unless marked.

**R10. One writer for imports.** Apple Health import runs on one device only
(the iPhone, where the Health data originates), and each day-bundle note has an
id derived from source and date, so a repeated import updates the same note
instead of creating a rival copy (my call).

## 6. Stages

### Stage 1: Calendar and reminders (shared service)

- **What:** an Event entry (title, start, optional end, optional repeat rule,
  reminder offsets, the subsystem and note it belongs to, status
  planned/done/skipped). A calendar screen (month and agenda views). A reminder
  scheduler that keeps the next 14 days scheduled, stays under the 64-pending
  limit, and reschedules on launch, after sync, and after any event edit. The
  which-device setting. An API other subsystems call to add, update and remove
  their events.
- **Covers:** tracker #73 (calendar). Car services and insurance renewals can
  use it later.
- **Done when:** a repeating event made on the iPad reminds on the iPhone at the
  right time, with the phone offline at that moment, once the iPhone has synced
  after the event was made (R7); and editing or deleting it changes the
  reminder after the next sync.
- **Size:** a project.

### Stage 2: Diabetes logs

- **What:** blood sugar (value + unit, time, context: fasting / before meal /
  after meal / bedtime / other, note), food (time, description, optional carbs
  estimate, optional photo), activity (type, duration, intensity). Fast entry, a
  today view, the owner's target range, simple trends. "Check 2 hours after a
  meal" creates a stage 1 event.
- **Open for this stage:** how the owner measures blood sugar (meter, sensor,
  which device) and their preferred unit (mmol/L or mg/dL).
- **Size:** a project.

### Stage 3: Apple Health import

- **What:** read-only HealthKit access on the iPhone for blood glucose, steps,
  workouts, active energy and weight; daily bundle notes (R2, R10); no
  duplicates on re-import;
  workouts at a planned session's time tick that session done.
- **Size:** medium.

### Stage 4: AI training plans and insights

- **What:** the AI drafts a training plan as structured sessions from the logs
  and the owner's goals; the owner reviews and edits; approval turns sessions
  into stage 1 events. A periodic insight summary. The AI gets computed
  figures (averages, before/after, by meal) through tools, not raw text dumps.
- **Engine:** the backend AI service with opt-in (R4), until stage 5 can serve
  the same requests.
- **Size:** a project (app + backend endpoint).

### Stage 5: Home assistant over all notes

- **What:** on the home computer, read the OneDrive Hmm folder read-only (4.1 A);
  load typed entries into a local database for queries (using the R3 schemas);
  index free-text notes for search; run a local model that answers with both.
- **Left to the stage 5 design:** the model and runtime, how the app reaches it
  away from home, and whether it can propose changes back (if so, as drafts
  under R5).
- **Size:** a project, mostly outside this app.

## 7. Order and dependencies

1 → 2 → 3 → 4 → 5. Stage 2 should follow stage 1 closely: the AI is only as
good as the history, and every month without logs is a month the assistant
won't have. Stage 3 could run alongside stage 2 if the owner's readings come
from a sensor that writes to Apple Health.

The plugin refactor is **not** a prerequisite (my call): stages 1 and 2 are
built as self-contained features so they slot in when it happens.

## 8. Left to each stage's design

Screens and layouts, the exact JSON fields beyond R1, the repeat-rule format,
chart choices, packages, test plans, and the prompts and tool list for stage 4.
