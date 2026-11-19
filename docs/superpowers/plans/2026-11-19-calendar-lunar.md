# Calendar Lunar (农历) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show 农历 / 节气 / traditional festivals on the month grid behind a synced switch, and let yearly events repeat on a lunar date (birthdays), with every stored and computed date staying Gregorian.

**Architecture:** One pure wrapper file (`domain/lunar.dart`) is the only importer of the `lunar` package. `RecurrenceRule` learns lunar `BYMONTH`/`SKIP`; the expander turns a supported lunar yearly rule into Gregorian slots; everything downstream (occurrences, overrides, reminders, badge) is untouched. UI reads a synced `showLunarProvider` and the wrapper.

**Tech Stack:** Flutter, Riverpod 3, `lunar` 1.7.8 (pub, MIT), gen-l10n en/zh, shared_preferences via `SyncableSettings`.

**Spec:** `docs/superpowers/specs/2026-11-19-calendar-lunar-design.md` (owner-approved 2026-11-19; calls C-1..C-7 at its end).

## Global Constraints

- Dependency exactly `lunar: 1.7.8` in `pubspec.yaml` (no caret). Only `lib/features/calendar/domain/lunar.dart` imports `package:lunar/...`.
- Gregorian is the only internal calendar: nothing lunar is stored except the RRULE text; no lunar value is persisted for display.
- All lunar text (days, months, 节气, festivals, the lunar part of repeat text) is Chinese in both app languages.
- Supported range: lunar years `kLunarMinYear = 1901` … `kLunarMaxYear = 2099`; outside it no label, no lunar choice, no lunar expansion.
- Month names: 正月 二月 三月 四月 五月 六月 七月 八月 九月 十月 冬月 腊月; leap prefix 闰. Day names: 初一…初十, 十一…十九, 二十, 廿一…廿九, 三十.
- Festivals (non-leap months only): 春节 1/1, 元宵 1/15, 端午 5/5, 七夕 7/7, 中元 7/15, 中秋 8/15, 重阳 9/9, 腊八 12/8, 除夕 = last day of 腊月 (29 or 30).
- Picker-built lunar rule text: `RSCALE=CHINESE;FREQ=YEARLY[;INTERVAL=n];BYMONTH=<m>[L];BYMONTHDAY=<d>;SKIP=BACKWARD[;COUNT=n|;UNTIL=…]`.
- A parsed rule's `format()` still returns its original text for every lunar rule (C-5). Gregorian rules' `format()` output must be byte-identical to today's.
- Project rules: platform-branched switches (Cupertino on iOS/macOS), `HmmIconButton` only, no `ref.watch` inside a LayoutBuilder builder, no WidgetRef/BuildContext after an await, help entries updated with their controls, never `dart format` a directory, commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, never stage CLAUDE.md except the Task 6 calendar-row sentence.

## Review Focus

1. A birthday entered on a January/February date before 春节 (it belongs to the previous lunar year) → next occurrence about a year later on the right day, never skipped or doubled. Pinned in Task 3.
2. A fixed-time event whose own offset differs from the device zone, near midnight → lunar date taken from the event's own wall date (C-3). Pinned in Task 3.
3. Another device on an older build pushes a settings bundle without the lunar key → this device's switch is not reset. Pinned in Task 4.
4. Owner edits a lunar birthday and moves the start date → the rule follows the new start's lunar date. Pinned in Task 6.
5. A "this and following" split of a day-30 birthday lands on 廿九 in a short year → the new series still opens as an editable lunar repeat on day 30, and saving keeps `BYMONTHDAY=30`. Pinned in Task 6.

---

### Task 1: Lunar wrapper and dependency (verifies the package first — C-6)

**Files:**
- Modify: `pubspec.yaml` (add `lunar: 1.7.8`), `pubspec.lock`
- Create: `lib/features/calendar/domain/lunar.dart`
- Test: `test/features/calendar/domain/lunar_test.dart`

**Interfaces:**
- Produces (all pure, date fields only — time-of-day and zone ignored):
  - `const int kLunarMinYear = 1901; const int kLunarMaxYear = 2099;`
  - `class LunarDate { const LunarDate(this.year, this.month, this.day, {this.isLeap = false}); final int year, month, day; final bool isLeap; }` with `==`/`hashCode`.
  - `LunarDate? toLunar(DateTime date)` — null outside range.
  - `DateTime? fromLunar(int year, int month, int day, {bool leap = false})` — exact; null if that lunar date does not exist (no such leap month, or day 30 in a 29-day month) or out of range. Returns `DateTime.utc(y, m, d)`.
  - `DateTime? fromLunarBackward(int year, int month, int day, {bool leap = false})` — SKIP=BACKWARD: a missing leap month uses the normal month of that number; day 30 in a short month becomes day 29. Null only out of range.
  - `enum LunarLabelKind { festival, solarTerm, month, day }`; `class LunarCellLabel { const LunarCellLabel(this.text, this.kind); final String text; final LunarLabelKind kind; }` with `==`/`hashCode`.
  - `LunarCellLabel? lunarCellLabel(DateTime date)` — priority festival > 节气 > month name on day 1 (with 闰) > day name.
  - `String lunarMonthDayText(int month, int day, {bool leap = false})` — e.g. `十月廿八`, `闰四月初八`.
  - `String? lunarFullText(DateTime date)` — `<干支>年<month><day>` plus ` · <festival or 节气>` when there is one, e.g. 2024-02-10 → `甲辰年正月初一 · 春节`.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add lunar:1.7.8` then make sure `pubspec.yaml` reads `lunar: 1.7.8` (exact, no `^`).
Expected: `flutter pub get` succeeds.

- [ ] **Step 2: Write the failing tests** (`lunar_test.dart`; `d(y,m,dd) => DateTime(y,m,dd)`)

```dart
test('春节 dates', () {
  for (final day in [d(2024,2,10), d(2025,1,29), d(2026,2,17)]) {
    expect(lunarCellLabel(day)!.text, '春节');
    expect(lunarCellLabel(day)!.kind, LunarLabelKind.festival);
  }
  expect(toLunar(d(2024,2,10)), const LunarDate(2024, 1, 1));
});
test('other festivals', () {
  expect(lunarCellLabel(d(2024,2,24))!.text, '元宵');
  expect(lunarCellLabel(d(2025,5,31))!.text, '端午');
  expect(lunarCellLabel(d(2025,10,6))!.text, '中秋');
});
test('除夕 on a 29-day and a 30-day 腊月', () {
  expect(lunarCellLabel(d(2026,2,16))!.text, '除夕');
  expect(toLunar(d(2026,2,16)), const LunarDate(2025, 12, 29));
  expect(lunarCellLabel(d(2024,2,9))!.text, '除夕');
  expect(toLunar(d(2024,2,9)), const LunarDate(2023, 12, 30));
});
test('leap months', () {
  expect(toLunar(d(2025,7,25)), const LunarDate(2025, 6, 1, isLeap: true));
  expect(lunarCellLabel(d(2025,7,25))!.text, '闰六月');
  expect(lunarCellLabel(d(2025,7,25))!.kind, LunarLabelKind.month);
  expect(toLunar(d(2023,3,22)), const LunarDate(2023, 2, 1, isLeap: true));
});
test('节气, including terms near the year boundary', () {
  expect(lunarCellLabel(d(2025,12,7))!.text, '大雪');
  expect(lunarCellLabel(d(2025,12,21))!.text, '冬至');
  expect(lunarCellLabel(d(2026,1,5))!.text, '小寒');
  expect(lunarCellLabel(d(2026,4,5))!.text, '清明');
  expect(lunarCellLabel(d(2026,4,5))!.kind, LunarLabelKind.solarTerm);
});
test('plain day', () {
  expect(lunarCellLabel(d(2024,2,11)), const LunarCellLabel('初二', LunarLabelKind.day));
});
test('fromLunar / fromLunarBackward', () {
  expect(fromLunar(2025, 6, 1, leap: true), DateTime.utc(2025,7,25));
  expect(fromLunar(2024, 6, 1, leap: true), isNull);
  expect(fromLunarBackward(2024, 6, 1, leap: true), fromLunar(2024, 6, 1));
  expect(fromLunar(2024, 12, 30), isNull);
  expect(fromLunarBackward(2024, 12, 30), DateTime.utc(2025,1,28));
  expect(fromLunar(2023, 12, 30), DateTime.utc(2024,2,9));
});
test('text', () {
  expect(lunarMonthDayText(10, 28), '十月廿八');
  expect(lunarMonthDayText(4, 8, leap: true), '闰四月初八');
  expect(lunarMonthDayText(11, 5), '冬月初五');
  expect(lunarMonthDayText(12, 20), '腊月二十');
  expect(lunarMonthDayText(1, 1), '正月初一');
  expect(lunarFullText(d(2024,2,10)), '甲辰年正月初一 · 春节');
});
test('out of range', () {
  expect(toLunar(d(1850,1,1)), isNull);
  expect(lunarCellLabel(d(1850,1,1)), isNull);
  expect(fromLunar(2150, 1, 1), isNull);
});
```

- [ ] **Step 3: Run to see them fail**

Run: `flutter test test/features/calendar/domain/lunar_test.dart`
Expected: FAIL (file/functions missing).

- [ ] **Step 4: Implement `lunar.dart`**

Read the package source in the pub cache to confirm the API (expected: `Solar.fromYmd(y,m,d).getLunar()`, `Lunar.fromYmd(y, m, d)` with negative month for leap, `LunarYear.fromYear(y).getLeapMonth()`, `LunarMonth.fromYm(y, m)?.getDayCount()` with negative m for leap, `lunar.getJieQi()`, `lunar.getYearInGanZhi()`). Festivals come from our own table above (not the package's festival list), skipping leap months. 节气 text must be one of the 24 Chinese names — if `getJieQi()` returns an internal key for boundary terms, map it. Month/day names come from our own tables (constraints above). Guard the range before calling the package.

**If the package disagrees with any expected value above, stop and report it — do not change the expected values.**

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/calendar/domain/lunar_test.dart` → all pass. `flutter analyze` → no issues.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/calendar/domain/lunar.dart test/features/calendar/domain/lunar_test.dart
git commit -m "feat(calendar): lunar wrapper over the lunar package (dates, 节气, festivals)"
```

---

### Task 2: RecurrenceRule understands lunar yearly rules

**Files:**
- Modify: `lib/features/calendar/domain/recurrence_rule.dart`
- Test: `test/features/calendar/domain/recurrence_rule_test.dart`

**Interfaces:**
- Produces on `RecurrenceRule`: fields `final int? byMonth; final bool byMonthLeap; final String? skip;` (constructor params default `null`, `false`, `null`);
  `bool get isSupportedLunar` = `rscale == 'CHINESE' && freq == yearly && byMonth in 1..12 && byMonthDay.length == 1 && byMonthDay.single in 1..30 && (skip == null || skip == 'BACKWARD') && byDay.isEmpty && unsupported.isEmpty`;
  `factory RecurrenceRule.lunarYearly({required int month, required int day, bool leap = false, int interval = 1, int? count, DateTime? until})` (rscale `CHINESE`, skip `BACKWARD`, `untilIsDate: true`, `original` null).
- `isCustom` becomes false for supported lunar rules (their yearly BYMONTHDAY no longer counts as custom); all other lunar rules stay custom.

- [ ] **Step 1: Write failing tests**

```dart
test('supported lunar rule parses BYMONTH/SKIP', () {
  final r = RecurrenceRule.parse('RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4L;BYMONTHDAY=30;SKIP=BACKWARD');
  expect([r.byMonth, r.byMonthLeap, r.skip, r.byMonthDay], [4, true, 'BACKWARD', [30]]);
  expect(r.isSupportedLunar, isTrue);
  expect(r.isCustom, isFalse);
  expect(r.unsupported, '');
});
test('SKIP absent is still supported (read as BACKWARD)', () {
  final r = RecurrenceRule.parse('RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15');
  expect(r.isSupportedLunar, isTrue);
  expect(r.format(), 'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15'); // C-5: original kept
});
test('unsupported lunar shapes stay custom and verbatim', () {
  for (final t in [
    'RSCALE=CHINESE;FREQ=MONTHLY;BYMONTHDAY=1',
    'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15;SKIP=FORWARD',
    'RSCALE=HEBREW;FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=1',
    'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4,5;BYMONTHDAY=15',
  ]) {
    final r = RecurrenceRule.parse(t);
    expect(r.isSupportedLunar, isFalse, reason: t);
    expect(r.isCustom, isTrue, reason: t);
    expect(r.format(), t, reason: t);
  }
});
test('lunarYearly formats canonically', () {
  expect(RecurrenceRule.lunarYearly(month: 10, day: 28).format(),
      'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=28;SKIP=BACKWARD');
  expect(RecurrenceRule.lunarYearly(month: 4, day: 30, leap: true, interval: 2, count: 5).format(),
      'RSCALE=CHINESE;FREQ=YEARLY;INTERVAL=2;BYMONTH=4L;BYMONTHDAY=30;SKIP=BACKWARD;COUNT=5');
  expect(RecurrenceRule.parse(RecurrenceRule.lunarYearly(month: 4, day: 8, leap: true).format()).isSupportedLunar, isTrue);
});
test('Gregorian rules with BYMONTH/SKIP are unchanged', () {
  const t = 'FREQ=YEARLY;BYMONTH=3;SKIP=OMIT;BYDAY=1MO';
  final r = RecurrenceRule.parse(t);
  expect(r.byMonth, isNull);
  expect(r.isCustom, isTrue);
  expect(r.format(), t);
});
```
Update the existing test (~line 48) that uses `RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15` as the "custom lunar" example: switch it to `RSCALE=CHINESE;FREQ=MONTHLY;BYMONTHDAY=1` so it still means "unsupported lunar".

- [ ] **Step 2: Run** `flutter test test/features/calendar/domain/recurrence_rule_test.dart` → new tests FAIL.

- [ ] **Step 3: Implement.** In `parse`, BYMONTH and SKIP keep going into `unsupported` in their original position; after the loop, only when the rule is lunar (`rscale` non-null, not `GREGORIAN`) and BYMONTH is a single `^(\d{1,2})(L)?$` value, move them out of `unsupported` into the new fields (SKIP likewise, upper-cased). `format()` canonical order inserts `BYMONTH=<m>[L]` before BYMONTHDAY and `SKIP=<v>` right after it. Update the class doc comment's "Understood" list.

- [ ] **Step 4: Run** the rule tests → PASS. Existing expander/description tests that relied on the old lunar example may now fail; those are updated in Tasks 3 and 6 — note them in the report, don't touch them here.

- [ ] **Step 5: Commit** `feat(calendar): parse lunar yearly rules (BYMONTH with L, SKIP)`

---

### Task 3: Expander and truncate handle supported lunar rules

**Files:**
- Modify: `lib/features/calendar/domain/recurrence_expander.dart` (`_Ctx.slots`), `lib/features/calendar/states/event_edit_state.dart` (`truncateBefore`, ~line 520)
- Test: `test/features/calendar/domain/recurrence_expander_test.dart`, the existing `truncateBefore` tests' file (`grep -rln truncateBefore test`)

**Interfaces:**
- Consumes: `toLunar`, `fromLunar`, `fromLunarBackward` (Task 1); `isSupportedLunar`, `byMonth`, `byMonthLeap` (Task 2).
- Behaviour: `slots()` for a supported lunar rule yields `e.start` first (C-1), then for `k = 0, 1, …` (capped by `kMaxExpansionCandidates`) lunar year `ly = toLunar(baseDate).year + k*interval`, date `fromLunarBackward(ly, byMonth, byMonthDay.single, leap: byMonthLeap)`, yielding `_slotAt(date)` only when `date` is after the base date (C-2); stop at the first null (out of range). If `toLunar(baseDate)` is null, yield only the start. `baseDate` is `_baseWall`'s date — the event's own wall date (C-3). Unsupported lunar rules keep yielding only the start.
- `truncateBefore`: returns null only for `isLunar && !isSupportedLunar`; the truncated rule copies `byMonth`, `byMonthLeap`, `skip`.

- [ ] **Step 1: Write failing tests** (use the file's existing event/expand helpers; expected dates are Task 1's verified values or computed with `fromLunar`):

```dart
test('lunar birthday: 腊月三十 falls on 廿九 in short years', () {
  // start all-day 2024-02-09 = lunar 2023-12-30
  // rule RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=30;SKIP=BACKWARD
  // range 2024-01-01..2027-01-01 → starts 2024-02-09, 2025-01-28, 2026-02-16
});
test('leap-month birthday uses the normal month in other years', () {
  // start 2025-07-25, BYMONTH=6L;BYMONTHDAY=1 → 2025-07-25, then fromLunar(2026, 6, 1)
});
test('normal month never lands in a leap month', () {
  // start fromLunar(2025, 6, 1), BYMONTH=6;BYMONTHDAY=1; range to 2026-01-01 → only that start (not 2025-07-25)
});
test('Review Focus 1: January start belongs to the previous lunar year', () {
  // start 2025-01-28 (lunar 2024-12-29), BYMONTH=12;BYMONTHDAY=29 → 2025-01-28, 2026-02-16
});
test('INTERVAL=2 counts lunar years from the start', () {
  // start 2024-02-10, BYMONTH=1;BYMONTHDAY=1;INTERVAL=2; range to 2027-01-01 → 2024-02-10, 2026-02-17
});
test('COUNT includes the start', () {
  // start 2024-02-10, 1/1, COUNT=2 → 2024-02-10, 2025-01-29 only
});
test('UNTIL stops the series', () {
  // start 2024-02-10, 1/1, UNTIL=20251231 → 2024-02-10, 2025-01-29
});
test('start that does not match the rule is still occurrence 1', () {
  // start 2024-03-01, 1/1 → 2024-03-01, 2025-01-29, 2026-02-17
});
test('Review Focus 2: fixed-time event converts in its own offset', () {
  // FixedTime instant 2024-02-09T16:30Z, offset +08:00 (wall 2024-02-10 00:30 = 春节), 1/1,
  // resolver for a UTC-5 device → second occurrence instant 2025-01-28T16:30Z
});
test('timed floating lunar event keeps its time', () {
  // floating 2024-02-10 09:00, 1/1 → second occurrence wall 2025-01-29 09:00
});
```
Replace the existing stage-1 test (~line 184, "lunar yields only the first occurrence") so it uses the unsupported `RSCALE=CHINESE;FREQ=MONTHLY;BYMONTHDAY=1`. Add `truncateBefore` tests: the 腊月三十 series truncated before its 2026-02-16 occurrence keeps `BYMONTH=12`, `BYMONTHDAY=30`, `SKIP=BACKWARD` and gets `UNTIL=20260215`; an unsupported lunar series still returns null.

- [ ] **Step 2: Run** `flutter test test/features/calendar/domain/recurrence_expander_test.dart` → FAIL.
- [ ] **Step 3: Implement** per the Interfaces block.
- [ ] **Step 4: Run** `flutter test test/features/calendar` and `TZ=Asia/Shanghai flutter test test/features/calendar` → all pass (read the summary line; the description test from Task 2's note may still fail until Task 6 — if so, list it).
- [ ] **Step 5: Commit** `feat(calendar): expand lunar yearly repeats into Gregorian dates`

---

### Task 4: "Show lunar calendar" synced setting

**Files:**
- Modify: `lib/features/settings/domain/syncable_settings.dart`, `lib/features/settings/data/syncable_settings_repository.dart`, `lib/features/settings/presentation/widgets/calendar_settings_section.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (regenerate with `flutter gen-l10n`)
- Create: `lib/features/calendar/states/show_lunar_provider.dart`
- Test: the existing syncable-settings tests (`grep -rln SyncableSettings test`), `test/features/calendar/states/show_lunar_provider_test.dart`, the calendar settings section test if one exists (else `test/features/settings/calendar_settings_section_test.dart`)

**Interfaces:**
- `SyncableSettingsRepository.calendarShowLunarKey = 'calendar.show_lunar'` (public, prefs bool).
- `SyncableSettings.calendarShowLunar`: `bool?` (null = bundle predates the field). JSON key `calendarShowLunar`, written only when non-null, read only when present. `read()` uses `prefs.getBool` (may be null); `apply()` writes only when non-null (C-4).
- `final showLunarProvider = NotifierProvider<ShowLunarNotifier, bool>(…)` — same shape as `ContactSortByNotifier` (`lib/features/settings/providers/contact_sort_provider.dart`): default `false`, hydrates from prefs, re-reads on `settingsBusProvider`; `Future<void> set(bool v)` writes the pref and calls `bumpLastModified()`.
- ARB: `settingsCalendarShowLunar` en "Show lunar calendar" / zh "显示农历"; `settingsCalendarShowLunarSubtitle` en "农历 dates, 节气 and festivals on the month grid. Synced across your devices." / zh "在月历上显示农历日期、节气和传统节日。在你的设备间同步。"

- [ ] **Step 1: Failing tests**
  - JSON round-trip keeps `true`/`false`; bundle JSON without the key gives `calendarShowLunar == null`.
  - Review Focus 3: pref `calendar.show_lunar = true`, `apply(bundle with calendarShowLunar: null)` leaves it `true`; `apply(…: false)` sets `false`.
  - Provider: starts `false`, hydrates `true` from prefs; `set(true)` persists and bumps last-modified.
  - Section: Cloud API mode renders nothing; otherwise a "Show lunar calendar" row with a switch renders even when `calendarRemindersSupported` is false (only the remind and permission rows depend on it); tapping it sets the provider.
- [ ] **Step 2: Run** those test files → FAIL.
- [ ] **Step 3: Implement.** Section: return empty only in Cloud API mode; title + lunar row always; existing remind/permission rows only when `calendarRemindersSupported`. `CupertinoSwitch` on iOS/macOS, `Switch` elsewhere (existing `isApple` pattern). Update the class doc comment.
- [ ] **Step 4: Run** the touched test files and `flutter analyze` → clean.
- [ ] **Step 5: Commit** `feat(calendar): synced "Show lunar calendar" setting`

---

### Task 5: Month grid labels and selected-day lunar text

**Files:**
- Modify: `lib/features/calendar/presentation/widgets/month_grid.dart`, `lib/features/calendar/presentation/widgets/agenda_list.dart`, `lib/features/calendar/presentation/screens/calendar_home_screen.dart`, ARB (`helpCalendarMonthBody` en/zh)
- Test: `test/features/calendar/presentation/calendar_home_screen_test.dart` (or a new `month_grid_test.dart` for the widget alone)

**Interfaces:**
- Consumes: `lunarCellLabel`, `lunarFullText`, `LunarCellLabel`, `LunarLabelKind` (Task 1); `showLunarProvider` (Task 4).
- `MonthGrid` gains `final Map<int, LunarCellLabel>? lunarLabels;` (null = off; keyed by day of month). When non-null, cells are 56 pt tall (44 today) and show the label under the number with `Key('calendar-lunar-$day')`, `labelSmall`-sized, `colorScheme.primary` for festival/solarTerm, `onSurfaceVariant` otherwise; the event dot stays below the label.
- `AgendaList` gains `final String? lunarText;` shown in the date header as `"<full date> · <lunarText>"`.
- Home screen: `ref.watch(showLunarProvider)` in `build()` (not inside any LayoutBuilder builder), pass the flag into `_content`, build the label map for the visible month and `lunarFullText(data.day)` only when on.
- `helpCalendarMonthBody`: append en " With Show lunar calendar on (Settings), each day also shows its 农历 date, 节气 or festival." / zh "在设置中打开"显示农历"后，每天还会显示农历日期、节气或节日。"

- [ ] **Step 1: Failing widget tests**
  - Switch off: no `calendar-lunar-*` keys; existing tests stay green.
  - Switch on, Feb 2026: `calendar-lunar-17` shows `春节`, `calendar-lunar-16` `除夕`, `calendar-lunar-18` `初二`; Apr 2026: `calendar-lunar-5` `清明`.
  - Switch on, selected 2024-02-10: agenda header contains `甲辰年正月初一 · 春节`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/calendar` → pass.
- [ ] **Step 5: Commit** `feat(calendar): 农历, 节气 and festivals on the month grid`

---

### Task 6: Editor lunar choice, repeat text, help, CLAUDE.md row

**Files:**
- Modify: `lib/features/calendar/states/event_edit_state.dart` (`EventForm`), `lib/features/calendar/presentation/widgets/repeat_picker.dart`, `lib/features/calendar/presentation/widgets/repeat_description.dart`, ARB en/zh, `CLAUDE.md` (calendar row only)
- Test: `test/features/calendar/presentation/event_edit_screen_test.dart`, `test/features/calendar/presentation/repeat_description_test.dart`, EventForm tests (`grep -rln "EventForm" test`)

**Interfaces:**
- Consumes: `toLunar`, `fromLunarBackward`, `lunarMonthDayText`, `LunarDate` (Task 1); `RecurrenceRule.lunarYearly`, `isSupportedLunar` (Task 2).
- `EventForm` gains `final bool lunar` (default false) and `final LunarDate? lunarAnchor` (the rule's month/day/leap when opened from a rule). `copyWith(start:)` with a different start clears `lunarAnchor` (re-derive from the new start); `copyWith(lunar:)` sets the flag.
- `EventForm.fromEvent`: a supported lunar rule whose `fromLunarBackward(toLunar(seriesStartDate).year, byMonth, byMonthDay.single, leap: byMonthLeap)` equals the series start date opens as `freq: yearly, lunar: true, lunarAnchor: LunarDate(that year, byMonth, day, isLeap: byMonthLeap)` with interval/count/until as for Gregorian; any other lunar rule stays `customRule` (clear-only).
- `EventForm.rrule`: when `freq == yearly && lunar`, anchor = `lunarAnchor ?? toLunar(dateOnly(start))`; build `RecurrenceRule.lunarYearly(month:, day:, leap:, interval:, count:, until:)` (same count/until mapping as Gregorian); if the anchor is null (out of range), fall back to the Gregorian yearly rule.
- Picker: when `freq == yearly` and `toLunar(form.start) != null`, a second `_choice<bool>` (keyPrefix `calendar-repeat-calendar`) with `false: l.calendarRepeatOnDate(DateFormat.MMMd(locale).format(start))`, `true: l.calendarRepeatOnLunarDate(lunarMonthDayText(...))` from the current anchor. Out of range → no choice shown, `lunar` treated as false.
- `describeRepeat`: a supported lunar rule reads `l.calendarRepeatLunarYearlyText(n, lunarMonthDayText(byMonth, day, leap: byMonthLeap))` plus the existing count/until suffix; unsupported lunar still `calendarRepeatLunar`.
- ARB (en / zh):
  - `calendarRepeatOnDate` "On {date}" / "{date}"
  - `calendarRepeatOnLunarDate` "On 农历{date}" / "农历{date}"
  - `calendarRepeatLunarYearlyText` `{n, plural, =1{Every year on 农历{date}} other{Every {n} years on 农历{date}}}` / `{n, plural, =1{每年农历{date}} other{每{n}年农历{date}}}`
  - `helpCalendarEventEditRepeatBody` en: "Choose how often it repeats and when the repeat ends. A yearly repeat can follow the lunar date (农历) of the start day: a leap-month date falls in the normal month in other years, and day 30 falls on day 29 when that month is short. A repeat set elsewhere is shown as Custom or Lunar and can only be cleared." zh: "选择重复频率和结束方式。每年重复可以按开始日期的农历日期：闰月日期在其他年份落在同名的普通月份，三十日在小月落在廿九。在其他地方设置的重复显示为"自定义"或"农历"，只能清除。"
- CLAUDE.md calendar row: after "anything else shown as Custom repeat" add "; yearly repeats can follow a lunar date (`RSCALE=CHINESE`, expanded to Gregorian), and Settings → Calendar → Show lunar calendar (synced) adds 农历/节气/festival labels to the month grid".

- [ ] **Step 1: Failing tests**
  - Picker: yearly on 2025-11-18 shows both choices; picking lunar → `form.rrule == RecurrenceRule.lunarYearly(month: toLunar(d).month, day: toLunar(d).day, leap: toLunar(d).isLeap).format()`; the description shows `Every year on 农历…`.
  - Review Focus 4: lunar form, then `copyWith(start: DateTime(2026,2,17,9))` → `rrule` contains `BYMONTH=1;BYMONTHDAY=1`.
  - Review Focus 5: event all-day start 2025-01-28 with rule `RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=30;SKIP=BACKWARD` → `fromEvent` gives `lunar == true`, `lunarAnchor.day == 30`, and `rrule` contains `BYMONTHDAY=30`.
  - A supported lunar rule that does not match its start (start 2024-03-01, rule 1/1) → `customRule` set; picker shows clear-only.
  - Description: `RSCALE=CHINESE;FREQ=YEARLY;INTERVAL=2;BYMONTH=4L;BYMONTHDAY=8;SKIP=BACKWARD;COUNT=3` → en starts "Every 2 years on 农历闰四月初八" with the existing count suffix; zh starts "每2年农历闰四月初八". Update the existing description test (~line 41) to use `RSCALE=CHINESE;FREQ=MONTHLY;BYMONTHDAY=1` for "Lunar repeat".
  - Start outside range (2150) → no `calendar-repeat-calendar-*` keys.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Verify the whole branch:** `flutter analyze` clean; `flutter test` full suite (read the summary line); `TZ=Asia/Shanghai flutter test test/features/calendar`.
- [ ] **Step 5: Commit** (stage CLAUDE.md for this row only) `feat(calendar): lunar yearly repeat in the editor`

---

### Task 7: Owner device check (owner, after install)

Install per the deploy rules (back up first; never uninstall). Owner checks: switch off → grid unchanged; switch on → 农历/节气/festivals appear on both devices (synced); a lunar birthday shows the right next Gregorian date and reminds; leap/day-30 text reads correctly in English and Chinese.
