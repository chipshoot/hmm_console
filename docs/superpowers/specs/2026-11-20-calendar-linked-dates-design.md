# Linked important dates — design

Third of the owner's three calendar projects (lunar → public holidays →
linked important dates). Follows `2026-11-19-calendar-lunar-design.md` and
`2026-11-19-calendar-public-holidays-design.md`. Owner decisions 2026-11-20.

## Why

The app already holds dates that matter: the driver's licence expiry, car
insurance and registration expiry, and when each car service is next due.
Today they sit in their own screens and nothing warns the owner before they
pass. The owner also wants family birthdays, including 农历 (lunar)
birthdays for family in China, remembered without hand-making calendar
events that drift out of date when a detail changes.

Success: these dates appear on the calendar by themselves, remind the owner
ahead of time, follow every change made in their own screen, and never
appear twice — on either device.

## Goals

1. **Five kinds of linked date** become calendar events owned by their
   source (owner decision):
   - driver's licence expiry;
   - car insurance policy expiry;
   - vehicle registration expiry;
   - scheduled car service next due date;
   - contact birthday (new field), only when that contact's
     **Remind me** is on (owner decision; off by default).
2. **Default reminders** (owner decision): expiry and due dates remind
   **one month before**; birthdays remind **on the day**.
3. **Per-date reminders** (owner decision): the owner can change the
   reminders of each linked event in the calendar, and those changes are kept
   when the source date later moves.
4. **Lunar birthdays** (owner decision): a contact's birthday is either
   公历 (Gregorian, default) or 农历 (lunar), and a lunar birthday repeats on
   its lunar date every year.
5. **Existing data counts**: licence, insurance, registration and service
   dates entered before this release appear without re-entry.

## Non-goals

- Expiry dates for other ID documents (passport, health card) — later
  (my call; owner did not ask for them now).
- Anniversaries or other per-contact dates.
- Importing birthdays from the phone's address book.
- Per-kind on/off settings (e.g. "no service reminders") — later if wanted;
  removing an event's reminders covers it for now.
- Cloud API mode (the calendar, contacts and licence don't work there).
- The vehicle entity's legacy `insuranceExpiryDate` / `nextServiceDueDate`
  snapshot fields: the policy and schedule notes are the sources.

## Anti-goals

- **Duplicate events.** Two devices, an offline edit, or a re-run must never
  produce a second copy of a linked event.
- **Silently undoing the owner's choices.** A reminder the owner changed must
  not be reset by the app.
- **Sending anything off the device.** Nothing here calls an outside service.

## Approaches

- **A. Each screen tells the calendar on save.** Simplest, but dates entered
  before this release never appear until re-saved, and offline edits on two
  devices can leave duplicates.
- **B. A matcher keeps the calendar in step with all stored dates (chosen
  by the owner).** One piece of code reads every source date and makes the
  calendar match: creates, moves and removes events. Existing data appears
  on day one, deletions are handled, and deterministic event ids stop
  duplicates across devices.
- **C. No stored events; computed when drawn (like holidays).** Can't
  duplicate, but reminders, per-date reminder changes, done/skip and the
  Reminders inbox all need stored events — the most work for the least gain.

## Design

### Storage facts this design relies on

- Contacts, the licence, vehicles, policies and schedules are all notes in
  the one `Notes` table, told apart by catalog. All sync in cloudStorage
  mode. `Notes.uuid` is the only id that is the same on every device; the
  vehicle, policy and schedule entities expose only the device-local int id,
  so the matcher looks the uuid up through the note repository.
- `Contact.id` is its note uuid.
- The licence is one note found by subject `DriverLicence:self`; two devices
  that each create it offline get two notes with different uuids. Its event
  key is therefore a constant, not the note uuid.
- A calendar event's id is its note's uuid. `LocalCalendarRepository.saveEvent`
  restores a soft-deleted note with the same uuid.

### Event identity (no duplicates)

Each linked event's id is a **UUID v5** of a fixed namespace and a key:

| Kind | Key | Owner (`subsystem`, `noteUuid`) |
|---|---|---|
| Licence expiry | `licence:expiry` | `driverLicence`, `self` |
| Registration expiry | `vehicle:<vehicle note uuid>:registration` | `automobile`, vehicle uuid |
| Insurance expiry | `insurance:<policy note uuid>:expiry` | `insurance`, policy uuid |
| Service due | `service:<schedule note uuid>:due` | `scheduledService`, schedule uuid |
| Birthday | `contact:<contact id>:birthday` | `contacts`, contact id |

Every device computes the same id, so two devices creating the same event
write the same note and sync merges them. The matcher always passes this id
to `upsertOwnedEvent` (a null id would mint a random one).

### Which dates are linked

- **Licence:** when it has an expiry date.
- **Registration:** active vehicles with a registration expiry date.
- **Insurance:** active policies on active vehicles whose expiry is no more
  than 90 days in the past (my call: the mark stays briefly after expiry,
  then leaves so years of old policies don't pile up).
- **Service due:** active schedules on active vehicles with a next due date.
- **Birthday:** active contacts with a birthday and **Remind me** on.

### Event shape

- **All-day** on the source date. Expiry and due dates don't repeat.
- **Birthdays repeat yearly**:
  - Gregorian: `FREQ=YEARLY` on the month and day. A 29 February birthday
    shows on 28 February in non-leap years (my call; matches My holidays).
    Only birthday rules do this: they carry `RSCALE=GREGORIAN;SKIP=BACKWARD`
    (RFC 7529), which `RecurrenceRule` and the expander learn to honour.
    Hand-made yearly 29 February events keep skipping non-leap years as
    today.
  - Lunar: `RecurrenceRule.lunarYearly` (`RSCALE=CHINESE…;SKIP=BACKWARD`),
    with a leap month (`BYMONTH=4L`) when the birthday is in one. The series
    start is the Gregorian date of the lunar birthday in the birth year when
    known and inside 1901–2099, otherwise in the current year.
- **Default reminders:** expiry/due = 30 days before (all-day reminders fire
  at 09:00, so 09:00 thirty days earlier); birthday = on the day at 09:00.
  Time Sensitive on, as for all subsystem events.
- **Titles** in the app's current language, refreshed when it changes:
  - "Driver's licence expires" / "驾照到期"
  - "<vehicle> registration expires" / "<vehicle> 行驶证到期"
  - "<vehicle> insurance expires" / "<vehicle> 保险到期" (the provider in
    the event notes line when known)
  - "<vehicle>: <service> due" / "<vehicle>：<service> 到期"
  - "<name>'s birthday" / "<name>生日"
  Exact wording and Chinese translations are the builder's, following the ARB
  conventions. `<vehicle>` is `Automobile.displayName`; `<name>` is the
  contact's display name.
- **Language-neutral titles** (my call; the two devices may use different
  languages). The event stores a `linked` entry in its extra fields:
  `{ "kind": "licenceExpiry" | "registrationExpiry" | "insuranceExpiry" |
  "serviceDue" | "birthday", "args": {…} }` (vehicle name, service name,
  contact name, birth year). The detail screen, agenda, Reminders inbox and
  notification text build the title from it in the device's language. The
  stored `title` is the creating device's rendering, kept as the fallback for
  older builds. The matcher compares `kind` and `args`, never the rendered
  title, so devices in different languages don't rewrite each other.
- **Insurance provider** goes in `reminderBody` (matcher-owned), not in the
  event notes, which stay the owner's (my call).
- **Age:** when the birth year is known, the event stores it and the day
  detail and agenda show the age for that occurrence (e.g. "turns 70").
  For lunar birthdays the age counts lunar years.

### What the matcher writes, and what it keeps

For each wanted event the matcher compares with what's stored and **writes
only when something it owns differs**, so repeated runs settle and don't
churn sync:

- **Matcher-owned (always set):** the `linked` kind and args, start, repeat
  rule, owner and `reminderBody`. The title is rewritten only when `kind` or
  `args` change.
- **Owner-owned (kept from the stored event once it exists):** reminders,
  Time Sensitive, notes, done/skip per occurrence.

A new event gets the default reminders. A moved date keeps the owner's
reminders (owner decision). `upsertOwnedEvent` today overwrites reminders
and Time Sensitive; the matcher passes the stored values back, or the service
gains a way to keep them (builder's choice).

**Removal:** the matcher lists events whose owner subsystem is one of the five
above (`ICalendarRepository` gains a list-by-subsystem query; today it only
matches subsystem plus note uuid), and deletes any whose id is not in the
wanted set (source deleted, vehicle sold, contact deactivated, Remind me
switched off, policy too old).

**Coming back keeps the owner's settings** (my call). When a wanted event's
id matches a soft-deleted event note, the matcher reads that note's content
and keeps its reminders, Time Sensitive, notes and done/skip, instead of
writing defaults. This covers Undo after Remind me is switched off, and a
policy or contact restored from Recently Deleted.

**No removals mid-sync** (my call). The matcher doesn't run while a sync is
in progress; it runs once the sync finishes. A pull can land an event before
the contact or policy it belongs to, and removing it then would delete it
on every device.

**One licence** (my call). If two licence notes exist (two devices each
created one offline), the matcher uses the one modified most recently, so
both devices pick the same expiry date.

### Linked events in the calendar

- The detail screen keeps its "From <source>" line (labels: Driver's licence,
  Vehicle, Insurance, Car service, Contacts) and adds **Open <source>**, which
  goes to the licence, vehicle, policy, schedule or contact.
- **Editable:** reminders, Time Sensitive, notes, done/skip.
- **Not editable:** title, date and repeat — shown read-only with "Change it
  in <source>" (my call: the matcher would reset them anyway).
- **No Delete** for linked events (my call). The source decides: switch off
  Remind me, delete the policy, clear the date. Removing every reminder keeps
  the date on the calendar but silences it. This avoids the matcher restoring
  a deleted event. A linked event deleted by an older build on another device
  is restored on the next run; that's accepted.

### When the matcher runs

- At app start, after the first frame (alongside `ReminderSync`).
- On app resume.
- When notes change — local saves and sync pulls both write the notes table
  (the `ICalendarRepository.changes()`-style Drift watch, or
  `notifyLocalChange()` plus the `SyncController.addListener` pattern used by
  `NotePurgeScheduler`). Debounced (~2 s). Its own writes trigger one more run
  that finds nothing to do.
- Not in Cloud API mode: it does nothing there, and treats the
  contacts/licence/calendar "unavailable" errors as "skip".

`ReminderSync` already reschedules notifications whenever calendar events
change, so linked events need nothing extra to remind.

### Contacts: the birthday field

- **Stored** in the contact JSON as `birthday`:
  `{ "calendar": "gregorian" | "lunar", "month": 1–12, "day": 1–31 (lunar 1–30),
  "leap": bool (lunar only), "year": int? }` plus `remindBirthday: bool`
  (default false). Added to the codec's known keys; older builds keep it via
  `extraFields`.
- **Editor:** a Birthday row opens a picker with a 公历 / 农历 switch.
  - Gregorian: month and day, optional year.
  - Lunar: month 正月…腊月 with a 闰 (leap) option, day 初一…三十, optional
    year. A new picker: none exists today.
  - Cupertino picker on iOS, Material on Android. Clear removes the birthday.
- **Detail:** shows the birthday (lunar ones as e.g. 闰四月初五, with the next
  Gregorian date), the age when the year is known, and the **Remind me**
  switch, which saves at once.
- Remind me is shown only when a birthday is set.

### Help and platform rules

- The contact editor's Birthday row and the detail's Remind me get help
  entries; the event detail's help explains linked events.
- `HmmIconButton`, `HelpButton`, platform-branched pickers and switches per
  CLAUDE.md. Remind me changes go through `showUndoableAction`.

## Review focus (likely to bite)

1. Two devices offline both create the same linked event → one event after
   sync.
2. The owner changes a reminder, then the source date moves → the reminder
   change survives.
3. A lunar birthday in a leap month, or on 三十 in a short month → shows on
   the backward-fallback day, never vanishes.
4. A 29 February Gregorian birthday → shows on 28 February in non-leap years.
5. Switching the app language → titles follow; nothing duplicates.

## Left to the builder

- Wording and Chinese translations of titles, labels and help.
- Whether the matcher re-passes stored reminders or the service gets a
  keep-owner-settings option.
- Where the display-time title builder lives (shared by detail, agenda,
  inbox and notification text).
- Exact change trigger (Drift watch vs sync listener plus local-change hook)
  and debounce.
- Picker layout details within the platform rules.
- The UUID v5 namespace value.
