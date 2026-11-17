# Stage 1: Calendar and reminders

Date: 2026-11-17. Status: design, awaiting the owner's approval.
Roadmap: `docs/superpowers/specs/2026-11-17-health-and-home-assistant-roadmap-design.md`
(approved 2026-11-17). Its rules R1–R10 bind this stage; they are referenced, not
repeated.

## 1. Intent

A calendar and reminder service inside the app that any subsystem can use. The
first users are the diabetes subsystem (stage 2: checks after meals) and AI
training plans (stage 4: workout sessions). Car services and insurance renewals
can join later. Reminders must fire from the phone itself, offline, with no
server.

The owner also asked for the **interface contract to be fixed now**, so a future
server calendar (the `Hmm.BigCalendar` project in the backend) can plug in
without changing screens or callers. That contract is section 4.

## 2. Goals, non-goals

**Goals**
- Create, edit and delete events: one-off or repeating, timed or all-day, with
  reminders.
- Month and agenda views; mark one occurrence done or skipped.
- Phone notifications that fire offline, on the device the owner chooses.
- A service other subsystems call to add, update and remove their events.
- An interface, shared test suite and JSON schema the server version must meet.

**Non-goals for stage 1**
- Server implementation (only its contract; see 4.5).
- Showing events in Apple Calendar (EventKit), or importing from it.
- Done/Skip buttons on the notification itself. Tapping opens the event (my
  call: notification actions need a background isolate writing to the database,
  which is worth its own small follow-up).
- Moving existing car-service or insurance dates into the calendar.
- Showing other subsystems' log entries on the calendar. The calendar shows
  events only; a way for subsystems to contribute display-only items comes with
  stage 2.

## 3. Constraints

- Project conventions in `CLAUDE.md`: Riverpod, Drift, GoRouter, gen-l10n
  (en/zh), Cupertino on iOS / Material 3 on Android, `HmmIconButton`, a
  `HelpId` + `HelpButton` per screen, `showUndoableAction` for actions that hide
  data, permanent deletes keep a confirmation.
- Entities are JSON in notes under a catalog; in `cloudStorage` each note syncs
  to OneDrive as `/notes/<id>.json`, last writer wins per note
  (`docs/sync_contract.md`).
- Notes carry a `uuid`, which is the sync identity (deduplicated by uuid).
- iOS keeps at most 64 pending local notifications per app.
- The dashboard already has a placeholder "Calendar" tile with route `calendar`
  and no screen (`dashboard_screen.dart`). Stage 1 makes it real.
- No notification or time-zone package is in `pubspec.yaml`.
- The plugin refactor (`docs/plugin-architecture-spike-2026-09-07.md`) wants new
  features not to add to the `core/` → `features/` dependency. Contacts put its
  local repository in `core/data/local/`; this feature does not (4.6).

## 4. Design

### 4.1 Domain model (`lib/features/calendar/domain/`, pure Dart)

```dart
class CalendarEvent {
  final String id;                  // UUID created on the device; also the note's uuid
  final int schemaVersion;          // 1
  final String title;
  final String? notes;
  final EventTime start;
  final EventTime? end;             // null = no end (a moment, or a whole day)
  final RecurrenceRule? recurrence; // null = one-off
  final List<Reminder> reminders;
  final EventOwner? owner;          // set when a subsystem created it
  final EventStatus status;         // active | cancelled (whole series)
  final EventSource source;         // manual | subsystem | assistant
  final bool draft;                 // true for assistant-made events until approved (R5)
  final List<OccurrenceOverride> occurrences;
  final DateTime updatedAt;
  final Map<String, Object?> extraFields; // unknown keys, written back untouched
}

sealed class EventTime {}
class FixedTime extends EventTime    { DateTime instant; Duration offset; } // one-off timed
class FloatingTime extends EventTime { int y, m, d, hh, mm; }               // repeating timed, wall clock (R8)
class AllDay extends EventTime       { int y, m, d; }

class RecurrenceRule { String rrule; }   // subset below; unknown parts kept verbatim
class Reminder { int minutesBefore; ReminderChannel channel; } // channel: device (email reserved)
class EventOwner { String subsystem; String? noteUuid; }       // e.g. diabetes + the meal note
class OccurrenceOverride {
  EventTime originalStart;          // which occurrence
  OccurrenceStatus status;          // done | skipped | cancelled | moved
  EventTime? movedTo;
}
class Occurrence { String eventId; DateTime start; DateTime? end; OccurrenceStatus? status; }
```

**Time rules** (R8, my calls on the details):
- A one-off timed event is a `FixedTime`: a doctor's appointment at 10:00 stays
  at that real moment even if the owner travels.
- A repeating timed event is a `FloatingTime`: "walk at 19:00" is 19:00 wherever
  the device is, through daylight-saving changes.
- All-day events are dates only.

**Repeats.** A subset of RFC 5545 RRULE, stored as the standard string:
`FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`, `INTERVAL`, `BYDAY` (weekly),
`BYMONTHDAY` (monthly), and one of `COUNT` or `UNTIL`. A rule with parts outside
the subset is kept as written, shown as "Custom repeat", expanded on the parts
that are understood, and not editable in the repeat picker until cleared.
Monthly on the 31st skips months without one (RFC 5545 behaviour).
**Lunar repeats are reserved, not built.** A rule carrying `RSCALE` other than
`GREGORIAN` (RFC 7529, e.g. `RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15`)
is kept exactly as written, shown as "Lunar repeat", and in stage 1 yields only
its first occurrence (the event's own start), so it never fires on a wrong
Gregorian date. A follow-up after stage 1 adds 农历 dates on the month grid
(display only) and real lunar expansion: a leap-month date falls in the normal
month in other years, and day 30 falls on day 29 in a short month (owner
approved the follow-up, 2026-11-17).

**Occurrences** are computed, never stored, by
`expandOccurrences(CalendarEvent e, DateTime from, DateTime to) → List<Occurrence>`,
a pure function, with overrides applied. Done, skipped and moved are recorded
**per occurrence** inside the event (`occurrences`), so a weekly walk can be done
on Monday and skipped on Wednesday. Overrides are kept forever: they are the
history stage 4 learns from.

### 4.2 Stored form

- Catalog: `Hmm.CalendarMan.Event` (follows the existing `Hmm.<Subsystem>Man.<Entity>` names).
- One note per event (series). Note `uuid` = event `id`, and lookups go
  through the existing `getNoteByUuid`. Note `subject` = `Event:<id>`,
  following Contacts' rule that the subject is identity, never a label (titles
  change); the title lives only in the JSON. Event notes are entity notes: the
  Notes feature treats them as it treats contact notes today (my call).
- The catalog row is created lazily on first save, like Contacts. The
  `CalendarMan` domain uses the default catalog colour; no palette change.
- Range queries load the catalog's notes and expand in memory; an owner's few
  hundred events make this cheap (my call; an index can come later behind the
  same interface).
- Content: the JSON below. The same shape is the future API body (4.5) and is
  described by `docs/schemas/calendar.event.schema.json` (R3). A test checks the
  codec's output against the schema.

```json
{
  "schemaVersion": 1,
  "id": "4f0c…",
  "title": "Evening walk",
  "notes": null,
  "start": { "floating": "2026-11-18T19:00" },
  "end":   { "floating": "2026-11-18T19:30" },
  "rrule": "FREQ=WEEKLY;BYDAY=MO,WE,FR",
  "reminders": [ { "minutesBefore": 15, "channel": "device" } ],
  "owner": { "subsystem": "diabetes", "noteUuid": null },
  "status": "active",
  "source": "assistant",
  "draft": false,
  "occurrences": [
    { "originalStart": { "floating": "2026-11-18T19:00" }, "status": "done" }
  ],
  "updatedAt": "2026-11-17T21:04:00-05:00"
}
```

`start` is one of `{ "fixed": "2026-11-20T10:00:00-05:00" }`,
`{ "floating": "…" }` or `{ "allDay": "2026-11-20" }`.

The codec follows the Contacts codec's safety rules: unknown keys go to
`extraFields` and are written back; a wrong-typed known value decodes to a
default for display and is written back unchanged until the owner edits that
field; an undecodable note surfaces as unreadable, never as absent.

**Conflicts.** The note is the sync unit, so last writer wins for the whole event:
marking Monday done on the phone while renaming the event on the iPad keeps
whichever saved last. Accepted for a single owner (my call).

**Deleting.** Deleting a series soft-deletes its note (`deletedAt`); the
existing purge removes it after 30 days. Notes' Recently Deleted screen lists
only ordinary notes (entity notes are restored by their own feature, G11), so
the way back in stage 1 is the undo on `showUndoableAction`; a calendar
"Recently deleted" list is a later addition (my call). Deleting one occurrence
adds a `cancelled` override. Deleting "this and following" only truncates the
series by setting `UNTIL`. All three use `showUndoableAction`.

**Editing a repeating event** offers "This occurrence" (a `moved` override, or a
changed title stored on that override) or "All occurrences". "This and
following" editing is left out of stage 1 (my call). When an "all" edit changes
the start time or rule, overrides that no longer match an occurrence stay in the
JSON as history and are ignored by expansion.

### 4.3 Reminders on the device

`IReminderScheduler` (`contract/`), implemented by `LocalReminderScheduler` with
`flutter_local_notifications` plus the `timezone` data and the device's zone
name (package choice and versions left to the builder).

- **Window:** occurrences in the next 14 days, nearest first, at most **60**
  pending (4 spare under iOS's 64). Each run cancels what Hmm scheduled and
  schedules the new set.
- **When it runs:** app start, return to foreground, and on any repository
  change, debounced about 1 s. `changes()` is built on the existing Drift
  `watchNotes()` stream filtered to the calendar catalog, so it fires for local
  edits **and** for sync pulls (a pull writes the same table). No new sync
  signal and no `core/` change is needed.
- **Time zone:** everything uses the device's current zone. Floating times and
  all-day reminders are recomputed on every run, so a zone change is picked up
  at the next foreground. A `FixedTime`'s instant is the truth; its offset is
  kept only to round-trip the stored string.
- **Notification identity:** id = a stable 31-bit hash of event id + occurrence
  start; payload = `calendar|<eventId>|<occurrenceStart>`. "Cancel what Hmm
  scheduled" cancels only pending notifications whose payload starts with
  `calendar|`, so a later feature's notifications are untouched.
- **Which device** (R7): a per-device, unsynced setting "Remind on this device".
  Default on for a phone, off for a tablet. Tablet = shortest side ≥ 600 pt, the
  rule the video feature already uses. When off, the scheduler cancels all and
  schedules nothing.
- **Skipped:** cancelled series, draft events, and occurrences marked done,
  skipped or cancelled.
- **Permission:** asked the first time the owner saves an event with a reminder
  on a device where reminders are on, never at launch. If denied, the calendar
  screen shows a banner that opens the system settings.
- **Content:** the title and the time ("19:00 · Evening walk"), plus an optional
  body line a subsystem supplies through `CalendarService` (stage 2 uses it for
  the blood sugar prompt, R6). Tapping opens the event's screen at that
  occurrence.
- All-day events remind at 09:00 on the day by default (my call).
- New events get one reminder 15 minutes before by default; the editor can
  remove it or add more (my call).

### 4.4 Contract (`lib/features/calendar/contract/`)

```dart
abstract interface class ICalendarRepository {
  Future<List<CalendarEvent>> eventsBetween(DateTime from, DateTime to); // any occurrence overlaps
  Future<CalendarEvent?> getEvent(String id);
  Future<CalendarEvent> saveEvent(CalendarEvent event);  // upsert by id; sets updatedAt
  Future<void> deleteEvent(String id);                   // soft delete (Recently Deleted)
  Future<List<CalendarEvent>> eventsOwnedBy(EventOwner owner);
  Future<CalendarEvent> setOccurrence(String eventId, OccurrenceOverride o);
  Stream<void> changes();                                // local edits and sync pulls
}

abstract interface class IReminderScheduler {
  Future<void> reschedule(List<Occurrence> upcoming);    // device only, never the server
  Future<void> cancelAll();
  Future<bool> requestPermission();
}

/// The only calendar API other subsystems use.
abstract interface class CalendarService {
  Future<CalendarEvent> upsertOwnedEvent(EventOwner owner, CalendarEventDraft draft);
  Future<void> removeOwnedEvents(EventOwner owner);
  Future<List<CalendarEvent>> ownedEvents(EventOwner owner);
}
```

Errors: `CalendarEventNotFound(id)` for writes to a missing event,
`CalendarEventUnreadable(id)` for a note that cannot be decoded, and
`CalendarCloudApiUnavailable` in Cloud API mode (the Contacts pattern, including
an `isCalendarCloudApiUnavailable(error)` helper that unwraps Riverpod's
`ProviderException`).

**Shared contract tests**:
`test/features/calendar/contract/calendar_repository_contract.dart` exports
`runCalendarRepositoryContract(ICalendarRepository Function() create)`. It runs
against the local repository now and must run against the API repository later.
It covers at least: save then get round-trips every field including
`extraFields`; saving the same id twice updates rather than duplicates;
`eventsBetween` returns a repeating event whose first occurrence is before the
range; delete removes it from every query; `setOccurrence` on a missing id
throws `CalendarEventNotFound`; `changes()` emits after save, delete and
`setOccurrence`.

### 4.5 Future server contract (documented, not built)

| Call | Meaning |
|---|---|
| `GET /v1/calendar/events?from=&to=` | Events with an occurrence in the range |
| `GET /v1/calendar/events/{id}` | One event |
| `PUT /v1/calendar/events/{id}` | Upsert with the client id; body = the 4.2 JSON; `409` if the stored `updatedAt` is newer than the one sent |
| `DELETE /v1/calendar/events/{id}` | Delete |
| `PUT /v1/calendar/events/{id}/occurrences` | Body = one `OccurrenceOverride` |

`Hmm.BigCalendar` mapping: `Appointment` → `CalendarEvent` (`GuidEntity` id
already fits client UUIDs), `HostId` → `owner`, `StartTime`/`EndTime` →
`start`/`end`, `Cancelled` → `status`, `Notifications` → `reminders` (its
`Email` action becomes channel `email`; device reminders stay on the phone).
`ContactInfo` has no counterpart yet and stays server-only.

### 4.6 Wiring and code layout

```
lib/features/calendar/
  domain/        entities, recurrence, expandOccurrences
  contract/      ICalendarRepository, IReminderScheduler, CalendarService, errors
  data/          calendar_event_codec.dart, local_calendar_repository.dart
  notifications/ local_reminder_scheduler.dart, reminder_sync.dart (window + triggers)
  states/        providers
  presentation/  screens, widgets
```

The local repository may import from `core/` (the note and catalog
repositories and their providers): features → core is the allowed direction.

`calendarRepositoryProvider` lives in the feature (`states/`), picks the local
repository in `local` and `cloudStorage`, and throws
`CalendarCloudApiUnavailable` in `cloudApi`, so the screens show a friendly
"Calendar isn't available in Cloud API mode yet" message (my call: no local
fallback, which would split events across two stores). It is **not** added to
`core/data/repository_providers.dart` (plugin-spike direction).

Routes: `/calendar` (home), `/calendar/event/new`, `/calendar/event/:id`
(optional `?at=` occurrence start), `/calendar/event/:id/edit`. The dashboard
tile already points at `calendar`; the launcher gets a "Calendar" destination.

### 4.7 Screens

**Calendar home.** Phone: a compact month grid over the agenda of the selected
day. Wide (≥ 1000 pt): month on the left, the day's agenda on the right. Dots
under days with events. A "Today" button; add (`+`) in the top bar on iOS, a
FAB on Android. A help button.

```
 ┌──────────────────────────────┐
 │ ‹  November 2026  ›   Today + ?│
 │ M  T  W  T  F  S  S          │
 │ …  17 [18] 19 20 21 22       │
 │       •   •      •           │
 ├──────────────────────────────┤
 │ Wed 18 November              │
 │ 07:00  Check blood sugar  ✓  │
 │ 19:00  Evening walk  ↻       │
 │ All day  Insurance renewal   │
 └──────────────────────────────┘
```

An agenda row shows time, title, a repeat mark, and its status (done ✓, skipped
–). Swiping a row marks that occurrence done (right) or skipped (left), with
undo; a long press offers Edit, Delete this one, Delete series.

**Event screen.** Title, when, repeat in words ("Every Mon, Wed, Fri"),
reminders, notes, the owning subsystem if any ("From Diabetes"), and for a
repeating event the occurrence opened plus Done / Skip buttons. Draft events
(R5) show an Approve button (clears `draft`) and are greyed in the agenda.
Nothing in stage 1 creates drafts; this is built now so stage 4 only has to
create them.

**Event editor.** Title, all-day switch, start, end, repeat (None, Daily,
Weekly with weekday chips, Monthly, Yearly, plus end: never / on date / after N),
reminders (add/remove, minutes-before choices), notes. Platform pickers per
`CLAUDE.md`.

**Settings.** A "Calendar" section with "Remind on this device" and, when
permission is denied, a shortcut to the system settings.

Every screen gets a `HelpId`, help entries and en/zh strings.

## 5. Approaches considered

- **Calendar location:** in-app (chosen) vs. finishing `Hmm.BigCalendar` first
  (roadmap 4.2).
- **Notifications:** an existing package (chosen) vs. a hand-written Swift
  plugin like the video one. The package also covers Android and handles
  time-zone-aware scheduling.
- **Month grid:** built in the app (chosen, my call) vs. a calendar package. Most
  packages look Material-only and would break the iOS look rule.
- **Overrides:** inside the event note (chosen) vs. one note per override. Inside
  keeps a series and its history one sync unit; the cost is the last-writer-wins
  case in 4.2.

## 6. Tests

- Contract suite (4.4) on the local repository.
- `expandOccurrences`: daily/weekly/monthly/yearly, `INTERVAL`, `BYDAY`,
  `COUNT`/`UNTIL`, monthly on the 31st, overrides (done, cancelled, moved), a
  floating 07:00 across the America/Toronto DST change (2027-03-14 and
  2027-11-07), and an unsupported rule part kept verbatim.
- Codec: round-trip, unknown keys kept, wrong-typed values kept, schema check.
- Scheduler with a fake plugin: 60-cap keeps the nearest, cancelled, draft and
  done occurrences skipped, "Remind on this device" off schedules nothing,
  permission denied leaves nothing scheduled and sets the banner state.
- Widget tests for the three screens and the Settings row, both platforms where
  the UI branches.

## 7. Done when

A repeating event made on the iPad reminds on the iPhone at the right time, with
the phone offline at that moment, once the iPhone has synced after the event was
made; editing or deleting it changes the reminder after the next sync; marking an
occurrence done stops that reminder; and the contract suite passes.

## 8. Left to the builder

Package versions and native setup, the debounce mechanism, exact widget
structure, colours, the help text wording, and how the month grid handles
locale-dependent first weekday (follow the locale).
