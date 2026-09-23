# Car Notes from the Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A note attached to a car filters and reads as an Automobile note (never General), the notes row names the car it belongs to, and a car's notes are one tap from the Automobile hub.

**Architecture:** No storage change. A car note stays a General-catalog note whose `parentNoteId` is the car's note id; the notes list stops deriving a note's domain from its catalog alone and derives it from what the note is attached to. Every typed record already carries its domain in its catalog name (`Hmm.AutomobileMan.AutomobileInfo` → `AutomobileMan`), so the same rule serves health, book and insurance notes later with no new code. The hub button and the vehicle-notes screen are UI over the existing `attachedNotesProvider`.

**Tech Stack:** Flutter, Riverpod 3 (`AsyncNotifier`, `FutureProvider.family`), GoRouter 17 (bare routers in widget tests), gen-l10n ARB files (`lib/l10n/app_en.arb`, `app_zh.arb` → committed `lib/l10n/gen/`).

**Spec:** `docs/superpowers/specs/2026-09-19-car-notes-from-hub-design.md`

## Global Constraints

- Every user-visible string goes through `AppLocalizations` with keys in **both** `app_en.arb` and `app_zh.arb`, then `flutter gen-l10n`; the generated files under `lib/l10n/gen/` are committed, so `git add lib/l10n` picks them up.
- No schema change, no migration, no re-cataloguing of existing notes. `MutateNote` and `attachedNotesProvider` are **not** modified by this plan.
- Widget tests use a bare `GoRouter` with placeholder routes, never the app router (it sits behind the auth redirect).
- `flutter analyze` must be clean except two known pre-existing `info` lints in files this plan does not touch (`lib/features/onboarding/presentation/screens/onboarding_screen.dart:222`, `lib/main.dart:98`). `flutter test` must be green before each commit.
- The `timeout` shell command does not exist on this Mac; use `flutter test --timeout 60s <path>`. The full suite takes ~2 minutes and currently reports **1590** passing.
- Leave the pre-existing uncommitted `ios/Podfile.lock` change and untracked `docs/plugin-architecture-spike-2026-09-07.md` alone; never stage them, and never stage `.superpowers/`.
- Commit messages end with `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`. A harness attribution reminder naming a different model does not apply to this repository.

---

## File map

| File | Responsibility |
|---|---|
| `lib/features/notes/states/notes_list_state.dart` | Modify: `targetsById` map, domain resolvers, filter predicate, search (Task 1) |
| `test/features/notes/notes_list_domain_test.dart` | New: the truth table + search (Task 1) |
| `lib/features/notes/presentation/widgets/note_list_tile.dart` | Modify: title parenthetical, context label and colour (Task 2) |
| `lib/features/notes/presentation/screens/notes_list_screen.dart` | Modify: pass the three context values (Task 2) |
| `test/features/notes/presentation/note_list_tile_test.dart` | New (Task 2) |
| `lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart` | Modify: notes button + badge on each vehicle row (Task 3) |
| `lib/features/automobile_records/presentation/screens/vehicle_notes_screen.dart` | Modify: car name, caption, New note button (Task 4) |
| `lib/features/notes/presentation/widgets/attached_notes_section.dart` | Modify: `showAdd` flag (Task 4) |
| `test/features/automobile_records/vehicle_notes_screen_test.dart` | New (Task 4) |
| `lib/l10n/app_en.arb`, `app_zh.arb`, `lib/l10n/gen/*` | Modify: 3 new keys (Tasks 3, 4) |
| `CLAUDE.md` | Modify: note the derived-domain rule (Task 5) |

---

### Task 1: A note lives where it is attached

**Files:**
- Modify: `lib/features/notes/states/notes_list_state.dart` — `NotesListData` fields/constructor (~:22-46), `visible` (~:57-100), `build()` (~:165-195)
- Test: `test/features/notes/notes_list_domain_test.dart`

**Interfaces:**
- Consumes: `HmmNote` (`id`, `subject`, `catalogId`, `parentNoteId`, `effectiveNoteDate`), `NoteCatalog` (`id`, `name`), `CatalogPalette.domainKeyFor(String?)`.
- Produces, on `NotesListData`: library-level `typedef AttachTarget = ({String domain, String subject});`; field `final Map<int, AttachTarget> targetsById` (constructor `this.targetsById = const {}`); methods `String? parentDomainOf(HmmNote)`, `String? ownDomainOf(HmmNote)`, `String? effectiveDomain(HmmNote)`, `String? contextSubjectOf(HmmNote)`. Task 2 renders from these.

- [ ] **Step 1: Write the failing test**

Create `test/features/notes/notes_list_domain_test.dart`:

```dart
// A note belongs to what it is attached to. A General note under a car is an
// automobile note — it filters under Automobile and NOT under General, the
// same way a note attached to a subsystem anchor already behaved. A record
// that already belongs to the domain it hangs under (a service record on a
// car) keeps filtering by its exact catalog, so picking one catalog in the
// filter sheet does not drag in its whole domain.

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

const _general = 1;
const _autoInfo = 2;
const _serviceRecord = 3;

NoteCatalog _cat(int id, String name) => NoteCatalog(
    id: id, name: name, schema: '{}', formatType: 0, isDefault: false);

HmmNote _note(int id, {int? catalogId, int? parentNoteId, String? subject}) =>
    HmmNote(
      id: id,
      uuid: 'u$id',
      subject: subject ?? 'note $id',
      authorId: 1,
      catalogId: catalogId,
      parentNoteId: parentNoteId,
      createDate: DateTime(2026, 1, id),
    );

/// The car (id 100), the notes hanging off it, and some controls.
NotesListData _data({Set<int>? filter, String query = ''}) {
  final all = [
    _note(100, catalogId: _autoInfo, subject: '2019 Honda Civic'),
    _note(1, catalogId: _general, parentNoteId: 100, subject: 'Winter tyres'),
    _note(2, catalogId: _general, subject: 'Buy milk'),
    _note(3, catalogId: _serviceRecord, parentNoteId: 100),
    _note(4, catalogId: _general, parentNoteId: 2),
    _note(5, catalogId: _general, parentNoteId: 999), // dangling parent
    _note(6, catalogId: _general, parentNoteId: 900), // anchor parent
  ];
  return NotesListData(
    all: all,
    catalogsById: {
      _general: _cat(_general, 'General'),
      _autoInfo: _cat(_autoInfo, 'Hmm.AutomobileMan.AutomobileInfo'),
      _serviceRecord: _cat(_serviceRecord, 'Hmm.AutomobileMan.ServiceRecord'),
    },
    catalogFilter: filter,
    query: query,
    catalogDomainById: const {
      _general: 'General',
      _autoInfo: 'AutomobileMan',
      _serviceRecord: 'AutomobileMan',
    },
    anchorDomainById: const {900: 'AutomobileMan'},
    targetsById: const {
      100: (domain: 'AutomobileMan', subject: '2019 Honda Civic'),
      2: (domain: 'General', subject: 'Buy milk'),
    },
  );
}

Set<int> ids(List<HmmNote> notes) => notes.map((n) => n.id).toSet();

void main() {
  group('effectiveDomain', () {
    final d = _data();
    HmmNote byId(int id) => d.all.firstWhere((n) => n.id == id);

    test('a General note under a car is an automobile note', () {
      expect(d.effectiveDomain(byId(1)), 'AutomobileMan');
      expect(d.contextSubjectOf(byId(1)), '2019 Honda Civic');
    });

    test('an unattached General note stays General', () {
      expect(d.effectiveDomain(byId(2)), 'General');
      expect(d.contextSubjectOf(byId(2)), isNull);
    });

    test('a note under an anchor takes its domain, with no subject', () {
      expect(d.effectiveDomain(byId(6)), 'AutomobileMan');
      expect(d.contextSubjectOf(byId(6)), isNull);
    });

    test('a dangling parent falls back to the catalog domain', () {
      expect(d.effectiveDomain(byId(5)), 'General');
    });

    test('a note under a General note stays General', () {
      expect(d.effectiveDomain(byId(4)), 'General');
    });
  });

  group('the Automobile domain filter', () {
    // The drawer selects every catalog in the domain.
    final automobile = _data(filter: const {_autoInfo, _serviceRecord});

    test('shows the car, its service record, its note, the anchor note', () {
      expect(ids(automobile.visible), {100, 3, 1, 6});
    });

    test('leaves unattached General notes out', () {
      expect(ids(automobile.visible), isNot(contains(2)));
    });
  });

  group('the General domain filter', () {
    final general = _data(filter: const {_general});

    test('a note attached to a car has moved out of General', () {
      expect(ids(general.visible), isNot(contains(1)));
    });

    test('unattached and General-parented notes stay', () {
      expect(ids(general.visible), containsAll(<int>{2, 4, 5}));
    });
  });

  test('picking one catalog does not drag in the whole domain', () {
    // Only "Service record" selected: the car itself must not appear.
    final only = _data(filter: const {_serviceRecord});
    expect(ids(only.visible), contains(3));
    expect(ids(only.visible), isNot(contains(100)));
  });

  test('search matches the parent subject as well as the subject', () {
    expect(ids(_data(query: 'honda').visible), contains(1));
    expect(ids(_data(query: 'tyres').visible), contains(1));
    expect(ids(_data(query: 'honda').visible), isNot(contains(2)));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test --timeout 60s test/features/notes/notes_list_domain_test.dart`
Expected: FAIL to compile — `NotesListData` has no `targetsById`, `effectiveDomain` or `contextSubjectOf`.

- [ ] **Step 3: Add the map and the resolvers**

In `notes_list_state.dart`, above `class NotesListData`:

```dart
/// What a note needs to know about the note it is attached to: the domain
/// that note belongs to, and what to call it on screen.
typedef AttachTarget = ({String domain, String subject});
```

Add the constructor parameter `this.targetsById = const {},` to `NotesListData`, and the field beside `anchorDomainById`:

```dart
  /// Note id -> the domain and subject of a note others can attach to (a
  /// car, a policy, a book). Every typed record carries its domain in its
  /// own catalog name, so this needs no per-domain knowledge.
  final Map<int, AttachTarget> targetsById;
```

Add the matching `copyWith` parameter `Map<int, AttachTarget>? targetsById,` and line `targetsById: targetsById ?? this.targetsById,`, following the existing fields.

Then the resolvers, immediately above `List<HmmNote> get visible`:

```dart
  /// The domain of the thing this note is attached to, when that thing
  /// carries one: a subsystem anchor, or any typed record such as a car.
  String? parentDomainOf(HmmNote n) {
    final p = n.parentNoteId;
    if (p == null) return null;
    return anchorDomainById[p] ?? targetsById[p]?.domain;
  }

  String? ownDomainOf(HmmNote n) =>
      n.catalogId == null ? null : catalogDomainById[n.catalogId];

  /// Where the note lives: what it is attached to, falling back to its own
  /// catalog. A dangling parent resolves to neither, so the note keeps its
  /// catalog's domain rather than vanishing from every filter.
  String? effectiveDomain(HmmNote n) => parentDomainOf(n) ?? ownDomainOf(n);

  /// The parent's subject, for the row and for search. Null when unattached,
  /// and for an anchor parent (anchors are not in the loaded set).
  String? contextSubjectOf(HmmNote n) {
    final p = n.parentNoteId;
    return p == null ? null : targetsById[p]?.subject;
  }
```

- [ ] **Step 4: Widen the filter predicate and the search**

In `visible`, replace the whole `items = items.where((n) { ... });` block (the one computing `attachedDomain`) with:

```dart
      items = items.where((n) {
        final own = ownDomainOf(n);
        final parent = parentDomainOf(n);
        // Attached to something in ANOTHER domain — a General note under a
        // car. It lives there and nowhere else, so General keeps meaning
        // "attached to nothing in particular". This is what the code already
        // did for notes attached to a subsystem anchor; cars now count too.
        if (parent != null && parent != own) {
          return selectedDomains.contains(parent);
        }
        // Otherwise the note is a record of its own domain, so it filters by
        // its exact catalog: picking "Insurance" must not drag in every note
        // that happens to hang off a car.
        return n.catalogId != null && f.contains(n.catalogId);
      });
```

Reword the comment above `selectedDomains` from "attached to a subsystem anchor whose domain is among them" to "attached to something whose domain is among them".

Then the search, replacing `items = items.where((n) => n.subject.toLowerCase().contains(q));`:

```dart
      items = items.where((n) =>
          n.subject.toLowerCase().contains(q) ||
          (contextSubjectOf(n)?.toLowerCase().contains(q) ?? false));
```

- [ ] **Step 5: Build the map in `build()`**

In `NotesListState.build()`, after the `anchorDomainById` loop and before `return NotesListData(`:

```dart
    // Anything with a domain of its own can be attached to, so a note under
    // it borrows that domain. Built from the notes already loaded: no query.
    final targetsById = {
      for (final n in visibleNotes)
        if (n.catalogId != null && catalogDomainById[n.catalogId] != null)
          n.id: (
            domain: catalogDomainById[n.catalogId]!,
            subject: n.subject,
          ),
    };
```

and pass `targetsById: targetsById,` in the `NotesListData(...)` call.

- [ ] **Step 6: Run the test and the whole notes suite**

Run: `flutter test --timeout 60s test/features/notes`
Expected: all PASS, including the new file. If an existing notes test fails, read it before touching it — a note that used to appear under General and now does not is the intended change, so that expectation moves; anything else is a real regression: stop and report.

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/features/notes test/features/notes`
Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add lib/features/notes/states/notes_list_state.dart test/features/notes/notes_list_domain_test.dart
git commit -m "feat(notes): a note belongs to whatever it is attached to

A General note under a car is an automobile note: the list derives a
note's domain from its parent, not from its catalog alone, so car notes
filter under Automobile and General keeps meaning 'attached to nothing'.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: The row names what the note is about

**Files:**
- Modify: `lib/features/notes/presentation/widgets/note_list_tile.dart:15-41`
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart:158-166`
- Test: `test/features/notes/presentation/note_list_tile_test.dart`

**Interfaces:**
- Consumes: `NotesListData.effectiveDomain / parentDomainOf / contextSubjectOf` (Task 1), `catalogLabel` and `domainLabel` (`lib/features/notes/presentation/catalog_labels.dart`), `CatalogPalette.domainStyle(String)`.
- Produces: `NoteListTile` gains `final String? titleContext`, `final String? contextLabel`, `final Color? contextColor` — all optional; all null for an unattached note, which then renders exactly as before.

- [ ] **Step 1: Write the failing test**

Create `test/features/notes/presentation/note_list_tile_test.dart`:

```dart
// The subject line is what people scan and what travels to search results,
// so an attached note names its parent there. The parenthetical must never
// be the part that gets ellipsized — a long subject truncates instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

const _general = NoteCatalog(
    id: 1, name: 'General', schema: '{}', formatType: 0, isDefault: false);

HmmNote _note(String subject) => HmmNote(
      id: 1,
      uuid: 'u1',
      subject: subject,
      authorId: 1,
      catalogId: 1,
      createDate: DateTime(2026, 9, 12),
    );

Future<void> _pump(WidgetTester tester, Widget tile) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ListView(children: [tile])),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an attached note names its parent in the title',
      (tester) async {
    await _pump(
      tester,
      NoteListTile(
        note: _note('Oil change receipt'),
        catalog: _general,
        titleContext: '2019 Honda Civic',
        contextLabel: 'Automobile',
        contextColor: Colors.blue,
      ),
    );

    expect(find.text('Oil change receipt'), findsOneWidget);
    expect(find.text(' (2019 Honda Civic)'), findsOneWidget);
    // The secondary line names the domain it now filters under, not the
    // catalog it is stored in.
    expect(find.textContaining('Automobile · '), findsOneWidget);
    expect(find.textContaining('General · '), findsNothing);
  });

  testWidgets('a long subject ellipsizes, the parent stays whole',
      (tester) async {
    await _pump(
      tester,
      NoteListTile(
        note: _note('Replaced the cabin air filter and both wiper blades '
            'plus the pollen filter behind the glovebox'),
        catalog: _general,
        titleContext: '2019 Honda Civic',
        contextLabel: 'Automobile',
        contextColor: Colors.blue,
      ),
    );

    expect(find.text(' (2019 Honda Civic)'), findsOneWidget);
    final subject = tester.widget<Text>(find.textContaining('Replaced the'));
    expect(subject.overflow, TextOverflow.ellipsis);
  });

  testWidgets('an unattached note renders as before', (tester) async {
    await _pump(
      tester,
      NoteListTile(note: _note('Buy milk'), catalog: _general),
    );

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.textContaining(' ('), findsNothing);
    expect(find.textContaining('General · '), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test --timeout 60s test/features/notes/presentation/note_list_tile_test.dart`
Expected: FAIL to compile — `NoteListTile` has no `titleContext`.

- [ ] **Step 3: Add the three parameters**

In `note_list_tile.dart`, extend the constructor and fields:

```dart
  const NoteListTile({
    super.key,
    required this.note,
    this.catalog,
    this.titleContext,
    this.contextLabel,
    this.contextColor,
    this.onTap,
  });

  final HmmNote note;
  final NoteCatalog? catalog;

  /// What the note hangs off — a car, a policy — shown after the subject.
  /// Composed here and never stored: writing it into the subject would
  /// duplicate on the next render and reach sync and the editor.
  final String? titleContext;

  /// Replaces the catalog label on the secondary line with the domain the
  /// note actually filters under.
  final String? contextLabel;

  /// Replaces the catalog dot's colour with that domain's colour.
  final Color? contextColor;

  final VoidCallback? onTap;
```

In `build`, the dot's `color:` becomes `contextColor ?? style.color`, the secondary becomes

```dart
      secondary:
          Text('${contextLabel ?? catalogLabel(catalog?.name, l)} · $date'),
```

and the title becomes a row, so the subject gives up characters before the context does:

```dart
      title: titleContext == null
          ? Text(note.subject)
          : Row(
              children: [
                Flexible(
                  child: Text(note.subject, overflow: TextOverflow.ellipsis),
                ),
                Text(
                  ' ($titleContext)',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
```

- [ ] **Step 4: Run the test**

Run: `flutter test --timeout 60s test/features/notes/presentation/note_list_tile_test.dart`
Expected: PASS.

- [ ] **Step 5: Feed the values from the list**

In `notes_list_screen.dart`, in the builder that creates `NoteListTile` (~line 158), compute the three values above the `return NoteListTile(`:

```dart
                  final domain = data.effectiveDomain(note);
                  final attached = data.parentDomainOf(note) != null;
                  final parentSubject = data.contextSubjectOf(note);
                  // The parent's own words, capped so a long record name
                  // cannot swallow the row; an anchor has no subject, so it
                  // falls back to the domain's name.
                  final titleContext = parentSubject != null
                      ? (parentSubject.length > 20
                          ? '${parentSubject.substring(0, 20)}…'
                          : parentSubject)
                      : (attached && domain != null
                          ? domainLabel(domain, l)
                          : null);
```

and pass them:

```dart
                    titleContext: titleContext,
                    contextLabel: attached && domain != null
                        ? domainLabel(domain, l)
                        : null,
                    contextColor: attached && domain != null
                        ? CatalogPalette.domainStyle(domain).color
                        : null,
```

`l` is the `AppLocalizations` already used in this screen; if it is not in scope inside that builder, read it there with `final l = AppLocalizations.of(context);`. Add any missing imports (`../catalog_labels.dart` for `domainLabel`, `../../../../core/notes/catalog_palette.dart`).

- [ ] **Step 6: Analyze and run the notes tests**

Run: `flutter analyze lib/features/notes test/features/notes && flutter test --timeout 60s test/features/notes`
Expected: No issues; all PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/notes/presentation/widgets/note_list_tile.dart lib/features/notes/presentation/screens/notes_list_screen.dart test/features/notes/presentation/note_list_tile_test.dart
git commit -m "feat(notes): name the car a note belongs to in its row

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Notes button on every hub row

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart:141-166` (`_VehicleRow`)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (+ regenerate)
- Test: `test/features/automobile_records/automobile_hub_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `attachedNotesProvider` (`FutureProvider.family<List<HmmNote>, int>`, `lib/features/notes/states/attached_notes_state.dart`), the existing route `/automobiles/manage/:id/notes`.
- Produces: each vehicle row's `trailing` is a `Row` of notes button + fuel button, then the chevron the row now supplies itself.

- [ ] **Step 1: Add the l10n key**

In `lib/l10n/app_en.arb`, directly after the `"@automobileHubGasLogFor"` block (it closes with `},` around line 634):

```json
  "automobileHubNotesFor": "Notes for {name}",
  "@automobileHubNotesFor": {
    "placeholders": {"name": {"type": "String"}}
  },
```

In `lib/l10n/app_zh.arb`, directly after its `"automobileHubGasLogFor"` line:

```json
  "automobileHubNotesFor": "{name}的备注",
```

Run: `flutter gen-l10n`
Expected: `automobileHubNotesFor(String name)` exists in `lib/l10n/gen/app_localizations.dart`.

- [ ] **Step 2: Give `_pump` an attached-notes override**

In `test/features/automobile_records/automobile_hub_screen_test.dart`, add a parameter to the existing `_pump` helper so no test reaches the real note repository, defaulting to "no notes". Pass the notes themselves rather than an override list — two overrides of the same provider in one container is an error, not a last-one-wins:

```dart
  List<HmmNote> notes = const [],
```

In its `ProviderContainer(overrides: [...])`, append after the existing entries:

```dart
    attachedNotesProvider(1).overrideWith((ref) async => notes),
```

and in the router built there, add a notes route beside the existing `':id/edit'`:

```dart
                GoRoute(
                    path: ':id/notes',
                    builder: (_, s) =>
                        stub('notes ${s.pathParameters['id']}')),
```

Imports: `package:hmm_console/features/notes/data/models/hmm_note.dart`,
`package:hmm_console/features/notes/states/attached_notes_state.dart`.

- [ ] **Step 3: Write the failing tests**

Inside the existing `group('vehicles', ...)`:

```dart
    testWidgets("the notes button opens that car's notes", (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip('Notes for 2020 Honda Civic'));
      await tester.pumpAndSettle();
      expect(find.text('notes 1'), findsOneWidget);
    });

    testWidgets('the notes button badges how many notes the car has',
        (tester) async {
      await _pump(tester, notes: [
        HmmNote(
            id: 7,
            uuid: 'n7',
            subject: 'Winter tyres',
            authorId: 1,
            createDate: DateTime(2026, 1, 1)),
        HmmNote(
            id: 8,
            uuid: 'n8',
            subject: 'Rattle',
            authorId: 1,
            createDate: DateTime(2026, 1, 2)),
      ]);

      expect(find.widgetWithText(Badge, '2'), findsOneWidget);
    });

    testWidgets('no badge when the car has no notes', (tester) async {
      await _pump(tester);
      expect(find.byType(Badge), findsNothing);
    });
```

- [ ] **Step 4: Run and watch them fail**

Run: `flutter test --timeout 60s test/features/automobile_records/automobile_hub_screen_test.dart`
Expected: the three new tests FAIL (no "Notes for …" tooltip, no `Badge`); the existing ones still pass.

- [ ] **Step 5: Add the button**

In `_VehicleRow.build`, replace the single `trailing: IconButton.filledTonal(...)` with:

```dart
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NotesButton(automobile: automobile),
          IconButton.filledTonal(
            tooltip: l.automobileHubGasLogFor(automobile.displayName),
            icon: const Icon(Icons.local_gas_station_outlined),
            onPressed: () {
              // The gas-log list reads the SELECTED vehicle, so select first.
              ref
                  .read(selectedAutomobileIdProvider.notifier)
                  .select(automobile.id);
              context.push('/gas-logs');
            },
          ),
          Icon(Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
```

and add, after `_VehicleRow`:

```dart
/// The car's notes, one tap from the hub. The badge is the count, so a car
/// with nothing written about it carries no decoration at all.
class _NotesButton extends ConsumerWidget {
  const _NotesButton({required this.automobile});
  final Automobile automobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final count =
        ref.watch(attachedNotesProvider(automobile.id)).value?.length;
    const icon = Icon(Icons.sticky_note_2_outlined);
    return IconButton.filledTonal(
      tooltip: l.automobileHubNotesFor(automobile.displayName),
      icon: count == null || count == 0
          ? icon
          : Badge(label: Text('$count'), child: icon),
      onPressed: () =>
          context.push('/automobiles/manage/${automobile.id}/notes'),
    );
  }
}
```

Import `../../../notes/states/attached_notes_state.dart`.

- [ ] **Step 6: Run the hub tests**

Run: `flutter test --timeout 60s test/features/automobile_records/automobile_hub_screen_test.dart`
Expected: all PASS. If the failure output says "A RenderFlex overflowed", the three controls do not fit the test viewport: drop the chevron's `Icon` to `size: 20` and re-run before changing the layout further.

- [ ] **Step 7: Analyze and commit**

```bash
flutter analyze lib/features/automobile_records lib/l10n test/features/automobile_records
git add lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart lib/l10n test/features/automobile_records/automobile_hub_screen_test.dart
git commit -m "feat(automobile): a notes button on every hub row

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Vehicle notes screen leads with New note

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/vehicle_notes_screen.dart` (whole file, 24 lines)
- Modify: `lib/features/notes/presentation/widgets/attached_notes_section.dart:16-52`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (+ regenerate)
- Test: `test/features/automobile_records/vehicle_notes_screen_test.dart`

**Interfaces:**
- Consumes: `automobilesStateProvider`, `attachedNotesProvider`, `AttachedNotesSection`, `CatalogPalette.domainStyle('AutomobileMan')`.
- Produces: `AttachedNotesSection` gains `final bool showAdd` (default `true`).

- [ ] **Step 1: Add the l10n keys**

In `lib/l10n/app_en.arb`, after the `"recordsVehicleNotes"` entry (~line 1037):

```json
  "vehicleNotesNew": "New note",
  "vehicleNotesDomainCaption": "Automobile · {name}",
  "@vehicleNotesDomainCaption": {
    "placeholders": {"name": {"type": "String"}}
  },
```

In `lib/l10n/app_zh.arb`, after its `"recordsVehicleNotes"` entry (~line 490):

```json
  "vehicleNotesNew": "新建笔记",
  "vehicleNotesDomainCaption": "汽车 · {name}",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/features/automobile_records/vehicle_notes_screen_test.dart`:

```dart
// The screen the hub's notes button opens: it names the car, says where a
// new note will land, and leads with the one action that matters.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/vehicle_notes_screen.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _StubAutomobiles extends AutomobilesState {
  @override
  Future<List<Automobile>> build() async => [
        Automobile(
            id: 1,
            year: 2020,
            maker: 'Honda',
            model: 'Civic',
            meterReading: 100,
            isActive: true),
      ];
}

Future<void> _pump(WidgetTester tester) async {
  final router = GoRouter(initialLocation: '/v', routes: [
    GoRoute(
        path: '/v',
        builder: (_, _) => const VehicleNotesScreen(automobileId: 1)),
    GoRoute(
        path: '/notes/new',
        builder: (_, s) => Scaffold(
            body: Text('editor parent=${s.uri.queryParameters['parent']}'))),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      automobilesStateProvider.overrideWith(_StubAutomobiles.new),
      attachedNotesProvider(1).overrideWith((ref) async => <HmmNote>[]),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names the car and where a new note lands', (tester) async {
    await _pump(tester);
    expect(find.text('2020 Honda Civic'), findsOneWidget);
    expect(find.text('Automobile · 2020 Honda Civic'), findsOneWidget);
  });

  testWidgets('New note opens the editor attached to this car',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'New note'));
    await tester.pumpAndSettle();
    expect(find.text('editor parent=1'), findsOneWidget);
  });

  testWidgets('the section does not offer a second add button',
      (tester) async {
    await _pump(tester);
    // One add control on the screen: the New note button. The section's own
    // "+" is suppressed, so exactly one add icon is present.
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
```

`Automobile.displayName` renders `"2020 Honda Civic"` for these fields — confirm by reading the getter at `lib/features/gas_log/domain/entities/automobile.dart:198` and adjust the test's expected strings (only the test's) if it differs.

- [ ] **Step 3: Run and watch it fail**

Run: `flutter test --timeout 60s test/features/automobile_records/vehicle_notes_screen_test.dart`
Expected: FAIL — the screen shows the static "Vehicle Notes" title and has no New note button.

- [ ] **Step 4: Add the `showAdd` flag**

In `attached_notes_section.dart`, add to the constructor and fields:

```dart
    this.showAdd = true,
```
```dart
  /// The owning screen may offer its own add action, in which case the
  /// section must not duplicate it.
  final bool showAdd;
```

and guard the add `IconButton` in the header row with `if (showAdd)`, leaving the attach (📎) button untouched.

- [ ] **Step 5: Rewrite the screen**

`vehicle_notes_screen.dart` becomes:

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notes/catalog_palette.dart';
import '../../../gas_log/states/automobiles_state.dart';
import '../../../notes/presentation/widgets/attached_notes_section.dart';
import '../../../notes/states/attached_notes_state.dart';

class VehicleNotesScreen extends ConsumerWidget {
  const VehicleNotesScreen({super.key, required this.automobileId});

  /// The automobile's id IS its note id (automobiles are stored as notes),
  /// which is why a note attached to it reads as an automobile note.
  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final name = ref
        .watch(automobilesStateProvider)
        .value
        ?.where((a) => a.id == automobileId)
        .firstOrNull
        ?.displayName;

    return Scaffold(
      appBar: AppBar(title: Text(name ?? l.recordsVehicleNotes)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (name != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  l.vehicleNotesDomainCaption(name),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            CatalogPalette.domainStyle('AutomobileMan').color,
                      ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: FilledButton.icon(
                onPressed: () async {
                  await context.push('/notes/new?parent=$automobileId');
                  ref.invalidate(attachedNotesProvider(automobileId));
                },
                icon: const Icon(Icons.add),
                label: Text(l.vehicleNotesNew),
              ),
            ),
            AttachedNotesSection(
              parentId: automobileId,
              title: l.recordsNotes,
              showAdd: false,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test --timeout 60s test/features/automobile_records test/features/notes`
Expected: all PASS.

- [ ] **Step 7: Analyze and commit**

```bash
flutter analyze lib/features/automobile_records lib/features/notes lib/l10n
git add lib/features/automobile_records/presentation/screens/vehicle_notes_screen.dart lib/features/notes/presentation/widgets/attached_notes_section.dart lib/l10n test/features/automobile_records/vehicle_notes_screen_test.dart
git commit -m "feat(automobile): the vehicle notes screen leads with New note

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Whole-suite verification and docs

**Files:**
- Modify: `CLAUDE.md` (the `notes/` feature-table row)

- [ ] **Step 1: Full analyze and test**

Run: `flutter analyze && flutter test`
Expected: only the two known pre-existing `info` lints; all tests pass (1590 before this plan, plus roughly 14 new).

If a test outside `notes/` and `automobile_records/` fails, it is most likely asserting the old "a car note lists under General" behaviour — read it, confirm that is what it asserts, and update that expectation in this task's commit. Anything else: stop and report.

- [ ] **Step 2: Note the rule in CLAUDE.md**

In the feature table, append to the `notes/` row's purpose cell:

```
A note's **domain is derived from what it is attached to** (`notes_list_state.dart`): a General note whose `parentNoteId` is a car lists under Automobile rather than General, and its row names the car. No per-domain note catalog exists or is needed.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record how a note's domain is derived

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: Report**

Report the branch state and the test count. Do not deploy and do not merge — both are the user's to ask for.
