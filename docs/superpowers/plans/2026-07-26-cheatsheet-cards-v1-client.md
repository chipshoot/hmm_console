# Cheatsheet Cards — v1 (Client) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the **client-side** Cheatsheet feature (hmm_console): create read-only "wallet" cards whose rows reference a *piece of any note* (field / section / whole) and render live, stored as note-content.

**Architecture:** A `CheatsheetCard` domain entity is serialized into an `HmmNote`'s `content` (envelope `{"note":{"content":{"Cheatsheet":{...}}}}`) under a fixed `Hmm.Cheatsheet` catalog — mirroring `LocalGasLogRepository`. A `CheatsheetResolver` reads each row's referenced note by `uuid` and extracts the piece (field via JSON-path introspection, section via markdown heading, whole via content). Riverpod `AsyncNotifier`s drive a template-first designer, a wallet screen, and a read-only detail with tap-to-call/Maps.

**Tech Stack:** Dart/Flutter, Riverpod 3.0.3, Drift (in-memory for tests), GoRouter, `url_launcher`.

**Spec:** `docs/superpowers/specs/2026-07-23-cheatsheet-cards-design.md`. **Backend `/v1/cheatsheets` + cloudApi repo are a SEPARATE follow-up plan** — this plan is the local-first client (works in `DataMode.local`/`cloudStorage`).

**Revision:** 2026-07-26 (rev 3).

- **rev 2** folded the 2026-07-26 plan-defect review (`Obsidian: HomeMadeMessage/Design Defect/2026-07-26 Cheatsheet Cards v1 plan defects`) **into the task bodies below** — there is no separate amendment appendix. See *Defect-review provenance* at the end for the defect → task map.
- **rev 3** reconciles T1–T10 with what execution actually built. Four snippets in rev 2 were wrong or would not have compiled cleanly; they are corrected **in place** (same no-appendix rule), each with the reason inline: T1 list equality, T2 `as List?` casts, T8 error-path assertion, T10 file layering + launch-failure behaviour. T11–T16 are still as-designed and unexecuted.

## Global Constraints

- **Riverpod 3.0.3:** read async provider values with `.value ?? <default>` — **never** `.valueOrNull`. `WidgetRef` is `sealed` — never faked in tests; override the real Notifier via a fixed subclass + `overrideWith(() => Sub())`, or `overrideWithValue(x)` for plain `Provider<T>`.
- **Storage envelope:** every cheatsheet note's `content` is `jsonEncode({'note': {'content': {'Cheatsheet': <cardJson>}}})` — mirrors `LocalGasLogRepository._serializeGasLog`. Deserialize with `jsonDecode` in a try/catch that returns `null` on any failure.
- **Fixed catalog:** `const cheatsheetCatalogName = 'Hmm.CheatsheetMan.Cheatsheet';` obtained via `catalogRepo.getOrCreateCatalog(cheatsheetCatalogName, '{}')`. (3-segment name so `CatalogPalette.domainKeyFor` groups it as its own "Cheatsheet" domain.)
- **Stable note subject:** a cheatsheet note's subject is **`'Cheatsheet:${card.id}'`** — never title-derived. Titles are mutable and non-unique; the subject is an identity, not a label. The title lives only inside the card JSON.
- **Stable card identity:** `CheatsheetCard.id` is a **v4 UUID from `generateUuid()`** (`lib/core/util/uuid.dart`), generated once at create time and **never regenerated on edit**. Production callers never supply an id; tests inject a fixed `String Function() idGen`.
- **No catalog field-schema exists** in the client (the `schema` column is never parsed). `field`-granularity binding is done by **introspecting the referenced note's content JSON** into leaf paths — NOT by reading a schema. `locator` for a field is a **dotted JSON path into the inner content map** (e.g. `GasLog.station`).
- **Introspection is filtered, not raw:** `fieldPaths` never offers internal/audit keys (`id`, `uuid`, `_v`, `*Id`, `*Date`, `*At`, …). A catalog-keyed `CheatsheetBindingAdapter` registry is the v2 robustness path — out of scope here (see T4 notes).
- **Tags + wallet group live in the card JSON** (the `HmmNote` model has no `tags` field). Never use the note-tag system for these.
- **Stable references:** a row references its source note by **`HmmNote.uuid`** (cross-device stable), never the local int `id`. This is load-bearing and has a **mandatory** dedicated test (T6).
- **No silent caps:** every list read pages until exhausted. A fixed `pageSize:` ceiling that drops rows is a defect, not an optimization.
- **Never crash on bad references:** unbound row, missing note, missing field/section, malformed JSON → a muted placeholder, never an exception. One malformed row must never discard a whole card.
- **Deferred to a later phase (do NOT build in v1):** `quickAccess` (the Quick Access Panel is an action-button registry, not a card surface) and `sortOrder`/user reordering. Neither field exists on the entity, the codec, the editor, or the designer in v1. `protected` stays as a Phase-2-reserved flag.
- **Value actions are explicit** — `call` / `map` / `none`, chosen in the designer. No inference in v1 (the spec's testing section is already reconciled to match).
- `flutter analyze` clean after every task. Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## Verified API surface (checked against the tree 2026-07-26)

Use these exact signatures; do not guess.

```dart
// lib/core/data/local/local_hmm_note_repository.dart
abstract interface class IHmmNoteRepository {
  Future<PageList<HmmNote>> getNotes({int? catalogId, int? parentNoteId,
      int page = 1, int pageSize = 20, bool includeDeleted = false});
  Future<HmmNote?> getNoteById(int id);
  Future<HmmNote?> getNoteByUuid(String uuid);
  Future<HmmNote> createNote(HmmNoteCreate input);
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch);
  Future<void> deleteNote(int id);
  Stream<List<HmmNote>> watchNotes();
  // + setParentNote, getUnattachedNotes
}
// lib/core/network/pagination.dart
typedef PageList<T> = PaginatedResponse<T>;   // .items : List<T>, .meta : PaginationMeta
// PaginationMeta: totalCount, pageSize, currentPage, totalPages
// lib/core/data/hmm_note_input.dart
HmmNoteCreate({required subject, required catalogId, content, parentNoteId, description,
               attachments, uuid, noteDate, location})
HmmNoteUpdate({subject, content, description, attachments, noteDate, location})
// lib/core/data/local/local_note_catalog_repository.dart
INoteCatalogRepository.getOrCreateCatalog(String name, String schema) -> Future<NoteCatalog>
// lib/core/util/uuid.dart
String generateUuid();
// lib/features/notes/data/models/hmm_note.dart
HmmNote { int id; String uuid; String subject; String? content; String? description; int? catalogId; ... }
```

## File Structure

- `lib/features/cheatsheet/domain/entities/cheatsheet_source.dart` — `SourceGranularity`, `ValueAction`, `CheatsheetSource` (T1)
- `lib/features/cheatsheet/domain/entities/cheatsheet_row.dart` — `CheatsheetRow` (T1)
- `lib/features/cheatsheet/domain/entities/cheatsheet_card.dart` — `CheatsheetCard` (T1)
- `lib/features/cheatsheet/data/cheatsheet_codec.dart` — card <-> JSON map, schema-versioned (T2)
- `lib/features/cheatsheet/data/i_cheatsheet_repository.dart` — repo interface (T3)
- `lib/core/data/local/local_cheatsheet_repository.dart` — CRUD over notes (T3)
- `lib/features/cheatsheet/domain/note_piece_extractor.dart` — filtered field-paths + field/section/whole extraction (T4)
- `lib/features/cheatsheet/data/cheatsheet_resolver.dart` — resolve a row -> value (T5)
- `lib/features/cheatsheet/data/cheatsheet_templates.dart` — starter templates (T7)
- `lib/core/data/repository_providers.dart` — add `cheatsheetRepositoryModeProvider` (T3)
- `lib/features/cheatsheet/states/cheatsheets_state.dart` — list `AsyncNotifier` (T8)
- `lib/features/cheatsheet/states/cheatsheet_editor_state.dart` — designer state + `cheatsheetIdGenProvider` (T9)
- `lib/core/util/launch_actions.dart` — pure `telUri`/`mapsUri` builders, no feature imports (T10)
- `lib/features/cheatsheet/data/cheatsheet_launcher.dart` — `ValueAction` dispatch, `LaunchActionException`, `launchActionProvider` (T10)
- `lib/features/cheatsheet/presentation/widgets/source_picker.dart` (T11)
- `lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart` (T12)
- `lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart` (T13)
- `lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart` (T14)
- `lib/core/navigation/{route_names,router_config}.dart` + dashboard `_allFunctions` (T15)
- Tests mirror each under `test/`; T6 (cross-device) and T16 (acceptance) are test-only tasks.

---

### Task 1: Domain entities

**Files:**
- Create: `lib/features/cheatsheet/domain/entities/cheatsheet_source.dart`, `.../cheatsheet_row.dart`, `.../cheatsheet_card.dart`
- Test: `test/features/cheatsheet/domain/cheatsheet_card_test.dart`

**Interfaces — Produces:**
- `enum SourceGranularity { field, section, whole }`, `enum ValueAction { call, map, none }`
- `class CheatsheetSource { final String noteUuid; final SourceGranularity kind; final String? locator; }` — value equality + `copyWith`.
- `class CheatsheetRow { final String label; final CheatsheetSource? source; final ValueAction valueAction; final bool openSource; }` — value equality + `copyWith` (with a `clearSource` flag so a bound row can be unbound).
- `class CheatsheetCard { final String id, title, walletGroup; final List<String> tags; final String templateId; final bool protected; final List<CheatsheetRow> rows; }` — value equality + `copyWith`.

> **No `quickAccess`, no `sortOrder`** — both are deferred out of v1 (see Global Constraints). `protected` is reserved for Phase 2 and is not surfaced in any v1 UI.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  test('card value-equality + copyWith', () {
    const s = CheatsheetSource(
        noteUuid: 'n1', kind: SourceGranularity.field, locator: 'GasLog.station');
    const r = CheatsheetRow(
        label: 'Station', source: s, valueAction: ValueAction.none, openSource: true);
    const c = CheatsheetCard(
        id: 'c1', title: 'Fuel', walletGroup: 'Vehicle', tags: ['a'],
        templateId: 'blank', rows: [r]);
    expect(c, equals(c.copyWith()));
    expect(c.copyWith(title: 'X').title, 'X');
    expect(c.copyWith(title: 'X'), isNot(equals(c)));
    expect(c.copyWith(title: 'X').id, 'c1'); // identity survives edits
    expect(r.copyWith(clearSource: true).source, isNull); // unbound is representable
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/features/cheatsheet/domain/cheatsheet_card_test.dart` -> FAIL (types missing).

- [ ] **Step 3: Implement.** `cheatsheet_source.dart`:

```dart
enum SourceGranularity { field, section, whole }

enum ValueAction { call, map, none }

class CheatsheetSource {
  const CheatsheetSource({required this.noteUuid, required this.kind, this.locator});
  final String noteUuid;
  final SourceGranularity kind;
  final String? locator; // field -> JSON path; section -> heading; whole -> null

  CheatsheetSource copyWith({String? noteUuid, SourceGranularity? kind, String? locator}) =>
      CheatsheetSource(
          noteUuid: noteUuid ?? this.noteUuid,
          kind: kind ?? this.kind,
          locator: locator ?? this.locator);

  @override
  bool operator ==(Object o) =>
      o is CheatsheetSource && o.noteUuid == noteUuid && o.kind == kind && o.locator == locator;
  @override
  int get hashCode => Object.hash(noteUuid, kind, locator);
}
```

`cheatsheet_row.dart`:

```dart
import 'cheatsheet_source.dart';

class CheatsheetRow {
  const CheatsheetRow({
    required this.label,
    required this.source,
    this.valueAction = ValueAction.none,
    this.openSource = true,
  });
  final String label;
  final CheatsheetSource? source; // null = unbound
  final ValueAction valueAction;
  final bool openSource;

  bool get isBound => source != null;

  CheatsheetRow copyWith(
          {String? label,
          CheatsheetSource? source,
          bool clearSource = false,
          ValueAction? valueAction,
          bool? openSource}) =>
      CheatsheetRow(
          label: label ?? this.label,
          source: clearSource ? null : (source ?? this.source),
          valueAction: valueAction ?? this.valueAction,
          openSource: openSource ?? this.openSource);

  @override
  bool operator ==(Object o) =>
      o is CheatsheetRow &&
      o.label == label &&
      o.source == source &&
      o.valueAction == valueAction &&
      o.openSource == openSource;
  @override
  int get hashCode => Object.hash(label, source, valueAction, openSource);
}
```

`cheatsheet_card.dart`:

```dart
import 'cheatsheet_row.dart';

class CheatsheetCard {
  const CheatsheetCard({
    required this.id,
    required this.title,
    required this.walletGroup,
    required this.tags,
    required this.templateId,
    required this.rows,
    this.protected = false,
  });

  /// Stable v4 UUID minted once at create time — never regenerated on edit.
  final String id;
  final String title;
  final String walletGroup;
  final List<String> tags;
  final String templateId;

  /// Phase-2 reserved (biometric/PIN gating). Not surfaced in any v1 UI.
  final bool protected;
  final List<CheatsheetRow> rows;

  CheatsheetCard copyWith({
    String? id, String? title, String? walletGroup, List<String>? tags,
    String? templateId, bool? protected, List<CheatsheetRow>? rows,
  }) =>
      CheatsheetCard(
          id: id ?? this.id, title: title ?? this.title,
          walletGroup: walletGroup ?? this.walletGroup, tags: tags ?? this.tags,
          templateId: templateId ?? this.templateId, protected: protected ?? this.protected,
          rows: rows ?? this.rows);

  // Hand-rolled rather than package:collection's ListEquality — `collection`
  // is not a direct dependency and nothing in lib/ imports it. This matches
  // the house idiom (see NoteAttachments in core/data/attachments).
  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheatsheetCard && other.id == id && other.title == title &&
        other.walletGroup == walletGroup && other.templateId == templateId &&
        other.protected == protected &&
        _sameList(other.tags, tags) && _sameList(other.rows, rows);
  }

  @override
  int get hashCode => Object.hash(id, title, walletGroup, templateId, protected,
      Object.hashAll(tags), Object.hashAll(rows));
}
```

- [ ] **Step 4: Run to green** — `flutter test test/features/cheatsheet/domain/cheatsheet_card_test.dart` -> PASS. `flutter analyze`.
- [ ] **Step 5: Commit** — `git add lib/features/cheatsheet/domain test/features/cheatsheet/domain && git commit -m "feat(cheatsheet): domain entities"`

---

### Task 2: Codec (card <-> JSON map, schema-versioned + defensive)

**Files:** Create `lib/features/cheatsheet/data/cheatsheet_codec.dart`; Test `test/features/cheatsheet/data/cheatsheet_codec_test.dart`

**Interfaces — Consumes** T1 entities. **Produces:**
`class CheatsheetCodec { static const currentSchemaVersion = 1; static int schemaVersionOf(Map); static Map<String,dynamic> toMap(CheatsheetCard c); static CheatsheetCard fromMap(Map<String,dynamic> m); }`

**Robustness contract (non-negotiable):**
- `toMap` writes `'schemaVersion': 1`; `fromMap` tolerates its absence (default 1) and an unknown *newer* version (best-effort decode of the keys it knows).
- Decoding is **field-by-field defensive**: a wrong-typed or malformed *row* is dropped on its own — it must never discard the whole card. A non-`String` element in `tags` is skipped.
- **Never cast a persisted value.** `(m['rows'] as List?) ?? const []` *throws* on a non-list rather than defaulting — one wrong-typed key would lose the entire card, which is the failure this task exists to prevent. Use `is` guards (`_list`, `_str`, `_bool`) everywhere.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_codec.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  const card = CheatsheetCard(
    id: 'c1', title: 'Claim', walletGroup: 'Vehicle', tags: ['legal'],
    templateId: 'accidentClaim',
    rows: [
      CheatsheetRow(label: 'Plate',
          source: CheatsheetSource(noteUuid: 'auto1', kind: SourceGranularity.field,
              locator: 'AutomobileInfo.plate'),
          valueAction: ValueAction.none, openSource: true),
      CheatsheetRow(label: 'Unbound', source: null),
    ],
  );

  test('round-trips including an unbound row', () {
    expect(CheatsheetCodec.fromMap(CheatsheetCodec.toMap(card)), equals(card));
  });
  test('stamps and reads schemaVersion', () {
    expect(CheatsheetCodec.toMap(card)['schemaVersion'], 1);
    expect(CheatsheetCodec.schemaVersionOf(const {}), 1); // absent -> 1
    expect(CheatsheetCodec.schemaVersionOf(const {'schemaVersion': 7}), 7);
  });
  test('tolerates absent optional keys', () {
    final c = CheatsheetCodec.fromMap({'id': 'x', 'title': 'T', 'rows': []});
    expect(c.id, 'x');
    expect(c.walletGroup, 'Ungrouped');
    expect(c.rows, isEmpty);
  });
  test('a newer schemaVersion still decodes known fields', () {
    final c = CheatsheetCodec.fromMap({
      'schemaVersion': 99, 'id': 'x', 'title': 'T', 'rows': [], 'futureKey': {'a': 1},
    });
    expect(c.id, 'x');
    expect(c.title, 'T');
  });
  test('one malformed row is dropped, the rest of the card survives', () {
    final c = CheatsheetCodec.fromMap({
      'id': 'x', 'title': 'T',
      'rows': [
        {'label': 'good', 'openSource': true},
        'not-a-map',                                   // malformed
        {'label': 'alsoBad', 'source': 'not-a-map'},   // malformed source
      ],
    });
    expect(c.rows.map((r) => r.label), ['good']);
    expect(c.title, 'T'); // whole card NOT discarded
  });
  test('non-string tag elements are skipped', () {
    final c = CheatsheetCodec.fromMap({'id': 'x', 'title': 'T', 'tags': ['ok', 7, null], 'rows': []});
    expect(c.tags, ['ok']);
  });
  test('wrong-typed scalars fall back to defaults', () {
    final c = CheatsheetCodec.fromMap({'id': 'x', 'title': 42, 'protected': 'yes', 'rows': []});
    expect(c.title, '');
    expect(c.protected, isFalse);
  });
}
```

- [ ] **Step 2: Run red.** FAIL (codec missing).
- [ ] **Step 3: Implement**

```dart
import '../domain/entities/cheatsheet_card.dart';
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';

class CheatsheetCodec {
  /// Bump when the persisted card shape changes incompatibly, and branch on
  /// [schemaVersionOf] in [fromMap]. v1 is the only known shape today; newer
  /// versions decode best-effort through the defensive readers below.
  static const currentSchemaVersion = 1;

  static int schemaVersionOf(Map<String, dynamic> m) =>
      (m['schemaVersion'] as num?)?.toInt() ?? 1;

  static Map<String, dynamic> toMap(CheatsheetCard c) => {
        'schemaVersion': currentSchemaVersion,
        'id': c.id, 'title': c.title, 'walletGroup': c.walletGroup, 'tags': c.tags,
        'templateId': c.templateId, 'protected': c.protected,
        'rows': c.rows.map(_rowToMap).toList(),
      };

  static CheatsheetCard fromMap(Map<String, dynamic> m) {
    final rows = <CheatsheetRow>[];
    for (final e in _list(m['rows'])) {
      try {
        rows.add(_rowFromMap((e as Map).cast<String, dynamic>()));
      } catch (_) {
        // Drop only this row — a single bad row must never lose the card.
      }
    }
    return CheatsheetCard(
      id: _str(m['id']) ?? '',
      title: _str(m['title']) ?? '',
      walletGroup: _str(m['walletGroup']) ?? 'Ungrouped',
      tags: _list(m['tags']).whereType<String>().toList(),
      templateId: _str(m['templateId']) ?? 'blank',
      protected: _bool(m['protected']) ?? false,
      rows: rows,
    );
  }

  /// `as List?` would throw on a non-list; persisted data may hold anything.
  static List<Object?> _list(Object? v) => v is List ? v : const [];

  static String? _str(Object? v) => v is String ? v : null;

  static bool? _bool(Object? v) => v is bool ? v : null;

  static Map<String, dynamic> _rowToMap(CheatsheetRow r) => {
        'label': r.label,
        'valueAction': r.valueAction.name,
        'openSource': r.openSource,
        if (r.source != null) 'source': _srcToMap(r.source!),
      };

  static CheatsheetRow _rowFromMap(Map<String, dynamic> m) => CheatsheetRow(
        label: _str(m['label']) ?? '',
        source: m['source'] == null
            ? null
            : _srcFromMap((m['source'] as Map).cast<String, dynamic>()), // throws -> row dropped
        valueAction: ValueAction.values
            .firstWhere((v) => v.name == m['valueAction'], orElse: () => ValueAction.none),
        openSource: m['openSource'] is bool ? m['openSource'] as bool : true,
      );

  static Map<String, dynamic> _srcToMap(CheatsheetSource s) => {
        'noteUuid': s.noteUuid, 'kind': s.kind.name,
        if (s.locator != null) 'locator': s.locator,
      };

  static CheatsheetSource _srcFromMap(Map<String, dynamic> m) => CheatsheetSource(
        noteUuid: _str(m['noteUuid']) ?? '',
        kind: SourceGranularity.values
            .firstWhere((k) => k.name == m['kind'], orElse: () => SourceGranularity.whole),
        locator: _str(m['locator']),
      );
}
```

- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): schema-versioned card codec"`

---

### Task 3: Local repository (note-content CRUD)

**Files:**
- Create: `lib/features/cheatsheet/data/i_cheatsheet_repository.dart`, `lib/core/data/local/local_cheatsheet_repository.dart`
- Modify: `lib/core/data/repository_providers.dart` (add `cheatsheetRepositoryModeProvider` — local only for v1; cloudApi throws `UnimplementedError('cheatsheet cloudApi: backend plan')`)
- Test: `test/core/data/local/local_cheatsheet_repository_test.dart`

**Interfaces — Consumes** T1 entities, T2 codec, `IHmmNoteRepository`, `INoteCatalogRepository.getOrCreateCatalog`, `HmmNoteCreate`, `HmmNoteUpdate`. **Produces:**
```dart
abstract interface class ICheatsheetRepository {
  Future<List<CheatsheetCard>> getCards();
  Future<CheatsheetCard?> getCard(String id);           // by card id
  Future<CheatsheetCard> saveCard(CheatsheetCard card); // upsert by id
  Future<void> deleteCard(String id);
}
```

**Two hard requirements:**
1. **Subject is `'Cheatsheet:${card.id}'`** on create *and* update — never title-derived. Renaming a card must not change the note subject.
2. **`_allNotes()` pages until exhausted** — no fixed `pageSize` ceiling that can silently hide cards.

> Read `lib/core/data/local/local_gas_log_repository.dart` first — mirror its structure (catalog constant, envelope serialize/deserialize, note create/update, soft-delete). The cheatsheet note has **no parent** (`parentNoteId: null`). Match on the cheatsheet by the `id` stored in its JSON (list the catalog's notes, decode each, filter).

- [ ] **Step 1: Write the failing test** (in-memory Drift, mirroring `test/core/data/local/local_service_record_header_test.dart`)

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository noteRepo;
  late LocalNoteCatalogRepository catalogRepo;
  late LocalCheatsheetRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();
    noteRepo = LocalHmmNoteRepository(db, () async => author);
    catalogRepo = LocalNoteCatalogRepository(db);
    repo = LocalCheatsheetRepository(noteRepo, catalogRepo);
  });
  tearDown(() => db.close());

  CheatsheetCard sample(String id) => CheatsheetCard(
      id: id, title: 'Claim', walletGroup: 'Vehicle', tags: const [],
      templateId: 'blank', rows: const [
        CheatsheetRow(label: 'Plate',
            source: CheatsheetSource(noteUuid: 'n', kind: SourceGranularity.whole)),
      ]);

  Future<List<HmmNote>> allCheatsheetNotes() async {
    final catalog = await catalogRepo.getOrCreateCatalog(cheatsheetCatalogName, '{}');
    final out = <HmmNote>[];
    var page = 1;
    while (true) {
      final res = await noteRepo.getNotes(catalogId: catalog.id, page: page, pageSize: 100);
      out.addAll(res.items);
      if (res.items.isEmpty || page >= res.meta.totalPages) break;
      page++;
    }
    return out;
  }

  test('save creates, getCard reloads, getCards lists', () async {
    expect((await repo.saveCard(sample('c1'))).id, 'c1');
    expect((await repo.getCard('c1'))!.title, 'Claim');
    expect((await repo.getCards()).length, 1);
  });
  test('save upserts by id (no duplicate note)', () async {
    await repo.saveCard(sample('c1'));
    await repo.saveCard(sample('c1').copyWith(title: 'Updated'));
    expect((await repo.getCards()).length, 1);
    expect((await repo.getCard('c1'))!.title, 'Updated');
  });
  test('subject is the stable Cheatsheet:{id}, unchanged by a title rename', () async {
    await repo.saveCard(sample('c1'));
    expect((await allCheatsheetNotes()).single.subject, 'Cheatsheet:c1');
    await repo.saveCard(sample('c1').copyWith(title: 'Renamed'));
    expect((await allCheatsheetNotes()).single.subject, 'Cheatsheet:c1'); // identity, not a label
    expect((await repo.getCard('c1'))!.title, 'Renamed');
  });
  test('getCards returns every card across page boundaries', () async {
    for (var i = 0; i < 45; i++) {
      await repo.saveCard(sample('c$i'));       // > the 20-per-page default
    }
    expect((await repo.getCards()).length, 45);
    expect(await repo.getCard('c44'), isNotNull);
  });
  test('delete removes it', () async {
    await repo.saveCard(sample('c1'));
    await repo.deleteCard('c1');
    expect(await repo.getCard('c1'), isNull);
  });
}
```

- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** the interface file, then `local_cheatsheet_repository.dart`:

```dart
import 'dart:convert';
import '../../../features/cheatsheet/data/cheatsheet_codec.dart';
import '../../../features/cheatsheet/data/i_cheatsheet_repository.dart';
import '../../../features/cheatsheet/domain/entities/cheatsheet_card.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../hmm_note_input.dart';
import 'local_hmm_note_repository.dart';
import 'local_note_catalog_repository.dart';

const cheatsheetCatalogName = 'Hmm.CheatsheetMan.Cheatsheet';

/// The note subject is an identity, never a label: titles are mutable and
/// non-unique, so they live only inside the card JSON.
String cheatsheetSubjectFor(String cardId) => 'Cheatsheet:$cardId';

class LocalCheatsheetRepository implements ICheatsheetRepository {
  LocalCheatsheetRepository(this._notes, this._catalogs);
  final IHmmNoteRepository _notes;
  final INoteCatalogRepository _catalogs;

  static const _pageSize = 100;

  String _serialize(CheatsheetCard c) =>
      jsonEncode({'note': {'content': {'Cheatsheet': CheatsheetCodec.toMap(c)}}});

  CheatsheetCard? _deserialize(String? content) {
    if (content == null) return null;
    try {
      final data = (jsonDecode(content) as Map)['note']?['content']?['Cheatsheet'];
      return data is Map ? CheatsheetCodec.fromMap(data.cast<String, dynamic>()) : null;
    } catch (_) {
      return null;
    }
  }

  Future<int> _catalogId() async =>
      (await _catalogs.getOrCreateCatalog(cheatsheetCatalogName, '{}')).id;

  /// Pages until exhausted — a fixed ceiling would silently hide cards.
  Future<List<HmmNote>> _allNotes() async {
    final catalogId = await _catalogId();
    final out = <HmmNote>[];
    var page = 1;
    while (true) {
      final res = await _notes.getNotes(catalogId: catalogId, page: page, pageSize: _pageSize);
      out.addAll(res.items);
      if (res.items.isEmpty || page >= res.meta.totalPages) break;
      page++;
    }
    return out;
  }

  @override
  Future<List<CheatsheetCard>> getCards() async =>
      (await _allNotes()).map((n) => _deserialize(n.content)).whereType<CheatsheetCard>().toList();

  Future<HmmNote?> _noteForCard(String id) async {
    for (final n in await _allNotes()) {
      if (_deserialize(n.content)?.id == id) return n;
    }
    return null;
  }

  @override
  Future<CheatsheetCard?> getCard(String id) async =>
      _deserialize((await _noteForCard(id))?.content);

  @override
  Future<CheatsheetCard> saveCard(CheatsheetCard card) async {
    final subject = cheatsheetSubjectFor(card.id);
    final existing = await _noteForCard(card.id);
    if (existing == null) {
      await _notes.createNote(HmmNoteCreate(
          subject: subject, catalogId: await _catalogId(), content: _serialize(card)));
    } else {
      await _notes.updateNote(
          existing.id, HmmNoteUpdate(subject: subject, content: _serialize(card)));
    }
    return card;
  }

  @override
  Future<void> deleteCard(String id) async {
    final n = await _noteForCard(id);
    if (n != null) await _notes.deleteNote(n.id);
  }
}
```

Then in `repository_providers.dart` add (mirroring `gasLogRepositoryModeProvider`):

```dart
final localCheatsheetRepositoryProvider = Provider<ICheatsheetRepository>((ref) =>
    LocalCheatsheetRepository(
        ref.watch(localHmmNoteRepositoryProvider), ref.watch(localNoteCatalogRepositoryProvider)));

final cheatsheetRepositoryModeProvider = Provider<ICheatsheetRepository>((ref) {
  if (!_useLocal(ref.watch(dataModeProvider))) {
    throw UnimplementedError('cheatsheet cloudApi repo ships in the backend plan');
  }
  return ref.watch(localCheatsheetRepositoryProvider);
});
```

- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): local note-content repository"`

---

### Task 4: Note-piece extractor (filtered field paths + extraction)

**Files:** Create `lib/features/cheatsheet/domain/note_piece_extractor.dart`; Test `test/features/cheatsheet/domain/note_piece_extractor_test.dart`

**Interfaces — Produces:**
```dart
class NotePieceExtractor {
  static List<String> fieldPaths(String? noteContent);      // bindable leaves only
  static String? field(String? noteContent, String path);   // value at a dotted path, else null
  static List<String> sectionHeadings(String? markdown);
  static String? section(String? markdown, String heading);
  static String whole(String? noteContent, String? description);
}
```
Malformed JSON -> `[]`/`null` (never throws).

**Binding-surface policy.** `fieldPaths` is an *offer* list shown in the designer, so it must not expose internal/audit plumbing. A path is **excluded when any segment** is an internal key: one of `{_v, id, uuid, authorId, parentNoteId, version}`, or matches `RegExp(r'^_|Id$')`, or ends in `Date`/`At` (case-insensitive). `field(content, path)` deliberately still resolves *any* explicit path, so an already-bound reference keeps working even if the offer policy later tightens.

> **v2 robustness path (out of scope here):** replace raw introspection with a catalog-keyed `CheatsheetBindingAdapter` registry that publishes a curated, stable set of semantic fields per catalog (`Hmm.AutomobileMan.GasLog` -> station/price/…), keeping raw introspection only as an explicitly labelled fallback. That removes the serializer-shape brittleness this filter only mitigates. Do **not** build it in v1.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/note_piece_extractor.dart';

const gasNote = '{"note":{"content":{"GasLog":{"station":"Shell","price":1.65,'
    '"nested":{"x":"y"},"id":7,"uuid":"u","_v":1,"createdDate":"2026-01-01",'
    '"modifiedAt":"2026-01-02","automobileId":3}}}}';
const md = '# Title\nintro\n## Shortcuts\n- dd delete line\n- yy yank\n## Config\nset nu\n';

void main() {
  test('fieldPaths flattens leaf scalars', () {
    expect(NotePieceExtractor.fieldPaths(gasNote),
        containsAll(['GasLog.station', 'GasLog.price', 'GasLog.nested.x']));
  });
  test('fieldPaths hides internal/audit keys', () {
    final paths = NotePieceExtractor.fieldPaths(gasNote);
    expect(paths, isNot(contains('GasLog.id')));
    expect(paths, isNot(contains('GasLog.uuid')));
    expect(paths, isNot(contains('GasLog._v')));
    expect(paths, isNot(contains('GasLog.createdDate')));
    expect(paths, isNot(contains('GasLog.modifiedAt')));
    expect(paths, isNot(contains('GasLog.automobileId')));
  });
  test('field still resolves an explicitly bound internal path', () {
    // Offer policy != resolution policy: existing bindings must not break.
    expect(NotePieceExtractor.field(gasNote, 'GasLog.id'), '7');
  });
  test('field reads a dotted path', () {
    expect(NotePieceExtractor.field(gasNote, 'GasLog.station'), 'Shell');
    expect(NotePieceExtractor.field(gasNote, 'GasLog.missing'), isNull);
  });
  test('malformed content never throws', () {
    expect(NotePieceExtractor.fieldPaths('not json'), isEmpty);
    expect(NotePieceExtractor.field('not json', 'a.b'), isNull);
  });
  test('section extracts the block under a heading', () {
    expect(NotePieceExtractor.sectionHeadings(md), containsAll(['Title', 'Shortcuts', 'Config']));
    expect(NotePieceExtractor.section(md, 'Shortcuts'), contains('dd delete line'));
    expect(NotePieceExtractor.section(md, 'Shortcuts'), isNot(contains('set nu')));
    expect(NotePieceExtractor.section(md, 'Nope'), isNull);
  });
}
```

- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement**

```dart
import 'dart:convert';

class NotePieceExtractor {
  static Map<String, dynamic>? _entityMap(String? content) {
    if (content == null) return null;
    try {
      final inner = (jsonDecode(content) as Map)['note']?['content'];
      return inner is Map ? inner.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  static const _internalKeys = {'_v', 'id', 'uuid', 'authorId', 'parentNoteId', 'version'};
  static final _internalPattern = RegExp(r'^_|Id$');
  static final _timestampPattern = RegExp(r'(date|at)$', caseSensitive: false);

  /// Offer policy for the designer: never surface internal/audit plumbing.
  /// Resolution ([field]) is deliberately unrestricted so existing bindings
  /// survive a tightening of this policy.
  static bool _isInternal(String segment) =>
      _internalKeys.contains(segment) ||
      _internalPattern.hasMatch(segment) ||
      _timestampPattern.hasMatch(segment);

  static List<String> fieldPaths(String? content) {
    final root = _entityMap(content);
    if (root == null) return const [];
    final out = <String>[];
    void walk(String prefix, Map<String, dynamic> m) {
      for (final e in m.entries) {
        if (_isInternal(e.key)) continue;
        final path = prefix.isEmpty ? e.key : '$prefix.${e.key}';
        final v = e.value;
        if (v is Map) {
          walk(path, v.cast<String, dynamic>());
        } else if (v is! List) {
          out.add(path);
        }
      }
    }
    walk('', root);
    return out;
  }

  static String? field(String? content, String path) {
    dynamic node = _entityMap(content);
    for (final seg in path.split('.')) {
      if (node is Map && node.containsKey(seg)) {
        node = node[seg];
      } else {
        return null;
      }
    }
    if (node == null || node is Map || node is List) return null;
    return node.toString();
  }

  static final _heading = RegExp(r'^#{1,6}\s+');

  static List<String> sectionHeadings(String? md) => md == null
      ? const []
      : md.split('\n').where(_heading.hasMatch).map((l) => l.replaceFirst(_heading, '').trim()).toList();

  static String? section(String? md, String heading) {
    if (md == null) return null;
    final lines = md.split('\n');
    final start = lines.indexWhere(
        (l) => _heading.hasMatch(l) && l.replaceFirst(_heading, '').trim() == heading);
    if (start < 0) return null;
    final body = <String>[];
    for (var i = start + 1; i < lines.length; i++) {
      if (_heading.hasMatch(lines[i])) break;
      body.add(lines[i]);
    }
    return body.join('\n').trim();
  }

  static String whole(String? content, String? description) =>
      (description != null && description.trim().isNotEmpty) ? description : (content ?? '');
}
```

- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): note-piece extractor (field/section/whole)"`

---

### Task 5: Resolver

**Files:** Create `lib/features/cheatsheet/data/cheatsheet_resolver.dart`; Test `test/features/cheatsheet/data/cheatsheet_resolver_test.dart`

**Interfaces — Consumes** `IHmmNoteRepository.getNoteByUuid`, T4 `NotePieceExtractor`, T1 `CheatsheetRow`/`CheatsheetSource`. **Produces:**
```dart
class ResolvedValue { final String? text; final bool missing; final bool unbound; }
class CheatsheetResolver { CheatsheetResolver(this._notes); Future<ResolvedValue> resolve(CheatsheetRow row); }
```
unbound -> `unbound: true`; note-by-uuid not found -> `missing: true`; field/section absent -> `missing: true`; success -> `text`.

- [ ] **Step 1: Write the failing test** (minimal fake `IHmmNoteRepository` implementing only `getNoteByUuid`; `UnimplementedError` for the rest)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_resolver.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
// import HmmNote + IHmmNoteRepository; define _FakeNotes(Map<String,HmmNote>) implementing getNoteByUuid.

void main() {
  final note = HmmNote(id: 1, uuid: 'auto1', subject: 's', authorId: 1,
      createDate: DateTime(2026),
      content: '{"note":{"content":{"AutomobileInfo":{"plate":"ABC123"}}}}');
  CheatsheetResolver r() => CheatsheetResolver(_FakeNotes({'auto1': note}));

  test('field hit', () async {
    final v = await r().resolve(const CheatsheetRow(label: 'Plate',
        source: CheatsheetSource(noteUuid: 'auto1', kind: SourceGranularity.field,
            locator: 'AutomobileInfo.plate')));
    expect(v.text, 'ABC123');
  });
  test('unbound', () async {
    expect((await r().resolve(const CheatsheetRow(label: 'x', source: null))).unbound, isTrue);
  });
  test('missing note', () async {
    expect((await r().resolve(const CheatsheetRow(label: 'x',
        source: CheatsheetSource(noteUuid: 'nope', kind: SourceGranularity.whole)))).missing, isTrue);
  });
  test('missing field', () async {
    expect((await r().resolve(const CheatsheetRow(label: 'x',
        source: CheatsheetSource(noteUuid: 'auto1', kind: SourceGranularity.field,
            locator: 'AutomobileInfo.vin')))).missing, isTrue);
  });
}
```

- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement**

```dart
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';
import '../domain/note_piece_extractor.dart';
// import IHmmNoteRepository

class ResolvedValue {
  const ResolvedValue({this.text, this.missing = false, this.unbound = false});
  final String? text;
  final bool missing;
  final bool unbound;
}

class CheatsheetResolver {
  CheatsheetResolver(this._notes);
  final IHmmNoteRepository _notes;

  Future<ResolvedValue> resolve(CheatsheetRow row) async {
    final s = row.source;
    if (s == null) return const ResolvedValue(unbound: true);
    final note = await _notes.getNoteByUuid(s.noteUuid);
    if (note == null) return const ResolvedValue(missing: true);
    final value = switch (s.kind) {
      SourceGranularity.field => NotePieceExtractor.field(note.content, s.locator ?? ''),
      SourceGranularity.section =>
        NotePieceExtractor.section(note.description ?? note.content, s.locator ?? ''),
      SourceGranularity.whole => NotePieceExtractor.whole(note.content, note.description),
    };
    if (value == null || value.isEmpty) return const ResolvedValue(missing: true);
    return ResolvedValue(text: value);
  }
}
```

- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): live resolver"`

---

### Task 6: Cross-device reference resolution (MANDATORY integration test)

**Files:** Test only — `test/features/cheatsheet/data/cheatsheet_cross_device_test.dart`

**Why this task exists:** the entire reference model rests on "`uuid` is stable, the local int `id` is not." T5's fake repo cannot prove that. This test uses **two real in-memory Drift databases** and a **real `LocalHmmNoteRepository`**, deliberately giving the same logical note *different* local int ids in each, then asserts every reference still resolves. Treat a failure here as a design failure, not a test bug.

**Consumes:** `HmmDatabase`, `LocalHmmNoteRepository`, `LocalNoteCatalogRepository`, `LocalCheatsheetRepository` (T3), `CheatsheetResolver` (T5).

- [ ] **Step 1: Write the failing test**

```dart
// Sketch — adapt setUp to the two-database helper; A = authoring device, B = fresh device.
void main() {
  // setUp: dbA/dbB (NativeDatabase.memory()), an author each, notesA/notesB
  // (LocalHmmNoteRepository), catalogs, repoA/repoB (LocalCheatsheetRepository).

  test('a reference resolves in a fresh DB where the local int id differs', () async {
    // A: filler notes first so the source note is NOT id 1.
    for (var i = 0; i < 3; i++) {
      await notesA.createNote(HmmNoteCreate(subject: 'filler$i', catalogId: autoCatalogA.id));
    }
    final srcA = await notesA.createNote(HmmNoteCreate(
        subject: 'Auto', catalogId: autoCatalogA.id,
        content: '{"note":{"content":{"AutomobileInfo":{"plate":"ABC123"}}}}'));
    expect(srcA.id, greaterThan(1)); // guards the premise of the test

    final card = CheatsheetCard(id: 'c1', title: 'Claim', walletGroup: 'Vehicle',
        tags: const [], templateId: 'blank', rows: [
      CheatsheetRow(label: 'Plate', source: CheatsheetSource(
          noteUuid: srcA.uuid, kind: SourceGranularity.field, locator: 'AutomobileInfo.plate')),
    ]);
    final cardNoteA = (await repoA.saveCard(card), await notesA.getNoteByUuid(/* card note */));

    // Transfer, the way the sync providers do it: replay the notes into B
    // carrying the stable uuid (HmmNoteCreate.uuid) but NOT the int id, and in
    // a different order so the int ids genuinely differ.
    final srcB = await notesB.createNote(HmmNoteCreate(
        subject: srcA.subject, catalogId: autoCatalogB.id, content: srcA.content,
        uuid: srcA.uuid));
    expect(srcB.id, isNot(srcA.id)); // different local identity, same uuid
    // ...replay the cheatsheet note into B the same way (subject/content/uuid).

    final reloaded = (await repoB.getCard('c1'))!;
    final v = await CheatsheetResolver(notesB).resolve(reloaded.rows.first);
    expect(v.text, 'ABC123'); // resolved by uuid, not by int id
  });

  test('a late-arriving source resolves once it lands', () async {
    const row = CheatsheetRow(label: 'Plate', source: CheatsheetSource(
        noteUuid: 'not-here-yet', kind: SourceGranularity.field,
        locator: 'AutomobileInfo.plate'));
    final resolver = CheatsheetResolver(notesB);
    expect((await resolver.resolve(row)).missing, isTrue);   // before sync
    await notesB.createNote(HmmNoteCreate(subject: 'Auto', catalogId: autoCatalogB.id,
        uuid: 'not-here-yet',
        content: '{"note":{"content":{"AutomobileInfo":{"plate":"XYZ789"}}}}'));
    expect((await resolver.resolve(row)).text, 'XYZ789');    // after sync
  });

  test('a permanently missing source degrades, never throws', () async {
    final v = await CheatsheetResolver(notesB).resolve(const CheatsheetRow(label: 'x',
        source: CheatsheetSource(noteUuid: 'gone', kind: SourceGranularity.whole)));
    expect(v.missing, isTrue);
  });
}
```

- [ ] **Step 2: Run red** (fails until T3/T5 are in and correct).
- [ ] **Step 3: Make it pass** — no production change should be needed if T3/T5 are right. If one is, fix it here and note what changed.
- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "test(cheatsheet): cross-device uuid reference resolution"`

---

### Task 7: Starter templates

**Files:** Create `lib/features/cheatsheet/data/cheatsheet_templates.dart`; Test `test/features/cheatsheet/data/cheatsheet_templates_test.dart`

**Interfaces — Produces:** `class CheatsheetTemplate { final String id, title, walletGroup; final List<String> rowLabels; }`; `class CheatsheetTemplates { static List<CheatsheetTemplate> all; static CheatsheetCard instantiate(CheatsheetTemplate t, String id); }` — instantiated rows are all **unbound**. `instantiate` takes the id from its caller (T9 mints it); it never generates one itself.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_templates.dart';

void main() {
  test('accidentClaim instantiates labeled unbound rows', () {
    final t = CheatsheetTemplates.all.firstWhere((t) => t.id == 'accidentClaim');
    final card = CheatsheetTemplates.instantiate(t, 'c1');
    expect(card.id, 'c1');
    expect(card.templateId, 'accidentClaim');
    expect(card.rows, isNotEmpty);
    expect(card.rows.every((r) => r.source == null), isTrue);
    expect(card.rows.map((r) => r.label), contains('Plate'));
  });
  test('blank has no rows', () {
    final t = CheatsheetTemplates.all.firstWhere((t) => t.id == 'blank');
    expect(CheatsheetTemplates.instantiate(t, 'c2').rows, isEmpty);
  });
}
```

- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** — `all`: `accidentClaim` (walletGroup 'Vehicle'; labels Plate, VIN, Insurer, Policy #, Driver, Phone, Address), `healthInfo` ('Health'; Person, Family doctor, Doctor phone, Pharmacy, Pharmacy phone, Address), `document` ('Reference'; Section 1), `blank` ('Ungrouped'; no labels). `instantiate` -> `CheatsheetCard(id: id, title: t.title, walletGroup: t.walletGroup, tags: const [], templateId: t.id, rows: t.rowLabels.map((l) => CheatsheetRow(label: l, source: null)).toList())`.
- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): starter templates"`

---

### Task 8: List state (`AsyncNotifier`)

**Files:** Create `lib/features/cheatsheet/states/cheatsheets_state.dart`; Test `test/features/cheatsheet/states/cheatsheets_state_test.dart`

**Interfaces — Consumes** `cheatsheetRepositoryModeProvider`. **Produces:** `class CheatsheetsState extends AsyncNotifier<List<CheatsheetCard>> { Future<List<CheatsheetCard>> build(); Future<void> refresh(); Future<void> save(CheatsheetCard); Future<void> remove(String id); }` + `cheatsheetsStateProvider`. Mirror `lib/features/gas_log/states/gas_logs_state.dart`.

- [ ] **Step 1: Write the failing test** — `ProviderContainer(overrides: [cheatsheetRepositoryModeProvider.overrideWithValue(_FakeRepo(...))])`; `await container.read(cheatsheetsStateProvider.future)` returns the repo's cards; after `save`, re-read includes the new card; after `save` of an existing id, the list length is unchanged. (`_FakeRepo` implements `ICheatsheetRepository` over an in-memory `Map`.)

> **Asserting the error path:** subscribe with `container.listen(...)`, settle with a short `Future.delayed`, then assert `state.hasError` — the idiom in `automobiles_state_test.dart`. Do **not** `await container.read(provider.future)` and expect it to throw: with no listener the provider never leaves its loading state, so that future only completes on dispose, with a `StateError` about being "disposed during loading" rather than the repository's exception. It reads as a 30-second hang.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** — `build()` = `await ref.read(cheatsheetRepositoryModeProvider).getCards()`; `save`/`remove` call the repo then `ref.invalidateSelf()`; `refresh` = `ref.invalidateSelf()`.
- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): list state"`

---

### Task 9: Designer editor state (create + edit lifecycle)

**Files:** Create `lib/features/cheatsheet/states/cheatsheet_editor_state.dart`; Test `test/features/cheatsheet/states/cheatsheet_editor_state_test.dart`

**Interfaces — Produces:**
```dart
/// Injectable so tests can pin ids; production is the real v4 generator.
final cheatsheetIdGenProvider = Provider<String Function()>((_) => generateUuid);

class CheatsheetEditor extends Notifier<CheatsheetCard> {
  CheatsheetCard build();                       // an empty blank card
  void startFromTemplate(String templateId);    // mints a FRESH id via cheatsheetIdGenProvider
  void load(CheatsheetCard existing);           // edit: state = existing, id preserved
  void setTitle(String);  void setWalletGroup(String);  void setTags(List<String>);
  void addRow(String label);  void removeRow(int);
  void bindRow(int, CheatsheetSource);  void unbindRow(int);
  void setValueAction(int, ValueAction);  void setOpenSource(int, bool);
  Future<void> commit();                        // ref.read(cheatsheetsStateProvider.notifier).save(state)
}
final cheatsheetEditorProvider = NotifierProvider<CheatsheetEditor, CheatsheetCard>(CheatsheetEditor.new);
```

**Identity rules:** `startFromTemplate` takes **no id from callers** — it reads `cheatsheetIdGenProvider` and mints one. `load` never touches the id. Partial binding is allowed (a card may be saved with unbound rows). There is no `quickAccess`/`sortOrder` control.

- [ ] **Step 1: Write the failing test**
  - `startFromTemplate('accidentClaim')` yields unbound rows and a non-empty id.
  - Two `startFromTemplate` calls (with the real generator) yield **distinct** ids.
  - With `cheatsheetIdGenProvider.overrideWithValue(() => 'fixed')`, the new card's id is `'fixed'`.
  - `bindRow(0, src)` sets row 0's source and leaves the rest unbound.
  - `load(existing)` then `setTitle('X')` then `commit()` -> the captured save arg has `id == existing.id` (assert via a fixed-subclass `CheatsheetsState` capturing the argument).
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** — pure `state = state.copyWith(rows: ...)` manipulation; `commit` delegates to the list state.
- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): designer editor state (create + edit)"`

---

### Task 10: Launch actions (tel: / maps:)

**Files:**
- Create `lib/core/util/launch_actions.dart` — pure URI builders, **no feature imports**; Test `test/core/util/launch_actions_test.dart`
- Create `lib/features/cheatsheet/data/cheatsheet_launcher.dart` — `ValueAction` dispatch; Test `test/features/cheatsheet/data/cheatsheet_launcher_test.dart`

> **Why two files:** `launchAction` takes a `ValueAction`, which lives in `features/cheatsheet`. Putting it in `core/util` would make **core import a feature** and invert the dependency direction. Pure `Uri` construction is genuinely generic and stays in core; the enum dispatch belongs to the feature that owns the enum.

**Interfaces — Produces:**
```dart
// core/util/launch_actions.dart — generic, no feature types
Uri telUri(String phone);     // strips punctuation; keeps a LEADING + (international prefix)
Uri mapsUri(String address);  // https://maps.apple.com/?q=<encoded>

// features/cheatsheet/data/cheatsheet_launcher.dart
class LaunchActionException implements Exception { final Uri uri; }
Uri? uriForAction(ValueAction action, String value);   // null for none / blank value
Future<void> launchAction(ValueAction action, String value);
/// Overridable in widget tests so the detail screen never touches url_launcher.
final launchActionProvider =
    Provider<Future<void> Function(ValueAction, String)>((ref) => launchAction);
```

Two behavioural decisions, both load-bearing for T14:

- **`launchAction` throws `LaunchActionException`** when `launchUrl` returns false. `note_markdown_body._launchExternal` deliberately *swallows* failures, which is right for an incidental markdown link and wrong here: a value somebody deliberately tapped should report that it went nowhere. T14 catches this and shows a message — the "launch failure surfaces a message and does not crash" test depends on it failing loudly.
- **`mapsUri` uses `https://maps.apple.com`, not a `geo:` scheme.** There is then always a handler — native Maps on Apple platforms, a browser everywhere else. A `geo:` URI has no handler on desktop and would throw on every launch.

Keep URI building pure + unit-tested; the `launchUrl` call itself is a thin wrapper (not unit-tested).

- [ ] **Step 1: test** — `telUri('(555) 123-4567').toString() == 'tel:5551234567'`; `telUri('+1 555-123-4567')` keeps the `+`; `mapsUri('1 Main St').toString()` contains `maps.apple.com/?q=1%20Main%20St` (use `Uri.encodeComponent`) and its scheme is `https`; `uriForAction(ValueAction.none, x)` and a blank value are both null; `launchActionProvider` is overridable.
- [ ] **Step 2–5:** implement, green, analyze, commit `feat(cheatsheet): tel/maps launch helpers`.

---

### Task 11: Source picker widget

**Files:** Create `lib/features/cheatsheet/presentation/widgets/source_picker.dart`; Test `test/features/cheatsheet/presentation/source_picker_test.dart`

**Behavior:** a modal returning a `CheatsheetSource?`.
- **Step 1 — choose a note:** a searchable list. **It must not cap the candidate set** — page through `getNotes` until exhausted (or drive it from `watchNotes()`), with incremental/lazy loading and a search box. A hard `pageSize` that hides notes is a defect.
- **Step 2 — choose granularity:** if `NotePieceExtractor.fieldPaths(note.content)` is non-empty, show **field** options (the filtered dotted paths); if `sectionHeadings(note.description ?? note.content)` is non-empty, show **section** options; always offer **Whole**.
- Returns `CheatsheetSource(noteUuid: note.uuid, kind: ..., locator: ...)`.

- [ ] **Step 1: widget test** — override the note repo to return one structured note; drive the picker to a field selection; assert the returned source `(kind: field, locator: '<path>', noteUuid: '<uuid>')`. Add a test with **more notes than one page** asserting a note on the second page is reachable (scroll/search). `ProviderScope` overrides only; never fake `WidgetRef`.
- [ ] **Step 2–5:** implement following the bottom-sheet idiom (`lib/features/notes/presentation/widgets/catalog_filter_sheet.dart`) + the notes list; green, analyze, commit `feat(cheatsheet): source picker`.

---

### Task 12: Designer screen (create + edit)

**Files:** Create `lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart`; Test `test/features/cheatsheet/presentation/cheatsheet_designer_screen_test.dart`

**Behavior:** one screen, two entry modes.
- **Create** (`cheatsheets/new`): a template chooser (`CheatsheetTemplates.all`) -> `editor.startFromTemplate(id)`.
- **Edit** (`cheatsheets/:id/edit`): resolve the card from `cheatsheetsStateProvider` (or the repo) and `editor.load(card)` — no template chooser, id preserved.
- Then: editable rows (label + a bound-source summary, or "Tap to bind" -> opens T11 picker -> `editor.bindRow`), a per-row value-action selector (`call`/`map`/`none` — **explicit**, no inference) and an `openSource` toggle; title/walletGroup/tags fields; add/remove rows; a **Save** calling `editor.commit()`.
- **No** quickAccess switch and **no** reorder affordance in v1.

Mirror `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart`. Uses `cheatsheetEditorProvider` (T9).

- [ ] **Step 1: widget tests**
  - *Create/partial save:* start from `accidentClaim`; assert labeled rows render "Tap to bind"; inject a picker result binding row 0; tap Save; assert the (overridden) list-state `save` received a card with row 0 bound and the rest unbound.
  - *Edit, no duplication:* pump in edit mode over a saved card, change the title, Save; assert `save` was called with the **same id**, and against a real `LocalCheatsheetRepository` that `getCards()` still returns exactly one card.
  - *Explicit action:* set row 0's action to `call`; assert the saved card's `rows[0].valueAction == ValueAction.call`.
- [ ] **Step 2–5:** implement, green, analyze, commit `feat(cheatsheet): designer screen`.

---

### Task 13: Wallet screen

**Files:** Create `lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart`; Test `test/features/cheatsheet/presentation/cheatsheet_wallet_screen_test.dart`

**Behavior:** `ref.watch(cheatsheetsStateProvider)` -> `AsyncValue.when`; group `.value ?? const []` by `walletGroup` into labeled stacks; tap a card -> push detail (T14); `+` -> designer create (T12). Handle empty/loading/error.

- **Ordering is deterministic:** groups sorted by `walletGroup` (case-insensitive), cards within a group by `title` (case-insensitive) with `id` as the tie-breaker. There is no `sortOrder` and no user reordering in v1 — but two cards with the same title must never swap places between builds.
- **Filtering + search:** a free-text search over the title, plus a tag filter. Search is **case-insensitive**; the tag filter shows only cards carrying the tag; both applied together intersect. The tag chip set is normalized — trimmed and case-insensitively de-duplicated.

- [ ] **Step 1: widget tests**
  - two cards in "Vehicle"/"Health" -> both group headers + titles render; tapping a card pushes the detail route.
  - deterministic order: two cards with the same title in one group render in `id` order, stable across a rebuild.
  - search `'cla'` matches `'Claim'` (case-insensitive); search with no match shows the empty-result state (not a blank screen).
  - tag filter `'legal'` shows only cards carrying it; combined title+tag filter intersects.
  - tag chips: cards with `['Legal', 'legal ', 'health']` produce chips `{legal, health}` (trimmed + de-duped).
- [ ] **Step 2–5:** implement, green, analyze, commit `feat(cheatsheet): wallet screen`.

---

### Task 14: Detail screen (live, actionable)

**Files:** Create `lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart`; Test `test/features/cheatsheet/presentation/cheatsheet_detail_screen_test.dart`

**Behavior:** add
```dart
final cheatsheetResolverProvider =
    Provider((ref) => CheatsheetResolver(ref.watch(hmmNoteRepositoryProvider)));
/// Overridable in tests; production navigates to the note by uuid.
final cheatsheetOpenSourceProvider =
    Provider<void Function(BuildContext, String noteUuid)>((_) => defaultOpenSource);
```
For the card, resolve each row -> `label -> value`; muted `—` when `unbound`, `source removed` when `missing`; when `valueAction == call/map` the value is tappable -> `ref.read(launchActionProvider)(action, value)` (T10) inside a try/catch that surfaces a SnackBar on failure and never crashes; an "open source" affordance when `openSource` -> `cheatsheetOpenSourceProvider`. Read-only; an **Edit** action pushes `cheatsheets/:id/edit` (T12/T15).

- [ ] **Step 1: widget tests** (all via the injected `launchActionProvider` / `cheatsheetOpenSourceProvider` — never real `url_launcher`)
  - a resolved `field` row renders its value (`ABC123`); a `missing` row renders "source removed"; an `unbound` row renders `—`.
  - a `section` row and a `whole` row each render their text.
  - a `call` row's value tap invokes the launcher with `(ValueAction.call, '<value>')`.
  - a `map` row's value tap invokes the launcher with `(ValueAction.map, '<value>')`.
  - an `openSource` row's affordance tap invokes the open-source callback with the row's **source uuid**.
  - a launcher that throws -> a message is shown and the screen stays alive (no exception escapes).
  - the Edit action pushes `cheatsheets/:id/edit` with the card's id.
- [ ] **Step 2–5:** implement, green, analyze, commit `feat(cheatsheet): detail screen`.

---

### Task 15: Navigation + entry point

**Files:** Modify `lib/core/navigation/route_names.dart`, `lib/core/navigation/router_config.dart`, `lib/features/dashboard/presentation/screens/dashboard_screen.dart`.

**Route tree (four routes — the edit route is what makes T12's edit mode reachable):**

| name | path | screen |
| --- | --- | --- |
| `cheatsheets` | `/cheatsheets` | wallet (T13) |
| `cheatsheetCreate` | `/cheatsheets/new` | designer, create mode |
| `cheatsheetDetail` | `/cheatsheets/:id` | detail (T14) |
| `cheatsheetEdit` | `/cheatsheets/:id/edit` | designer, edit mode (`load`) |

Dashboard: `_allFunctions` tile `AppFunction(icon: Icons.style_outlined, title: 'Cheatsheets', description: 'Quick-reference cards', route: 'cheatsheets')` + `case 'cheatsheets': context.pushNamed(RouterNames.cheatsheets.name);`.

- [ ] **Step 1: test** — a router test that navigating `cheatsheets` builds `CheatsheetWalletScreen`, `cheatsheets/new` builds the designer in create mode, `cheatsheets/:id` builds the detail, and `cheatsheets/:id/edit` builds the designer in edit mode with that id; a dashboard test asserting the Cheatsheets tile exists and its `case` pushes the route (follow existing dashboard/router tests).
- [ ] **Step 2: Run to green + analyze.**
- [ ] **Step 3: Commit** — `git commit -m "feat(cheatsheet): navigation + dashboard entry"`

---

### Task 16: Acceptance test (end-to-end)

**Files:** Test only — `test/features/cheatsheet/cheatsheet_acceptance_test.dart`

**Why:** every task above proves one seam. This proves the seams compose. Runs against a **real** in-memory Drift DB + real `LocalCheatsheetRepository`/`LocalHmmNoteRepository`/`CheatsheetResolver`; only the launcher and open-source callbacks are injected.

- [ ] **Step 1: Write the test** — one flow, asserted at each stage:
  1. Seed a source note with a known `uuid` and content.
  2. Open the designer, create from the `accidentClaim` template (id minted, not supplied).
  3. Bind one row to a **field** of the source note; set its action to `call`; leave another row unbound.
  4. Save -> exactly one cheatsheet note exists, subject `Cheatsheet:{id}`.
  5. Reload from a **fresh** repository + resolver instance (nothing cached).
  6. Open the wallet -> the card appears in its group; a title search finds it.
  7. Open the detail -> the bound row resolves to the real value; the unbound row shows `—`.
  8. Tap the `call` value -> the injected launcher receives `(ValueAction.call, value)`.
  9. Edit -> change the title -> save -> still exactly one card, **same id**, new title.
  10. Delete -> the wallet is empty and the note is gone from the catalog.
- [ ] **Step 2: Run red -> green.** Fix whatever seam it exposes.
- [ ] **Step 3: Run the FULL `flutter test` (all green) + `flutter analyze` clean.**
- [ ] **Step 4: Commit** — `git commit -m "test(cheatsheet): end-to-end acceptance"`

---

## Self-Review (author checklist — completed, rev 2)

- **Spec coverage:** entities/codec (T1–T2) · note-content storage (T3) · field/section/whole resolution (T4–T5) · cross-device references (T6) · templates (T7) · list+designer states (T8–T9) · actionable values (T10, T14) · source picker/designer/wallet/detail (T11–T14) · nav (T15) · acceptance (T16). Roadmap/Phase-2 (image/ID + protection), `quickAccess`, `sortOrder`/reordering, and the backend `/v1/cheatsheets` module are **out of this plan** (explicitly deferred). ✓
- **Spec correction encoded:** `field` binding uses **JSON-path introspection** of note content (no catalog schema exists client-side) — Global Constraints + T4. The spec's "reads the note's schema" wording is superseded; the spec's value-action inference line is already reconciled to "explicit, no inference". **Flag to the human:** update the spec's Data-model note to say JSON-path introspection when convenient.
- **Type consistency:** `CheatsheetCard/Row/Source`, `SourceGranularity{field,section,whole}`, `ValueAction{call,map,none}`, `CheatsheetCodec`, `NotePieceExtractor`, `CheatsheetResolver`/`ResolvedValue`, `ICheatsheetRepository`, `cheatsheetsStateProvider`, `cheatsheetEditorProvider`, `cheatsheetIdGenProvider`, `cheatsheetResolverProvider`, `launchActionProvider`, `cheatsheetOpenSourceProvider` consistent across tasks. ✓
- **API surface verified against the tree** (2026-07-26): `getNotes -> PageList` with `.items`/`.meta.totalPages`, `HmmNoteCreate/Update` field lists, `getOrCreateCatalog`, `generateUuid()`. ✓
- **Riverpod 3.0.3 / sealed WidgetRef / `.value ??`** honored in every state + widget task. ✓
- **Never-crash resolution** (unbound/missing/malformed/one-bad-row) covered in T2/T4/T5/T6/T14. ✓
- **No silent truncation:** T3 pages to exhaustion with a page-boundary test; T11 paginates/searches. ✓

## Defect-review provenance

Source: `Obsidian: HomeMadeMessage/Design Defect/2026-07-26 Cheatsheet Cards v1 plan defects`. Scope calls made by the human: **defer `quickAccess` + `sortOrder`**; **lightweight field filter now, adapter registry as v2**.

| # | Defect | Resolution | Where |
| --- | --- | --- | --- |
| 1 | Cross-device reference test absent | Dedicated mandatory integration task, two real DBs, differing int ids, late-arriving source | T6 |
| 2 | Quick Access stored but never surfaced | `quickAccess` **removed from v1** (entity, codec, editor, designer) | T1, T2, T7, T9, T12 |
| 3 | Existing-card editing incomplete | `load()` + edit route + no-duplication test | T9, T12, T15 |
| 4 | Ordering stored but not implemented | `sortOrder` **removed**; deterministic title→id ordering instead | T1, T13 |
| 5 | Subject conflicts with the contract | `subject: 'Cheatsheet:${card.id}'` + rename test | T3 |
| 6 | Card UUID generation unspecified | `cheatsheetIdGenProvider` (`generateUuid`), minted in `startFromTemplate`, preserved on edit | T9 |
| 7 | Wallet filter/search untested | Case-insensitive search, tag semantics, combined filter, empty state, tag normalization | T13 |
| 8 | Detail interaction coverage incomplete | call/map/open-source/unbound/missing/section/whole/launch-failure tests via injected adapters | T14 |
| 9 | Value-action inference inconsistent | Explicit actions only; spec reconciled (already committed) | Global, T12 |
| 10 | Raw JSON introspection too permissive | Internal/audit key filter on the *offer* surface; resolution unrestricted; adapter registry documented as v2 | T4 |
| 11 | Pagination can hide cards | Page-until-exhausted + boundary test; picker paginates/searches | T3, T11 |
| 12 | Codec tolerance overstated | `schemaVersion`, per-row defensive decode, tag coercion, typed-scalar fallbacks | T2 |

## Notes for the executor

Tasks 1–10 are headless and fully TDD'd (complete code given for T1–T5). T6 and T16 are test-only and are the two that prove the design rather than a unit. Tasks 11–14 are widget-heavy — the plan gives exact behavior, interfaces, provider wiring, and the existing files to mirror (`automobile_records/presentation/screens/service_record_form_screen.dart`, `notes/presentation/widgets/catalog_filter_sheet.dart`, `notes/presentation/widgets/note_markdown_body.dart`, dashboard/router tests). Where the real accessors differ from a snippet, **follow the tree and adapt** (flag DONE_WITH_CONCERNS if a pattern can't be matched cleanly). Each task ends green + `flutter analyze` clean; run the full suite at T15 and T16.
