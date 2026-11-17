# Calendar and Reminders (Stage 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An in-app calendar with repeating events, per-occurrence done/skip, and offline phone reminders, behind a repository contract a future server can implement.

**Architecture:** A new `lib/features/calendar/` feature. Events are JSON in notes under catalog `Hmm.CalendarMan.Event` (note uuid = event id). Pure domain code (model, codec, recurrence expansion, reminder planning) is separated from the Drift-backed repository and from the notification plugin, so each is tested alone. A shared contract test suite pins `ICalendarRepository` for today's local implementation and a future API one.

**Tech Stack:** Flutter, Riverpod 3, Drift, GoRouter, gen-l10n (en/zh), `flutter_local_notifications`, `timezone`, a device time-zone name package (e.g. `flutter_timezone`).

**Spec:** `docs/superpowers/specs/2026-11-17-calendar-reminders-stage1-design.md` (binding), roadmap `docs/superpowers/specs/2026-11-17-health-and-home-assistant-roadmap-design.md` (rules R1–R10).

**Branch:** create `feat/calendar-stage1` from `docs/health-agent-roadmap` (which holds the spec and this plan).

## Global Constraints

- Catalog name `Hmm.CalendarMan.Event`; note `uuid` = event id; note `subject` = `Event:<id>`; the title lives only in the JSON.
- JSON fields exactly as spec §4.2: `schemaVersion` (1), `id`, `title`, `notes`, `start`, `end`, `rrule`, `reminders[{minutesBefore, channel}]`, `owner{subsystem, noteUuid}`, `status` (`active`|`cancelled`), `source` (`manual`|`subsystem`|`assistant`), `draft`, `occurrences[{originalStart, status, movedTo?}]`, `updatedAt` (ISO 8601 with offset).
- `start`/`end` are one of `{"fixed": "2026-11-20T10:00:00-05:00"}`, `{"floating": "2026-11-18T19:00"}`, `{"allDay": "2026-11-20"}`.
- Unknown keys are kept in `extraFields` and written back; a note that cannot be decoded raises `CalendarEventUnreadable`, never reads as absent.
- RRULE subset: `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`, `INTERVAL`, `BYDAY` (weekly), `BYMONTHDAY` (monthly), one of `COUNT`/`UNTIL`; other parts kept verbatim and shown as "Custom repeat".
- Reminder window: next **14 days**, nearest first, at most **60** pending; payload prefix `calendar|`; id = stable 31-bit hash of event id + occurrence start + minutes before.
- Defaults: new event one reminder 15 min before; all-day reminds 09:00 on the day.
- "Remind on this device": per device, not synced; default on when shortest side < 600 pt, off otherwise (`kInlineVideoMinShortestSide` = 600).
- Cloud API mode: `CalendarCloudApiUnavailable`; no local fallback. Provider lives in the feature, **not** in `core/data/repository_providers.dart`.
- Project rules (CLAUDE.md): `HmmIconButton` only (the icon-button guard test must stay green), a `HelpId` + `HelpButton` per screen, `showUndoableAction` for done/skip/delete, Cupertino on iOS / Material 3 on Android, every string in both `app_en.arb` and `app_zh.arb`, never `ref.watch` inside a `LayoutBuilder` builder, never `dart format` a directory.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A floating event at a time that doesn't exist or happens twice on a DST day** (02:30 on 2027-03-14, 01:30 on 2027-11-07, America/Toronto): one occurrence, fired at the time the `timezone` package resolves to. Never dropped, never doubled. Test in Task 2.
2. **A soft-deleted event's uuid is saved again** (undo after delete, or a sync restoring it): `getNoteByUuid` also returns deleted rows, so `getEvent` must treat `deletedAt != null` as absent, and `saveEvent` on that uuid restores and updates the same note rather than creating a second one with a clashing uuid. Test in Task 3.
3. **An event note written by a newer build or edited by hand** (an unknown key, `"draft": "yes"`, `start` missing): an unknown key survives a save, a wrong-typed value is written back unchanged, and a missing `start` makes the event unreadable rather than crashing the agenda. Test in Task 1. The agenda skips unreadable events and still shows the rest (Task 7).
4. **A reminder whose fire time has already passed** (an event in 10 min with a 15-min reminder, or the app reopened late): nothing is scheduled for a past time, and the event itself still shows. Test in Task 5.
5. **An end before the start, or a repeat that can never occur** (`UNTIL` before the start, `COUNT=0`): the editor refuses to save the first, and the second yields no occurrences and no reminders. Tests in Task 2 and Task 8.

---

### Task 1: Domain model, JSON codec and schema

**Files:**
- Create: `lib/features/calendar/domain/calendar_event.dart` (CalendarEvent, EventOwner, Reminder, OccurrenceOverride, enums)
- Create: `lib/features/calendar/domain/event_time.dart` (sealed EventTime + FixedTime/FloatingTime/AllDay)
- Create: `lib/features/calendar/data/calendar_event_codec.dart`
- Create: `docs/schemas/calendar.event.schema.json` (JSON Schema draft 2020-12)
- Test: `test/features/calendar/data/calendar_event_codec_test.dart`

**Interfaces:**
- Produces:
  - `CalendarEvent` with the fields in spec §4.1, immutable, `copyWith`, value equality. `recurrence` is `String? rrule` on the entity (the parser is Task 2).
  - `enum EventStatus { active, cancelled }`, `enum EventSource { manual, subsystem, assistant }`, `enum OccurrenceStatus { done, skipped, cancelled, moved }`, `enum ReminderChannel { device, email }`.
  - `sealed class EventTime`, plus `FixedTime(DateTime instant, Duration offset)`, `FloatingTime(int year, month, day, hour, minute)` and `AllDay(int year, month, day)`. Each has value equality and a `Map<String, String> toWire()` / `static EventTime fromWire(Map)` pair, plus `String wireKey` (a canonical one-line string such as `floating:2026-11-18T19:00`) for ids, payloads and override matching.
  - `class CalendarEventCodec { static CalendarEvent decode(String id, Map<String, Object?> json); static Map<String, Object?> encode(CalendarEvent e); }`. `decode` throws `CalendarEventUnreadable(id)` (defined here, re-exported by Task 3's errors file) when `start` or `title` is missing or not decodable.
  - `rawKnownValues` on the entity keeps wrong-typed known values, mirroring `ContactCodec`.

- [ ] **Step 1: Write the failing tests**
  - `round-trips every field including extraFields`: encode then decode the spec §4.2 example plus `"futureKey": {"a": 1}`. The decoded event equals the original, and the re-encoded map contains `futureKey`.
  - `fixed, floating and allDay starts round-trip`: `{"fixed":"2026-11-20T10:00:00-05:00"}` keeps offset −5 h and the instant 15:00Z. `{"floating":"2026-11-18T19:00"}` gives `FloatingTime(2026,11,18,19,0)`. `{"allDay":"2026-11-20"}` gives `AllDay(2026,11,20)`.
  - `wrong-typed known value is written back unchanged`: `"draft": "yes"` decodes to `draft == false`, and `encode` emits `"draft": "yes"` while the event is otherwise unchanged.
  - `missing start is unreadable`: `decode` throws `CalendarEventUnreadable`.
  - `missing schemaVersion reads as 1`.
  - `encoded output satisfies the schema`: load `docs/schemas/calendar.event.schema.json`. Every `required` key is present in `encode(example)`, and every top-level key except `extraFields` keys is in `properties`. This is a hand check with no schema library.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/calendar/data/calendar_event_codec_test.dart`
Expected: FAIL (files don't exist).

- [ ] **Step 3: Implement the model, codec and schema file**

Follow `lib/features/contacts/data/contact_codec.dart` for unknown keys and raw known values.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/calendar/data/calendar_event_codec_test.dart`
Expected: All tests passed.

- [ ] **Step 5: Commit**

`git add lib/features/calendar docs/schemas test/features/calendar && git commit -m "feat(calendar): event model, codec and JSON schema"`

### Task 2: Recurrence rule and occurrence expansion

**Files:**
- Create: `lib/features/calendar/domain/recurrence_rule.dart`
- Create: `lib/features/calendar/domain/recurrence_expander.dart`
- Create: `lib/features/calendar/domain/occurrence.dart`
- Modify: `pubspec.yaml` (add `timezone`, used in tests through a resolver)
- Test: `test/features/calendar/domain/recurrence_rule_test.dart`, `test/features/calendar/domain/recurrence_expander_test.dart`

**Interfaces:**
- Consumes: Task 1 `CalendarEvent`, `EventTime`, `OccurrenceOverride`.
- Produces:
  - `class RecurrenceRule { Frequency freq; int interval; List<Weekday> byDay; List<int> byMonthDay; int? count; DateTime? until; String unsupported; bool get isCustom; static RecurrenceRule parse(String rrule); String format(); }`. `format(parse(x))` keeps unsupported parts verbatim.
  - `typedef LocalResolver = DateTime Function(int y, int m, int d, int hh, int mm);` This resolves wall-clock time to a UTC instant in the device zone. The default is `(y,m,d,hh,mm) => DateTime(y,m,d,hh,mm).toUtc()`.
  - `class Occurrence { String eventId; EventTime originalStart; DateTime start; DateTime? end; bool allDay; OccurrenceStatus? status; String? titleOverride; }`. `start` and `end` are UTC.
  - `List<Occurrence> expandOccurrences(CalendarEvent e, DateTime fromUtc, DateTime toUtc, {LocalResolver resolve})`. It returns occurrences whose start falls in [from, to), plus any that started before `from` and are still running at `from`, sorted by start. `cancelled` overrides are omitted; `moved` overrides use `movedTo`; `done` and `skipped` set `status`. A cancelled series returns []. A one-off event (no rrule) yields at most one occurrence.

- [ ] **Step 1: Write the failing tests**
  - Parse/format: `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=6` round-trips. `FREQ=MONTHLY;BYSETPOS=-1;BYDAY=FR` has `isCustom == true`, and `format()` still contains `BYSETPOS=-1`.
  - Daily, weekly `BYDAY=MO,WE,FR`, monthly `BYMONTHDAY=31` (Jan 31, Mar 31, May 31 in a Jan–Jun range; no Feb or Apr), yearly, `INTERVAL=2`, `COUNT=3` (exactly 3), and `UNTIL` inclusive of the last day.
  - Overrides: a done override sets status, a cancelled one removes that occurrence, a moved one changes its start, and an override matching no occurrence is ignored.
  - A one-off `FixedTime` event inside the range gives 1 occurrence; outside it gives 0.
  - **DST (Review Focus 1)**, using a resolver built from `timezone` `America/Toronto`:
    - Floating 07:00 daily: 2027-03-13 → 12:00Z, 2027-03-14 → 11:00Z, 2027-11-06 → 11:00Z, 2027-11-07 → 12:00Z.
    - Floating 02:30 daily: exactly one occurrence on 2027-03-14.
    - Floating 01:30 daily: exactly one occurrence on 2027-11-07.
  - **Never occurs (Review Focus 5):** `UNTIL` before the start gives []; `COUNT=0` gives []; a cancelled series gives [].
  - An event started before `from` and still running at `from` is included.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/calendar/domain/`
Expected: FAIL.

- [ ] **Step 3: Implement the parser and the expander**

Iterate candidate dates in wall-clock terms, then resolve each through `resolve`. Never add `Duration(days: 1)` to UTC instants, which drifts across DST. Cap the iteration at the range end or 5,000 candidates, whichever comes first.

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/calendar/domain/`
Expected: All tests passed.

- [ ] **Step 5: Commit**

`git commit -m "feat(calendar): RRULE subset and occurrence expansion"`

### Task 3: Repository contract, shared contract suite, local repository, mode provider

**Files:**
- Create: `lib/features/calendar/contract/i_calendar_repository.dart`
- Create: `lib/features/calendar/contract/calendar_errors.dart`
- Create: `lib/features/calendar/data/local_calendar_repository.dart`
- Create: `lib/features/calendar/states/calendar_providers.dart`
- Create: `test/features/calendar/contract/calendar_repository_contract.dart` (exports the suite function; no `main`)
- Test: `test/features/calendar/data/local_calendar_repository_test.dart` (runs the suite and local-only tests), `test/features/calendar/states/calendar_repository_mode_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2. Core `IHmmNoteRepository` (`getNoteByUuid`, `createNote(HmmNoteCreate(subject, catalogId, content, uuid))`, `updateNote(id, HmmNoteUpdate(content))`, `deleteNote`, `restoreNote`, `getNotes(catalogId)`, `watchNotes()`), `INoteCatalogRepository` (`getCatalogByName`, `createCatalog`).
- Produces:
  - `ICalendarRepository`, exactly as spec §4.4.
  - `CalendarEventNotFound(String id)`, `CalendarEventUnreadable(String id)`, `CalendarCloudApiUnavailable` (extends `UnimplementedError`), and `bool isCalendarCloudApiUnavailable(Object e)`, which unwraps `ProviderException` like the Contacts helper.
  - `LocalCalendarRepository(IHmmNoteRepository notes, INoteCatalogRepository catalogs, {DateTime Function() now})`. It creates the catalog lazily (schema `{"type":"calendarEvent"}`).
  - `Future<List<CalendarEventReadResult>> readAll()` returns each event, or an unreadable id, so screens can skip bad notes. `eventsBetween` skips unreadable ones.
  - Providers: `localCalendarRepositoryProvider`, `calendarRepositoryProvider` (local in `local` and `cloudStorage`, throws `CalendarCloudApiUnavailable` in `cloudApi`).
- `void runCalendarRepositoryContract(Future<ICalendarRepository> Function() create)` covers the spec §4.4 list:
  - round-trip including `extraFields`;
  - save twice by the same id updates and doesn't duplicate;
  - `eventsBetween` returns a repeating event whose first occurrence is before the range;
  - delete removes the event from `getEvent`, `eventsBetween` and `eventsOwnedBy`;
  - `setOccurrence` on a missing id throws `CalendarEventNotFound`;
  - `setOccurrence` replaces an existing override with the same `originalStart`, so there is never more than one per occurrence;
  - `changes()` emits after save, delete and `setOccurrence`.

- [ ] **Step 1: Write the failing tests**
  - Write the contract suite and run it against `LocalCalendarRepository` on `HmmDatabase(NativeDatabase.memory())` with an inserted author. Copy the setup from `test/core/data/local/local_hmm_note_repository_restore_test.dart`.
  - Local-only tests:
    - the note's subject is `Event:<id>` and its uuid is the id;
    - **Review Focus 2:** after `deleteEvent(id)`, `getEvent(id)` is null; then `saveEvent` with the same id restores that same note (same local note id) with the new content, and only one note with that uuid exists;
    - `changes()` emits when a note in the calendar catalog is inserted directly through the note repository, which simulates a sync pull;
    - a note with undecodable content makes `getEvent` throw `CalendarEventUnreadable`, and `eventsBetween` still returns the other events.
  - Mode test: copy `test/features/contacts/data/contact_repository_mode_test.dart`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/calendar/data/local_calendar_repository_test.dart test/features/calendar/states/`
Expected: FAIL.

- [ ] **Step 3: Implement**

`changes()` is `notes.watchNotes()` mapped to the calendar catalog's notes and de-duplicated on the list of `(uuid, lastModifiedDate)`, emitting `void`. `saveEvent` sets `updatedAt` to `now()`.

- [ ] **Step 4: Run them to verify they pass**

Same command. Expected: All tests passed.

- [ ] **Step 5: Commit**

`git commit -m "feat(calendar): repository contract, contract suite and local repository"`

### Task 4: CalendarService for other subsystems

**Files:**
- Create: `lib/features/calendar/contract/calendar_service.dart` (interface + `CalendarEventDraft`)
- Create: `lib/features/calendar/data/default_calendar_service.dart`
- Modify: `lib/features/calendar/states/calendar_providers.dart` (add `calendarServiceProvider`)
- Test: `test/features/calendar/data/default_calendar_service_test.dart`

**Interfaces:**
- Consumes: `ICalendarRepository`.
- Produces:
  - `class CalendarEventDraft { String? id; String title; String? notes; EventTime start; EventTime? end; String? rrule; List<Reminder> reminders; String? reminderBody; bool draft; EventSource source; }`. `reminderBody` is stored in the event's `extraFields['reminderBody']`, the line a subsystem adds to the notification (spec §4.3).
  - `CalendarService`, as spec §4.4.

- [ ] **Step 1: Write the failing tests**
  - `upsertOwnedEvent` with no draft id creates an event with that owner and `source == subsystem` unless the draft says `assistant`. Calling it again with the returned id updates rather than creating a second event.
  - `removeOwnedEvents` deletes only that owner's events.
  - `ownedEvents` lists them.
  - `reminderBody` round-trips.

  Use the local repository on an in-memory database.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/calendar/data/default_calendar_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them to verify they pass**

Same command. Expected: All tests passed.

- [ ] **Step 5: Commit**

`git commit -m "feat(calendar): calendar service for subsystems"`

### Task 5: Reminder planning (pure)

**Files:**
- Create: `lib/features/calendar/notifications/reminder_plan.dart`
- Test: `test/features/calendar/notifications/reminder_plan_test.dart`

**Interfaces:**
- Consumes: `expandOccurrences`, `LocalResolver`.
- Produces:
  - `class PlannedReminder { int id; DateTime fireAtUtc; String title; String? body; String payload; }`.
  - `int reminderNotificationId(String eventId, EventTime originalStart, int minutesBefore)`: a stable FNV-1a hash of `"$eventId|${originalStart.wireKey}|$minutesBefore"`, masked to 31 bits.
  - `List<PlannedReminder> planReminders({required List<CalendarEvent> events, required DateTime nowUtc, required LocalResolver resolve, required String Function(Occurrence o) formatTitle, int windowDays = 14, int cap = 60})`.
    - It skips cancelled series, `draft` events, and occurrences with status done, skipped or cancelled.
    - It skips fire times at or before `nowUtc`.
    - All-day reminders fire at 09:00 local on the day minus `minutesBefore`.
    - It sorts by fire time and keeps the first `cap`.
    - The payload is `calendar|<eventId>|<originalStart.wireKey>`.
    - The body comes from `extraFields['reminderBody']`.

- [ ] **Step 1: Write the failing tests**
  - The 60 cap keeps the nearest when 100 candidates exist.
  - The 14-day window excludes day 15.
  - Draft, cancelled and done occurrences are skipped.
  - **Review Focus 4:** an event in 10 min with a 15-min reminder gives no reminder; with a 5-min reminder it gives one.
  - An all-day event on 2026-11-20 with `minutesBefore: 0` fires at 09:00 local.
  - Ids are stable across calls and differ across occurrences and offsets.
  - The payload format is exact.
  - The body is carried.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/calendar/notifications/reminder_plan_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them to verify they pass**

Same command. Expected: All tests passed.

- [ ] **Step 5: Commit**

`git commit -m "feat(calendar): reminder planning"`

### Task 6: Device scheduler, reminder sync and the per-device setting

**Files:**
- Modify: `pubspec.yaml` (add `flutter_local_notifications` and a device time-zone package)
- Modify: `ios/Runner/AppDelegate.swift` (set the notification-centre delegate per the plugin's iOS setup), `android/app/src/main/AndroidManifest.xml` (the plugin's receivers, `POST_NOTIFICATIONS`, exact-alarm handling per its docs)
- Create: `lib/features/calendar/contract/i_reminder_scheduler.dart`
- Create: `lib/features/calendar/notifications/notification_gateway.dart` (thin wrapper interface over the plugin, so tests can fake it)
- Create: `lib/features/calendar/notifications/local_reminder_scheduler.dart`
- Create: `lib/features/calendar/notifications/reminder_sync.dart`
- Create: `lib/features/calendar/states/remind_on_device_provider.dart`
- Modify: `lib/main.dart` or the app root (start `ReminderSync` after the first frame; initialise the time-zone database and the local location)
- Test: `test/features/calendar/notifications/local_reminder_scheduler_test.dart`, `test/features/calendar/notifications/reminder_sync_test.dart`, `test/features/calendar/states/remind_on_device_provider_test.dart`

**Interfaces:**
- Consumes: Task 3 `calendarRepositoryProvider` and `changes()`; Task 5 `planReminders`.
- Produces:
  - `IReminderScheduler`, as spec §4.4. `reschedule` takes `List<PlannedReminder>`, a ruling recorded here: planning is pure and scheduling is just delivery.
  - `abstract interface class NotificationGateway { Future<void> initialize(void Function(String payload) onTap); Future<List<PendingReminder>> pending(); Future<void> cancel(int id); Future<void> schedule(PlannedReminder r); Future<bool> requestPermission(); Future<bool> permissionGranted(); }`.
  - `LocalReminderScheduler.reschedule` cancels only pending entries whose payload starts with `calendar|`, then schedules the given list.
  - `remindOnDeviceProvider`: a `Notifier<bool>` backed by `shared_preferences` key `calendar.remindOnDevice`. When the key is unset, it defaults from the shortest side (< 600 → true). It is never synced.
  - `calendarPermissionDeniedProvider`: a `Notifier<bool>` that drives the banner.
  - `ReminderSync`: triggers on start, on `AppLifecycleState.resumed`, and on each `changes()` emission, debounced 1 s. Each run reads all events, plans with the device resolver, and calls `reschedule`. When `remindOnDevice` is false it calls `cancelAll()` instead.
- Permission is requested in Task 8's save path, not here.

- [ ] **Step 1: Write the failing tests** (fake `NotificationGateway`)
  - `reschedule` leaves a pending `other|x` notification alone and replaces `calendar|…` ones.
  - `ReminderSync` with the setting off cancels all calendar reminders and schedules none.
  - A `changes()` emission triggers exactly one reschedule after the debounce (fake async).
  - Two emissions within 1 s trigger one reschedule.
  - When permission isn't granted, nothing is scheduled and `calendarPermissionDeniedProvider` becomes true.
  - Remind-on-device defaults to true for a 390×844 size and false for 820×1180, and a stored value overrides the default.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/calendar/notifications/ test/features/calendar/states/remind_on_device_provider_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add the packages, the native setup, the gateway over `flutter_local_notifications` (`zonedSchedule` with a `TZDateTime` in `tz.local`), the scheduler and the sync. Initialise `tz.local` from the device zone name at startup.

- [ ] **Step 4: Run them to verify they pass**

Same command. Expected: All tests passed. Then run `flutter analyze`. Expected: No issues found.

- [ ] **Step 5: Commit**

`git commit -m "feat(calendar): device reminder scheduler and sync"`

### Task 7: Calendar home screen, routes, dashboard tile, launcher, help

**Files:**
- Create: `lib/features/calendar/presentation/screens/calendar_home_screen.dart`
- Create: `lib/features/calendar/presentation/widgets/month_grid.dart`, `agenda_list.dart`, `agenda_row.dart`
- Create: `lib/features/calendar/states/calendar_view_state.dart` (selected day, visible month, the day's occurrences, days with events in the month)
- Create: `lib/core/navigation/calendar_routes.dart`; modify `lib/core/navigation/router_config.dart` (spread `...calendarRoutes` beside `...contactRoutes`), `lib/core/navigation/route_names.dart`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart` (the existing "Calendar" tile; make the title and description localised)
- Modify: `lib/features/launcher/domain/launcher_registry.dart` (a `calendar` destination like `contacts`, icon `Icons.calendar_month_outlined`)
- Modify: `lib/core/help/help_registry.dart` (`HelpId.calendar`), `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/calendar/presentation/calendar_home_screen_test.dart`, `test/features/calendar/states/calendar_view_state_test.dart`

**Interfaces:**
- Consumes: `calendarRepositoryProvider`, `expandOccurrences`, `ICalendarRepository.setOccurrence`, `showUndoableAction`.
- Produces:
  - Routes `/calendar` (name `calendar`), `/calendar/event/new`, `/calendar/event/:id` (query `at` = `originalStart.wireKey`), and `/calendar/event/:id/edit`. Declare `new` before `:id`, as `contact_routes.dart` explains.
  - Shared widgets used by Task 8: `CalendarCloudApiMessage` and `UnreadableEventTile`.

- [ ] **Step 1: Write the failing tests**
  - View state: selecting 2026-11-18 lists that day's occurrences in time order, with all-day ones first. The month's event days include a repeating event's days.
  - Phone (390×844):
    - the month grid sits above the agenda;
    - swiping a row right calls `setOccurrence(done)` and shows the undo message, and undo restores the previous status;
    - swiping left marks it skipped;
    - long press offers Edit, Delete this one and Delete series.
  - Wide (1200×800): the grid and the agenda sit side by side.
  - In Cloud API mode the friendly message shows, not an error.
  - An unreadable event note doesn't hide the others (Review Focus 3).
  - A help button is present, and `HelpId.calendar` resolves in en and zh.
  - On iOS `+` is in the top bar; on Android there's a FAB.
  - The launcher registry contains `calendar`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/calendar/presentation/calendar_home_screen_test.dart test/features/calendar/states/calendar_view_state_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

The month grid's first weekday follows the locale (`MaterialLocalizations.firstDayOfWeekIndex`).

- [ ] **Step 4: Run them to verify they pass**

Same command, plus `flutter test test/core/help/`. Expected: All tests passed.

- [ ] **Step 5: Commit**

`git commit -m "feat(calendar): calendar home, routes, launcher and help"`

### Task 8: Event screen and editor

**Files:**
- Create: `lib/features/calendar/presentation/screens/event_detail_screen.dart`, `event_edit_screen.dart`
- Create: `lib/features/calendar/presentation/widgets/repeat_picker.dart`, `reminder_list_editor.dart`, `edit_scope_dialog.dart`, `repeat_description.dart` (`String describeRepeat(RecurrenceRule r, AppLocalizations l)`)
- Create: `lib/features/calendar/states/event_edit_state.dart`
- Modify: `lib/core/help/help_registry.dart` (`HelpId.calendarEvent`, `HelpId.calendarEventEdit`), ARB files, `calendar_routes.dart`
- Test: `test/features/calendar/presentation/event_detail_screen_test.dart`, `event_edit_screen_test.dart`, `test/features/calendar/presentation/repeat_description_test.dart`

**Interfaces:**
- Consumes:
  - `ICalendarRepository`;
  - `IReminderScheduler.requestPermission` through a provider;
  - `remindOnDeviceProvider` and `calendarPermissionDeniedProvider`;
  - `RecurrenceRule`.
- Produces:
  - Saving builds the stored time types: a one-off timed event becomes `FixedTime` (device offset at that instant), a repeating timed event becomes `FloatingTime`, and an all-day event becomes `AllDay`.
  - Switching an existing event between one-off and repeating converts the start in wall-clock terms.

- [ ] **Step 1: Write the failing tests**
  - `describeRepeat`: `FREQ=WEEKLY;BYDAY=MO,WE,FR` reads "Every Mon, Wed, Fri" in en; a custom rule reads "Custom repeat".
  - Editor:
    - a new event defaults to one 15-min reminder;
    - **Review Focus 5:** an end before the start blocks saving and shows the message;
    - saving a repeating 19:00 event stores `{"floating":"…T19:00"}`;
    - a one-off stores `fixed`;
    - all-day stores `allDay`;
    - a custom rule keeps its text and the picker is read-only until the owner taps Clear.
  - Permission: the first save with a reminder while remind-on-device is true calls `requestPermission` once; a denial sets the banner provider; a later save doesn't ask again.
  - Editing a repeating event asks "This occurrence" or "All occurrences". "This occurrence" with a new time writes a `moved` override, and with a new title stores `titleOverride` on that override (`extraFields` of the override, key `title`). "All" updates the series.
  - Detail:
    - a repeating event opened with `at` shows Done and Skip, which call `setOccurrence` with undo;
    - "From Diabetes" shows when the owner subsystem is `diabetes`;
    - a draft shows Approve, which clears `draft`;
    - Delete series uses `showUndoableAction`, and undo restores the event;
    - Delete this-and-following sets `UNTIL` to the day before the occurrence.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/calendar/presentation/`
Expected: FAIL for the new files.

- [ ] **Step 3: Implement**

Use platform pickers per CLAUDE.md: Cupertino date and time pickers on iOS, Material on Android.

- [ ] **Step 4: Run them to verify they pass**

Same command. Expected: All tests passed.

- [ ] **Step 5: Commit**

`git commit -m "feat(calendar): event screen and editor"`

### Task 9: Settings section, permission banner, notification tap, docs

**Files:**
- Create: `lib/features/settings/presentation/widgets/calendar_settings_section.dart`; modify `settings_screen.dart` (add it beside `ReceiptExtractionSettingsSection`)
- Create: `lib/features/calendar/presentation/widgets/permission_banner.dart`; modify `calendar_home_screen.dart`
- Modify: `reminder_sync.dart` / app root: route a tapped payload `calendar|<id>|<wireKey>` to `/calendar/event/<id>?at=<wireKey>`, including a cold start from the notification (`getNotificationAppLaunchDetails`)
- Modify: `CLAUDE.md` (add a `calendar/` row to the feature table: purpose, catalog, Cloud API unavailable, spec path)
- Modify: ARB files, help entries for the Settings rows (`HelpId.settings` gets a calendar control entry if Settings has one)
- Test: `test/features/settings/calendar_settings_section_test.dart`, `test/features/calendar/notifications/notification_tap_test.dart`

**Interfaces:**
- Consumes: `remindOnDeviceProvider`, `calendarPermissionDeniedProvider`, `NotificationGateway.initialize(onTap)`.
- Produces: `String? calendarRouteForPayload(String payload)`. It returns null for a non-calendar or malformed payload, and the tap is then ignored.

- [ ] **Step 1: Write the failing tests**
  - The Settings switch toggles and persists `calendar.remindOnDevice`.
  - When permission is denied, an "Open Settings" row appears.
  - The banner shows on the calendar home only while denied.
  - `calendarRouteForPayload('calendar|abc|floating:2026-11-18T19:00')` gives `/calendar/event/abc?at=floating%3A2026-11-18T19%3A00`. `'other|x'` and `'calendar|'` give null.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/settings/calendar_settings_section_test.dart test/features/calendar/notifications/notification_tap_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run all checks**

Run: `flutter analyze`, then `flutter test`.
Expected: "No issues found!", then the summary line `All tests passed!`. Read the summary line itself, not a pipe's exit code.

- [ ] **Step 5: Commit**

`git commit -m "feat(calendar): settings, permission banner and notification tap"`

### Task 10: On-device check (owner, with the controller)

Not a code task. After merge approval and a backed-up install on both devices (the standing deploy rules), the owner checks spec §7:
1. Create a repeating event on the iPad.
2. Open Hmm on the iPhone so it syncs.
3. Put the iPhone in airplane mode.
4. The reminder arrives on time.
5. Edit, then delete, on the iPad. After the iPhone's next sync, the reminder moves, then disappears.
6. Mark an occurrence done. Its reminder doesn't fire.
7. The iPad never shows a reminder while its setting is off.

Record the result in the ledger and on tracker row #73.
