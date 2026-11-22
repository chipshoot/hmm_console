# Glucose Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A glucose log. Blood glucose readings are notes in catalog `Hmm.GlucoseMan.Reading`, imported from Apple Health on the iPhone or typed in. The log has an optional tag, one owner-set target range, a list, a form, a dashboard tile and launcher entries.

**Architecture:**
- A new feature, `lib/features/glucose/`, copying `lib/features/activity/` file for file:
  - domain types plus a codec that preserves unknown data;
  - an `IGlucoseRepository` contract with a local implementation over notes (local / cloudStorage; Cloud API throws);
  - screens.
- HealthKit is read through the pub.dev `health` package, behind a `GlucoseSampleSource` interface. A pure `GlucoseImporter` decides what to save.
- A `GlucoseImportRunner` modelled on `LinkedDatesSync` (`lib/features/calendar/linked/linked_dates_sync.dart`) decides when to run.

**Tech Stack:** Flutter, Riverpod, Drift (notes table only, no new tables), go_router, gen-l10n, `health` (new), `uuid` (existing, v5).

**Spec:** `docs/superpowers/specs/2026-11-22-glucose-log-design.md` (approved 2026-11-22, commit 482c77a). Read it before any task. Where this plan says "like Activity", open the named Activity file and mirror it.

## Global Constraints

**Note storage**
- Catalog name `Hmm.GlucoseMan.Reading`. Catalog schema string `{"type":"glucoseReading"}`. Note uuid = reading id. Note subject `Glucose:<id>`.
- Reading JSON keys exactly as spec §5.2:
  - `schemaVersion` (1), `id`, `takenAt`, `glucose` {`value`, `unit`}, `context`, `notes`, `source`, `appleHealth` {`sampleId`, `sourceName`}, `draft`, `updatedAt`;
  - required: `schemaVersion, id, takenAt, glucose, source, updatedAt`.
- `takenAt` is ISO 8601 with UTC offset (`OffsetDateTime` from `lib/features/activity/domain/offset_date_time.dart`, reused, not copied). `updatedAt` is UTC ISO `…Z`, whole seconds.
- Allowed values:
  - `unit`: `mg/dL | mmol/L`;
  - `context`: `fasting | beforeMeal | afterMeal | bedtime | other`, optional;
  - `source`: `manual | appleHealth | assistant`.
- The codec preserves unknown keys (top level, inside `glucose` and `appleHealth`) and wrong-typed known values, exactly like `ActivityCodec`.

**Values and units**
- Values are stored exactly as entered or imported. Imported values are mg/dL as the package returns them. Never convert before storing.
- Display conversion: mmol/L = mg/dL ÷ 18.016. Display rounding: mmol/L to 1 decimal, mg/dL whole.
- Valid typed values: 20–600 mg/dL, or 1.1–33.3 mmol/L.

**Import**
- Imported id = `Uuid().v5(kGlucoseIdNamespace, 'appleHealth:<sampleId>')`, with `kGlucoseIdNamespace = '5b6f2c1e-8d3a-4f7b-9e2c-1a4d6b8c0e57'`.
- Imported `takenAt` = `OffsetDateTime.fromLocal(sampleInstantUtc.toLocal())`, i.e. the zone's offset at the sample's instant.
- An import skips any sample whose id exists live or deleted, and never modifies an existing reading.
- Import window:
  - first import: `DateTime.utc(2000)` to now;
  - later imports: (stored last end − 7 days) to now.
- Import gates. All of these must hold:
  - iOS;
  - not Cloud API;
  - "Import from Apple Health on this device" on (unset → on when shortest side < 600 pt, like `RemindOnDeviceNotifier`);
  - first import done (per-device flag);
  - not waiting for the first sync (`cloudSync && controller.status.lastSyncAt == null`, as `linkedDatesSyncProvider` does);
  - at least 15 minutes since the last automatic run.
  The manual "Import now" bypasses the first-import flag and the 15-minute throttle, but no other gate.
- Per-device prefs keys: `glucose.importOnDevice`, `glucose.importedOnce`, `glucose.lastImportEnd` (UTC ISO).

**Settings**
- Synced settings keys in `SyncableSettings`:
  - `glucoseRangeLow` (num?), `glucoseRangeHigh` (num?), `glucoseRangeUnit` (String?);
  - `glucoseDisplayUnit` (String?; unset → `mg/dL` if the device region is `US`, else `mmol/L`).
- No default target range.

**Privacy and modes**
- No embeddings or model-derived data in notes. No network calls. Health data never leaves the device except via existing note sync.
- Cloud API mode: the repository provider throws `GlucoseCloudApiUnavailable`. Screens show a "not available" message, and the launcher hides the glucose destinations.
- `changes()` never emits for the initial snapshot.

**Project rules**
- Every new screen gets a `HelpId`, a `helpFor` case, en **and** zh ARB strings, and a `HelpButton` last in the app bar.
- Icon buttons only via `HmmIconButton` with a localized tooltip.
- Deletes via `showUndoableAction`, with no `WidgetRef`/`BuildContext` in `undo`.
- iOS uses Cupertino variants (branch on `Theme.of(context).platform`).
- ARB edits are followed by `flutter gen-l10n`, and the generated `lib/l10n/gen/*` is committed.
- Never `dart format` a directory; format only files you touched.
- Never stage `CLAUDE.md`.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **First import of years of history.** It must finish without freezing the UI, and save in batches (≤ 100 readings per `runExclusive` body). Test in Task 4: 250 fake samples all saved, and the save calls are split.
2. **A reading near a daylight-saving change, or near midnight.** A January sample imported in July keeps its January offset and stays under its own date. Test in Task 4, with a sample at 2026-01-15T12:00Z showing offset −05:00 when the test zone is America/Toronto. Use a `toLocal` seam if zone control is needed.
3. **The display unit changes after the range was set.** Colouring still compares correctly (the range is stored with its unit). Test in Task 3: range 4.0–7.0 mmol/L and a reading of 130 mg/dL gives `above`.
4. **An import finds nothing, or HealthKit throws.** The first case shows the "No readings found…" message (spec §5.3). The second shows a short error and never crashes or blocks the screen. Test in Task 4 (importer result) and Task 5 (list shows the message).
5. **An imported reading is edited.** Value and time are read-only, the tag and notes save, and a later import leaves the edit alone. Test in Task 6 (form) and Task 4 (importer skips the existing id).

---

### Task 1: Domain types, codec and schema

**Files:**
- Create:
  - `lib/features/glucose/domain/glucose_reading.dart`
  - `lib/features/glucose/domain/glucose_units.dart`
  - `lib/features/glucose/data/glucose_codec.dart`
  - `docs/schemas/glucose.reading.schema.json`
- Test:
  - `test/features/glucose/domain/glucose_units_test.dart`
  - `test/features/glucose/data/glucose_codec_test.dart`
  - `test/features/glucose/data/glucose_schema_test.dart`

**Interfaces:**
- Consumes: `OffsetDateTime` (activity domain).
- Produces:
  - `enum GlucoseUnit { mgdl, mmoll }` with `wire` (`'mg/dL'`, `'mmol/L'`) and `static GlucoseUnit? fromWire(String)`.
  - `enum GlucoseContext { fasting, beforeMeal, afterMeal, bedtime, other }` with `wire` = name.
  - `enum GlucoseSource { manual, appleHealth, assistant }`.
  - `class GlucoseValue { final num value; final GlucoseUnit unit; num inUnit(GlucoseUnit u); String display(GlucoseUnit u); }`. `display` returns, for example, `'6.2 mmol/L'` or `'112 mg/dL'`.
  - `class AppleHealthRef { final String sampleId; final String? sourceName; }`.
  - `class GlucoseReading`:
    - fields: `id`, `takenAt` (OffsetDateTime), `glucose` (GlucoseValue), `context` (GlucoseContext?), `notes` (String), `source`, `appleHealth` (AppleHealthRef?), `draft` (bool), `updatedAt` (DateTime?), plus private preserved-data fields like `Activity`;
    - `copyWith` with `clearContext`.
  - `bool isValidTypedValue(GlucoseValue v)`: true for 20–600 mg/dL equivalents.
  - `class GlucoseCodec { static GlucoseReading decode(String id, String json); static String encode(GlucoseReading r); }` and `class GlucoseUnreadable implements Exception`.

- [ ] **Step 1: Write the failing tests.**
  - `GlucoseValue(112, mgdl).inUnit(mmoll)` is closeTo 6.2166, delta 0.001.
  - `display(mmoll)` returns `'6.2 mmol/L'`.
  - `GlucoseValue(6.2, mmoll).display(mgdl)` returns `'112 mg/dL'`.
  - `isValidTypedValue`: 19 mg/dL false, 20 true, 600 true, 601 false, 1.1 mmol/L true, 33.4 mmol/L false.
  - Codec round-trip of the spec §5.2 example, and decode → encode keeps:
    - an unknown top-level key `"future": {"x":1}`;
    - an unknown key inside `glucose`;
    - a wrong-typed `context: 7`.
  - Missing `takenAt` throws `GlucoseUnreadable`.
  - An integral double value `112.0` decodes to 112.
  - The schema test parses the JSON file:
    - `required` equals the six required keys;
    - `properties.schemaVersion.const` is 1, matching `GlucoseCodec.schemaVersion`.
- [ ] **Step 2: Run** `flutter test test/features/glucose/`. Expected: FAIL (files missing).
- [ ] **Step 3: Implement.** Mirror `lib/features/activity/data/activity_codec.dart` for how unknown keys and wrong-typed values are kept.
- [ ] **Step 4: Run the same command.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(glucose): reading type, codec and schema`.

### Task 2: Repository contract, local implementation, providers

**Files:**
- Create:
  - `lib/features/glucose/contract/i_glucose_repository.dart`
  - `lib/features/glucose/contract/glucose_errors.dart`
  - `lib/features/glucose/data/local_glucose_repository.dart`
  - `lib/features/glucose/states/glucose_providers.dart`
- Test:
  - `test/features/glucose/contract/glucose_repository_contract.dart`
  - `test/features/glucose/data/local_glucose_repository_test.dart`
  - `test/features/glucose/support/fake_glucose_repository.dart`
  - `test/features/glucose/support/fake_glucose_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 types; `localHmmNoteRepositoryProvider`, `localNoteCatalogRepositoryProvider`, `dataModeProvider` (as `activity_providers.dart` does).
- Produces:
  - `abstract interface class IGlucoseRepository`:
    - `Future<List<GlucoseReading>> readingsBetween(DateTime from, DateTime to)`: `takenAt.utc` in `[from, to)`, newest first, unreadable skipped;
    - `Future<GlucoseReading?> getReading(String id)`;
    - `Future<bool> existsIncludingDeleted(String id)`;
    - `Future<GlucoseReading> saveReading(GlucoseReading r)`;
    - `Future<void> deleteReading(String id)`;
    - `Stream<void> changes()`.
  - `GlucoseIdCollision`, `GlucoseCloudApiUnavailable`, `bool isGlucoseCloudApiUnavailable(Object)`, and `export … GlucoseUnreadable`.
  - `localGlucoseRepositoryProvider` and `glucoseRepositoryProvider`. The latter throws in cloudApi.
  - `void runGlucoseRepositoryContract(Future<IGlucoseRepository> Function() create)`.
  - `FakeGlucoseRepository`. It must honour `existsIncludingDeleted` for deleted ids.

- [ ] **Step 1: Write the contract suite, modelled on `test/features/activity/contract/activity_repository_contract.dart`.** Cover everything the Activity suite covers, plus:
  - `existsIncludingDeleted` is false for an unknown id, true for a live one, and still true after `deleteReading`.
  - `saveReading` of a deleted id restores it.
  - A save over a note of another catalog with that uuid throws `GlucoseIdCollision`.
- [ ] **Step 2: Run** `flutter test test/features/glucose/`. Expected: FAIL.
- [ ] **Step 3: Implement.** Mirror `local_activity_repository.dart`: catalog get-or-create with the by-name fallback, paging by 100, soft delete and restore. `existsIncludingDeleted` reads the note by uuid including deleted rows, and only counts notes in this catalog.
- [ ] **Step 4: Run.** Expected: PASS against both the local implementation and the fake.
- [ ] **Step 5: Commit** `feat(glucose): repository contract and local store`.

### Task 3: Settings: target range, display unit, per-device import state

**Files:**
- Modify:
  - `lib/features/settings/domain/syncable_settings.dart` (four fields: JSON, copyWith, equality, as for `calendarShowLunar`)
  - `lib/features/settings/data/syncable_settings_repository.dart` (prefs keys `glucose.rangeLow`, `glucose.rangeHigh`, `glucose.rangeUnit`, `glucose.displayUnit`)
- Create:
  - `lib/features/glucose/domain/glucose_range.dart`
  - `lib/features/glucose/states/glucose_settings_providers.dart`
- Test:
  - `test/features/glucose/domain/glucose_range_test.dart`
  - `test/features/glucose/states/glucose_settings_providers_test.dart`
  - extend the existing `SyncableSettings` JSON round-trip test

**Interfaces:**
- Produces:
  - `class GlucoseRange { final num low; final num high; final GlucoseUnit unit; }`.
  - `enum GlucoseBand { below, inRange, above }`.
  - `GlucoseBand? bandFor(GlucoseValue v, GlucoseRange? r)`: null when `r` is null. It compares after converting `v` to `r.unit`, so a value equal to `low` or `high` is `inRange`.
  - `glucoseRangeProvider` (`Notifier<GlucoseRange?>`, with `set(GlucoseRange)` and `clear()`).
  - `glucoseDisplayUnitProvider` (`Notifier<GlucoseUnit>`, with `set`). The default comes from the device region (`PlatformDispatcher.instance.locale.countryCode == 'US'` → mgdl), with a constructor seam for tests.
  - `glucoseImportOnDeviceProvider` (`Notifier<bool>`, with `set`). Copy `RemindOnDeviceNotifier` with key `glucose.importOnDevice`.
  - `GlucoseImportPrefs`, a small class over SharedPreferences:
    - `Future<bool> importedOnce()`, `Future<void> markImportedOnce()`;
    - `Future<DateTime?> lastImportEnd()`, `Future<void> setLastImportEnd(DateTime utc)`;
  - `glucoseImportPrefsProvider`.

- [ ] **Step 1: Write the failing tests.**
  - `bandFor`:
    - null range gives null;
    - 4.0–7.0 mmol/L: 6.2 mmol/L is inRange, 7.0 is inRange, 7.1 is above, 3.9 is below;
    - **Review Focus 3:** range 4.0–7.0 mmol/L with 130 mg/dL gives `above`.
  - The settings round-trip keeps all four new fields, and old JSON without them decodes with nulls.
  - The display unit defaults to mgdl for country `US` and mmoll for `CA`.
  - The import setting defaults to true at side 390 and false at side 820.
- [ ] **Step 2: Run** the new tests and the settings tests. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/glucose/ test/features/settings/ test/core/settings/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(glucose): target range, display unit and import settings`.

### Task 4: Apple Health source, importer and runner

**Files:**
- Modify:
  - `pubspec.yaml`: add `health` (latest stable that resolves; pin the exact version the resolver picks)
  - `ios/Runner/Runner.entitlements`: `com.apple.developer.healthkit` true, and `com.apple.developer.healthkit.access` as an empty array
  - `ios/Runner/Info.plist`: `NSHealthShareUsageDescription` = "Hmm reads your blood glucose readings so they appear in your glucose log."
  - `ios/Runner.xcodeproj/project.pbxproj`: only if the HealthKit capability needs the entitlements file referenced (it already is)
  - `lib/main.dart`: start the runner the way `linkedDatesSyncProvider` is started (lines ~77 and ~146)
- Create:
  - `lib/features/glucose/import/glucose_sample_source.dart`
  - `lib/features/glucose/import/health_glucose_sample_source.dart`
  - `lib/features/glucose/import/glucose_importer.dart`
  - `lib/features/glucose/import/glucose_import_runner.dart`
- Test:
  - `test/features/glucose/import/glucose_importer_test.dart`
  - `test/features/glucose/import/glucose_import_runner_test.dart`
  - `test/features/glucose/support/fake_glucose_sample_source.dart`

**Interfaces:**
- Consumes: `IGlucoseRepository`, `GlucoseImportPrefs`, `glucoseImportOnDeviceProvider`, `syncControllerProvider` (`status.lastSyncAt`, `runExclusive`, `isSyncing`), `dataModeProvider`.
- Produces:
  - `class GlucoseSample { final String sampleId; final DateTime instantUtc; final num mgdl; final String? sourceName; }`.
  - `abstract interface class GlucoseSampleSource`:
    - `Future<bool> requestAccess()`;
    - `Future<List<GlucoseSample>> samples(DateTime fromUtc, DateTime toUtc)`.
  - `HealthGlucoseSampleSource`, using `Health().configure()`, then `requestAuthorization([HealthDataType.BLOOD_GLUCOSE], permissions: [HealthDataAccess.READ])`, then `getHealthDataFromTypes`. It maps `uuid`, `dateFrom`, the numeric value in mg/dL, and `sourceName`.
  - `String glucoseIdForSample(String sampleId)`, plus the `kGlucoseIdNamespace` constant.
  - `class GlucoseImportResult { final int added; final int seen; final Object? error; }`.
  - `class GlucoseImporter`:
    - constructor `({required IGlucoseRepository repo, required GlucoseSampleSource source, required GlucoseImportPrefs prefs, required DateTime Function() now, required Future<T?> Function<T>(Future<T> Function()) runExclusive, DateTime Function(DateTime utc) toLocal = _toLocal})`;
    - `Future<GlucoseImportResult> run({required bool manual})`. On `manual` with `importedOnce` false it calls `requestAccess()` first. On success it sets `lastImportEnd = now` and `markImportedOnce()`. On error it leaves both untouched and returns `error`.
  - `GlucoseImportRunner with WidgetsBindingObserver`:
    - `start()`, `dispose()`, `Future<GlucoseImportResult?> importNow()`;
    - automatic runs fire on start and on resume, with every gate checked;
    - exposes `ValueListenable<GlucoseImportResult?> lastResult` for the list's message.
  - `glucoseImportRunnerProvider`.

- [ ] **Step 1: Write the importer tests, with the fake source and fake repo.** Pin `now` to `2026-11-22T12:00Z`.
  - **First import:** window from `DateTime.utc(2000)` to now. Three samples are saved with:
    - id `glucoseIdForSample(sampleId)`;
    - `source` `appleHealth`, `glucose` in mg/dL as given, `appleHealth.sampleId` and `sourceName` set, `context` null.
  - **Second run, same samples:** `added == 0`, and no extra saves.
  - **Deleted stays deleted:** after a reading is deleted from the repo, the next run doesn't save it.
  - **An existing reading is not modified:** the stored copy has `context: afterMeal` and notes `"x"`, and both survive a run with the same sample.
  - **Later window:** with `lastImportEnd = 2026-11-20T00:00Z`, the source is asked from `2026-11-13T00:00Z`.
  - **Source throws:** the result has the error, and `lastImportEnd` and `importedOnce` are unchanged.
  - **Review Focus 1:** 250 samples are all saved, and `runExclusive` is called at least 3 times.
  - **Review Focus 2:** a sample at `2026-01-15T12:00Z`, with a `toLocal` seam that returns that instant at −05:00, stores `takenAt` `2026-01-15T07:00:00-05:00`.
- [ ] **Step 2: Write the runner tests**, with injected gate functions like `LinkedDatesSync`'s.
  - No automatic run when any one gate fails: not iOS, cloudApi, setting off, `importedOnce` false, waiting for first sync.
  - A run on start when all gates pass.
  - A second resume within 15 minutes doesn't run; one after 15 minutes does.
  - `importNow()` runs even with `importedOnce` false, and calls `requestAccess`.
  - `importNow()` returns null in cloudApi.
- [ ] **Step 3: Run** `flutter test test/features/glucose/import/`. Expected: FAIL.
- [ ] **Step 4: Implement.**
  - Add the package and the iOS setup.
  - Save readings in chunks of 100, each chunk inside `runExclusive`.
  - Wire the runner in `main.dart`.
- [ ] **Step 5: Run** the import tests, then `flutter analyze`. Expected: PASS and no issues.
- [ ] **Step 6: Build check.** Run `flutter build ios --no-codesign --debug`. Expected: builds (this proves the plugin and entitlements compile).
- [ ] **Step 7: Commit** `feat(glucose): import readings from Apple Health`.

### Task 5: List screen, routes, note display

**Files:**
- Create:
  - `lib/core/navigation/glucose_routes.dart` (`/glucose`, `/glucose/new`, `/glucose/:id`)
  - `lib/features/glucose/presentation/screens/glucose_list_screen.dart`
  - `lib/features/glucose/states/glucose_list_state.dart`
  - `lib/features/glucose/presentation/glucose_note_display.dart`
- Modify:
  - `lib/core/navigation/route_names.dart`: `glucose`, `glucoseCreate`, `glucoseEdit`
  - `lib/core/navigation/router_config.dart`: spread `glucoseRoutes`
  - `lib/features/notes/rendering/note_display.dart`: register the display, like `ActivityNoteDisplay`
  - `lib/core/help/help_registry.dart`: `HelpId.glucose`
  - the ARB files
- Test:
  - `test/features/glucose/presentation/glucose_list_screen_test.dart`
  - `test/features/glucose/states/glucose_list_state_test.dart`

**Interfaces:**
- Consumes: the repository, range, display unit, runner (`importNow`, `lastResult`), and `glucoseImportOnDeviceProvider`.
- Produces:
  - `GlucoseListScreen`.
  - `glucoseListProvider`: readings grouped by `takenAt.wallDate`, newest first, last 90 days, refreshed on `changes()`.
  - `GlucoseNoteDisplay` with `catalogName` = `Hmm.GlucoseMan.Reading`. Its title is `'Glucose 6.2 mmol/L'` in the display unit.

- [ ] **Step 1: Write the failing widget tests.** Use the fake repo and the providers overridden.
  - **Rows:** each row shows the value in the display unit, the tag label when set, the band word or dot when a range is set, the time, and a Health or typed marker.
  - **Grouping:** readings are grouped under "Today" and "Yesterday" by the reading's own wall date.
  - **No range:** "Set your target range" appears and opens the range screen route.
  - **Empty:**
    - the empty state shows "Log a reading";
    - on iOS with import on, it also shows "Import from Apple Health", which calls `importNow`.
  - **Nothing found (Review Focus 4):** when `lastResult` is `added 0, seen 0, error null` after a manual run, the text "No readings found. If you use a meter app, check Health → Sharing → Apps → Hmm." is shown.
  - **Error:** an error result shows a short error SnackBar.
  - **Delete:** a swipe shows the undo SnackBar; undo restores the reading.
  - **Cloud API:** shows the not-available message.
  - **Help:** a `HelpButton` is present.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Mirror `activity_list_screen.dart`. The Import now `HmmIconButton` shows only on iOS with import on.
- [ ] **Step 4: Run** `flutter gen-l10n`, then the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(glucose): list screen and routes`.

### Task 6: Entry and edit form, range setting screen

**Files:**
- Create:
  - `lib/features/glucose/presentation/screens/glucose_edit_screen.dart`
  - `lib/features/glucose/states/glucose_edit_state.dart`
  - `lib/features/glucose/presentation/screens/glucose_range_screen.dart` (route `/glucose/range`, name `glucoseRange`)
- Modify:
  - `glucose_routes.dart`, `route_names.dart`
  - `help_registry.dart`: `HelpId.glucoseEdit`, `HelpId.glucoseRange`
  - the Settings screen: add a "Glucose" row opening `/glucose/range`, beside the existing calendar section
  - the ARB files
- Test:
  - `test/features/glucose/presentation/glucose_edit_screen_test.dart`
  - `test/features/glucose/presentation/glucose_range_screen_test.dart`
  - `test/features/glucose/states/glucose_edit_state_test.dart`

**Interfaces:**
- Consumes: the repository, `isValidTypedValue`, the range and display unit providers, the platform date-time picker helper used by Activity (`lib/features/calendar/presentation/widgets/platform_date_time_pickers.dart`).
- Produces: `GlucoseEditScreen({String? readingId})`, `GlucoseRangeScreen` (range, display unit, and on iOS the per-device import switch; spec §5.3 and §5.4).

- [ ] **Step 1: Write the failing tests.**
  - **New reading:**
    - the unit toggle defaults to the display unit;
    - Save stays disabled until a valid value is entered;
    - 650 mg/dL shows an out-of-range error and keeps Save disabled;
    - saving 6.2 mmol/L stores `glucose {6.2, mmol/L}`, `source manual`, and `takenAt` = the picked time with the device offset.
  - **Tag:** it can be picked and cleared, and clearing stores no `context`.
  - **Imported reading (Review Focus 5):**
    - value and time are read-only, and "From Apple Health · CONTOUR DIABETES" is shown;
    - changing the tag to `afterMeal` and the notes saves both, and leaves `glucose`, `takenAt` and `appleHealth` unchanged.
  - **Range screen:**
    - saving low 4.0, high 7.0 in mmol/L sets `glucoseRangeProvider`;
    - low ≥ high shows an error and doesn't save;
    - changing the display unit updates `glucoseDisplayUnitProvider`.
  - On iOS only, the switch "Import from Apple Health on this device" shows, reflects `glucoseImportOnDeviceProvider`, and toggling it calls `set`. It is absent on Android.
  - **Help:** each screen has a `HelpButton`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Mirror `activity_edit_screen.dart` for layout, the Cupertino and Material branches, and save and error handling.
- [ ] **Step 4: Run** `flutter gen-l10n`, then the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(glucose): entry form and target range setting`.

### Task 7: Dashboard tile and launcher

**Files:**
- Modify:
  - `lib/features/dashboard/presentation/screens/dashboard_screen.dart`: an `AppFunction` "Glucose" (icon `"🩸"`, description "Blood sugar", route `glucose`), its route case, and a subtitle like the Activity tile's
  - `lib/features/launcher/domain/launcher_registry.dart`: destinations `glucose` and `glucoseLog`, both added to `_localOnlyDestinationIds`
  - the ARB files
- Create: `lib/features/glucose/states/last_glucose_reading.dart`
- Test:
  - `test/features/dashboard/dashboard_glucose_tile_test.dart`
  - `test/features/glucose/states/last_glucose_reading_test.dart`
  - extend the launcher registry tests

**Interfaces:**
- Produces: `lastGlucoseReadingProvider`, a stream-backed `AsyncValue<GlucoseReading?>` of the newest live reading, refreshed on `changes()`, with errors mapped to null like `health_minutes_today.dart`.

- [ ] **Step 1: Write the failing tests.**
  - **Tile with a reading:** "Last: 6.2 mmol/L · 2 h ago", with the clock pinned. A band dot shows when a range is set.
  - **Tile, no readings:** "No readings yet".
  - **Tile, Cloud API:** "Not available" (`activityNotAvailableShort` style).
  - **Tap:** opens `GlucoseListScreen` with no "coming soon" SnackBar.
  - **Launcher:** the `glucose` and `glucoseLog` destinations exist, and are hidden for `DataMode.cloudApi`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter gen-l10n`, then `flutter test test/features/dashboard/ test/features/launcher/ test/features/glucose/`. Expected: PASS.
- [ ] **Step 5: Run** the full suite, `flutter test`, and `flutter analyze`. Expected: all pass, no issues.
- [ ] **Step 6: Commit** `feat(glucose): dashboard tile and launcher entries`.
