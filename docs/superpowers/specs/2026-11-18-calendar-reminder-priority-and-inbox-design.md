# Calendar: per-event Time Sensitive and the reminders inbox (tracker #82)

Date: 2026-11-18. Status: approved by the owner ("go with your suggestions for
#82"). Builds on calendar stage 1
(`2026-11-17-calendar-reminders-stage1-design.md`, merged 8d65f57).

## Intent

Stage 1 made every reminder Time Sensitive (55ad559), so ordinary events also
break through Focus. The owner wants priority per event, and a way to see
which reminders fired without hunting through Notification Center: a number on
the Hmm icon and a list inside the app.

## Goals

1. **Time Sensitive per event.** A switch in the event editor; each reminder is
   delivered at its event's level (Time Sensitive or normal).
2. **Icon badge.** The Hmm icon shows how many reminders have fired since the
   owner last opened the reminders list.
3. **Reminders inbox.** A bell on the dashboard with the same count opens a
   "Reminders" list: recently fired reminders (title, time), newest first;
   tapping one opens its event occurrence. Opening the list clears the count
   and the icon badge.

## Non-goals

Android badges (secondary platform; the inbox still works there). Syncing the
"seen" state between devices (reminders fire on one device, R7). A live count
of reminders still waiting. Server push.

## Decisions (owner-approved defaults are marked)

- **Stored field.** New optional JSON key `timeSensitive` (bool) on the event;
  missing reads as false. Additive, so `schemaVersion` stays 1; the schema file
  `docs/schemas/calendar.event.schema.json` gains the property.
- **Defaults (owner).** Off for events the owner creates in the editor; on for
  events created through `CalendarService` by subsystems
  (`CalendarEventDraft.timeSensitive` defaults to true), e.g. diabetes checks.
  Existing events read as off.
- **Delivery.** `PlannedReminder` carries `timeSensitive`; the gateway uses
  `InterruptionLevel.timeSensitive` or `.active`. The entitlement from 55ad559
  stays.
- **What counts as fired.** Computed, not read from the OS: a reminder has
  fired when its planned fire time is in the past. The inbox lists reminders
  whose fire time falls in the last 7 days (my call), skipping done, skipped and
  cancelled occurrences, drafts and cancelled series — the same rules as
  planning. This works offline, survives the owner clearing Notification
  Center, and needs no OS query.
- **Unseen count.** Per device, not synced: prefs key
  `calendar.remindersSeenAt` (ISO instant). Unseen = fired reminders with fire
  time after `seenAt` (and within the 7-day window). A fresh install sets
  `seenAt` to now on first run, so old history never floods the badge (my call).
- **Badge numbers.** iOS sets the badge from each delivered notification's
  `badgeNumber`, so the planner assigns the i-th upcoming reminder
  `unseenNow + i` (1-based). Every reschedule recomputes them, so the number
  stays right after edits, opening the list, or new events.
- **Clearing.** Opening the inbox sets `seenAt = now`, sets the icon badge to 0
  through a small native channel (`hmm/badge`: `setBadgeCount` on iOS 16+,
  `applicationIconBadgeNumber` before), and triggers a ReminderSync run so
  pending badge numbers restart from 1.
- **Bell (owner).** On the dashboard top bar, an `HmmIconButton` bell with the
  unseen count as a badge; hidden in Cloud API mode and when the device's
  "Remind on this device" is off (no reminders fire there).
- **Screen.** `/calendar/reminders` (`RemindersInboxScreen`): rows "19:00 ·
  Evening walk — fired 18:55", newest first; tap opens
  `/calendar/event/<id>?at=<wireKey>`; empty state "No reminders in the last 7
  days"; loading, error and Cloud API states distinct (repo UI-state lesson).
  New `HelpId.calendarReminders`, en + zh strings.

## Anti-goals

The badge must not count reminders that never showed: when "Remind on this
device" is off the count is zero. Health data never leaves the device for this
feature.

## Left to the builder

Widget structure, the exact row layout, the display cap on the bell (99+),
test fakes for the native channel.
