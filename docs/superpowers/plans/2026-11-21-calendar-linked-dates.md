# Linked Important Dates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Licence, registration, insurance and service-due dates, plus contact birthdays (Gregorian or lunar, opt-in per contact), appear on the calendar by themselves as reminding events that follow their source and never duplicate.

**Architecture:** Each subsystem exposes its entities to the calendar through one `DatedNoteSource` returning `DatedNote`s (adapters over the entities). A calendar-side matcher collects every `DatedItem`, derives a deterministic UUID v5 event id from each item's key, and makes the stored calendar events match — writing only matcher-owned fields and keeping the owner's reminders, Time Sensitive, notes and done/skip. Titles are language-neutral (`linked: {kind, args}` in extra fields) and rendered per device.

**Tech Stack:** Flutter, Riverpod, Drift (notes table), `crypto` (SHA-1 for UUID v5, already a dependency), `lunar` 1.7.8 via `features/calendar/domain/lunar.dart`, gen-l10n.

**Spec:** `docs/superpowers/specs/2026-11-20-calendar-linked-dates-design.md` (owner-approved 2026-11-21, commits 229efb2, 5259e97).

## Global Constraints

- Five kinds, keys and owners exactly (spec "Event identity"):
  - `licence:expiry` → owner (`driverLicence`, `self`)
  - `vehicle:<vehicle note uuid>:registration` → (`automobile`, vehicle uuid)
  - `insurance:<policy note uuid>:expiry` → (`insurance`, policy uuid)
  - `service:<schedule note uuid>:due` → (`scheduledService`, schedule uuid)
  - `contact:<contact id>:birthday` → (`contacts`, contact id)
- Event id = UUID v5(namespace `5b0e7c1a-9d4f-5e2b-8a63-0f1d2c3b4a59`, key). Never a random id for a linked event.
- All-day events. Default reminders: expiry/due `Reminder(minutesBefore: 43200)` (30 days before 09:00); birthday `Reminder(minutesBefore: 0)` (09:00 on the day). `timeSensitive: true`, `source: EventSource.subsystem`.
- `linked` extra field shape: `{"kind": "licenceExpiry"|"registrationExpiry"|"insuranceExpiry"|"serviceDue"|"birthday", "args": {…}}`. The matcher compares kind+args, never the rendered title.
- Matcher-owned: `linked`, start, rrule, owner, `reminderBody`; title rewritten only when the event is new or kind/args changed. Owner-owned and kept: reminders, timeSensitive, notes, occurrences (done/skip).
- Scope: licence with an expiry; active vehicles with a registration expiry; active policies on active vehicles with expiry ≥ today − 90 days; active schedules on active vehicles with a next due date; active contacts with a birthday and `remindBirthday == true`.
- Birthday rules: Gregorian `RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD` (29 Feb → 28 Feb in non-leap years, birthday rules only); lunar `RecurrenceRule.lunarYearly(month, day, leap)`. Lunar range 1901–2099.
- Contact JSON: `birthday: {"calendar": "gregorian"|"lunar", "month": 1–12, "day": 1–31 (lunar 1–30), "leap": bool (lunar only), "year": int?}`, `remindBirthday: bool` (default false).
- No matcher run while a sync is in progress; nothing in Cloud API mode; nothing sent off the device.
- Linked events: no Delete; title/date/repeat read-only with "Change it in <source>"; Open <source> on the detail screen.
- Project rules (CLAUDE.md): `HmmIconButton` with localized tooltip; every changed control updates its help entry; `showUndoableAction` for Remind me; platform-branched pickers/switches via `Theme.of(context).platform`; never `ref.watch` inside a LayoutBuilder; no WidgetRef/BuildContext after an await; never `dart format` a directory; run `flutter gen-l10n` after ARB edits; branch `feat/calendar-linked-dates`, never amend; commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; never stage CLAUDE.md.

## Rulings made while planning (spec left these to the builder)

- **Contracts live in `lib/features/calendar/contract/dated_note.dart`**, beside `CalendarService` (already the calendar's public API for subsystems). Every entity uses an adapter (entities expose no uuid, and contacts/licence shouldn't depend on calendar types).
- **`DatedNoteSource` gains `subsystems` and `locationOf(owner)`** so the calendar's Open button and removal scope need no subsystem imports. Cost if wrong: two extra members per source.
- **One automobile source** returns vehicles, policies and schedules (they share the vehicle lookup); owners stay distinct per kind.
- **The matcher writes through `ICalendarRepository`, not `upsertOwnedEvent`.** It is calendar-internal and must keep occurrences and soft-deleted settings, which the service would drop. The deterministic-id rule is unchanged; `CalendarService` stays the API for other subsystems.
- **Birthday series anchor year:** birth year when known (lunar: in 1901–2099), else the fixed year 2000 (a leap year, so 29 Feb is valid) rather than the current year — a moving anchor would rewrite every birthday event each 1 January. Occurrence 1 in 2000 is in the past and never reminds.
- **For a lunar birthday `year` is the lunar year.** Age for a lunar birthday = lunar year of the occurrence − that year.
- **Lunar picker labels are Chinese (正月…腊月, 初一…三十) in every language**, as the lunar grid labels already are.
- **A source that throws aborts the whole run with no writes and no removals** (otherwise a transient error would delete that kind's events on every device).
- **Triggers:** start (after first frame), resume, any `IHmmNoteRepository.watchNotes()` emission, and after each finished sync; 2 s debounce; each run inside `SyncController.runExclusive` (null = sync running → the after-sync listener runs it later).

## Review Focus

1. **A source fails or is still empty at start-up** (author not loaded, contacts repo error) → existing linked events stay untouched; no removal wave. Test in Task 6.
2. **Event pulled before its source arrives** (policy note not yet synced) → no run while the sync is in progress; it runs once the sync finishes. Test in Task 6.
3. **Owner edited reminders, then turned Remind me off and Undo** → the restored event has the edited reminders and its done/skip marks. Test in Task 5.
4. **Lunar birthday on 三十 or in a leap month in a year without it** → an occurrence still appears on the fallback day every year 2026–2035. Test in Task 9.
5. **Two licence notes with different expiry** → both devices pick the most recently modified note's expiry. Test in Task 7.

---

### Task 1: UUID v5 and the dated-note contract

**Files:**
- Modify: `lib/core/util/uuid.dart`
- Create: `lib/features/calendar/contract/dated_note.dart`
- Test: `test/core/util/uuid_v5_test.dart`, `test/features/calendar/contract/dated_note_test.dart`

**Interfaces:**
- Produces:
  - `String uuidV5(String namespace, String name)` (RFC 4122 §4.3, SHA-1 via `package:crypto`, lowercase hyphenated).
  - `const kLinkedEventNamespace = '5b0e7c1a-9d4f-5e2b-8a63-0f1d2c3b4a59';`
  - `String linkedEventId(String key) => uuidV5(kLinkedEventNamespace, key);`
  - `enum LinkedKind { licenceExpiry, registrationExpiry, insuranceExpiry, serviceDue, birthday }` (wire name = `.name`).
  - `class DatedItem { const DatedItem({required String key, required LinkedKind kind, required Map<String, Object?> args, required AllDay date, RecurrenceRule? repeat, required EventOwner owner, String? reminderBody}); String get eventId => linkedEventId(key); }` (value equality; args compared as JSON; repeat compared by `format()`).
  - `abstract interface class DatedNote { List<DatedItem> get dates; }`
  - `abstract interface class DatedNoteSource { Set<String> get subsystems; Future<List<DatedNote>> datedNotes(); Future<String?> locationOf(EventOwner owner); }` — `locationOf` returns a GoRouter location of the source screen, or null when the source no longer exists.
  - Subsystem constants: `kLinkedSubsystemLicence = 'driverLicence'`, `kLinkedSubsystemAutomobile = 'automobile'`, `kLinkedSubsystemInsurance = 'insurance'`, `kLinkedSubsystemScheduledService = 'scheduledService'`, `kLinkedSubsystemContacts = 'contacts'`.

- [ ] **Step 1: Write the failing tests**

```dart
test('uuidV5 matches the RFC 4122 DNS vector', () {
  expect(uuidV5('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'www.example.com'),
      '2ed6657d-e927-568b-95e1-2665a8aea6a2');
});
test('linkedEventId is stable and key-specific', () {
  expect(linkedEventId('licence:expiry'), linkedEventId('licence:expiry'));
  expect(linkedEventId('licence:expiry'), isNot(linkedEventId('contact:a:birthday')));
  expect(linkedEventId('licence:expiry')[14], '5'); // version nibble
});
test('DatedItem equality compares args by value', () {
  // two items built separately with args {'name': 'Mum'} → equal, same hashCode
});
```

- [ ] **Step 2: Run** `flutter test test/core/util/uuid_v5_test.dart test/features/calendar/contract/dated_note_test.dart` — expect FAIL (undefined names).
- [ ] **Step 3: Implement** `uuidV5` (namespace bytes + UTF-8 name → SHA-1 → first 16 bytes, version 5, variant 1) and the contract file.
- [ ] **Step 4: Run the tests** — PASS (read the summary line).
- [ ] **Step 5: Commit** `feat(calendar): UUID v5 and dated-note contract`.

---

### Task 2: Gregorian yearly rule that falls back from 29 February

**Files:**
- Modify: `lib/features/calendar/domain/recurrence_rule.dart` (parse SKIP when `RSCALE=GREGORIAN`; factory; getter)
- Modify: `lib/features/calendar/domain/recurrence_expander.dart` (yearly case, ~line 273)
- Test: `test/features/calendar/domain/recurrence_rule_test.dart`, `test/features/calendar/domain/recurrence_expander_test.dart`

**Interfaces:**
- Produces: `factory RecurrenceRule.gregorianYearlyBackward()` → `format()` gives `RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD`; `bool get isGregorianSkipBackward` (rscale GREGORIAN, yearly, skip BACKWARD, no byDay/byMonthDay/unsupported).

- [ ] **Step 1: Write the failing tests**

```dart
test('RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD round-trips and is not custom', () {
  final r = RecurrenceRule.parse('RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD');
  expect(r.skip, 'BACKWARD');
  expect(r.unsupported, isEmpty);
  expect(r.isCustom, isFalse);
  expect(r.isGregorianSkipBackward, isTrue);
  expect(RecurrenceRule.gregorianYearlyBackward().format(),
      'RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD');
});
test('29 Feb birthday rule shows 28 Feb in non-leap years', () {
  // all-day start AllDay(2000, 2, 29), rrule gregorianYearlyBackward,
  // expand 2025-01-01..2029-01-01 → 2025-02-28, 2026-02-28, 2027-02-28, 2028-02-29
});
test('plain FREQ=YEARLY on 29 Feb still skips non-leap years', () {
  // same start, 'FREQ=YEARLY' → only 2028-02-29 in that window
});
```

Also add a test that the repeat description used by `event_detail_screen.dart` reads a gregorianYearlyBackward event as yearly, not "Custom".

- [ ] **Step 2: Run** both test files — FAIL.
- [ ] **Step 3: Implement.** In `parse`, when `rscale == 'GREGORIAN'` move `SKIP=` from `unsupported` into `skip` (lunar path unchanged). In the expander's yearly case, when `base.day > dim` and `rule.isGregorianSkipBackward`, yield `DateTime.utc(y, base.month, dim)`.
- [ ] **Step 4: Run** `flutter test test/features/calendar` — PASS.
- [ ] **Step 5: Commit** `feat(calendar): Gregorian yearly SKIP=BACKWARD for birthdays`.

---

### Task 3: Repository queries for the matcher

**Files:**
- Modify: `lib/features/calendar/contract/i_calendar_repository.dart`, `lib/features/calendar/data/local_calendar_repository.dart`
- Modify: the fake in `test/features/calendar/notifications/reminder_sync_test.dart` (it implements the interface)
- Test: `test/features/calendar/data/local_calendar_repository_test.dart`

**Interfaces:**
- Produces:
  - `Future<CalendarEvent?> getEventIncludingDeleted(String id)` — decodes the note even when soft-deleted; null when no note; unreadable behaviour as `getEvent`.
  - `Future<List<CalendarEvent>> eventsOwnedBySubsystems(Set<String> subsystems)` — live, readable events whose `owner.subsystem` is in the set.

- [ ] **Step 1: Failing tests:** `getEventIncludingDeleted returns a soft-deleted event with its reminders`; `getEvent still returns null for it`; `eventsOwnedBySubsystems returns only matching live events` (events owned by contacts, insurance, diabetes, plus a deleted contacts event; query {contacts, insurance} → 2).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** in the local repo (`getNoteByUuid` + `_decode`; `_readable()` filter). Stub both in the test fake.
- [ ] **Step 4: Run** `flutter test test/features/calendar` — PASS.
- [ ] **Step 5: Commit** `feat(calendar): list by subsystem and read deleted events`.

---

### Task 4: Language-neutral linked titles

**Files:**
- Create: `lib/features/calendar/domain/linked_event.dart`
- Create: `lib/features/calendar/presentation/linked_event_title.dart`
- Create: `lib/core/i18n/app_localizations_now.dart`
- Modify: `lib/features/calendar/notifications/reminder_sync.dart` (`reminderTitle`, `reminderTitleFormatProvider`), `lib/features/calendar/presentation/widgets/agenda_row.dart:45`, `lib/features/calendar/presentation/screens/event_detail_screen.dart:352`, `lib/features/calendar/presentation/calendar_note_display.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (+ regenerate)
- Test: `test/features/calendar/presentation/linked_event_title_test.dart`, `test/features/calendar/notifications/reminder_sync_test.dart`

**Interfaces:**
- Consumes: `LinkedKind` (Task 1).
- Produces:
  - `class LinkedInfo { final LinkedKind kind; final Map<String, Object?> args; }`; `LinkedInfo? linkedInfoOf(CalendarEvent e)` (null when absent, malformed or unknown kind); `Map<String, Object?> linkedToJson(LinkedKind kind, Map<String, Object?> args)`.
  - Args keys: `vehicle` (String), `service` (String), `name` (String), `birthYear` (int?), `calendar` (`'gregorian'|'lunar'`, birthdays only).
  - `String linkedTitle(LinkedInfo info, AppLocalizations l)`.
  - `String eventTitle(CalendarEvent e, Occurrence? o, AppLocalizations l)` — `o?.titleOverride`, else the linked title, else `e.title`.
  - `int? birthdayAgeAt(LinkedInfo info, DateTime occurrenceDate)` — Gregorian `date.year − birthYear`; lunar `toLunar(date)!.year − birthYear`; null without birthYear or when not a birthday.
  - `final appLocalizationsNowProvider = Provider<AppLocalizations>(…)` — the locale logic moved out of `reminderTitleFormatProvider` (chosen locale, else platform, else en).
  - ARB keys: `calendarLinkedLicenceExpiry`, `calendarLinkedRegistrationExpiry(vehicle)`, `calendarLinkedInsuranceExpiry(vehicle)`, `calendarLinkedServiceDue(vehicle, service)`, `calendarLinkedBirthday(name)`, `calendarLinkedTurnsAge(age)`. English: "Driver's licence expires", "{vehicle} registration expires", "{vehicle} insurance expires", "{vehicle}: {service} due", "{name}'s birthday", "turns {age}". Chinese: "驾照到期", "{vehicle} 行驶证到期", "{vehicle} 保险到期", "{vehicle}：{service} 到期", "{name}生日", "{age}岁".

- [ ] **Step 1: Failing tests:**

```dart
test('linked birthday title follows the language', () {
  final e = event(extra: {'linked': {'kind': 'birthday', 'args': {'name': 'Mum'}}},
      title: 'Mum生日');
  expect(eventTitle(e, null, en), "Mum's birthday");
  expect(eventTitle(e, null, zh), 'Mum生日');
});
test('unknown kind falls back to the stored title', () { /* kind 'passport' → e.title */ });
test('an occurrence title override wins', () { /* … */ });
test('lunar age counts lunar years', () {
  // calendar lunar, birthYear 1956; occurrence 2026-02-10 (lunar year 2025) → 69
});
test('notification title uses the linked title', () {
  // reminderTitle via the en provider → "All day · Driver's licence expires"
});
```

- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** `reminderTitle` gains `String Function(CalendarEvent, Occurrence)? titleOf` (default: stored title); the provider passes `(e, o) => eventTitle(e, o, l)`. Agenda row and detail use `eventTitle(e, o, AppLocalizations.of(context))` and append ` · ${l.calendarLinkedTurnsAge(age)}` when `birthdayAgeAt` is non-null. `CalendarNoteDisplay` uses the linked title when present. Run `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter test test/features/calendar` — PASS.
- [ ] **Step 5: Commit** `feat(calendar): language-neutral titles for linked events`.

---

### Task 5: The matcher

**Files:**
- Create: `lib/features/calendar/linked/linked_dates_matcher.dart`
- Test: `test/features/calendar/linked/linked_dates_matcher_test.dart` (in-memory `LocalCalendarRepository`, as the existing repository tests build it)

**Interfaces:**
- Consumes: Tasks 1, 3, 4 (`linkedToJson`, `linkedInfoOf`, `linkedTitle`).
- Produces:
  - `class LinkedDatesMatcher { LinkedDatesMatcher(ICalendarRepository repo, {required AppLocalizations l}); Future<MatchResult> apply({required List<DatedItem> wanted, required Set<String> subsystems}); }`
  - `class MatchResult { final int created, updated, removed; }` (value equality).
  - `List<Reminder> defaultLinkedReminders(LinkedKind kind)` — `[Reminder(minutesBefore: 0)]` for birthday, else `[Reminder(minutesBefore: 43200)]`.

Behaviour:
1. Duplicate keys in `wanted` → keep the first.
2. Per item: `live = getEvent(id)`; if null, `prev = getEventIncludingDeleted(id)`.
   - live: if every matcher-owned field equals (`linked` JSON, start `wireKey`, rrule string, owner subsystem+noteUuid, `reminderBody`) → no write. Else save `live` with the owned fields replaced; title re-rendered only if kind/args changed.
   - prev (soft-deleted): prev's reminders, timeSensitive, notes, occurrences + owned fields + rendered title → `saveEvent` (restores the note). Counts as created.
   - neither: new event, default reminders, `timeSensitive: true`, `source: subsystem`.
3. Removal: `eventsOwnedBySubsystems(subsystems)` → `deleteEvent` those with `linkedInfoOf(e) != null` whose id isn't wanted.

- [ ] **Step 1: Failing tests:**
  - `creates a licence event with the 30-day reminder and Time Sensitive` — id `linkedEventId('licence:expiry')`, reminders `[Reminder(minutesBefore: 43200)]`, start `AllDay(2027, 3, 14)`, `timeSensitive` true.
  - `second run with the same input writes nothing` — `MatchResult(0, 0, 0)`, `updatedAt` unchanged.
  - `a moved date keeps the owner's reminders` — set reminders `[Reminder(minutesBefore: 1440)]`, re-run with a new date → still `[1440]`, start moved.
  - `two devices converge on one event` — two repos fed the same items get identical ids and content apart from `updatedAt`.
  - `language change does not rewrite` — run with `en`, then a `zh` matcher → `MatchResult(0, 0, 0)`, title still English.
  - `removed item is deleted; a non-linked event of the same subsystem is kept`.
  - `coming back keeps reminders and done marks` (Review Focus 3) — run; set reminders and a done override; run with empty wanted; run with the item again → reminders and done override restored.
  - `birthday gets its rule and the on-the-day reminder`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** `linked_dates_matcher.dart`.
- [ ] **Step 4: Run** `flutter test test/features/calendar/linked` — PASS.
- [ ] **Step 5: Commit** `feat(calendar): linked dates matcher`.

---

### Task 6: Running the matcher

**Files:**
- Create: `lib/features/calendar/linked/linked_dates_sync.dart`
- Create: `lib/features/calendar/linked/dated_note_sources_provider.dart`
- Modify: `lib/main.dart` (start after the first frame beside `_startCalendarReminders`; keep alive with `ref.listen` like `notePurgeSchedulerProvider`, re-starting a rebuilt instance)
- Test: `test/features/calendar/linked/linked_dates_sync_test.dart`

**Interfaces:**
- Consumes: Task 5; `SyncController.runExclusive`, `status.isSyncing`, `addListener`; `IHmmNoteRepository.watchNotes()`; `appLocalizationsNowProvider`; `dataModeProvider`; `isCalendarCloudApiUnavailable`.
- Produces:
  - `final datedNoteSourcesProvider = Provider<List<DatedNoteSource>>((ref) => [])` — Tasks 7–9 each add one entry.
  - `class LinkedDatesSync with WidgetsBindingObserver { void start(); void trigger(); Future<MatchResult?> runNow(); void dispose(); }` and `linkedDatesSyncProvider` (rebuilt with the sync controller and data mode).
- Rules: `runNow` returns null without work in Cloud API mode or when the calendar repository throws its unavailable error; collects every source's `datedNotes()` → `dates`; if any source throws, `debugPrint('Linked dates skipped (${e.runtimeType})')` and return null **without calling the matcher**; runs inside `controller.runExclusive` (null = sync running). `trigger()` debounces 2 s. The after-sync listener triggers only when `!controller.status.isSyncing`. `start()` subscribes to `watchNotes()`, registers the lifecycle observer (resume → trigger) and triggers once; idempotent.

- [ ] **Step 1: Failing tests:**
  - `a throwing source leaves existing linked events alone` (Review Focus 1).
  - `no run while a sync is in progress` (Review Focus 2) — fake controller `isSyncing: true` → `runNow()` null, nothing written; set false and notify → one run.
  - `cloud API mode does nothing`.
  - `bursts of note changes run once` — fakeAsync: 5 triggers within 1 s → one run after 2 s.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** and wire `main.dart`.
- [ ] **Step 4: Run** `flutter test test/features/calendar` — PASS; `flutter analyze` — no issues.
- [ ] **Step 5: Commit** `feat(calendar): run the linked dates matcher on start, resume, changes and after sync`.

---

### Task 7: Licence source

**Files:**
- Create: `lib/features/driver_licence/data/licence_dated_source.dart`
- Modify: `lib/core/data/local/local_driver_licence_repository.dart` (`_note()`: of all notes with subject `DriverLicence:self`, return the one with the latest `lastModifiedDate ?? createDate`)
- Modify: `lib/features/calendar/linked/dated_note_sources_provider.dart`
- Test: `test/features/driver_licence/licence_dated_source_test.dart`, `test/core/data/local/local_driver_licence_repository_test.dart`

**Interfaces:**
- Consumes: Task 1; `driverLicenceRepositoryModeProvider`.
- Produces: `class LicenceDatedSource implements DatedNoteSource` — subsystems `{kLinkedSubsystemLicence}`; `locationOf` → `'/licence'` when a licence exists; one item when there is an expiry: key `licence:expiry`, kind `licenceExpiry`, args `{}`, owner (`driverLicence`, `self`), date = the expiry's calendar day as the licence screen shows it.

- [ ] **Step 1: Failing tests:** `no expiry → no items`; `expiry 2027-03-14 → one item on AllDay(2027, 3, 14)`; `two licence notes → the most recently modified wins for getLicence() and the item` (Review Focus 5).
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test test/features/driver_licence test/core/data/local` — PASS.
- [ ] **Step 5: Commit** `feat(licence): expose the expiry to the calendar`.

---

### Task 8: Automobile source (registration, insurance, service due)

**Files:**
- Create: `lib/features/automobile_records/data/automobile_dated_source.dart`
- Modify: `lib/features/calendar/linked/dated_note_sources_provider.dart`
- Test: `test/features/automobile_records/automobile_dated_source_test.dart`

**Interfaces:**
- Consumes: `IAutomobileRepository.getAutomobiles()` (active only), `IInsuranceRepository.getPolicies(autoId)`, `IScheduledServiceRepository.getSchedules(autoId)`, `IHmmNoteRepository.getNoteById(id)` / `getNoteByUuid(uuid)`, a clock `DateTime Function() now` (default `DateTime.now`). Repos via the `*RepositoryModeProvider`s.
- Produces: `class AutomobileDatedSource implements DatedNoteSource` — subsystems `{automobile, insurance, scheduledService}`. Items:
  - registration: key `vehicle:<uuid>:registration`, kind `registrationExpiry`, args `{'vehicle': displayName}`.
  - insurance: `isActive` policy with expiry day ≥ today − 90 days; key `insurance:<uuid>:expiry`, args `{'vehicle': displayName}`, `reminderBody` = provider when non-empty.
  - service: `isActive` schedule with `nextDueDate`; key `service:<uuid>:due`, args `{'vehicle': displayName, 'service': name}`.
  - Dates: the same calendar day each record's own screen shows (use that screen's conversion of the stored DateTime).
  - `locationOf`: `getNoteByUuid` → local ids → `/automobiles/manage/<autoId>/edit`, `/automobiles/manage/<autoId>/insurance/<policyId>/edit`, `/automobiles/manage/<autoId>/scheduled-services/<scheduleId>/edit`; null when missing or deleted.

- [ ] **Step 1: Failing tests:** `sold vehicle contributes nothing`; `policy expired 91 days ago is out, 90 days ago is in`; `inactive schedule or no due date contributes nothing`; `insurer goes in reminderBody`; `a record whose uuid lookup fails is skipped, others still listed`; `locationOf maps a policy owner to its edit route`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test test/features/automobile_records` — PASS.
- [ ] **Step 5: Commit** `feat(automobile): expose registration, insurance and service dates to the calendar`.

---

### Task 9: Contact birthday model and source

**Files:**
- Create: `lib/features/contacts/domain/entities/contact_birthday.dart`
- Modify: `lib/features/contacts/domain/entities/contact.dart` (`birthday`, `remindBirthday`, `copyWith`)
- Modify: `lib/features/contacts/data/contact_codec.dart` (`_knownKeys` + `birthday`, `remindBirthday`; defensive read; write `birthday` when set, `remindBirthday` when true)
- Create: `lib/features/contacts/data/contact_dated_source.dart`
- Modify: `lib/features/calendar/domain/lunar.dart` (add `lunarMonthName(int month, {bool leap = false})` and `lunarDayName(int day)` if absent)
- Modify: `lib/features/calendar/linked/dated_note_sources_provider.dart`
- Test: `test/features/contacts/contact_birthday_test.dart`, `test/features/contacts/contact_codec_test.dart`, `test/features/contacts/contact_dated_source_test.dart`

**Interfaces:**
- Produces:
  - `enum BirthdayCalendar { gregorian, lunar }`; `class ContactBirthday { final BirthdayCalendar calendar; final int month, day; final bool leap; final int? year; }` with `Map<String, Object?> toJson()` and `static ContactBirthday? fromJson(Object? v)` (null on any invalid value: month 1–12; day 1–31 Gregorian / 1–30 lunar; `leap` only for lunar).
  - `AllDay birthdaySeriesStart(ContactBirthday b)` — Gregorian `AllDay(year ?? 2000, month, day)`; lunar `fromLunarBackward(y, month, day, leap: leap)` with `y` = year when in 1901–2099, else 2000.
  - `RecurrenceRule birthdayRule(ContactBirthday b)` — `gregorianYearlyBackward()` or `lunarYearly(month: month, day: day, leap: leap)`.
  - `DateTime? nextBirthday(ContactBirthday b, DateTime today)` — first occurrence on/after today, via `expandOccurrences` on a synthetic all-day event so it matches the calendar exactly.
  - `class ContactDatedSource implements DatedNoteSource` — subsystems `{contacts}`; active contacts with a birthday and `remindBirthday`; key `contact:<id>:birthday`; args `{'name': displayName, 'birthYear': year, 'calendar': calendar.name}`; `locationOf` → `/contacts/<id>` (null when missing or deactivated).

- [ ] **Step 1: Failing tests:**
  - codec: `birthday and remindBirthday round-trip`; `unknown keys still preserved`; `an invalid birthday reads as null and the contact still loads`; `remindBirthday defaults false`.
  - `29 Feb with unknown year anchors on AllDay(2000, 2, 29)`.
  - `lunar 三十 and leap-month birthdays occur once every year 2026–2035` (Review Focus 4) — for lunar 4/30 and lunar leap 6/1: expand the synthetic event 2026-01-01..2036-01-01 → exactly 10 occurrences, one per year.
  - source: `Remind me off → nothing`; `deactivated contact → nothing`; `item carries name, birthYear and calendar args and the birthday rule`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test test/features/contacts test/features/calendar/domain` — PASS.
- [ ] **Step 5: Commit** `feat(contacts): birthday field and calendar source`.

---

### Task 10: Birthday picker

**Files:**
- Create: `lib/features/contacts/presentation/widgets/birthday_picker.dart`
- Modify: ARB files (+ regenerate)
- Test: `test/features/contacts/presentation/birthday_picker_test.dart`

**Interfaces:**
- Consumes: `ContactBirthday` (Task 9), `lunarMonthName`, `lunarDayName`.
- Produces: `Future<BirthdayPickResult?> showBirthdayPicker(BuildContext context, {ContactBirthday? initial})`; `sealed class BirthdayPickResult` with `BirthdayPicked(ContactBirthday birthday)` and `BirthdayCleared()`; null = cancelled.
- Layout: 公历/农历 control (`CupertinoSlidingSegmentedControl` on iOS/macOS, `SegmentedButton` otherwise). Gregorian: month and day (day list follows the month; 29 Feb allowed) and optional year. Lunar: month 正月…腊月 with a 闰 toggle, day 初一…三十, optional year. Cupertino wheels in a bottom sheet on iOS; a Material dialog with dropdowns on Android. Buttons: Done, Clear (only when `initial != null`), Cancel.
- ARB keys: `contactBirthday` ("Birthday"/"生日"), `contactBirthdayGregorian` ("Gregorian"/"公历"), `contactBirthdayLunar` ("Lunar"/"农历"), `contactBirthdayLeapMonth` ("Leap month"/"闰月"), `contactBirthdayYear` ("Year (optional)"/"年份（可选）"), `contactBirthdayNoYear` ("No year"/"不填年份"), `contactBirthdayClear` ("Clear"/"清除").

- [ ] **Step 1: Failing widget tests:** `iOS: picks lunar leap 4/5 without a year → BirthdayPicked(lunar, 4, 5, leap: true, year: null)`; `Android: picks 29 Feb 1960`; `Clear returns BirthdayCleared`; `switching 农历 → 公历 keeps the day within the month`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement**; `flutter gen-l10n`. **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `feat(contacts): Gregorian and lunar birthday picker`.

---

### Task 11: Contact editor and detail

**Files:**
- Modify: `lib/features/contacts/states/contact_edit_state.dart` (`setBirthday(ContactBirthday?)`; clearing also sets `remindBirthday` false)
- Modify: `lib/features/contacts/presentation/screens/contact_edit_screen.dart` (Birthday row after the relationship field; opens the picker)
- Modify: `lib/features/contacts/presentation/screens/contact_detail_screen.dart` (Birthday row and Remind me switch)
- Modify: `lib/features/contacts/states/contacts_state.dart` (add `setRemindBirthday(String id, bool on)` if no existing save path fits)
- Modify: `lib/core/help/help_registry.dart` (`HelpId.contactEdit` Birthday entry; `HelpId.contactDetail` Remind me entry), ARB files
- Test: `test/features/contacts/presentation/contact_edit_screen_test.dart`, `test/features/contacts/presentation/contact_detail_screen_test.dart`

**Behaviour:**
- Detail Birthday row: Gregorian in the locale's date format (with or without year); lunar `lunarMonthDayText(month, day, leap: leap)` plus "· next <date>" from `nextBirthday`; age when the year is known (`contactBirthdayAge(age)`: "Age {age}"/"{age}岁").
- Remind me switch (platform-branched), shown only when a birthday is set; toggling saves at once through `showUndoableAction` with `contactRemindOn`, `contactRemindOff`, `contactRemindFailed`, `contactRemindUndone`, `contactRemindUndoFailed`.
- Help: `helpContactEditBirthdayTitle/Body` (icon `Icons.cake`), `helpContactDetailRemindTitle/Body` (icon `Icons.notifications_active`) — the birthday then appears on the calendar and reminds at 9:00 on the day, adjustable in the calendar.

- [ ] **Step 1: Failing widget tests:** `editor: set a lunar birthday and save → stored birthday`; `editor: clearing the birthday turns Remind me off`; `detail: no birthday → no Remind me switch`; `detail: Remind me on saves remindBirthday true; Undo restores false`; `detail: lunar birthday shows 闰四月初五 and the next date`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement**; `flutter gen-l10n`. **Step 4: Run** `flutter test test/features/contacts test/core/help` — PASS (icon-button guard included).
- [ ] **Step 5: Commit** `feat(contacts): birthday in the editor and Remind me on the detail screen`.

---

### Task 12: Linked events in the calendar screens

**Files:**
- Modify: `lib/features/calendar/presentation/screens/event_detail_screen.dart` (`subsystemLabel` cases; Open <source>; no Delete for linked events)
- Modify: `lib/features/calendar/presentation/screens/event_edit_screen.dart`, `lib/features/calendar/states/event_edit_state.dart` (title/date/repeat read-only for linked events; `buildEvent` keeps the stored title, start and rrule for them)
- Create: `lib/features/calendar/linked/linked_source_location.dart` — `Future<String?> linkedSourceLocation(List<DatedNoteSource> sources, EventOwner owner)` (first source whose `subsystems` contains `owner.subsystem`)
- Modify: `lib/core/help/help_registry.dart` (`HelpId.calendarEvent` linked-events entry; `HelpId.calendarEventEdit` read-only note), ARB files
- Test: `test/features/calendar/presentation/event_detail_screen_test.dart`, `test/features/calendar/presentation/event_edit_screen_test.dart`

**Interfaces:**
- Consumes: `linkedInfoOf` (Task 4), `datedNoteSourcesProvider` (Task 6).
- ARB: `calendarSubsystemDriverLicence` ("Driver's licence"/"驾照"), `calendarSubsystemAutomobile` ("Vehicle"/"车辆"), `calendarSubsystemInsurance` ("Insurance"/"保险"), `calendarSubsystemScheduledService` ("Car service"/"保养"), `calendarSubsystemContacts` ("Contacts"/"联系人"), `calendarOpenSource(source)` ("Open {source}"/"打开{source}"), `calendarLinkedChangeIn(source)` ("Change it in {source}"/"请在{source}中修改"), `calendarOpenSourceGone` ("It's no longer there"/"已不存在"), `helpCalendarEventLinkedTitle/Body` (icon `Icons.link`).
- Open <source>: under "From <source>"; read the sources provider before the await, then `if (!context.mounted) return; context.push(location)`, or show `calendarOpenSourceGone` when null.

- [ ] **Step 1: Failing widget tests:** `linked event: no Delete, Open Contacts shown`; `tapping Open pushes /contacts/<id>`; `source gone → snackbar`; `edit screen: title, date and repeat read-only with "Change it in Contacts"; reminders editable; save keeps start and rrule`; `a hand-made event keeps Delete and editable fields`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement**; `flutter gen-l10n`. **Step 4: Run** `flutter test` (full suite, read the summary line) — all pass; `flutter analyze` — no issues.
- [ ] **Step 5: Commit** `feat(calendar): linked events show their source and stay read-only`.
