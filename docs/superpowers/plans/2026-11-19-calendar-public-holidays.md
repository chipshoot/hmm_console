# Calendar Public Holidays Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mark public holidays (any number of countries, China via holiday-cn, others via Nager.Date) and the owner's own holidays on the calendar month grid and in the selected day's detail, managed from a Holidays screen inside the calendar.

**Architecture:** Holidays are display-only data, never events. Pure domain types and a merge index (`holidays.dart`); one adapter per source behind `HolidaySource`; a per-device file cache with a refresh policy; two nullable synced `SyncableSettings` fields (country list, My holidays + hidden); Riverpod providers that feed `MonthGrid` marks and `AgendaList` lines; two new screens under `/calendar/holidays`.

**Tech Stack:** Flutter, Riverpod 3, Dio 5 (plain instance), shared_preferences, path_provider, gen-l10n en/zh.

**Spec:** `docs/superpowers/specs/2026-11-19-calendar-public-holidays-design.md` (read it; H-1…H-9 are binding).

## Global Constraints

- Holidays are never `CalendarEvent`s: no agenda rows, no reminders, never through the recurrence expander or ReminderSync.
- Holiday requests carry only a country code and a year: one plain `Dio` with **no** Hmm API interceptors, no auth header, generic user agent `hmm-console`, timeouts 10 s.
- Sources: Nager `https://date.nager.at/api/v3/PublicHolidays/{year}/{CC}` and `https://date.nager.at/api/v3/AvailableCountries`; China always `https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{year}.json` (404 = not published yet). Nager is never used for `CN`.
- Nager filter: `types` contains `Public` AND (`global == true` OR `counties` contains the region). No region → `global` only. Nager days are always day off.
- Holiday names are shown as the source gives them (`localName` / holiday-cn `name`) in every app language. Grid marks are the characters **休** / **班** in every language.
- Refresh: years = shown month's year (the grid draws only that month's days, so H-9 reduces to this), plus next year when device-local today is on/after 1 November. Past years never re-fetched; a saved current/future year re-fetched when > 7 days old; "not published" retried at most once a day; failures silent, saved data kept.
- Synced keys: `calendar.holiday_regions` (JSON list `{country, region?, color}`) and `calendar.my_holidays` (JSON object `{entries:[{id,name,kind:"once"|"yearly",start,end?,offDay}], hidden:[{source,name}]}`), dates `YYYY-MM-DD`. Both nullable (absent ≠ empty); every edit calls `bumpLastModified()`.
- Default region list when the key is absent: China, then Canada/Ontario (`[{country:"CN",color:0},{country:"CA",region:"CA-ON",color:1}]`); not written until the owner edits.
- Hide (H-1) drops every day with that (source, name), off and 班, all years.
- Date-only values are `DateTime(y, m, d)` (local midnight); parse `YYYY-MM-DD` by splitting, never `DateTime.parse`.
- Holidays live in the calendar (`/calendar/holidays`), nothing is added to Settings.
- Project rules: `HmmIconButton` with localized tooltip for icon buttons; every new screen gets a `HelpId` + `HelpButton` + ARB help keys; removals via `showUndoableAction`; platform-branch switches/sheets/dialogs on `Theme.of(context).platform`; FAB on Android only; no `ref.watch` inside `LayoutBuilder`; no `WidgetRef`/`BuildContext` after an `await`; never `dart format` a directory (format files you touched only).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Branch `feat/calendar-holidays`; never amend; never stage CLAUDE.md except the planned row in Task 7.

## Review Focus

1. A source returns malformed JSON (not a list, missing `date`, bad date string) → that fetch counts as a failure, saved data is kept, nothing throws into the UI. (Task 2 test.)
2. Holiday dates shift a day if parsed through UTC → `2025-01-28` must land on Jan 28 in `TZ=Asia/Shanghai` and the default zone. (Task 1 test; calendar suite under both zones in Task 8.)
3. The owner adds the same country/region twice → the list keeps one entry. (Tasks 4 and 6 tests.)
4. A synced bundle from an older client without the new keys → local holiday settings untouched. (Task 4 test.)
5. Next year is "not published" in November and published the next day → it appears without user action after the daily retry. (Task 3 test.)

---

## File Structure

- `lib/features/calendar/domain/holidays.dart` — types, JSON, `parseYmd`, `HolidayIndex`, `flagEmoji`, palette.
- `lib/features/calendar/domain/region_names.dart` — Canada and US subdivision names.
- `lib/features/calendar/data/holiday_sources.dart` — `HolidayFetch`, `HolidaySource`, `NagerSource`, `HolidayCnSource`, `sourceFor`, `holidayDio`, `fetchAvailableCountries`, `regionCodesIn`.
- `lib/features/calendar/data/holiday_cache.dart` — `HolidayCache`, `yearsToFetch`, `needsFetch`, `HolidayRefresher`.
- `lib/features/settings/domain/syncable_settings.dart`, `lib/features/settings/data/syncable_settings_repository.dart` — two fields/keys.
- `lib/features/calendar/states/holiday_settings_providers.dart` — `holidayRegionsProvider`, `myHolidaysProvider`.
- `lib/features/calendar/states/holiday_providers.dart` — cache/dio/refresher providers, `holidaysForMonthProvider`, marks/colours helpers.
- `lib/features/calendar/presentation/widgets/month_grid.dart`, `agenda_list.dart`, `screens/calendar_home_screen.dart` — marks, lines, Holidays button.
- `lib/features/calendar/presentation/screens/holidays_screen.dart`, `my_holidays_screen.dart`, `widgets/my_holiday_editor.dart`.
- `lib/core/navigation/calendar_routes.dart` (+ `RouterNames`), `lib/core/help/help_registry.dart`, `lib/l10n/app_en.arb`, `app_zh.arb`.

---

### Task 1: Holiday domain types and merge index

**Files:**
- Create: `lib/features/calendar/domain/holidays.dart`
- Test: `test/features/calendar/domain/holidays_test.dart`

**Interfaces:**
- Produces:
  - `DateTime? parseYmd(String s)` (null on bad input); `String ymd(DateTime d)`.
  - `class HolidayDay { final DateTime date; final String name; final bool offDay; final String sourceId; }` (value equality).
  - `class HolidayRegion { final String country; final String? region; final int color; String get sourceId => region ?? country; Map<String, Object?> toJson(); static HolidayRegion? fromJson(Object?); }` (value equality).
  - `const kDefaultHolidayRegions = [HolidayRegion(country: 'CN', color: 0), HolidayRegion(country: 'CA', region: 'CA-ON', color: 1)];`
  - `enum MyHolidayKind { once, yearly }`; `class MyHoliday { String id; String name; MyHolidayKind kind; DateTime start; DateTime? end; bool offDay; }`; `class HiddenHoliday { String source; String name; }`; `class MyHolidaysData { List<MyHoliday> entries; List<HiddenHoliday> hidden; Map<String, Object?> toJson(); static MyHolidaysData fromJson(Object?); }` (unreadable entries skipped; non-map → empty). All value-equal.
  - `const kMyHolidaysSourceId = 'mine';`
  - `class HolidayIndex { HolidayIndex({required List<HolidayDay> downloaded, required MyHolidaysData mine, required List<String> sourceOrder}); List<HolidayDay> on(DateTime date); Map<int, List<HolidayDay>> forMonth(DateTime month); ({DateTime from, DateTime to})? blockOf(HolidayDay d); }`
    - hidden (source, name) removed from downloaded days;
    - My holidays expanded with `sourceId = kMyHolidaysSourceId`: `once` = start…end inclusive (end null = one day); `yearly` = month/day of start every year, Feb 29 → Feb 28 in non-leap years;
    - `on` orders by `sourceOrder`, `mine` last;
    - `blockOf` = the run of consecutive days with the same source, name and offDay containing `d`; null when the run is one day.
  - `String flagEmoji(String countryCode)` (regional indicator symbols).
  - `const List<Color> kHolidayPalette` (≥ 6, readable on light and dark; values builder's call) and `const Color kMyHolidaysColor`.

- [ ] **Step 1: Write the failing tests**

```dart
test('parseYmd is date-only and rejects junk', () {
  expect(parseYmd('2025-01-28'), DateTime(2025, 1, 28));
  expect(parseYmd('2025-1-28x'), isNull);
  expect(parseYmd(''), isNull);
  expect(ymd(DateTime(2025, 3, 4)), '2025-03-04');
});
test('region and my-holidays JSON round trip (H-2 shapes)', () {
  const r = HolidayRegion(country: 'CA', region: 'CA-ON', color: 1);
  expect(r.toJson(), {'country': 'CA', 'region': 'CA-ON', 'color': 1});
  expect(HolidayRegion.fromJson(r.toJson()), r);
  expect(HolidayRegion.fromJson({'country': 'CN', 'color': 0})!.sourceId, 'CN');
  final m = MyHolidaysData(entries: [MyHoliday(id: 'a', name: 'Trip', kind: MyHolidayKind.once, start: DateTime(2026, 3, 2), end: DateTime(2026, 3, 4), offDay: true)], hidden: [HiddenHoliday(source: 'CA-ON', name: 'National Day for Truth and Reconciliation')]);
  expect(m.toJson(), {
    'entries': [{'id': 'a', 'name': 'Trip', 'kind': 'once', 'start': '2026-03-02', 'end': '2026-03-04', 'offDay': true}],
    'hidden': [{'source': 'CA-ON', 'name': 'National Day for Truth and Reconciliation'}],
  });
  expect(MyHolidaysData.fromJson(m.toJson()), m);
  expect(MyHolidaysData.fromJson({'entries': [{'id': 1}], 'hidden': 'x'}).entries, isEmpty);
});
test('index merges sources in order, mine last', () {
  final idx = HolidayIndex(
    downloaded: [
      HolidayDay(date: DateTime(2025, 1, 1), name: "New Year's Day", offDay: true, sourceId: 'CA-ON'),
      HolidayDay(date: DateTime(2025, 1, 1), name: '元旦', offDay: true, sourceId: 'CN'),
    ],
    mine: MyHolidaysData(entries: [MyHoliday(id: 'b', name: 'Bday', kind: MyHolidayKind.yearly, start: DateTime(2000, 1, 1), offDay: true)], hidden: const []),
    sourceOrder: const ['CN', 'CA-ON'],
  );
  expect(idx.on(DateTime(2025, 1, 1)).map((d) => d.sourceId), ['CN', 'CA-ON', 'mine']);
});
test('once range inclusive; yearly Feb 29 falls on Feb 28', () {
  final idx = HolidayIndex(downloaded: const [], sourceOrder: const [], mine: MyHolidaysData(entries: [
    MyHoliday(id: 'r', name: 'Trip', kind: MyHolidayKind.once, start: DateTime(2026, 3, 2), end: DateTime(2026, 3, 4), offDay: true),
    MyHoliday(id: 'l', name: 'Leap', kind: MyHolidayKind.yearly, start: DateTime(2024, 2, 29), offDay: true),
  ], hidden: const []));
  expect(idx.on(DateTime(2026, 3, 4)), hasLength(1));
  expect(idx.on(DateTime(2026, 3, 5)), isEmpty);
  expect(idx.on(DateTime(2027, 2, 28)).single.name, 'Leap');
  expect(idx.on(DateTime(2028, 2, 29)).single.name, 'Leap');
  expect(idx.on(DateTime(2028, 2, 28)), isEmpty);
});
test('hide removes off and 班 days of that holiday in every year (H-1)', () {
  final idx = HolidayIndex(sourceOrder: const ['CN'], downloaded: [
    HolidayDay(date: DateTime(2025, 1, 26), name: '春节', offDay: false, sourceId: 'CN'),
    HolidayDay(date: DateTime(2025, 1, 28), name: '春节', offDay: true, sourceId: 'CN'),
    HolidayDay(date: DateTime(2026, 2, 16), name: '春节', offDay: true, sourceId: 'CN'),
  ], mine: const MyHolidaysData(entries: [], hidden: [HiddenHoliday(source: 'CN', name: '春节')]));
  expect(idx.on(DateTime(2025, 1, 26)), isEmpty);
  expect(idx.on(DateTime(2025, 1, 28)), isEmpty);
  expect(idx.on(DateTime(2026, 2, 16)), isEmpty);
});
test('forMonth keys by day; blockOf finds the run', () {
  final days = [for (var d = 1; d <= 8; d++) HolidayDay(date: DateTime(2025, 10, d), name: '国庆节、中秋节', offDay: true, sourceId: 'CN')];
  final idx = HolidayIndex(downloaded: days, mine: const MyHolidaysData(entries: [], hidden: []), sourceOrder: const ['CN']);
  expect(idx.forMonth(DateTime(2025, 10)).keys, [1, 2, 3, 4, 5, 6, 7, 8]);
  final b = idx.blockOf(days[3])!;
  expect((b.from, b.to), (DateTime(2025, 10, 1), DateTime(2025, 10, 8)));
});
test('flagEmoji', () => expect(flagEmoji('CA'), '🇨🇦'));
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/features/calendar/domain/holidays_test.dart` → FAIL (missing file).
- [ ] **Step 3: Implement `holidays.dart`** per Interfaces; downloaded days indexed once by `ymd`, My holidays evaluated per queried date.
- [ ] **Step 4: Run** the file, and `TZ=Asia/Shanghai flutter test test/features/calendar/domain/holidays_test.dart` → pass.
- [ ] **Step 5: Commit** `feat(calendar): holiday domain types and merge index`.

---

### Task 2: Source adapters

**Files:**
- Create: `lib/features/calendar/data/holiday_sources.dart`
- Create fixtures: `test/features/calendar/data/fixtures/nager_ca_2025.json`, `holiday_cn_2025.json`, `nager_countries.json`
- Test: `test/features/calendar/data/holiday_sources_test.dart`

**Interfaces:**
- Consumes: `HolidayDay`, `parseYmd`, `HolidayRegion` (Task 1).
- Produces:
  - `sealed class HolidayFetch`; `HolidayYear(List<HolidayDay> days)`, `HolidayNotPublished()`, `HolidayFetchFailed(Object reason)`.
  - `abstract class HolidaySource { String get sourceId; Future<HolidayFetch> fetchYear(int year); }`
  - `NagerSource(Dio dio, {required String country, String? region})` (`sourceId = region ?? country`); `HolidayCnSource(Dio dio)` (`sourceId == 'CN'`).
  - `HolidaySource sourceFor(HolidayRegion r, Dio dio)` → `HolidayCnSource` when `r.country == 'CN'`, else `NagerSource`.
  - `Dio holidayDio()` — `BaseOptions(connectTimeout: 10 s, receiveTimeout: 10 s, headers: {'User-Agent': 'hmm-console'})`, no added interceptors.
  - `Future<List<({String code, String name})>?> fetchAvailableCountries(Dio dio)` (null on failure).
  - `Future<List<String>?> regionCodesIn(Dio dio, String country, int year)` — sorted distinct `counties` codes of Public non-global entries; `[]` = no regional holidays; null on failure.

- [ ] **Step 1: Save fixtures** (real data, committed): `curl -s https://date.nager.at/api/v3/PublicHolidays/2025/CA`, `curl -s https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/2025.json`, `curl -s https://date.nager.at/api/v3/AvailableCountries` into the three files.
- [ ] **Step 2: Write failing tests** with a fake `HttpClientAdapter` that serves fixtures by URL (or a given body/status, or throws) and records the last request's URI and headers.

```dart
test('Nager CA 2025 filtered to Ontario', () async {
  final r = await NagerSource(dio, country: 'CA', region: 'CA-ON').fetchYear(2025) as HolidayYear;
  final names = r.days.map((d) => d.name).toList();
  expect(r.days, hasLength(11));
  expect(names, containsAll(['Family Day', 'Civic Holiday', 'Boxing Day', 'Canada Day']));
  expect(names, isNot(contains('Louis Riel Day')));
  expect(r.days.every((d) => d.offDay && d.sourceId == 'CA-ON'), isTrue);
  expect(r.days.firstWhere((d) => d.name == 'Family Day').date, DateTime(2025, 2, 17));
});
test('Nager without region keeps global only', () async {
  final r = await NagerSource(dio, country: 'CA').fetchYear(2025) as HolidayYear;
  expect(r.days.map((d) => d.name), isNot(contains('Family Day')));
  expect(r.days.first.sourceId, 'CA');
});
test('Nager drops non-Public types', () async {
  final body = '[{"date":"2025-01-01","localName":"A","name":"A","global":true,"counties":null,"types":["Public"]},'
      '{"date":"2025-02-02","localName":"B","name":"B","global":true,"counties":null,"types":["Observance"]}]';
  final r = await NagerSource(dioServing(body), country: 'XX').fetchYear(2025) as HolidayYear;
  expect(r.days.single.name, 'A');
});
test('holiday-cn 2025 blocks and 补班', () async {
  final r = await HolidayCnSource(dio).fetchYear(2025) as HolidayYear;
  bool? off(DateTime d) => r.days.where((x) => x.date == d).map((x) => x.offDay).firstOrNull;
  expect(off(DateTime(2025, 1, 28)), isTrue);
  expect(off(DateTime(2025, 1, 26)), isFalse);
  expect([4, 5, 6].map((d) => off(DateTime(2025, 4, d))), [true, true, true]);
  expect(r.days.firstWhere((x) => x.date == DateTime(2025, 4, 4)).name, '清明节');
});
test('holiday-cn 404 is not published', () async {
  expect(await HolidayCnSource(dioStatus(404)).fetchYear(2027), isA<HolidayNotPublished>());
});
test('malformed JSON or network error is a failure', () async {
  expect(await HolidayCnSource(dioServing('{"days": 5}')).fetchYear(2025), isA<HolidayFetchFailed>());
  expect(await NagerSource(dioServing('[{"localName":"x"}]'), country: 'CA').fetchYear(2025), isA<HolidayFetchFailed>());
  expect(await NagerSource(dioStatus(500), country: 'CA').fetchYear(2025), isA<HolidayFetchFailed>());
  expect(await NagerSource(dioThrowing(), country: 'CA').fetchYear(2025), isA<HolidayFetchFailed>());
});
test('requests carry no auth header and only the country/year', () async {
  await sourceFor(const HolidayRegion(country: 'CN', color: 0), dio).fetchYear(2025);
  expect(adapter.lastHeaders.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
  expect(adapter.lastUri.toString(), 'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/2025.json');
  expect(holidayDio().options.headers['User-Agent'], 'hmm-console');
});
test('regionCodesIn and available countries', () async {
  expect(await regionCodesIn(dio, 'CA', 2025), containsAll(['CA-ON', 'CA-QC', 'CA-MB']));
  expect((await fetchAvailableCountries(dio))!.any((c) => c.code == 'CA' && c.name == 'Canada'), isTrue);
  expect(await regionCodesIn(dioThrowing(), 'CA', 2025), isNull);
});
```

- [ ] **Step 3: Run** → FAIL. **Step 4: Implement.** `validateStatus: (_) => true`, branch on status: 200 → decode (any type error or bad/missing `date` → `HolidayFetchFailed`); holiday-cn 404 → `HolidayNotPublished`; anything else → failed; `DioException` → failed.
- [ ] **Step 5: Run** → pass. **Step 6: Commit** `feat(calendar): Nager and holiday-cn sources`.

---

### Task 3: Device cache and refresh policy

**Files:**
- Create: `lib/features/calendar/data/holiday_cache.dart`
- Test: `test/features/calendar/data/holiday_cache_test.dart`

**Interfaces:**
- Consumes: `HolidayFetch`, `HolidaySource` (Task 2); `HolidayDay`, `HolidayRegion` (Task 1).
- Produces:
  - `enum CachedStatus { ok, notPublished }`; `class CachedYear { CachedStatus status; DateTime fetchedAt; List<HolidayDay> days; }` (JSON).
  - `class HolidayCache { HolidayCache(Future<Directory> Function() dir); Future<CachedYear?> read(String sourceId, int year); Future<void> write(String sourceId, int year, CachedYear y); Future<void> pruneExcept(Set<String> keepSourceIds); Future<List<HolidayDay>> daysFor(Set<String> sourceIds, Set<int> years); }` — file `holidays/<sourceId>_<year>.json` under `dir()` (production: `getApplicationSupportDirectory`); unreadable file = absent. `pruneExcept` leaves non-year files (e.g. `countries.json`) alone.
  - `Set<int> yearsToFetch(DateTime shownMonth, DateTime now)` → `{shownMonth.year}` ∪ `{now.year + 1}` when `now.month >= 11`.
  - `bool needsFetch(CachedYear? c, int year, DateTime now)`: null → true; `year < now.year` and `c != null` → false; `ok` → `now − fetchedAt > 7 days`; `notPublished` → `now − fetchedAt >= 1 day`.
  - `class HolidayRefresher { HolidayRefresher(HolidayCache cache, HolidaySource Function(HolidayRegion) sourceFor, DateTime Function() now); Future<bool> refresh(List<HolidayRegion> regions, Set<int> years); }` — prunes caches of sources not in `regions` (this is how "removing a country deletes its saved years" happens, so an undone removal never loses data mid-undo); fetches what `needsFetch` says; writes `ok`/`notPublished`; leaves the file untouched on failure; returns true when anything was written or pruned. Overlapping calls share one in-flight run.

- [ ] **Step 1: Failing tests** (temp dir; fake sources that count calls and return scripted results):

```dart
test('yearsToFetch', () {
  expect(yearsToFetch(DateTime(2026, 3), DateTime(2026, 10, 31)), {2026});
  expect(yearsToFetch(DateTime(2026, 11), DateTime(2026, 11, 1)), {2026, 2027});
  expect(yearsToFetch(DateTime(2025, 6), DateTime(2026, 12, 5)), {2025, 2027});
});
test('needsFetch policy', () {
  final now = DateTime(2026, 11, 19);
  expect(needsFetch(null, 2026, now), isTrue);
  expect(needsFetch(ok(DateTime(2020)), 2025, now), isFalse);
  expect(needsFetch(ok(DateTime(2026, 11, 13)), 2026, now), isFalse);
  expect(needsFetch(ok(DateTime(2026, 11, 11)), 2026, now), isTrue);
  expect(needsFetch(notPub(DateTime(2026, 11, 18, 23)), 2027, now), isFalse);
  expect(needsFetch(notPub(DateTime(2026, 11, 18)), 2027, now), isTrue);
});
test('not published, then published after the daily retry', () async {
  // now = 2026-11-19; CN 2027 → HolidayNotPublished; daysFor({'CN'},{2027}) empty
  // now = 2026-11-20; CN 2027 → HolidayYear([2027-01-01 元旦]); refresh returns true; daysFor has it
});
test('failure keeps saved data', () async {
  // ok cache 8 days old with 1 day; source fails → daysFor unchanged; read().fetchedAt unchanged; refresh returns false
});
test('prune drops removed sources only', () async {
  // files CN_2026, CA-ON_2026, countries.json; refresh([CN], {2026}) → CA-ON_2026 gone, others kept
});
test('overlapping refresh fetches once', () async {
  // two refresh() calls without awaiting the first → source.fetchYear called once
});
```

- [ ] **Step 2–5:** run → fail, implement, run → pass, commit `feat(calendar): holiday cache and refresh policy`.

---

### Task 4: Synced settings fields and notifiers

**Files:**
- Modify: `lib/features/settings/domain/syncable_settings.dart`, `lib/features/settings/data/syncable_settings_repository.dart`
- Create: `lib/features/calendar/states/holiday_settings_providers.dart`
- Test: `test/features/settings/syncable_settings_holidays_test.dart`, `test/features/calendar/states/holiday_settings_providers_test.dart`

**Interfaces:**
- Consumes: `HolidayRegion`, `MyHolidaysData`, `MyHoliday`, `HiddenHoliday`, `kDefaultHolidayRegions`, `kHolidayPalette` (Task 1).
- Produces:
  - `SyncableSettings.calendarHolidayRegions: List<HolidayRegion>?` (JSON key `calendarHolidayRegions`) and `SyncableSettings.calendarMyHolidays: MyHolidaysData?` (JSON key `calendarMyHolidays`) — written only when non-null, null when absent, in `toJson`/`fromJson`/`copyWith`, modelled on `calendarShowLunar`/`notesSavedSearches`.
  - Repository: `static const calendarHolidayRegionsKey = 'calendar.holiday_regions'`, `calendarMyHolidaysKey = 'calendar.my_holidays'` (prefs strings holding the JSON); `load` reads them (unreadable → null), `save` writes only non-null values.
  - `holidayRegionsProvider` (`NotifierProvider<HolidayRegionsNotifier, List<HolidayRegion>>`): synchronous default `kDefaultHolidayRegions`; hydrates from prefs and re-reads on `settingsBusProvider`, with the `_writes` guard of `ShowLunarNotifier`; `Future<bool> add(String country, String? region)` (false when that country+region exists; colour = lowest `kHolidayPalette` index not in use, else index 0); `Future<void> remove(String sourceId)`; `Future<void> restore(List<HolidayRegion> previous)`. Each write stores the whole list and calls `bumpLastModified()`.
  - `myHolidaysProvider` (`NotifierProvider<MyHolidaysNotifier, MyHolidaysData>`, default empty): `upsert(MyHoliday)`, `delete(String id)`, `hide(String source, String name)` (no duplicates), `unhide(String source, String name)`, `restore(MyHolidaysData previous)`; same persistence pattern.

- [ ] **Step 1: Failing tests:**

```dart
test('absent ≠ empty for both fields', () {
  final s = SyncableSettings.fromJson(minimalJson);
  expect(s.calendarHolidayRegions, isNull);
  expect(s.calendarMyHolidays, isNull);
  expect(s.toJson().containsKey('calendarHolidayRegions'), isFalse);
  expect(s.toJson().containsKey('calendarMyHolidays'), isFalse);
  final e = s.copyWith(calendarHolidayRegions: const [], calendarMyHolidays: const MyHolidaysData(entries: [], hidden: []));
  expect(SyncableSettings.fromJson(e.toJson()).calendarHolidayRegions, isEmpty);
  expect(SyncableSettings.fromJson(e.toJson()).calendarMyHolidays, isNotNull);
});
test('saving a pulled bundle without the keys leaves local values', () async {
  // prefs: calendar.holiday_regions = '[{"country":"CN","color":0}]'; repo.save(bundle with both fields null) → prefs string unchanged
});
test('default regions when never edited, and nothing written', () async {
  // after hydration: read(holidayRegionsProvider) == kDefaultHolidayRegions; prefs.containsKey(calendarHolidayRegionsKey) is false
});
test('add rejects duplicates and picks the lowest free colour', () async {
  // default (0,1): add('US', null) → true, color 2; add('CA', 'CA-ON') → false, length 3
  // remove('CN'); add('JP', null) → color 0
});
test('hide is idempotent and unhide restores', () async { /* hide twice → hidden.length 1; unhide → 0 */ });
test('every edit bumps last modified', () async { /* fake repository counts bumpLastModified for add/remove/upsert/delete/hide */ });
```

- [ ] **Step 2–5:** run → fail, implement, run this task's tests and `flutter test test/features/settings` → pass, commit `feat(calendar): synced holiday regions and My holidays`.

---

### Task 5: View providers, grid marks, day detail, home button

**Files:**
- Create: `lib/features/calendar/states/holiday_providers.dart`
- Modify: `lib/features/calendar/presentation/widgets/month_grid.dart`, `widgets/agenda_list.dart`, `screens/calendar_home_screen.dart`, ARB
- Test: `test/features/calendar/states/holiday_providers_test.dart`, `test/features/calendar/presentation/calendar_home_screen_test.dart` (new cases)

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces:
  - `holidayDioProvider` (`Provider<Dio>` = `holidayDio()`), `holidayCacheProvider` (`Provider<HolidayCache>`, dir = app support), `holidayRefresherProvider` (`Provider<HolidayRefresher>`, `now = DateTime.now`) — all overridable in tests.
  - `holidaysForMonthProvider` — `FutureProvider.family<HolidayIndex, DateTime /*first of month*/>`: watches `holidayRegionsProvider` and `myHolidaysProvider`; years = `yearsToFetch(month, DateTime.now())`; builds the index from `cache.daysFor(...)` (sourceOrder = regions' sourceIds) and returns it without waiting for the network; then calls `refresher.refresh(regions, years)` unawaited and `ref.invalidateSelf()` when it returns true and `ref.mounted`.
  - `class HolidayMark { final Color color; final bool offDay; }`; `Map<int, List<HolidayMark>> holidayMarksFor(HolidayIndex idx, DateTime month, Map<String, Color> colors)` — one mark per source per day; a source with any off day that day → off.
  - `Map<String, Color> holidayColors(List<HolidayRegion> regions)` (region colour from `kHolidayPalette[color % length]`; `mine` → `kMyHolidaysColor`).
  - `MonthGrid({…, Map<int, List<HolidayMark>>? holidayMarks})`: key `calendar-holiday-$day` on the mark; one mark → text `休`/`班` (≈10 pt, bold, mark colour) at the cell's top-right; 2–3 marks → dots (≈5 pt; workday dot hollow); > 3 → first three; null/empty → cell exactly as today; cell height unchanged.
  - `class HolidayLine { final String? flag; final String name; final bool offDay; final Color color; final String? range; final HolidayDay day; }`; `AgendaList({…, List<HolidayLine> holidayLines = const [], void Function(HolidayLine)? onHolidayTap})` — under the day header: flag (or `Icons.person_outline` for mine), name, ` · ` Day off/Workday, then ` (range)` when set; only downloaded lines are tappable.
  - Home `_content`: builds marks and lines from `holidaysForMonthProvider(data.month)` (watched in `build()`, not inside a `LayoutBuilder`); range text `'${DateFormat.MMMd(locale).format(from)} – ${DateFormat.MMMd(locale).format(to)}'`.
  - Home top bar: `HmmIconButton(icon: adaptiveIcon(context, material: Icons.flag_outlined, apple: CupertinoIcons.flag), tooltip: l.calendarHolidays, onPressed: () => context.push('/calendar/holidays'))` before the `HelpButton`; not shown when the calendar is in its Cloud API unavailable state (`CalendarCloudApiUnavailable`), and in that state no holiday provider is read.
  - Tapping a downloaded line → platform action sheet (Cupertino action sheet / Material bottom sheet) with `l.calendarHolidayHide` → `showUndoableAction`: do = `hide(source, name)`, undo = `unhide(source, name)`, messages `calendarHolidayHidden`/`calendarHolidayHideFailed`/`calendarHolidayShown`/`calendarHolidayUndoFailed`.
  - ARB (en / zh): `calendarHolidays` Holidays / 节假日; `calendarHolidayDayOff` Day off / 休息日; `calendarHolidayWorkday` Workday / 工作日; `calendarHolidayHide` Not a day off for me / 不是我的假日; `calendarHolidayHidden` "{name} hidden" / 已隐藏{name}; `calendarHolidayShown` "{name} shown again" / 已恢复{name}; `calendarHolidayHideFailed` "Couldn't hide {name}" / 无法隐藏{name}; `calendarHolidayUndoFailed` "Couldn't undo" / 无法撤销.

- [ ] **Step 1: Failing tests:**

```dart
test('marks: one per source, off wins within a source', () {
  // CN 班 (Jan 1 fake) + CA-ON off → marks[1] == [HolidayMark(cnColor, false), HolidayMark(caColor, true)]
});
test('provider returns cached data first, then refreshed data', () async {
  // cache has CN 2025 one day; refresher stub completes after a Completer with true and writes another day
  // first read → 1 day; complete → listener sees 2 days
});
testWidgets('grid: one source shows 休 in its colour', ...);        // find.descendant(of: byKey('calendar-holiday-1'), matching: find.text('休')); Text.style.color == mark colour
testWidgets('grid: two sources show two dots, no text', ...);
testWidgets('grid: no holidays → no calendar-holiday keys, cell height 44 / 56 as before', ...);
testWidgets('day detail lists 国庆节、中秋节 · Day off (Oct 1 – Oct 8)', ...);
testWidgets('Hide removes the line; Undo brings it back', ...);
testWidgets('Holidays button with tooltip opens /calendar/holidays', ...); // router test double
testWidgets('Cloud API mode: no Holidays button', ...);
```

- [ ] **Step 2–5:** run → fail, implement, `flutter test test/features/calendar` → pass, commit `feat(calendar): holiday marks on the grid and in the day detail`.

---

### Task 6: Holidays screen (add / remove countries)

**Files:**
- Create: `lib/features/calendar/presentation/screens/holidays_screen.dart`, `lib/features/calendar/domain/region_names.dart`
- Modify: `lib/core/navigation/calendar_routes.dart` (+ `RouterNames.calendarHolidays`), `lib/core/help/help_registry.dart` (`HelpId.calendarHolidays`), ARB
- Test: `test/features/calendar/presentation/holidays_screen_test.dart`

**Interfaces:**
- Consumes: `holidayRegionsProvider`, `holidayCacheProvider`, `holidayDioProvider`, `holidayRefresherProvider`, `fetchAvailableCountries`, `regionCodesIn`, `flagEmoji`, `holidayColors`.
- Produces:
  - Route `/calendar/holidays` (child of `/calendar`, name `calendarHolidays`).
  - `String regionName(String code)` — Canada: AB Alberta, BC British Columbia, MB Manitoba, NB New Brunswick, NL Newfoundland and Labrador, NS Nova Scotia, NT Northwest Territories, NU Nunavut, ON Ontario, PE Prince Edward Island, QC Quebec, SK Saskatchewan, YT Yukon; US: all 50 states + DC; otherwise the code.
  - Country names: from the last fetched available-countries list, saved as `countries.json` in the holiday cache dir; `CN` shows `中国` in zh; fallback = the code.
  - Screen: title `l.calendarHolidays`, `HelpButton(helpId: HelpId.calendarHolidays)`, add (iOS: `HmmIconButton` `Icons.add`, tooltip `l.calendarHolidaysAdd`; Android: FAB). Rows: colour swatch, flag + country name, region name or `l.calendarHolidaysWholeCountry`; subtitle (this device): `l.calendarHolidaysUpdated(date)` from the current year's `fetchedAt`, plus `l.calendarHolidaysNotPublished(year)` when next year's cache is `notPublished`. Last row **My holidays** (`l.calendarHolidaysMine`) → `/calendar/holidays/mine` (route in Task 7). Swipe a row (`Dismissible`, key `holiday-region-<sourceId>`) → `showUndoableAction` (do = `remove`, undo = `restore(previous)`; messages `calendarHolidaysRemoved`/`calendarHolidaysRemoveFailed`/…).
  - Add flow: country picker (searchable list in a platform sheet) from `fetchAvailableCountries`; `CN` → add directly; otherwise `regionCodesIn(country, now.year)`: non-empty → region picker (first "Whole country", then regions sorted by name); empty → add without region. Entries already in the list are not offered. Any fetch null → snackbar `l.calendarHolidaysOffline`, nothing added. After add → `refresh(regions, {now.year})` unawaited.
  - ARB (en/zh): `calendarHolidaysAdd`, `calendarHolidaysWholeCountry`, `calendarHolidaysUpdated` ("Updated {date}"), `calendarHolidaysNotPublished` ("{year} not published yet"), `calendarHolidaysOffline` ("Can't load countries. Check your connection."), `calendarHolidaysRemoved` ("{name} removed"), `calendarHolidaysRemoveFailed`, `calendarHolidaysRestored`, `calendarHolidaysMine` (My holidays / 我的假日), `calendarHolidaysSearch`; help `helpCalendarHolidaysTitle`, `helpCalendarHolidaysSummary`, `helpCalendarHolidaysAddTitle/Body`, `helpCalendarHolidaysRemoveTitle/Body`, `helpCalendarHolidaysMineTitle/Body`.

- [ ] **Step 1: Failing tests** (fake Dio adapter on the Task 2 fixtures; temp cache dir):

```dart
testWidgets('default list shows China and Canada · Ontario', ...);
testWidgets('adding Canada again offers regions without Ontario', ...);
testWidgets('adding the same country/region twice keeps one entry', ...);
testWidgets('offline add shows a message and adds nothing', ...);
testWidgets('swipe removes with undo; undo restores order and colour', ...);
testWidgets('help button opens the holidays help', ...);
```

- [ ] **Step 2–5:** run → fail, implement, run → pass, commit `feat(calendar): Holidays screen to add and remove countries`.

---

### Task 7: My holidays screen, editor, hidden list, docs

**Files:**
- Create: `lib/features/calendar/presentation/screens/my_holidays_screen.dart`, `widgets/my_holiday_editor.dart`
- Modify: routes (`/calendar/holidays/mine`, name `calendarMyHolidays`), help registry (`HelpId.calendarMyHolidays`; add a Holidays entry to `HelpId.calendar` for the marks and the button, icon `Icons.flag_outlined`), ARB, `CLAUDE.md` calendar row (one sentence: public holidays from the Holidays screen in the calendar — China via holiday-cn, others via Nager.Date, per-device cache, synced country list and My holidays)
- Test: `test/features/calendar/presentation/my_holidays_screen_test.dart`

**Interfaces:**
- Consumes: `myHolidaysProvider`, `MyHoliday`, `holidaysForMonthProvider`, `showPlatformDatePicker` (`widgets/platform_date_time_pickers.dart`), `lib/core/util/uuid.dart`.
- Produces:
  - Screen (`HelpButton(helpId: HelpId.calendarMyHolidays)`): entries (name; `DateFormat.yMMMd` date or range; `l.calendarMyHolidaysEveryYear` for yearly; Day off/Workday); add (iOS top-bar `HmmIconButton`, Android FAB); tap to edit; swipe delete via `showUndoableAction` (undo = `restore(previous)`). Section `l.calendarMyHolidaysHiddenSection` (only when non-empty): flag + name + `l.calendarMyHolidaysShowAgain` (`unhide`, undoable via `hide`).
  - Editor (full-screen page): name (required, trimmed), kind (One-time / Every year; platform segmented control as in the repeat picker), start date, end date (one-time only, optional; Save disabled when end < start), Day off switch (default on; platform switch). Save → `upsert` (new id via the uuid util; editing keeps the id).
  - ARB (en/zh): `calendarMyHolidaysAdd`, `calendarMyHolidaysEdit`, `calendarMyHolidaysName`, `calendarMyHolidaysOnce`, `calendarMyHolidaysYearly`, `calendarMyHolidaysEveryYear`, `calendarMyHolidaysStart`, `calendarMyHolidaysEnd`, `calendarMyHolidaysDayOff`, `calendarMyHolidaysDeleted`, `calendarMyHolidaysDeleteFailed`, `calendarMyHolidaysRestored`, `calendarMyHolidaysHiddenSection`, `calendarMyHolidaysShowAgain`; help `helpCalendarMyHolidaysTitle/Summary`, `helpCalendarMyHolidaysAddTitle/Body`, `helpCalendarMyHolidaysHiddenTitle/Body`, `helpCalendarHolidaysMarksTitle/Body`.

- [ ] **Step 1: Failing tests:**

```dart
testWidgets('add a one-time range; the index has it on each day', ...);  // read(holidaysForMonthProvider(month)).on(day)
testWidgets('end before start disables Save', ...);
testWidgets('edit a yearly entry keeps its id', ...);
testWidgets('swipe delete with undo', ...);
testWidgets('hidden section lists a hidden holiday; Show again removes it', ...);
```

- [ ] **Step 2–5:** run → fail, implement, run → pass, commit `feat(calendar): My holidays and hidden holidays` (stage `CLAUDE.md` only after `git diff CLAUDE.md` shows just the calendar-row sentence).

---

### Task 8: Branch verification

- [ ] `flutter analyze` → "No issues found!"
- [ ] `flutter test` → read the summary line; all pass (note skips).
- [ ] `flutter test test/features/calendar` and `TZ=Asia/Shanghai flutter test test/features/calendar` → all pass.
- [ ] `flutter test test/core/help` (icon-button guard, help coverage) → pass.
- [ ] Record results; a needed fix is its own commit.
