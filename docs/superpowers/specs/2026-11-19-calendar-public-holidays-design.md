# Calendar: public holidays — design

Follow-up to the lunar calendar (#81, `2026-11-19-calendar-lunar-design.md`).
Second of the owner's three calendar projects (lunar → public holidays →
linked important dates). Owner decisions 2026-11-19.

## Why

The owner lives in Ontario, Canada, and has family in China. They want to
**see at a glance which days are days off** for both, and to **plan around
holidays** (e.g. make an ordinary event to send New Year greetings). China's
make-up workdays (调休/补班) matter: a weekend that is a workday for the family
must not look free.

Success: with China and Canada (Ontario) on, the month grid marks every day
off and every 补班 day correctly, tapping a day names the holidays in their
own language, and next year's dates arrive by themselves.

## Goals

1. Public holidays for **any number of countries** (with a region where the
   country's holidays differ by region), added and removed by the owner.
2. **Marks on the month grid** and **names in the selected day's detail**.
3. **My holidays**: the owner's own days off, one-time or yearly, synced.
4. Correcting a downloaded holiday that is wrong for the owner.

## Non-goals

- Holiday **reminders**. To be reminded, the owner makes an ordinary event.
- Holidays as calendar **events** (they never appear in the agenda list, never
  get reminders, never sync as notes).
- Lunar-dated My holidays (lunar repeating events already cover these).
- Going through the Hmm server (approach B below) — possible later.
- Linked important dates — the next project.

## Anti-goals

- **Sending anything personal off the device.** Holiday requests carry only a
  country code and a year. They never carry the Hmm access token, the user's
  name or email, or any event data.
- The calendar waiting on the network. Grid and day detail render from what is
  saved; holidays appear when they arrive.
- Showing a downloaded day off that the owner has hidden, or hiding one they
  have not.

## Data sources (checked 2026-11-19)

- **Nager.Date** `https://date.nager.at/api/v3/PublicHolidays/{year}/{CC}` —
  free, no key. Each entry: `date`, `localName` (native language), `name`
  (English), `global` (bool), `counties` (ISO 3166-2 codes like `CA-ON`, or
  null), `types` (`Public`, `Bank`, `School`, `Optional`, `Observance`, …).
  Available countries: `https://date.nager.at/api/v3/AvailableCountries`.
  Canada 2025 is complete and region-tagged (Ontario: New Year's Day, Family
  Day, Good Friday, Victoria Day, Canada Day, Civic Holiday, Labour Day,
  National Day for Truth and Reconciliation, Thanksgiving, Christmas Day,
  Boxing Day).
- **Nager's China data is unusable**: one day per holiday, no 清明节, no 调休.
- **holiday-cn** (open data set built from State Council notices)
  `https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{year}.json`
  — `{ year, papers: [gov.cn URL], days: [{ name, date, isOffDay }] }`.
  2025 has the full blocks (春节 Jan 28–Feb 4) and the 补班 days
  (`isOffDay: false`, e.g. Jan 26, Feb 8). 2026 is published. A year not yet
  announced returns 404.

## Approaches considered

- **A. Each device fetches and saves — chosen by the owner.** The app fetches
  a year per country the first time it is needed, saves it, and re-checks now
  and then. One small adapter per source turns its format into a common list.
  Least work, offline once saved, nothing personal sent. Each device contacts
  Nager and GitHub itself.
- B. Through the Hmm server — one place to fix a source and devices only talk
  to our server; costs C# work and a VPS deploy, and no new years while the
  VPS is down. Adapters in A keep this switch cheap later.
- C. Bundled in the app — fully offline, but each year's China announcement
  (around November) would need a new build.

## Design

### 1. Model (all Gregorian, display-only)

A holiday day is `(date, name, offDay: bool, sourceId)`:

- `date` — a calendar date (no time, no zone).
- `name` — the source's native name (`localName` for Nager, `name` for
  holiday-cn; e.g. `国庆节、中秋节`, `Family Day`). Shown as is in every app
  language, like the lunar text.
- `offDay` — true = day off (休), false = make-up workday (班). Nager entries
  are always day off; holiday-cn uses `isOffDay`.
- `sourceId` — which country/region (or My holidays) it came from.

Holidays are **never stored as events** and never pass through the recurrence
expander or ReminderSync. Like the lunar label, they are looked up per day for
display.

### 2. Sources and adapters

- A `HolidaySource` interface: `fetchYear(year) → List<HolidayDay>` (or "not
  published yet" / failure).
- `NagerSource(country, region?)`: keep entries whose `types` contains
  `Public` and that are `global == true` or whose `counties` contains the
  region. With no region chosen, only `global` entries.
- `HolidayCnSource`: used for country `CN` instead of Nager, always.
- One plain `Dio` instance for both, **without** the Hmm API interceptors (no
  auth header), with a generic user agent and a short timeout.

### 3. Saving and refreshing (per device, not synced)

- Each fetched (source, year) is saved on the device with the time it was
  fetched. Builder's call where (a small JSON file per source-year or a prefs
  entry); it is a cache, not user data, and is not synced.
- **Which years:** the year being shown in the grid, and next year from
  1 November (China announces around then).
- **When to re-check:** a saved current or future year is re-fetched when it is
  more than 7 days old; past years are never re-fetched. "Not published yet"
  is retried at most once a day. Failures are silent and keep what is saved.
- Fetches run in the background when the calendar opens or the shown year
  changes; the grid updates when they land.
- Removing a country deletes its saved years.

### 4. Countries list (synced)

- **Settings → Calendar → Holidays** opens a new screen (with its own `HelpId`
  and `HelpButton`).
- The list shows each chosen country (flag, name, region if any, its colour,
  and "Updated <date>" or "2027 not published yet"), plus a **My holidays**
  row.
- **Add country**: pick from Nager's available countries; when the country's
  data has region-only holidays, then pick a region (or "whole country" =
  national holidays only). Region names: a small built-in table for Canada
  (and the US); other countries show the ISO code. Builder's call how the
  region list is gathered (e.g. the `counties` codes seen in the current
  year).
- **Remove**: swipe (Material: swipe or menu, per platform rules). Removal is
  undoable via `showUndoableAction`.
- **Colour**: each added country gets the next unused colour from a small
  fixed palette (at least 6, readable in light and dark); stored with it.
- **Synced** as a nullable `SyncableSettings` field (absent ≠ empty, like
  `notesSavedSearches` and `calendarShowLunar`) so older clients don't clobber
  it. Key e.g. `calendar.holiday_regions`. When absent the default is
  **China + Canada (Ontario)**; once the owner edits the list, it is stored.
- Hidden in Cloud API mode, like the rest of the calendar settings.

### 5. My holidays (synced)

- A list screen reached from the Holidays screen's My holidays row; add, edit,
  remove (remove undoable).
- An entry: name, **one-time** (a date or a date range) or **yearly** (the
  same month/day every year; Feb 29 falls on Feb 28 in other years), and
  **day off** (default) or **workday**.
- Synced as another nullable `SyncableSettings` field (e.g.
  `calendar.my_holidays`), whole-list, last writer wins, like saved searches.
- My holidays have their own colour and show as source "My holiday".

### 6. Correcting a downloaded holiday

- In the day detail, a downloaded holiday has a **Hide** action ("Not a day
  off for me"). Hiding is keyed by (source, holiday name) and applies **every
  year** (e.g. hide Ontario's National Day for Truth and Reconciliation once).
- Hidden holidays are listed at the bottom of My holidays with **Show again**.
- Stored in the same synced My holidays data (designer's call: one field keeps
  the owner's corrections together).

### 7. Month grid

- When at least one source has a holiday on a day, the cell gets a mark in the
  top-right corner:
  - one source: **休** (day off) or **班** (workday) in that source's colour;
  - two or three sources: one small dot per source in its colour (a workday
    dot is hollow); more than three: three dots.
- Works with or without the lunar labels; the lunar line and event dot keep
  their places. No holiday names in the cell (they don't fit; the owner
  agreed).
- Sketch (lunar on):

  ```
   ┌──────┬──────┬──────┐
   │ 30 班│  1 休│  2 休│
   │ 初九 │ 初十 │ 十一 │
   └──────┴──────┴──────┘
  ```

### 8. Selected day detail

- Under the day header (where the lunar text sits), one line per holiday:
  flag (or a person icon for My holidays), name, and "Day off" / "Workday"
  (localized UI words). For a multi-day block the builder may add the range,
  e.g. `国庆节、中秋节 · Day off (Oct 1–8)`.
- Tapping a downloaded holiday offers Hide (§6).

### 9. Help and docs

- New help entries: Holidays screen, My holidays screen.
- Updated: month grid help (the marks), calendar settings mention.
- CLAUDE.md calendar row: one sentence on public holidays.

## Testing

- Adapters against saved fixtures: Nager CA 2025 filtered to Ontario (11
  days, Family Day in, Louis Riel Day out); no-region = global only; non-Public
  types dropped. holiday-cn 2025: Jan 28 off, Jan 26 workday, 清明节 Apr 4–6;
  404 → "not published yet".
- Refresh policy: past years never re-fetched; current year after 7 days;
  next year only from Nov 1; failure keeps saved data.
- No auth header and no personal data on holiday requests (assert on the Dio
  instance / request).
- Merging: several sources on one day; My holidays one-time range and yearly
  (Feb 29 → Feb 28); hidden holiday hidden in all years and back on Show
  again.
- Settings sync: absent ≠ empty for both fields; default China + Canada (ON).
- Grid widget: one source 休/班 in colour; two sources dots; none = cell as
  today. Day detail lines and Hide.
- Calendar suite under `TZ=Asia/Shanghai` as before.

## Left to the builder

File layout under `features/calendar`, cache format and location, provider
names, palette values, exact badge size and placement, how the region list is
gathered, whether the day detail shows block ranges.

## Calls I made (owner may overrule)

- Holidays are display data, not events (no agenda rows, no reminders).
- Offline with nothing saved → no holidays shown, no error.
- Cloud API mode → no holidays (as the rest of the calendar).
- Hiding a downloaded holiday is per name and applies to every year.
- Default list when never edited: China + Canada (Ontario).
- Canada's "observed" substitute days (a holiday on a weekend moved to Monday)
  appear only if the source lists them; Nager lists the actual date. Fix with
  My holidays if needed.
