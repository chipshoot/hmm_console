# Calendar Reminder Priority and Inbox (#82) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-event Time Sensitive reminders, an app-icon badge counting reminders fired since last viewed, and a dashboard bell opening an in-app Reminders list.

**Architecture:** Extends the merged calendar stage 1 (`lib/features/calendar/`). The event gains a stored `timeSensitive` flag. The pure planner gains badge numbers and a "fired reminders" query that shares its candidate rules; ReminderSync feeds it the per-device `seenAt`. A tiny native channel clears the iOS badge. The inbox screen and the dashboard bell read one provider.

**Tech Stack:** Flutter, Riverpod 3, flutter_local_notifications 22.3.3 (`DarwinNotificationDetails.badgeNumber`, `interruptionLevel`), Swift method channel, gen-l10n en/zh.

**Spec:** `docs/superpowers/specs/2026-11-18-calendar-reminder-priority-and-inbox-design.md` (binding). Stage 1 spec: `docs/superpowers/specs/2026-11-17-calendar-reminders-stage1-design.md`.

**Branch:** `feat/calendar-reminder-inbox` (from main 8d65f57; spec committed d057705).

## Global Constraints

- Stored JSON key `timeSensitive` (bool), missing → false; `schemaVersion` stays 1; add the property to `docs/schemas/calendar.event.schema.json`.
- Defaults: editor-created events false; `CalendarEventDraft.timeSensitive` defaults to true.
- Gateway: `InterruptionLevel.timeSensitive` when the reminder's event is Time Sensitive, else `InterruptionLevel.active`.
- Fired window: last **7 days**; same skip rules as planning (done/skipped/cancelled occurrences, drafts, cancelled series, non-`device` channels).
- Prefs key `calendar.remindersSeenAt` (ISO 8601 UTC instant), per device, never synced; unset on first ReminderSync run → set to now.
- Unseen = fired reminders with fire time > seenAt and within 7 days; **0 when "Remind on this device" is off**.
- Badge number of the i-th upcoming reminder (1-based, after sort and cap) = `unseenNow + i`.
- Native channel name `hmm/badge`, method `clear` (iOS 16+: `UNUserNotificationCenter.current().setBadgeCount(0)`; earlier: `UIApplication.shared.applicationIconBadgeNumber = 0`); non-iOS: no-op.
- Route `/calendar/reminders` (name `calendarReminders`), screen `RemindersInboxScreen`, `HelpId.calendarReminders`; bell shows `99+` above 99.
- Bell hidden in Cloud API mode and when remind-on-device is off.
- Project rules from CLAUDE.md: `HmmIconButton` only, `HelpButton` per screen, en + zh strings, platform switches (Cupertino on iOS), never `ref.watch` in a `LayoutBuilder` builder, no `WidgetRef`/`BuildContext` after an await, loading/error/empty/Cloud API states visibly distinct, never `dart format` a directory. Detect Cloud API mode only with `isCalendarCloudApiUnavailable`.
- A stream consumed by a screen that reloads on every emission must not emit for its initial snapshot (lesson from 0afa09b).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Remind-on-device off (the iPad):** unseen count is 0, no badge numbers are scheduled, and the bell is hidden — even though events have past fire times. Tests in Task 3 and Task 4.
2. **Fresh install or first run of this build:** `seenAt` is unset, so it is set to now and the badge starts at 0 instead of counting a week of history. Test in Task 3.
3. **Owner edits events after some reminders fired but before opening the inbox:** the next reschedule continues numbering from the current unseen count (unseen 2 → next pending badge 3). Test in Task 3.
4. **An occurrence marked done after its reminder fired, or its event deleted:** it disappears from the inbox and the count drops at the next refresh. Test in Task 2 (pure) and Task 4 (screen).
5. **An event note written by an older build (no `timeSensitive` key) or with `"timeSensitive": "yes"`:** reads as false, and the raw value is written back unchanged. Test in Task 1.

---

### Task 1: Stored flag, schema, service default

**Files:**
- Modify: `lib/features/calendar/domain/calendar_event.dart` (field `final bool timeSensitive`, default false, in ctor/`copyWith`/equality)
- Modify: `lib/features/calendar/data/calendar_event_codec.dart` (`_knownKeys` gains `'timeSensitive'`; decode `read<bool>('timeSensitive') ?? false`; encode with the same `keep(...)` pattern as `draft`)
- Modify: `docs/schemas/calendar.event.schema.json` (`"timeSensitive": {"type": "boolean"}`, not required)
- Modify: `lib/features/calendar/contract/calendar_service.dart` (`CalendarEventDraft.timeSensitive`, default `true`), `lib/features/calendar/data/default_calendar_service.dart` (copy it onto the event)
- Test: `test/features/calendar/data/calendar_event_codec_test.dart`, `test/features/calendar/data/default_calendar_service_test.dart`

**Interfaces:**
- Produces: `CalendarEvent.timeSensitive` (bool); `CalendarEventDraft.timeSensitive` (bool, default true).

- [ ] **Step 1: Write the failing tests**
  - `timeSensitive round-trips`: an event with `timeSensitive: true` encodes `"timeSensitive": true` and decodes equal.
  - `missing timeSensitive reads false` (Review Focus 5).
  - `wrong-typed timeSensitive is written back unchanged`: `"timeSensitive": "yes"` decodes false; encode emits `"yes"`.
  - Schema hand check (existing test) still passes with the new property.
  - Service: `upsertOwnedEvent` with a default draft creates an event with `timeSensitive == true`; a draft with `timeSensitive: false` stores false; updating keeps the draft's value.
- [ ] **Step 2: Run them to verify they fail** — `flutter test test/features/calendar/data/` → FAIL.
- [ ] **Step 3: Implement** the field, codec, schema and service changes.
- [ ] **Step 4: Run them to verify they pass** — same command → All tests passed.
- [ ] **Step 5: Commit** — `feat(calendar): stored timeSensitive flag (default on for subsystem events)`

### Task 2: Planner — per-reminder priority, badge numbers, fired query

**Files:**
- Modify: `lib/features/calendar/notifications/reminder_plan.dart`
- Test: `test/features/calendar/notifications/reminder_plan_test.dart`

**Interfaces:**
- Consumes: `CalendarEvent.timeSensitive` (Task 1).
- Produces:
  - `PlannedReminder` gains `final bool timeSensitive` (default false) and `final int? badgeNumber`.
  - `planReminders(...)` gains `int unseenNow = 0`; after sort and cap, the i-th entry (1-based) gets `badgeNumber: unseenNow + i`.
  - `class FiredReminder { String eventId; EventTime originalStart; DateTime fireAtUtc; DateTime occurrenceStartUtc; String title; String payload; }`.
  - `List<FiredReminder> firedReminders({required List<CalendarEvent> events, required DateTime fromUtc, required DateTime toUtc, required LocalResolver resolve, required String Function(CalendarEvent, Occurrence) formatTitle})`: reminders with `fromUtc < fireAtUtc <= toUtc`, newest first, same skip rules and all-day 09:00 rule as `planReminders`. Factor the shared candidate generation into one private function both call; do not duplicate the rules.
- [ ] **Step 1: Write the failing tests**
  - `planReminders` with `unseenNow: 2` and three reminders → badge numbers `[3, 4, 5]` in fire order; default `unseenNow` → `[1, 2, 3]`; cap keeps numbering contiguous.
  - `timeSensitive` copied from the event onto each `PlannedReminder`.
  - `firedReminders` over the last 7 days: returns past fire times only, newest first; excludes a done occurrence and a deleted (absent) event (Review Focus 4); excludes a draft event; includes a moved occurrence at its moved fire time.
  - The pinned id test from stage 1 still passes (ids unchanged).
- [ ] **Step 2: Run them to verify they fail** — `flutter test test/features/calendar/notifications/reminder_plan_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them to verify they pass.**
- [ ] **Step 5: Commit** — `feat(calendar): reminder priority, badge numbers and fired-reminder query`

### Task 3: Delivery — gateway levels, badge channel, seenAt in ReminderSync

**Files:**
- Modify: `lib/features/calendar/notifications/notification_gateway.dart` (`schedule` uses `r.timeSensitive` → interruption level and `badgeNumber: r.badgeNumber`; new `Future<void> clearBadge()` on the interface, implemented via the `hmm/badge` channel on iOS, no-op elsewhere)
- Create: `ios/Runner/BadgePlugin.swift` (method channel `hmm/badge`, `clear`); register it in `ios/Runner/AppDelegate.swift` `didInitializeImplicitFlutterEngine` exactly like `VideoPlugin`; add the file to the Runner target in `ios/Runner.xcodeproj/project.pbxproj`
- Create: `lib/features/calendar/states/reminders_seen_provider.dart` (`kRemindersSeenAtKey = 'calendar.remindersSeenAt'`; `Future<DateTime?> readRemindersSeenAt()`, `Future<void> writeRemindersSeenAt(DateTime utc)`)
- Modify: `lib/features/calendar/notifications/reminder_sync.dart` (each run: if seenAt unset → write now; `unseenNow` = `firedReminders(fromUtc: max(seenAt, now − 7 days), toUtc: now).length` when remind-on-device is on, else 0; pass `unseenNow` to `planReminders`)
- Test: `test/features/calendar/notifications/reminder_sync_test.dart`, `test/features/calendar/notifications/local_reminder_scheduler_test.dart` (fake gateway records `timeSensitive`/`badgeNumber`)

**Interfaces:**
- Consumes: Task 2 `planReminders(unseenNow:)`, `firedReminders`, `PlannedReminder.timeSensitive/badgeNumber`.
- Produces: `NotificationGateway.clearBadge()`; `readRemindersSeenAt` / `writeRemindersSeenAt`; ReminderSync injectable `seenAt` reader/writer (constructor params, so tests use fakes).
- [ ] **Step 1: Write the failing tests** (fake gateway, fake clock)
  - First run with seenAt unset writes seenAt = now and schedules with badge numbers starting at 1 (Review Focus 2).
  - seenAt 1 h ago, two reminders fired since → next scheduled badge numbers start at 3 (Review Focus 3).
  - Remind-on-device off → nothing scheduled, no badge numbers, unseen not computed (Review Focus 1).
  - Gateway receives `timeSensitive` per reminder (true for the TS event, false for the other).
- [ ] **Step 2: Run them to verify they fail** — `flutter test test/features/calendar/notifications/` → FAIL.
- [ ] **Step 3: Implement**, including the Swift channel. Check the iOS side compiles: `flutter build ios --debug --no-codesign`.
- [ ] **Step 4: Run them to verify they pass**, then `flutter analyze` → No issues found!
- [ ] **Step 5: Commit** — `feat(calendar): per-reminder priority, icon badge numbers and seen state`

### Task 4: Reminders inbox screen and dashboard bell

**Files:**
- Create: `lib/features/calendar/states/reminders_inbox_state.dart` (`remindersInboxProvider`: `AsyncNotifier` returning `RemindersInbox { List<FiredReminder> items; int unseen; }` over the last 7 days, re-reading on `repo.changes()`; `Future<void> markSeen()` writes seenAt = now, calls `clearBadge()`, triggers `reminderSyncProvider` (`trigger()`), reading all refs before awaits)
- Create: `lib/features/calendar/presentation/screens/reminders_inbox_screen.dart`
- Modify: `lib/core/navigation/calendar_routes.dart` (route `reminders` under `/calendar`, declared before `event/:id`), `lib/core/navigation/route_names.dart` (`calendarReminders`)
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart` (bell `HmmIconButton` with count badge in the top bar → `/calendar/reminders`)
- Modify: `lib/core/help/help_registry.dart` (`HelpId.calendarReminders`; the dashboard's help entry gains the bell if the dashboard has one), `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/calendar/presentation/reminders_inbox_screen_test.dart`, `test/features/calendar/states/reminders_inbox_state_test.dart`, `test/features/dashboard/dashboard_reminders_bell_test.dart`

**Interfaces:**
- Consumes: Task 2 `firedReminders`, `FiredReminder`; Task 3 `readRemindersSeenAt`, `writeRemindersSeenAt`, `NotificationGateway.clearBadge`, `reminderSyncProvider`; stage 1 `calendarRouteForPayload` for the row tap target.
- Produces: `remindersInboxProvider`, `RemindersInboxScreen`, route `calendarReminders`.
- [ ] **Step 1: Write the failing tests**
  - State: two fired reminders since seenAt and one before → `items.length == 3`, `unseen == 2`; remind-on-device off → `unseen == 0` (Review Focus 1); after `markSeen` → `unseen == 0`, seenAt written, `clearBadge` called once, sync triggered.
  - Screen: rows newest first showing "HH:mm · Title" and the fired time; tap pushes `/calendar/event/<id>?at=<wireKey>`; opening the screen calls `markSeen` once; empty state text; Cloud API message; an occurrence marked done disappears after a change (Review Focus 4); HelpButton present and `HelpId.calendarReminders` resolves en + zh.
  - Dashboard: bell shows the count, `99+` for 120, hidden when remind-on-device is off and in Cloud API mode; tap opens `/calendar/reminders`.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them to verify they pass**, plus `flutter test test/core/help/` (icon-button and help guards).
- [ ] **Step 5: Commit** — `feat(calendar): reminders inbox and dashboard bell`

### Task 5: Editor switch, detail label, docs

**Files:**
- Modify: `lib/features/calendar/states/event_edit_state.dart` (`EventForm.timeSensitive`, default false for new events, loaded from an existing event, written by `buildEvent`; a series-only field for the "This occurrence / All" scope rule)
- Modify: `lib/features/calendar/presentation/screens/event_edit_screen.dart` (platform switch "Time Sensitive" with subtitle "Breaks through Focus" under Reminders; disabled when there are no device reminders)
- Modify: `lib/features/calendar/presentation/screens/event_detail_screen.dart` (shows "Time Sensitive" when on)
- Modify: help entries for the editor (`HelpId.calendarEventEdit` gains the switch), ARB files, `CLAUDE.md` calendar row (one sentence: per-event Time Sensitive; badge + `/calendar/reminders` inbox) — stage only that row
- Test: `test/features/calendar/presentation/event_edit_screen_test.dart`, `event_detail_screen_test.dart`
- [ ] **Step 1: Write the failing tests** — new event saves `timeSensitive == false`; toggling on saves true; editing an existing TS event shows the switch on; changing only the switch on a repeating event saves to the series without the scope dialog; detail shows the label only when on.
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run all checks** — `flutter analyze` → "No issues found!", full `flutter test` → summary line "All tests passed!", `TZ=Asia/Shanghai flutter test test/features/calendar/` → all passed.
- [ ] **Step 5: Commit** — `feat(calendar): Time Sensitive switch in the event editor`

### Task 6: On-device check (owner)

After a backed-up install on the iPhone: a normal event's reminder arrives without "Time Sensitive"; a TS event's reminder shows "Time Sensitive" during a Focus; two fired reminders show "2" on the icon and on the dashboard bell; opening the list shows both, clears the icon and the bell; the iPad shows no bell (its reminders are off).
