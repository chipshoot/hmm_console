# Activity Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A shared Activity log: activity entries as notes in catalog `Hmm.ActivityMan.Activity`, logged after the fact, with a list, a form, a calendar-session link, a dashboard tile (health minutes) and launcher entries.

**Architecture:** A new feature `lib/features/activity/` copying the calendar's shape: domain types + a codec that preserves unknown data, an `IActivityRepository` contract with a local implementation over notes (local / cloudStorage; Cloud API throws), a code kind registry, then screens. The calendar link uses the calendar's own occurrence wire key.

**Tech Stack:** Flutter, Riverpod, Drift (notes table only, no new tables), go_router, gen-l10n.

**Spec:** `docs/superpowers/specs/2026-11-21-activity-log-design.md` (approved 2026-11-21, commit 13826e3). Read it before any task.

## Global Constraints

- Catalog name `Hmm.ActivityMan.Activity`; catalog schema string `{"type":"activity"}`; note uuid = activity id; note subject `Activity:<id>`.
- Entry JSON keys exactly as spec §5.2: `schemaVersion` (1), `id`, `kind`, `start`, `durationMinutes`, `intensity`, `measurements`, `links`, `plannedEvent` {`eventId`, `occurrence`, `at`}, `notes`, `details`, `source`, `draft`, `updatedAt`. Required: `schemaVersion, id, kind, start, durationMinutes, source, updatedAt`.
- `start` and `plannedEvent.at`: ISO 8601 with UTC offset (e.g. `2026-11-21T18:40:00-05:00`); `updatedAt`: UTC ISO `…Z`, whole seconds.
- `durationMinutes`: integer 1..1440. `intensity`: `light | moderate | vigorous`. `source`: `manual | appleHealth | assistant`; v1 writes `manual`. Measurement: `{name, value (number), unit}`; v1 only `distance` with `km` or `mi`.
- Codec preserves unknown keys (top level, in each measurement, link, plannedEvent), wrong-typed known values, and unparseable list entries, exactly like `CalendarEventCodec`.
- Kind ids `<area>.<name>`; v1 kinds: `health.walk, health.run, health.cycling, health.swim, health.gym, health.yoga, health.other, reading.reading, development.coding`; distance offered for walk, run, cycling, swim.
- No embeddings or model-derived data in notes.
- Cloud API mode: repository provider throws `ActivityCloudApiUnavailable`; screens show a "not available" message.
- `changes()` never emits for the initial snapshot.
- Every new screen: `HelpId` + `helpFor` case + en **and** zh ARB strings + `HelpButton` last in the app bar. Icon buttons only via `HmmIconButton` with localized tooltip. Deletes via `showUndoableAction` (no `WidgetRef`/`BuildContext` in `undo`). iOS uses Cupertino variants (branch on `Theme.of(context).platform`).
- ARB edits are followed by `flutter gen-l10n`; generated `lib/l10n/gen/*` is committed.
- Never `dart format` a directory; format only files you touched. Never stage `CLAUDE.md`.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Travel / time zones:** an entry started `23:30-05:00` must stay under its own date (the start's recorded wall date) when the device is in UTC+8; the dashboard "today" compares the device's current date with each entry's recorded wall date. (Tests in Tasks 1, 4, 7.)
2. **Older build meets newer data:** an entry with an unknown kind, unknown keys and `details` must survive open → edit duration → save unchanged except the edited field. (Tests in Tasks 1, 5.)
3. **Delete then undo** restores the same id (soft-deleted note restored, not duplicated). (Tests in Tasks 3, 4.)
4. **Linked note deleted** after linking: the form shows "removed", saving keeps the link. (Test in Task 5.)
5. **One unreadable activity note** (bad JSON) does not break the list; other entries still show. (Tests in Tasks 3, 4.)

---

### Task 1: Domain types, codec, schema

**Files:**
- Create: `lib/features/activity/domain/activity.dart`, `lib/features/activity/domain/offset_date_time.dart`, `lib/features/activity/data/activity_codec.dart`, `docs/schemas/activity.activity.schema.json`
- Test: `test/features/activity/domain/offset_date_time_test.dart`, `test/features/activity/data/activity_codec_test.dart`

**Interfaces:**
- Produces:
  - `class OffsetDateTime { const OffsetDateTime(this.utc, this.offset); final DateTime utc; final Duration offset; DateTime get wall /* utc+offset, as UTC fields */; DateTime get wallDate /* DateTime.utc(y,m,d) of wall */; String toIso(); static OffsetDateTime? tryParse(String s); factory OffsetDateTime.fromLocal(DateTime local) /* offset = local.timeZoneOffset */; }` — first grep `lib/` for an existing ISO-with-offset helper and reuse it if one exists.
  - `enum ActivityIntensity { light, moderate, vigorous }`, `enum ActivitySource { manual, appleHealth, assistant }`.
  - `class ActivityMeasurement { String name; double value; String unit; Map<String,Object?> extraFields; }`, `class ActivityLink { String noteUuid; String? role; extraFields }`, `class PlannedEventRef { String eventId; String occurrence /* calendar wireKey */; OffsetDateTime? at; extraFields }`.
  - `class Activity { String id; String kind; OffsetDateTime start; int durationMinutes; ActivityIntensity? intensity; List<ActivityMeasurement> measurements; List<ActivityLink> links; PlannedEventRef? plannedEvent; String? notes; Map<String,Object?> details; ActivitySource source; bool draft; DateTime? updatedAt; extraFields; rawKnownValues; unreadableEntries; String get area /* kind before first '.' */; Activity copyWith(...); }`.
  - `class ActivityCodec { static const currentSchemaVersion = 1; static Activity decode(String id, Map<String,Object?> json); static Map<String,Object?> encode(Activity a); }`; `class ActivityUnreadable implements Exception { final String id; }` thrown when `kind` is not a non-empty String, `start` doesn't parse, or `durationMinutes` is not an int.

- [ ] **Step 1: Write failing tests.**
  - `offset_date_time_test.dart`: `tryParse('2026-11-21T18:40:00-05:00')` → `utc == DateTime.utc(2026,11,21,23,40)`, `offset == Duration(hours: -5)`, `toIso()` returns the same string, `wallDate == DateTime.utc(2026,11,21)`; `tryParse('2026-11-21T23:30:00-05:00')!.wallDate == DateTime.utc(2026,11,21)` (Review Focus 1); `tryParse('garbage') == null`; `tryParse('2026-11-21T18:40:00Z')` → offset zero and `toIso()` ends with `+00:00`.
  - `activity_codec_test.dart`: decode the spec §5.2 example then encode equals the input; unknown key `"future": 1` at top level and unknown keys inside a measurement, a link and `plannedEvent` survive encode; `"intensity": 7` decodes to null and is written back as `7`; measurement entry `"x"` is kept in `unreadableEntries['measurements']` and re-emitted; missing `schemaVersion` reads as 1; missing `kind`, `start: "bad"`, or `"durationMinutes": "30"` throw `ActivityUnreadable`; `details: {"reading": {"pages": 25}}` round-trips untouched.
  - Schema test (same file): load `docs/schemas/activity.activity.schema.json`; every `required` key is in the encode output; every output key is in `properties`; `properties.schemaVersion.const == ActivityCodec.currentSchemaVersion`.
- [ ] **Step 2: Run** `flutter test test/features/activity` — FAIL (missing files).
- [ ] **Step 3: Implement** the types and codec following `CalendarEventCodec`'s `read<T>` / `keep` / `_extras` pattern; write the schema (JSON Schema 2020-12, `$id` `https://homemademessage.com/schemas/activity.activity.schema.json`, `title` `Hmm.ActivityMan.Activity`, description says unknown keys are allowed and must be kept).
- [ ] **Step 4: Run** `flutter test test/features/activity` — PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(activity): entry model, codec and schema`.

### Task 2: Kind registry

**Files:**
- Create: `lib/features/activity/domain/activity_kind.dart`, `lib/features/activity/domain/builtin_activity_kinds.dart`, `lib/features/activity/states/activity_kinds_provider.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (+ regenerated `lib/l10n/gen/*`)
- Test: `test/features/activity/domain/activity_kind_test.dart`

**Interfaces:**
- Produces:
  - `class ActivityKind { const ActivityKind({required String id, required IconData icon, required String Function(AppLocalizations) label, ActivityIntensity? defaultIntensity, bool offersDistance = false}); String get area; }`
  - `final List<ActivityKind> builtinActivityKinds` — the 9 kinds; default intensity: run vigorous; walk, cycling, swim, gym, yoga moderate; other, reading, coding none.
  - `class ActivityKindRegistry { const ActivityKindRegistry(List<ActivityKind> kinds); ActivityKind? byId(String id); List<String> get areas /* first-seen order */; List<ActivityKind> inArea(String area); List<ActivityKind> get all; }`
  - `final activityKindRegistryProvider = Provider<ActivityKindRegistry>(...)` built from one list `[...builtinActivityKinds]` — the single registration point future subsystems append to.
  - `String activityAreaLabel(String area, AppLocalizations l)` (health / reading / development; unknown area → the raw id).
  - ARB keys: `activityKindWalk, activityKindRun, activityKindCycling, activityKindSwim, activityKindGym, activityKindYoga, activityKindOther, activityKindReading, activityKindCoding, activityAreaHealth, activityAreaReading, activityAreaDevelopment, activityIntensityLight, activityIntensityModerate, activityIntensityVigorous`.

- [ ] **Step 1: Failing test:** 9 kinds with unique ids; `byId('health.walk')!.offersDistance == true`; `byId('reading.reading')!.offersDistance == false`; `byId('health.unknown') == null`; `areas == ['health','reading','development']`; `inArea('health').length == 7`; every kind's English label is non-empty and differs from its zh label.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; add ARB strings (en + zh), run `flutter gen-l10n`.
- [ ] **Step 4: Run** — PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(activity): kind registry`.

### Task 3: Repository contract and local implementation

**Files:**
- Create: `lib/features/activity/contract/i_activity_repository.dart`, `lib/features/activity/contract/activity_errors.dart`, `lib/features/activity/data/local_activity_repository.dart`, `lib/features/activity/states/activity_providers.dart`
- Test: `test/features/activity/contract/activity_repository_contract.dart`, `test/features/activity/data/local_activity_repository_test.dart`, `test/features/activity/support/fake_activity_repository.dart`, `test/features/activity/support/fake_activity_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 `Activity`, `ActivityCodec`, `ActivityUnreadable`.
- Produces:
  - `abstract interface class IActivityRepository { Future<List<Activity>> activitiesBetween(DateTime from, DateTime to, {Set<String>? areas}); Future<Activity?> getActivity(String id); Future<Activity> saveActivity(Activity a); Future<void> deleteActivity(String id); Stream<void> changes(); }` — `activitiesBetween` filters by `start.utc` in `[from, to)`, newest first, skips unreadable notes, `areas` filters by `Activity.area`.
  - `const activityCatalogName = 'Hmm.ActivityMan.Activity'`; `String activitySubjectFor(String id) => 'Activity:$id'`.
  - `class ActivityCloudApiUnavailable extends UnimplementedError`, `class ActivityIdCollision implements Exception { final String id; }`, `bool isActivityCloudApiUnavailable(Object error)` (unwraps `ProviderException`, like `isCalendarCloudApiUnavailable`).
  - `LocalActivityRepository(IHmmNoteRepository notes, INoteCatalogRepository catalogs, {DateTime Function()? now, Duration changesRetryDelay = const Duration(seconds: 1)})` — mirror `LocalCalendarRepository` (catalog get-or-create with by-name fallback, paging by 100, `_liveNote`, save = create / restore+update / collision, `updatedAt` truncated to whole seconds, soft delete, `changes()` baseline-first and re-attach on error/done).
  - `localActivityRepositoryProvider`, `activityRepositoryProvider` (throws `ActivityCloudApiUnavailable` when `dataModeProvider` is `DataMode.cloudApi`).
  - `FakeActivityRepository implements IActivityRepository` (in-memory; broadcast `changes()` that never emits on subscribe) for screen tests.
- [ ] **Step 1: Failing tests.**
  - `runActivityRepositoryContract(Future<IActivityRepository> Function() create)`: save then get returns the same fields and an `updatedAt` with zero milliseconds; save same id twice → one entry; `activitiesBetween` returns `[from, to)` by `start.utc`, newest first; `areas: {'reading'}` filters; delete then get → null; delete missing id → no throw; **delete then save same id → `activitiesBetween` has exactly one** (Review Focus 3); `changes()` does not emit on subscribe, emits after a save and after a delete.
  - Local test: runs the contract with an in-memory `HmmDatabase` built exactly like `_make()` in `test/features/calendar/data/local_calendar_repository_test.dart`; **a note in the activity catalog with content `{bad` is skipped by `activitiesBetween` while a good one is returned, and `getActivity` on it throws `ActivityUnreadable`** (Review Focus 5); saving an id that exists in another catalog throws `ActivityIdCollision`; stored subject is `Activity:<id>`; `activityRepositoryProvider` throws `ActivityCloudApiUnavailable` under `DataMode.cloudApi`.
  - Fake test: runs the same contract against `FakeActivityRepository`.
- [ ] **Step 2: Run** `flutter test test/features/activity` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(activity): repository contract and local store`.

### Task 4: Activity list screen, routes, help, Notes-list display

**Files:**
- Create: `lib/features/activity/presentation/screens/activity_list_screen.dart`, `lib/features/activity/presentation/widgets/activity_row.dart`, `lib/features/activity/presentation/activity_summary.dart`, `lib/features/activity/presentation/activity_note_display.dart`, `lib/features/activity/presentation/widgets/activity_cloud_api_message.dart`, `lib/features/activity/states/activity_list_state.dart`, `lib/core/navigation/activity_routes.dart`
- Modify: `lib/core/navigation/route_names.dart` (add `activity, activityCreate, activityEdit`), `lib/core/navigation/router_config.dart` (spread `...activityRoutes` next to `...calendarRoutes`), `lib/core/help/help_registry.dart` (`HelpId.activity` with full entries; `HelpId.activityEdit` minimal), `lib/features/notes/rendering/note_display.dart` (register `ActivityNoteDisplay` in the const map), ARB + gen.
- Test: `test/features/activity/presentation/activity_list_screen_test.dart`, `test/features/activity/presentation/activity_summary_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - Routes: `/activity` (`activity`, list), `/activity/new` (`activityCreate`, declared before `:id`) and `/activity/:id` (`activityEdit`, key `ValueKey('activity-$id')`). Create/edit build `ActivityEditScreen({String? activityId})` from `lib/features/activity/presentation/screens/activity_edit_screen.dart`; in this task that file is a minimal stub (a `Scaffold` with the title and a `HelpButton(helpId: HelpId.activityEdit)`), which Task 5 replaces. Add `HelpId.activityEdit` with a title, summary and one entry now; Task 5 completes its entries.
  - `String activitySummary(Activity a, ActivityKindRegistry r, AppLocalizations l, {String? noteTitle})` → `Walk · 30 min · moderate · 2.4 km`; reading with a linked note title → `Reading · 40 min · "Dune"`; unknown kind → `Other (health.xyz) · 30 min`; ≥ 60 minutes → `1 h 20 min`; exactly 60 → `1 h`.
  - `activityListProvider` (notifier keyed by area filter `String?`): entries for the last 30 days by `start.utc`, grouped by `start.wallDate` (the entry's own recorded date, not the device zone), refreshed on `changes()`; `loadEarlier()` extends by 30 days. Day headers: Today / Yesterday relative to an injectable clock's local date, else a localized date.
  - `class ActivityNoteDisplay implements NoteDisplayEntry { static const catalogName = activityCatalogName; }` — title = `activitySummary`, preview = first line of notes, target `(route: RouterNames.activityEdit, params: {'id': id})` (strip `Activity:` prefix, fall back to `note.uuid`); an undecodable note → title `activityTitle`, empty preview.
  - `ActivityCloudApiMessage` (centered `l.activityCloudApiUnavailable`), shown when `isActivityCloudApiUnavailable(error)`.
  - ARB: `activityTitle, activityLogAction, activityEmpty, activityFilterAll, activityToday, activityYesterday, activityLoadEarlier, activityDeleted, activityDeleteFailed, activityDeleteUndone, activityUndoFailed, activityDraftLabel, activityCloudApiUnavailable, activityMinutes, activityHours, activityHoursMinutes, helpActivityTitle, helpActivitySummary, helpActivityAddTitle, helpActivityAddBody, helpActivityFilterTitle, helpActivityFilterBody, helpActivityDeleteTitle, helpActivityDeleteBody`.
- [ ] **Step 1: Failing tests** (widget tests with `FakeActivityRepository` override):
  - empty state shows `activityEmpty` and a log button;
  - entries render under Today / Yesterday / dated headers by `start.wallDate`;
  - **an entry `2026-11-20T23:30:00-05:00` renders under 20 Nov while the injected clock says 21 Nov 10:00 local** (Review Focus 1);
  - chips All / Health / Reading / Dev filter the rows;
  - a `draft: true` entry shows `activityDraftLabel`;
  - long-press → Delete calls `deleteActivity`; tapping Undo re-saves the same id and the row returns (Review Focus 3);
  - the screen shows the good entry while the store also holds an unreadable note (use the local repo over an in-memory DB with one `{bad` note; Review Focus 5);
  - Cloud API override → `activityCloudApiUnavailable`;
  - app bar has `HelpButton(helpId: HelpId.activity)`.
  - `activity_summary_test.dart`: the summary strings listed above; `ActivityNoteDisplay` target is `activityEdit` with the id.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** (Cupertino on iOS; `HmmIconButton` + localized tooltip for the add button).
- [ ] **Step 4: Run** `flutter test test/features/activity test/core/help test/features/notes` — PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(activity): list screen, routes and help`.

### Task 5: Activity form (create / edit)

**Files:**
- Create: `lib/features/activity/states/activity_edit_state.dart`, `lib/features/activity/presentation/distance_unit.dart`
- Modify: `lib/features/activity/presentation/screens/activity_edit_screen.dart` (replace the Task 4 stub), `lib/core/help/help_registry.dart` (complete `HelpId.activityEdit`), ARB + gen.
- Test: `test/features/activity/presentation/activity_edit_screen_test.dart`, `test/features/activity/states/activity_edit_state_test.dart`

**Interfaces:**
- Consumes: Tasks 1–4; `showNotePicker(BuildContext, {bool Function(HmmNote, String?)? canPick})` → `Future<HmmNote?>` from `lib/features/notes/presentation/screens/note_picker.dart`; `IHmmNoteRepository.getNoteByUuid` to resolve a link title.
- Produces:
  - `ActivityEditScreen({super.key, String? activityId})` (routes already exist from Task 4).
  - `String defaultDistanceUnit(Locale locale)` → `'mi'` when `countryCode` is one of `US, GB, LR, MM`, else `'km'`.
  - Edit state (`activityEditProvider` family by `String?` id) with an injectable clock and prefs:
    - New entry defaults: kind = most recently used kind (prefs key `activity.recentKinds`, per device, max 5, most recent first; first run `health.walk`); duration unset; ended = now; intensity = kind default.
    - `start = ended − duration`, stored via `OffsetDateTime.fromLocal`.
    - Save enabled iff kind set, duration in 1..1440 and ended not after now (otherwise inline `activityEndedInFuture`).
    - Changing to a kind without distance drops the distance measurement on save; a user-picked intensity is kept when the kind changes.
    - Editing an existing entry applies only touched fields via `copyWith` on the decoded `Activity`, so unknown kind, unknown keys, `details`, `source`, `draft`, `rawKnownValues` survive (Review Focus 2).
    - Exposes `PlannedEventRef? planned` and a setter for Task 6 (no UI yet).
  - Form controls: kind picker (recent first, then grouped by area), duration chips 15 / 30 / 45 / 60 + custom minutes, ended date+time picker (Cupertino on iOS), intensity segmented control, distance field only when `offersDistance` (unit from `defaultDistanceUnit`, or the stored unit when editing), linked-note row, notes field, delete in the app bar for existing entries (undoable, then pop).
  - Linked note: role = `book` for `reading`, `project` for `development`, `meal` for `health`; the row shows the note's title, or `activityLinkRemoved` when `getNoteByUuid` returns null or a deleted note — the link is kept on save (Review Focus 4).
  - Unknown kind: shows `activityUnknownKind` with the stored id; kind picker disabled.
  - ARB: `activityNewTitle, activityEditTitle, activityKindLabel, activityDurationLabel, activityDurationCustom, activityEndedLabel, activityEndedInFuture, activityIntensityLabel, activityDistanceLabel, activityLinkLabel, activityLinkNone, activityLinkRemoved, activityNotesLabel, activitySave, activityDelete, activityUnknownKind, helpActivityEditTitle, helpActivityEditSummary, helpActivityEditKindTitle, helpActivityEditKindBody, helpActivityEditDurationTitle, helpActivityEditDurationBody, helpActivityEditEndedTitle, helpActivityEditEndedBody, helpActivityEditLinkTitle, helpActivityEditLinkBody`.
- [ ] **Step 1: Failing tests.**
  - State: new → save disabled; kind + 30 → enabled; `start` = ended − 30 min; ended = now + 1 min → disabled with the future message; 1441 → disabled; after save `activity.recentKinds` starts with the saved kind and has ≤ 5 entries; `defaultDistanceUnit(const Locale('en','US')) == 'mi'`, `defaultDistanceUnit(const Locale('zh','CN')) == 'km'`.
  - **State: edit an entry with kind `health.parkour`, `details: {"health": {"hr": 120}}`, top-level `"future": 1` and `draft: true`; change duration 30 → 45; the encoded saved entry equals the original encode except `durationMinutes` and `updatedAt`** (Review Focus 2).
  - State: a walk with 2.4 km switched to gym saves with no measurements.
  - Widget: unknown kind shows `activityUnknownKind` and the stored id; **a link whose note is missing shows `activityLinkRemoved` and saving keeps it** (Review Focus 4); a picked note (override the picker) on `reading.reading` saves `ActivityLink(noteUuid, role: 'book')`; delete → Undo restores; `HelpButton(helpId: HelpId.activityEdit)` present.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** In the picker flow, do not await `notesListStateProvider.future` (it hangs when Notes is offstage).
- [ ] **Step 4: Run** `flutter test test/features/activity test/core/help` — PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(activity): log and edit form`.

### Task 6: Planned session link

**Files:**
- Create: `lib/features/activity/states/planned_sessions.dart`
- Modify: `lib/features/activity/presentation/screens/activity_edit_screen.dart`, `lib/features/activity/states/activity_edit_state.dart`, `lib/features/calendar/presentation/screens/event_detail_screen.dart`, ARB + gen.
- Test: `test/features/activity/states/planned_sessions_test.dart`, additions to `test/features/activity/states/activity_edit_state_test.dart` and `test/features/calendar/presentation/event_detail_screen_test.dart`

**Interfaces:**
- Consumes: `ICalendarRepository.eventsBetween(from, to)`, `expandOccurrences(e, fromUtc, toUtc)` (`recurrence_expander.dart`), `Occurrence` (`originalStart.wireKey`, `start`, `allDay`, `status`), `OccurrenceStatus`, `linkedInfoOf(e)` (`domain/linked_event.dart`), `ICalendarRepository.setOccurrence(eventId, OccurrenceOverride(originalStart: …, status: OccurrenceStatus.done))`, `calendarRepositoryProvider`, `isCalendarCloudApiUnavailable`; Task 3 repository; Task 4 `activitySummary`; Task 5 state `planned`.
- Produces:
  - `class PlannedSession { final CalendarEvent event; final Occurrence occurrence; }`; `Future<List<PlannedSession>> plannedSessions(ICalendarRepository repo, {required DateTime now})` — occurrences with start from local midnight of yesterday up to `now + 12 h`, excluding all-day occurrences, statuses `done | skipped | cancelled`, cancelled events, and linked events (`e.owner != null && linkedInfoOf(e) != null`); sorted by distance from `now`, nearest first.
  - Form: a "Planned session" row listing them (title + local time); picking one sets ended so that start equals the occurrence start (keeping duration; if duration unset, ended = occurrence start and duration stays unset) and sets `planned = PlannedEventRef(eventId: e.id, occurrence: o.originalStart.wireKey, at: OffsetDateTime.fromLocal(o.start.toLocal()))`; "None" clears it. Row hidden when the calendar provider throws.
  - Save with a new or changed `planned`: save the activity first, then `setOccurrence(... done)`; if that throws, the activity stays saved and `activityPlannedMarkFailed` is shown. Clearing the link or deleting the activity never calls `setOccurrence`.
  - `Future<List<Activity>> activitiesForOccurrence(IActivityRepository repo, {required String eventId, required String wireKey, required DateTime around})` — searches `activitiesBetween(around − 2 days, around + 2 days)` for matching `plannedEvent.eventId` and `plannedEvent.occurrence`.
  - Event detail: when the shown occurrence (from `resolveOccurrence`, or the event's start for a one-off) has linked activities, a `ListTile` after the notes tile reading `activityLoggedLine(summary)` (`Logged: {summary}`); tap pushes `activityEdit`. Not shown when the activity repository is unavailable.
  - ARB: `activityPlannedLabel, activityPlannedNone, activityPlannedMarkFailed, activityLoggedLine`.
- [ ] **Step 1: Failing tests.**
  - `plannedSessions` with a fake calendar holding: a timed one-off today 18:30, an all-day event today, an occurrence already done, a linked birthday (`extraFields['linked']` set, owner set), a cancelled event, and a daily repeating floating `07:00` event → returns the one-off plus today's and yesterday's 07:00, nearest to `now` first.
  - State: picking today's 07:00 stores `occurrence == 'floating:2026-11-21T07:00'`; save calls `setOccurrence` once with `status: done` and that `originalStart`; `setOccurrence` throwing → activity saved and the failure flag set; deleting the activity never calls `setOccurrence`.
  - Event detail: an activity linked to the shown occurrence renders `Logged: Walk · 30 min · moderate`; none → no tile.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/activity test/features/calendar` — PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(activity): link a log to a calendar session`.

### Task 7: Dashboard tile and launcher

**Files:**
- Create: `lib/features/activity/states/health_minutes_today.dart`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`, `lib/features/launcher/domain/launcher_registry.dart`, ARB + gen.
- Test: `test/features/activity/states/health_minutes_today_test.dart`, plus additions next to existing dashboard and launcher tests.

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces:
  - `int healthMinutesOn(List<Activity> entries, DateTime deviceToday)` — sums `durationMinutes` where `area == 'health'` and `start.wallDate` has the same y/m/d as `deviceToday`; `healthMinutesTodayProvider` (reads the last 2 days by `start.utc` plus one day ahead, recomputes on `changes()`, yields null in Cloud API).
  - Dashboard: a new `AppFunction(icon: "🚶", title: "Activity", description: "Log activity", route: "activity")`; localized title case → `l.dashboardActivityTitle`; subtitle `l.activityActiveToday(text)` (`Active today: 45 min`, using the Task 4 duration format) or `l.activityNoneToday` at 0; navigation case `context.pushNamed(RouterNames.activity.name)`; in Cloud API the tile behaves like the calendar tile.
  - Launcher: `LauncherDestination(id: 'activity', title: l.activityTitle, icon: Icons.directions_walk, routeName: RouterNames.activity.name, synonyms: const ['Activity','exercise','workout','walk','log','活动','运动','锻炼'])` and `LauncherDestination(id: 'activityLog', title: l.activityLogAction, icon: Icons.add_circle_outline, routeName: RouterNames.activityCreate.name, synonyms: const ['log activity','记录活动'])`; add both ids to the set that hides destinations in Cloud API.
  - ARB: `dashboardActivityTitle, activityActiveToday, activityNoneToday`.
- [ ] **Step 1: Failing tests.** `healthMinutesOn`: walk 30 + gym 45 today, reading 40 today, walk 20 yesterday → 75; **`2026-11-21T23:30:00-05:00` counts for deviceToday 21 Nov, not 22 Nov** (Review Focus 1). Dashboard: with those entries the tile reads `Active today: 1 h 15 min` and tapping goes to `activity`. Launcher: query `运动` finds `activity`; both destinations hidden in Cloud API.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full `flutter test` and `flutter analyze` — all pass.
- [ ] **Step 5: Commit** `feat(activity): dashboard tile and launcher entries`.
