# Calendar: lunar calendar (农历) — design

Tracker #81. Follow-up to calendar stage 1
(`2026-11-17-calendar-reminders-stage1-design.md`, "Lunar repeats are reserved,
not built"). Owner decisions 2026-11-17 and 2026-11-19.

## Why

The owner keeps **family birthdays and traditional festivals** on the Chinese
lunar calendar. Today the app can store a lunar repeat but only ever shows its
first date, cannot create one, and shows no lunar dates. Success: a birthday
entered once on its lunar date reminds every year on the right Gregorian day,
and the month grid reads like a Chinese wall calendar when lunar display is on.

## Goals

1. **Lunar display on the month grid**, behind one switch.
2. **Yearly lunar repeats**: create, edit, expand, remind.

## Non-goals (this project)

- **Public holidays by country** (Canada, China, US, India…; China's 调休
  workdays) — the next separate project.
- **Linked important dates** (licence/ID expiry, contact birthdays created by
  the owning feature as subsystem events) — the project after that.
- Festival *reminders*: festivals are labels only. To be reminded, the owner
  makes an ordinary lunar-yearly event.
- Lunar monthly repeats (初一/十五 each month), 八字/黄历/宜忌, lunar date pickers.

## Anti-goals

- A lunar event firing on a wrong Gregorian day. When a rule can't be expanded
  correctly, keep stage 1 behaviour (first occurrence only).
- Sending any data off the device: conversion is fully offline.

## Approaches considered

- **A. `lunar` pub package (6tail, MIT, pure Dart, offline, no dependencies)** —
  **chosen by the owner.** Covers lunar dates with leap months, 节气 and
  traditional festivals. Costs one dependency and unused extras (八字 etc.).
- B. Own compact month table (~1900–2100) + precomputed 节气 table — small and
  controlled, but we would own every off-by-one bug and the astronomy data.
- C. Platform Chinese calendar via method channel — neither iOS nor Android
  gives 节气, a channel call per date is slow for a grid, and nothing runs in
  `flutter test`. Rejected.

## Design

### 1. Lunar module

- Dependency `lunar: 1.7.8` (pinned exactly; 1.7.9 is under two weeks old).
- All use of the package goes through one small pure file,
  `lib/features/calendar/domain/lunar.dart`, so the rest of the app never
  imports the package. It exposes (names are the builder's call):
  - Gregorian date → lunar date `(year, month 1–12, isLeap, day 1–30)`.
  - Lunar `(year, month, isLeap, day)` → Gregorian date, or null if that lunar
    date doesn't exist that year.
  - Gregorian date → the cell label (below) and the full lunar text.
- Supported range: what the package supports (at least 1900–2100). Outside it,
  no label and no lunar expansion.

### 2. Show lunar calendar switch

- **Settings → Calendar → "Show lunar calendar"**, default **off**, **synced**
  across devices (a `SyncableSettings` key, e.g. `calendar.show_lunar`).
  Owner decision: one switch covers lunar days, 节气 and festivals together.
- Off: the grid is exactly as today.
- Lunar *repeats* work whatever the switch says (a birthday must still remind).

### 3. Month grid label

When on, each day cell gets a second small line under the date number. The
first match wins:

1. **Traditional festival** (lunar-dated): 春节 (正月初一), 元宵 (正月十五),
   端午 (五月初五), 七夕 (七月初七), 中元 (七月十五), 中秋 (八月十五),
   重阳 (九月初九), 腊八 (腊月初八), 除夕 (last day of 腊月, 29 or 30).
2. **节气** falling that day (24 terms; 清明 and 冬至 included here).
3. **First day of a lunar month**: the month name — 正月, 二月 … 冬月, 腊月;
   leap months 闰四月.
4. Otherwise the **lunar day**: 初一 … 初十, 十一 … 二十, 廿一 … 廿九, 三十.

Festival and 节气 labels are tinted with the accent colour; plain lunar days
use the secondary text colour. Labels are Chinese in both app languages — they
are the names. The event dot stays under the label; cell height grows to fit
(today 44 pt). Grid sketch:

```
 18      19      20      21
廿八    廿九    小雪    初二
  •
```

**Selected day** (builder's call where exactly; the existing day header above
the agenda is the natural place): when on, show the full lunar text after the
Gregorian date, e.g. `乙巳年十月廿八 · 小雪`.

### 4. Lunar yearly repeats

**Stored form** (RFC 7529):

```
RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=28;SKIP=BACKWARD
RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4L;BYMONTHDAY=30;SKIP=BACKWARD   (leap 4th month, day 30)
```

`INTERVAL`, `COUNT` and `UNTIL` work as for Gregorian rules.

**Expansion rules** (owner-approved 2026-11-17):

- A **leap-month** date (`4L`) falls in the leap month in years that have that
  same leap month, and in the **normal month** of that number in all other
  years (SKIP=BACKWARD semantics).
- **Day 30** falls on **day 29** in years where that month is short.
- A normal-month date (`BYMONTH=4`) never falls in a leap 4th month.
- Time of day, all-day and time-zone handling are exactly as for Gregorian
  events (the expander's existing slot logic).

**Which lunar rules expand:** `RSCALE=CHINESE`, `FREQ=YEARLY`, one `BYMONTH`
(with optional `L`), one `BYMONTHDAY` 1–30, `SKIP` absent or `BACKWARD`,
plus INTERVAL/COUNT/UNTIL. Anything else lunar (another RSCALE, other FREQ,
SKIP=FORWARD/OMIT, extra parts) keeps stage 1 behaviour: kept verbatim, shown
as "Lunar repeat", first occurrence only, picker can only clear it. (SKIP
absent is read as BACKWARD because that is what our editor means; RFC default
is OMIT — builder's call recorded here, owner can overrule.)

**Parser:** `RecurrenceRule` learns `BYMONTH` (with `L`) and `SKIP` for lunar
rules; a lunar rule we understand is formatted canonically, one we don't is
still returned exactly as parsed.

**This-and-following / truncate:** `truncateBefore` and the edit-scope paths
handle supported lunar rules like Gregorian ones (UNTIL the day before);
unsupported lunar rules keep returning null as today.

### 5. Editor

- When **Repeat = Yearly**, the repeat picker offers a choice between
  `Every year on Nov 18` (Gregorian, today's behaviour) and
  `Every year on 农历十月廿八` (lunar). The lunar month/day/leap is taken from
  the event's **start date**; changing the start date updates it. The choice is
  available whether or not the display switch is on.
- Picking lunar writes the stored form above. An existing rule of that exact
  supported shape opens as editable (Yearly + lunar selected); unsupported
  lunar rules stay "Lunar repeat", clear-only, as today.
- If the start date is outside the supported range, the lunar choice is
  disabled.

### 6. Descriptions

- Repeat text: en `Every year on 农历十月廿八`, zh `每年农历十月廿八`; leap
  months `农历闰四月初八`. Interval/count/until suffixes as for Gregorian.
- Event detail shows that text; the next Gregorian date is already shown by
  the occurrence.

### 7. Help and docs

- Help entries updated: Settings calendar section (new switch), event edit
  repeat (lunar choice, leap/day-30 rules in one sentence), month grid
  (labels).
- CLAUDE.md calendar row: one sentence replacing "anything else shown as Custom
  repeat" mention of lunar.

## Testing

- Lunar module against known dates: 春节 for 2024 (Feb 10), 2025 (Jan 29),
  2026 (Feb 17); 中秋 2025 (Oct 6); a leap year (2025 has 闰六月; 2023 闰二月);
  除夕 on a 29-day 腊月; 节气 days (e.g. 冬至 2025-12-21, 清明 2026-04-05).
- Expansion: leap-month birthday across leap and non-leap years; day-30
  birthday in a short month; INTERVAL=2; COUNT; UNTIL; all-day and timed;
  `TZ=Asia/Shanghai` run of the calendar suite as before.
- Parser round-trip: supported lunar rules canonical, unsupported verbatim.
- Grid widget: switch off = unchanged; label priority order.
- ReminderSync needs no change — it uses the expander — but a test confirms a
  lunar event yields reminders on the right days.

## Calls settled after the builder check (designer's calls, owner may overrule)

- **C-1 Start is occurrence 1.** As for Gregorian rules, the event's start is
  always the first occurrence; rule dates continue after it. The editor keeps
  the rule aligned with the start, so they differ only for rules written
  elsewhere.
- **C-2 Interval and first year.** INTERVAL counts lunar years from the
  start's lunar year (a January date may belong to the previous lunar year).
  A rule date in that first lunar year that falls before the start is
  dropped. COUNT counts occurrences including the start.
- **C-3 Which date converts.** The event's own wall date converts: the
  floating/all-day date as stored, or for a fixed-time event the wall date in
  its own stored offset — never the device zone.
- **C-4 Setting sync.** `show_lunar` is a nullable `SyncableSettings` field
  (absent ≠ false), modelled like `notesSavedSearches`, so older clients
  don't clobber it. The switch is hidden in Cloud API mode, like the
  reminders switch.
- **C-5 No silent rewrite.** A parsed lunar rule keeps returning its original
  text from `format()` until the picker builds a new rule; only picker-built
  rules are canonical (with `SKIP=BACKWARD`). Supported shapes stop counting
  as custom, so the picker opens them as editable; other lunar rules stay
  "Lunar repeat". Existing "Lunar repeat" tests for unsupported shapes keep
  passing.
- **C-6 Package verified first.** The plan's first task pins every test date
  above against `lunar` 1.7.8 before any expansion code is written; a
  disagreement stops the work and comes back to the owner.
- **C-7 Expansion cap.** Lunar yearly expansion reuses
  `kMaxExpansionCandidates` (counted in lunar years), like Gregorian yearly.

## Left to the builder

File layout inside `features/calendar`, provider names, exact picker UI
(segmented control vs. two rows, platform-branched per the UI rules), label
font size, where the selected-day lunar text sits.
