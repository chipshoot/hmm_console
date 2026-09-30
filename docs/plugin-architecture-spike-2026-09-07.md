# Plugin architecture spike — should subsystems become plugins?

**Status:** spike complete, findings only. **Nothing approved, nothing built.**
**Date:** 2026-09-07
**Question asked:** "Switch subsystems (gas log, automobile manager, etc.) to
plugins that add business logic above core Hmm logic, like Obsidian and Notion.
Is it a good design idea? Is it hard to make the switch?"
**Branch at time of spike:** `feat/vehicle-documents` (unrelated work in flight —
see *Repo state* at the bottom).

Related prior art, read this first: [`feature-contribution-registry.md`](./feature-contribution-registry.md)
(2026-08-08). It asks a narrower version of the same question and reaches a
sharper conclusion. This spike measures the codebase against it.

---

## Verdict

**Yes as a direction, no as a copy of Obsidian.** The valuable half is already
~80% built — this would be *finishing* a direction the codebase has been
drifting toward, not starting one. Medium effort, decomposes into independently
shippable steps, and the data model never moves.

---

## Finding 1 — the generic core already exists

Obsidian and Notion are not plugin systems that happen to store data. They are a
**generic core data model** (markdown files in a vault; blocks in a tree) with
typed views layered on top. The plugin API is downstream of that.

The Drift schema (`lib/core/data/local/database.dart:107-109`) has **five
tables**:

```dart
@DriftDatabase(tables: [Authors, NoteCatalogs, Notes, Tags, NoteTagRefs])
```

No `gas_logs`. No `automobiles`, `insurance_policies`, `cheatsheets`. Every
domain is JSON in a note, keyed by a catalog name and discovered by a subject
prefix — `local_gas_log_repository.dart:20`:

```dart
const _gasLogCatalogName = 'Hmm.AutomobileMan.GasLog';
```

Catalog names in use client-side: `Hmm.AutomobileMan.{AutomobileInfo, GasLog,
GasStation, AutoInsurancePolicy, AutoScheduledService, ServiceRecord,
DriverLicence}`, `Hmm.CheatsheetMan.Cheatsheet`, `Hmm.System.Subsystem`.
The backend mirrors this (`Hmm.Automobile` serializes to note content).

`Hmm.System.Subsystem` (`features/notes/data/subsystem_anchor.dart:10`) is
already a subsystem registry under a different name — anchor notes that
subsystems hang records off.

The things built *on top* of the core are domain-free too:

| Core subsystem | References into `features/` |
|---|---|
| `core/data/sync/` (~13 files, the whole sync engine) | 5 — all to `settings` |
| `core/data/vault/` + `core/data/attachments/` | **0** |
| `core/widgets/` | 2 — both `settings` |

The sync engine, attachment vault and shared widgets do not know gas logs exist.
**That is the hard part of a plugin architecture, and it is done.**

## Finding 2 — the runtime half is unavailable, permanently

Obsidian ships a JS runtime; plugins are JS bundles downloaded at runtime.
Flutter is AOT-compiled and App Store rule 2.5.2 forbids downloading executable
code. No `Assembly.Load`, no runtime catalogue, no drop-in module.
(`feature-contribution-registry.md` already established this: the *contribution*
half of the WinForms/MEF/Prism model translates, the *unload* half does not.)

So "plugin" here can only mean **compile-time modules with a declarative
contribution contract**. Consequences:

- Users still cannot install anything
- No third party can write a plugin
- Ship cycle unchanged (App Store review)
- Adding a feature stops requiring edits to five central files
- **Absence becomes testable** ← the actual prize

Notion does not do runtime plugins either; its "integrations" are API clients.

## Finding 3 — features are clean; the broken arrow is core → features

Cross-feature coupling is nearly zero. The entire matrix across 13 modules and
~26k lines of `lib/features/`:

- `cheatsheet → notes`
- `dashboard → auth`

That is all. The problem runs the other way. **`lib/core/` references
`lib/features/` 101 times**, concentrated in three places:

| Location | Refs | What it is |
|---|---|---|
| `core/data/local/` | 38 | Ten domain repositories living in core, importing feature entities |
| `core/navigation/` (`router_config.dart` + route files) | 34 | 35 `GoRoute`s declared centrally |
| `core/data/repository_providers.dart` | 10 | Mode switchboard hardcoding every domain |
| scattered (`i18n` 3, `notes` 4, `settings` 3, `widgets` 2, `auth` 1, `util` 1) | 14 | Odds and ends |
| `core/data/sync/` | 5 | All to `settings` |

Feature module sizes for reference: gas_log 7225 lines / 69 files,
automobile_records 5045 / 46, notes 4327 / 39, cheatsheet 2309 / 19,
settings 1937 / 12, driver_licence 1009 / 8, receipt_scan 787 / 10,
launcher 893 / 11, auth 871 / 21, dashboard 543 / 5, message_management 451 / 9,
onboarding 278 / 2, geocoding 124 / 4. `core/data/` alone is 14,230 lines.

### Evidence the leak already costs something

1. `features/cheatsheet/domain/source_scope.dart:21-25` **duplicates catalog-name
   constants by hand**, with a test to keep the copies honest, because importing
   them would drag Drift and Riverpod into a pure domain file. That comment is
   the architecture asking for a contract layer.
2. The drift bug in `feature-contribution-registry.md`: cheatsheets shipped to
   `main`, got a dashboard tile, was never registered as a launcher destination.
   Invisible to search, undetectable by any test, because the three catalogues
   key on different things.

---

## Proposed staging (NOT approved — this is the recommendation, not a plan)

**Do, in this order:**

1. **Move the ten `local_*_repository.dart` out of `core/data/local/` into their
   features.** They depend only on `HmmDatabase` + the note/catalog
   repositories; nothing pulls the other way. Kills 38 of 101 refs.
   Mechanical, low risk, mostly import fixes. *~1 session.*
2. **Invert `repository_providers.dart`.** Each feature declares its own
   `xxxRepositoryModeProvider` beside its interface, watching `dataModeProvider`.
   Core's copy shrinks to note/author/tag/catalog. Kills 10 more. *~½ session.*
3. **Build `FeatureContribution`** — already designed in
   `feature-contribution-registry.md`; `LauncherDestination` is ~80% of it.
   Unify dashboard tiles + launcher + quick panel onto one catalogue, then add
   the test that is impossible today: *every dashboard-visible feature has a
   launcher destination.* *~1–2 sessions.*
4. **Per-feature route lists.** Each feature exports `List<RouteBase> routes`;
   core composes. Kills the last 34. Do it last, when the pattern is proven.
   *~1 session.*

**Do NOT do:**

- **Per-feature ARB files.** `app_en.arb` is 1075 keys in one file; `gen-l10n`
  does not compose well. Would trade a working localization pipeline for
  architectural tidiness. Keep one ARB.
- **Per-module Drift schemas.** Not needed — everything is notes. This is the
  trap: it looks like the natural next step and buys nothing.
- **Runtime module loading on the backend.** .NET *could* via
  `AssemblyLoadContext`, and `Hmm.Automobile` / `Hmm.Cheatsheet` /
  `Hmm.BigCalendar` are already separate assemblies — but controllers live in
  `Hmm.ServiceApi`, and for a single-user personal app this is ceremony. The
  backend is already as modular as it needs to be.

## The caveat to re-read before starting

`feature-contribution-registry.md` set a trigger: *"the third feature that needs
to appear on more than one surface, or the first contributor that shouldn't live
in `core/`."* Ten domain repositories in `core/data/local/` and the
hand-duplicated constant in `source_scope.dart` say the second trigger tripped.
Steps 1–3 have earned their keep.

But the payoff is **not extensibility** — nobody will ever write a plugin for
this app. It is that core stops knowing about gas logs, absence becomes
testable, and adding feature #14 stops meaning "edit five central files and hope
you didn't miss one." Real, but smaller and more specific than "be like
Obsidian" — and framing it the second way pulls you toward the two items in the
*do not* list.

---

## Design session — 2026-09-08

User chose **full design for steps 1–3**. Ran `superpowers:brainstorming` on the
**architectural** path. Four decisions settled. **No code written; no `lib/` or
`test/` file touched** (verified by `git status`: only `ios/Podfile.lock`, which
predates the session, and this doc).

### Decision 1 — phantom dashboard tiles: DROP THEM

`dashboard_screen.dart:50-99` declares 8 tiles. **Four have no feature behind
them** — Pomodoro, Expenses, Weather, Calendar — and fall through
`_navigateToFunction`'s `default:` to a "coming soon" snackbar
(`dashboard_screen.dart:407`). No `lib/features/` folder exists for any of them.

Chosen: delete all four. `FeatureContribution` only ever describes features that
exist, so `available` means "usable right now" and nothing else. Rejected: a
`status: shipped | planned` field (a second concept every surface must handle).

*The drift is far worse than `feature-contribution-registry.md` recorded.* The
launcher has 11 real destinations; the dashboard shows 7 of them not at all
(vehicles, serviceRecords, scheduledServices, insurance, vehicleNotes,
gasStations, settings). The tile labelled "Gas Log" navigates to `/automobiles`,
while the launcher's `gasLog` goes to `gasLogList` — the same name means two
different things. The two catalogues barely intersect.

### Decision 2 — `HmmNote` moves to core

`hmm_note.dart` + `hmm_note_mapper.dart` move from `features/notes/data/` to
`core/data/models/`. 16 files import `HmmNote`; **13 are in `core/`**, only 3 in
features outside `notes/` itself. `core/notes/` (catalog_palette, editing,
rendering) reaches into the feature for it too. It is a core type filed under a
feature by accident. `features/notes/` keeps its screens and states.

Rejected: documenting `notes` as a "privileged feature" core may import — that
leaves the boundary a convention, and the completeness test could then only
assert a weaker rule.

### Decision 3 — localize everything now

The unified contract carries `String Function(AppLocalizations)` for every
user-visible string, so no surface can reintroduce a hardcoded one. ~36 new ARB
keys across `app_en.arb` + `app_zh.arb` (~11 dashboard descriptions, ~7 panel
create labels).

Context: launcher titles are localized today (`l.launcherDestGasLog`); dashboard
titles/descriptions and panel labels (`'New Note'`, `'New Gas Log'`) are
hardcoded English. Doing nothing would have *regressed* the launcher. The zh
side is unreviewed anyway — see [[i18n-chinese-unreviewed]].

### Decision 4 — approach C: manual manifest + completeness test

Dart has no runtime discovery and tree-shakes unreferenced code, so
self-registration by import side effect is unavailable. Something must import
every feature; the only question is where, and how you learn when it is wrong.

Chosen: a manual `lib/app/feature_manifest.dart` (above core, so core imports
nothing) **plus a test that enumerates `lib/features/*/` from disk** and asserts
each folder either contributes or sits on an explicit, commented exemption list
(`geocoding`, `receipt_scan` = services with no destination; `dashboard`,
`launcher` = surfaces, not destinations).

Rejected: `build_runner` codegen — safety is real but the machinery outweighs a
14-line list. C buys the same property with ~30 lines of test.

This is the point of the exercise: it turns *"absence is undetectable until the
catalogues share a key"* — the sentence in the registry doc justifying all of
this — into a green test.

---

## Design progress

**§1 — steps 1 & 2 (the two inversions): PRESENTED, awaiting user read.**

Target layout:

```
lib/core/data/
  contracts/                       ← NEW: pure, no Drift, no Riverpod
    i_{hmm_note,author,tag,note_catalog}_repository.dart
  models/
    hmm_note.dart                  ← from features/notes/data/models/
    hmm_note_mapper.dart           ← from features/notes/data/mappers/
  local/
    database.dart
    local_{hmm_note,author,tag,note_catalog}_repository.dart   ← impls only
  repository_providers.dart        ← the core four, nothing else
```

Eight files leave core, each to the feature owning its interface:

| To | Files |
|---|---|
| `gas_log/data/repositories/` | `local_gas_log_repository`, `local_automobile_repository`, `local_gas_station_repository` |
| `automobile_records/data/repositories/` | `local_insurance_repository`, `local_scheduled_service_repository`, `local_service_record_repository` |
| `cheatsheet/data/repositories/` | `local_cheatsheet_repository` |
| `driver_licence/data/` | `local_driver_licence_repository` |

**`contracts/` is an addition to the original step list.** The four core
interfaces (`IHmmNoteRepository`, `IAuthorRepository`, `ITagRepository`,
`INoteCatalogRepository`) are each declared *inside* their Drift implementation
file, so depending on the contract drags in Drift. That is the same pathology as
`source_scope.dart:21-25` hand-copying constants. Splitting them is what makes
the boundary enforceable rather than conventional.

Rule for the one ambiguous case: **follow the interface.** `IAutomobileRepository`
and `IGasStationRepository` live under `gas_log/` though `Automobile` is arguably
an `automobile_records` concern, so their local impls go to `gas_log/`.
Relocating interfaces is a separate refactor with a different blast radius —
noted as follow-up, deliberately not smuggled in.

Step 2: `_useLocal()` becomes public in `data_mode.dart`; each feature declares
its own mode provider beside its interface. Core's `repository_providers.dart`
drops from 12 providers / 10 feature imports to 4 / 0. Behaviour preserved
exactly, `UnimplementedError` throws included. Keeping the `…ModeProvider`
suffix — the clean name is taken by the API impl and freeing it means a rename
cascade. Optional cleanup, not part of step 2.

**§2 — the `FeatureContribution` contract: NOT YET WRITTEN.** The nuanced one.
The known problem: the quick panel is not "which feature is available" but regex
over the current route **with a capture group**
(`^(/gas-logs)(/.*)?$` → `$1/new`), so vehicle-scoped paths carry their concrete
id through (`/automobiles/manage/7/services` → `.../7/services/new`). A plain
`createsOn(path) → bool` as sketched in `feature-contribution-registry.md` throws
the capture away. The create *target* has to come from somewhere — this needs
designing, not copying.

Also to fold in: `_localOnlyDestinationIds = {'driverLicence'}` (launcher) and
`if (!(apiOnly && f.route == 'driverLicence'))` (dashboard) are the *same*
availability rule written twice in two shapes — the `available` predicate's first
customer. And `needsVehicle` / `usesVehiclePathId` are launcher-only today.

**§3 — testing + sequencing + risks: NOT YET WRITTEN.**

Three tests already identified:
1. Completeness — every `lib/features/*/` contributes or is exempted (decision 4)
2. Every contribution's `routeName` resolves to a real `RouterNames` value
   (`launcher_registry_test.dart` does this for the launcher already)
3. Every `available` contribution appears on **both** dashboard and launcher —
   the test that catches the original cheatsheet bug

---

## Resume here

**Next action:** get the user's read on §1 (above), then write §2 (the
`FeatureContribution` contract) and §3 (testing/sequencing), each with an
approval checkpoint.

**Then, per the brainstorming architectural path:** write the spec to
`docs/superpowers/specs/2026-09-08-feature-contribution-design.md`, commit it,
self-review it, get user review, and only then invoke `superpowers:writing-plans`.
**No implementation skill is invoked before that.**

**Standing constraint from the user (2026-09-08):** *"do not make any code
change… we're in the early stage of design."* Design only until they say
otherwise.

**Repo state:**
- Branch `feat/vehicle-documents`, **6 commits ahead of origin (unpushed)**
- Working tree: `ios/Podfile.lock` modified (predates this work), this doc untracked
- **No `lib/` or `test/` file has been touched by any of this**
- In-flight work takes precedence: the document scanner's on-device check is
  still open — see [[photo-id-capture-plan]]
