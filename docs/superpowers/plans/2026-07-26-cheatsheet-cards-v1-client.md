# Cheatsheet Cards — v1 (Client) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the **client-side** Cheatsheet feature (hmm_console): create read-only "wallet" cards whose rows reference a *piece of any note* (field / section / whole) and render live, stored as note-content.

**Architecture:** A `CheatsheetCard` domain entity is serialized into an `HmmNote`'s `content` (envelope `{"note":{"content":{"Cheatsheet":{...}}}}`) under a fixed `Hmm.Cheatsheet` catalog — mirroring `LocalGasLogRepository`. A `CheatsheetResolver` reads each row's referenced note by `uuid` and extracts the piece (field via JSON-path introspection, section via markdown heading, whole via content). Riverpod `AsyncNotifier`s drive a template-first designer, a wallet screen, and a read-only detail with tap-to-call/Maps.

**Tech Stack:** Dart/Flutter, Riverpod 3.0.3, Drift (in-memory for tests), GoRouter, `url_launcher`.

**Spec:** `docs/superpowers/specs/2026-07-23-cheatsheet-cards-design.md`. **Backend `/v1/cheatsheets` + cloudApi repo are a SEPARATE follow-up plan** — this plan is the local-first client (works in `DataMode.local`/`cloudStorage`).

## Global Constraints

- **Riverpod 3.0.3:** read async provider values with `.value ?? <default>` — **never** `.valueOrNull`. `WidgetRef` is `sealed` — never faked in tests; override the real Notifier via a fixed subclass + `overrideWith(() => Sub())`, or `overrideWithValue(x)` for plain `Provider<T>`.
- **Storage envelope:** every cheatsheet note's `content` is `jsonEncode({'note': {'content': {'Cheatsheet': <cardJson>}}})` — mirrors `LocalGasLogRepository._serializeGasLog`. Deserialize with `jsonDecode` in a try/catch that returns `null` on any failure.
- **Fixed catalog:** `const cheatsheetCatalogName = 'Hmm.CheatsheetMan.Cheatsheet';` obtained via `catalogRepo.getOrCreateCatalog(cheatsheetCatalogName, '{}')`. (3-segment name so `CatalogPalette.domainKeyFor` groups it as its own "Cheatsheet" domain.)
- **No catalog field-schema exists** in the client (the `schema` column is never parsed). `field`-granularity binding is done by **introspecting the referenced note's content JSON** into leaf paths — NOT by reading a schema. `locator` for a field is a **dotted JSON path into the inner content map** (e.g. `GasLog.station`).
- **Tags + wallet group live in the card JSON** (the `HmmNote` model has no `tags` field). Never use the note-tag system for these.
- **Stable references:** a row references its source note by **`HmmNote.uuid`** (cross-device stable), never the local int `id`.
- **Never crash on bad references:** unbound row, missing note, missing field/section → a muted placeholder, never an exception.
- `flutter analyze` clean after every task. Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## File Structure

- `lib/features/cheatsheet/domain/entities/cheatsheet_source.dart` — `SourceGranularity`, `ValueAction`, `CheatsheetSource` (T1)
- `lib/features/cheatsheet/domain/entities/cheatsheet_row.dart` — `CheatsheetRow` (T1)
- `lib/features/cheatsheet/domain/entities/cheatsheet_card.dart` — `CheatsheetCard` (T1)
- `lib/features/cheatsheet/data/cheatsheet_codec.dart` — card <-> JSON map (T2)
- `lib/core/data/local/local_cheatsheet_repository.dart` — CRUD over notes (T3)
- `lib/features/cheatsheet/data/i_cheatsheet_repository.dart` — repo interface (T3)
- `lib/features/cheatsheet/domain/note_piece_extractor.dart` — field-paths + field/section/whole extraction (T4)
- `lib/features/cheatsheet/data/cheatsheet_resolver.dart` — resolve a row -> value (T5)
- `lib/features/cheatsheet/data/cheatsheet_templates.dart` — starter templates (T6)
- `lib/core/data/repository_providers.dart` — add `cheatsheetRepositoryModeProvider` (T3)
- `lib/features/cheatsheet/states/cheatsheets_state.dart` — list `AsyncNotifier` (T7)
- `lib/features/cheatsheet/states/cheatsheet_editor_state.dart` — designer state (T8)
- `lib/core/util/launch_actions.dart` — tel:/maps launcher (T9)
- `lib/features/cheatsheet/presentation/widgets/source_picker.dart` (T10)
- `lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart` (T11)
- `lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart` (T12)
- `lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart` (T13)
- `lib/core/navigation/{route_names,router_config}.dart` + dashboard `_allFunctions` (T14)
- Tests mirror each under `test/`.

---

### Task 1: Domain entities

**Files:**
- Create: `lib/features/cheatsheet/domain/entities/cheatsheet_source.dart`, `.../cheatsheet_row.dart`, `.../cheatsheet_card.dart`
- Test: `test/features/cheatsheet/domain/cheatsheet_card_test.dart`

**Interfaces — Produces:**
- `enum SourceGranularity { field, section, whole }`, `enum ValueAction { call, map, none }`
- `class CheatsheetSource { final String noteUuid; final SourceGranularity kind; final String? locator; }` — value equality + `copyWith`.
- `class CheatsheetRow { final String label; final CheatsheetSource? source; final ValueAction valueAction; final bool openSource; }` — value equality + `copyWith` (with a `clearSource` flag so a bound row can be unbound).
- `class CheatsheetCard { final String id, title, walletGroup; final List<String> tags; final String templateId; final bool protected, quickAccess; final int sortOrder; final List<CheatsheetRow> rows; }` — value equality + `copyWith`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  test('card value-equality + copyWith', () {
    final s = CheatsheetSource(
        noteUuid: 'n1', kind: SourceGranularity.field, locator: 'GasLog.station');
    final r = CheatsheetRow(
        label: 'Station', source: s, valueAction: ValueAction.none, openSource: true);
    final c = CheatsheetCard(
        id: 'c1', title: 'Fuel', walletGroup: 'Vehicle', tags: const ['a'],
        templateId: 'blank', protected: false, quickAccess: false, sortOrder: 0,
        rows: [r]);
    expect(c, equals(c.copyWith()));
    expect(c.copyWith(title: 'X').title, 'X');
    expect(c.copyWith(title: 'X'), isNot(equals(c)));
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
import 'package:collection/collection.dart';
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
    this.quickAccess = false,
    this.sortOrder = 0,
  });
  final String id;
  final String title;
  final String walletGroup;
  final List<String> tags;
  final String templateId;
  final bool protected;
  final bool quickAccess;
  final int sortOrder;
  final List<CheatsheetRow> rows;

  CheatsheetCard copyWith({
    String? id, String? title, String? walletGroup, List<String>? tags,
    String? templateId, bool? protected, bool? quickAccess, int? sortOrder,
    List<CheatsheetRow>? rows,
  }) =>
      CheatsheetCard(
          id: id ?? this.id, title: title ?? this.title,
          walletGroup: walletGroup ?? this.walletGroup, tags: tags ?? this.tags,
          templateId: templateId ?? this.templateId, protected: protected ?? this.protected,
          quickAccess: quickAccess ?? this.quickAccess, sortOrder: sortOrder ?? this.sortOrder,
          rows: rows ?? this.rows);

  static const _eq = ListEquality();
  @override
  bool operator ==(Object o) =>
      o is CheatsheetCard && o.id == id && o.title == title && o.walletGroup == walletGroup &&
      _eq.equals(o.tags, tags) && o.templateId == templateId && o.protected == protected &&
      o.quickAccess == quickAccess && o.sortOrder == sortOrder && _eq.equals(o.rows, rows);
  @override
  int get hashCode => Object.hash(id, title, walletGroup, _eq.hash(tags), templateId,
      protected, quickAccess, sortOrder, _eq.hash(rows));
}
```

- [ ] **Step 4: Run to green** — `flutter test test/features/cheatsheet/domain/cheatsheet_card_test.dart` -> PASS. `flutter analyze`.
- [ ] **Step 5: Commit** — `git add lib/features/cheatsheet/domain test/features/cheatsheet/domain && git commit -m "feat(cheatsheet): domain entities"`

---

### Task 2: Codec (card <-> JSON map)

**Files:** Create `lib/features/cheatsheet/data/cheatsheet_codec.dart`; Test `test/features/cheatsheet/data/cheatsheet_codec_test.dart`

**Interfaces — Consumes** T1 entities. **Produces:** `class CheatsheetCodec { static Map<String,dynamic> toMap(CheatsheetCard c); static CheatsheetCard fromMap(Map<String,dynamic> m); }` — round-trips, tolerates unknown/absent keys, represents an unbound row (`source == null`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_codec.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';

void main() {
  final card = CheatsheetCard(
    id: 'c1', title: 'Claim', walletGroup: 'Vehicle', tags: const ['legal'],
    templateId: 'accidentClaim', protected: false, quickAccess: true, sortOrder: 2,
    rows: [
      CheatsheetRow(label: 'Plate',
          source: CheatsheetSource(noteUuid: 'auto1', kind: SourceGranularity.field, locator: 'AutomobileInfo.plate'),
          valueAction: ValueAction.none, openSource: true),
      const CheatsheetRow(label: 'Unbound', source: null),
    ],
  );

  test('round-trips including an unbound row', () {
    expect(CheatsheetCodec.fromMap(CheatsheetCodec.toMap(card)), equals(card));
  });
  test('tolerates absent optional keys', () {
    final c = CheatsheetCodec.fromMap({'id': 'x', 'title': 'T', 'rows': []});
    expect(c.id, 'x');
    expect(c.walletGroup, 'Ungrouped');
    expect(c.rows, isEmpty);
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
  static Map<String, dynamic> toMap(CheatsheetCard c) => {
        'id': c.id, 'title': c.title, 'walletGroup': c.walletGroup, 'tags': c.tags,
        'templateId': c.templateId, 'protected': c.protected, 'quickAccess': c.quickAccess,
        'sortOrder': c.sortOrder,
        'rows': c.rows.map(_rowToMap).toList(),
      };

  static CheatsheetCard fromMap(Map<String, dynamic> m) => CheatsheetCard(
        id: (m['id'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        walletGroup: (m['walletGroup'] ?? 'Ungrouped') as String,
        tags: ((m['tags'] as List?)?.cast<String>()) ?? const [],
        templateId: (m['templateId'] ?? 'blank') as String,
        protected: (m['protected'] ?? false) as bool,
        quickAccess: (m['quickAccess'] ?? false) as bool,
        sortOrder: (m['sortOrder'] ?? 0) as int,
        rows: ((m['rows'] as List?) ?? const [])
            .map((e) => _rowFromMap((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  static Map<String, dynamic> _rowToMap(CheatsheetRow r) => {
        'label': r.label,
        'valueAction': r.valueAction.name,
        'openSource': r.openSource,
        if (r.source != null) 'source': _srcToMap(r.source!),
      };

  static CheatsheetRow _rowFromMap(Map<String, dynamic> m) => CheatsheetRow(
        label: (m['label'] ?? '') as String,
        source: m['source'] == null
            ? null
            : _srcFromMap((m['source'] as Map).cast<String, dynamic>()),
        valueAction: ValueAction.values
            .firstWhere((v) => v.name == m['valueAction'], orElse: () => ValueAction.none),
        openSource: (m['openSource'] ?? true) as bool,
      );

  static Map<String, dynamic> _srcToMap(CheatsheetSource s) => {
        'noteUuid': s.noteUuid, 'kind': s.kind.name,
        if (s.locator != null) 'locator': s.locator,
      };

  static CheatsheetSource _srcFromMap(Map<String, dynamic> m) => CheatsheetSource(
        noteUuid: (m['noteUuid'] ?? '') as String,
        kind: SourceGranularity.values
            .firstWhere((k) => k.name == m['kind'], orElse: () => SourceGranularity.whole),
        locator: m['locator'] as String?,
      );
}
```

- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): card JSON codec"`

---

### Task 3: Local repository (note-content CRUD)

**Files:**
- Create: `lib/features/cheatsheet/data/i_cheatsheet_repository.dart`, `lib/core/data/local/local_cheatsheet_repository.dart`
- Modify: `lib/core/data/repository_providers.dart` (add `cheatsheetRepositoryModeProvider` — local only for v1; cloudApi throws `UnimplementedError('cheatsheet cloudApi: backend plan')`)
- Test: `test/core/data/local/local_cheatsheet_repository_test.dart`

**Interfaces — Consumes** T1 entities, T2 codec, `IHmmNoteRepository` (`getNoteByUuid`, `getNotes({catalogId})`, `createNote`, `updateNote`, `deleteNote`), `INoteCatalogRepository.getOrCreateCatalog`, `HmmNoteCreate`, `HmmNoteUpdate`. **Produces:**
```dart
abstract interface class ICheatsheetRepository {
  Future<List<CheatsheetCard>> getCards();
  Future<CheatsheetCard?> getCard(String id);           // by card id
  Future<CheatsheetCard> saveCard(CheatsheetCard card); // upsert by id
  Future<void> deleteCard(String id);
}
```

> Read `lib/core/data/local/local_gas_log_repository.dart` first — mirror its structure (catalog constant, envelope serialize/deserialize, note create/update, soft-delete). The cheatsheet note has **no parent** (`parentNoteId: null`). Match on the cheatsheet by the `id` stored in its JSON (list the catalog's notes, decode each, filter). **Verify the exact `IHmmNoteRepository` method names and `PageList` items accessor against the real file and adapt.**

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
  late LocalCheatsheetRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    repo = LocalCheatsheetRepository(noteRepo, LocalNoteCatalogRepository(db));
  });
  tearDown(() => db.close());

  CheatsheetCard sample(String id) => CheatsheetCard(
      id: id, title: 'Claim', walletGroup: 'Vehicle', tags: const [],
      templateId: 'blank', rows: [
        CheatsheetRow(label: 'Plate',
            source: CheatsheetSource(noteUuid: 'n', kind: SourceGranularity.whole)),
      ]);

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
  test('delete removes it', () async {
    await repo.saveCard(sample('c1'));
    await repo.deleteCard('c1');
    expect(await repo.getCard('c1'), isNull);
  });
}
```

- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** the interface file, then `local_cheatsheet_repository.dart` (adapt imports/accessors to the real `IHmmNoteRepository`):

```dart
import 'dart:convert';
import '../../../features/cheatsheet/data/cheatsheet_codec.dart';
import '../../../features/cheatsheet/data/i_cheatsheet_repository.dart';
import '../../../features/cheatsheet/domain/entities/cheatsheet_card.dart';
// import IHmmNoteRepository, HmmNote, HmmNoteCreate, HmmNoteUpdate, INoteCatalogRepository

const cheatsheetCatalogName = 'Hmm.CheatsheetMan.Cheatsheet';

class LocalCheatsheetRepository implements ICheatsheetRepository {
  LocalCheatsheetRepository(this._notes, this._catalogs);
  final IHmmNoteRepository _notes;
  final INoteCatalogRepository _catalogs;

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

  Future<List<HmmNote>> _allNotes() async =>
      (await _notes.getNotes(catalogId: await _catalogId(), pageSize: 500)).items;

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
    final existing = await _noteForCard(card.id);
    if (existing == null) {
      await _notes.createNote(HmmNoteCreate(
          subject: 'Cheatsheet: ${card.title}',
          catalogId: await _catalogId(),
          content: _serialize(card)));
    } else {
      await _notes.updateNote(existing.id,
          HmmNoteUpdate(subject: 'Cheatsheet: ${card.title}', content: _serialize(card)));
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

### Task 4: Note-piece extractor (field paths + extraction)

**Files:** Create `lib/features/cheatsheet/domain/note_piece_extractor.dart`; Test `test/features/cheatsheet/domain/note_piece_extractor_test.dart`

**Interfaces — Produces:**
```dart
class NotePieceExtractor {
  static List<String> fieldPaths(String? noteContent);      // ['GasLog.station','GasLog.price']
  static String? field(String? noteContent, String path);   // value at a dotted path, else null
  static List<String> sectionHeadings(String? markdown);    // markdown heading texts
  static String? section(String? markdown, String heading); // block under a heading, else null
  static String whole(String? noteContent, String? description);
}
```
Malformed JSON -> `[]`/`null` (never throws).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/note_piece_extractor.dart';

const gasNote = '{"note":{"content":{"GasLog":{"station":"Shell","price":1.65,"nested":{"x":"y"}}}}}';
const md = '# Title\nintro\n## Shortcuts\n- dd delete line\n- yy yank\n## Config\nset nu\n';

void main() {
  test('fieldPaths flattens leaf scalars', () {
    expect(NotePieceExtractor.fieldPaths(gasNote),
        containsAll(['GasLog.station', 'GasLog.price', 'GasLog.nested.x']));
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

  static List<String> fieldPaths(String? content) {
    final root = _entityMap(content);
    if (root == null) return const [];
    final out = <String>[];
    void walk(String prefix, Map<String, dynamic> m) {
      for (final e in m.entries) {
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
    final v = await r().resolve(CheatsheetRow(label: 'Plate',
        source: CheatsheetSource(noteUuid: 'auto1', kind: SourceGranularity.field, locator: 'AutomobileInfo.plate')));
    expect(v.text, 'ABC123');
  });
  test('unbound', () async {
    expect((await r().resolve(const CheatsheetRow(label: 'x', source: null))).unbound, isTrue);
  });
  test('missing note', () async {
    expect((await r().resolve(CheatsheetRow(label: 'x',
        source: CheatsheetSource(noteUuid: 'nope', kind: SourceGranularity.whole)))).missing, isTrue);
  });
  test('missing field', () async {
    expect((await r().resolve(CheatsheetRow(label: 'x',
        source: CheatsheetSource(noteUuid: 'auto1', kind: SourceGranularity.field, locator: 'AutomobileInfo.vin')))).missing, isTrue);
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
      SourceGranularity.section => NotePieceExtractor.section(note.description ?? note.content, s.locator ?? ''),
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

### Task 6: Starter templates

**Files:** Create `lib/features/cheatsheet/data/cheatsheet_templates.dart`; Test `test/features/cheatsheet/data/cheatsheet_templates_test.dart`

**Interfaces — Produces:** `class CheatsheetTemplate { final String id, title, walletGroup; final List<String> rowLabels; }`; `class CheatsheetTemplates { static List<CheatsheetTemplate> all; static CheatsheetCard instantiate(CheatsheetTemplate t, String id); }` — instantiated rows are all **unbound**.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_templates.dart';

void main() {
  test('accidentClaim instantiates labeled unbound rows', () {
    final t = CheatsheetTemplates.all.firstWhere((t) => t.id == 'accidentClaim');
    final card = CheatsheetTemplates.instantiate(t, 'c1');
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

### Task 7: List state (`AsyncNotifier`)

**Files:** Create `lib/features/cheatsheet/states/cheatsheets_state.dart`; Test `test/features/cheatsheet/states/cheatsheets_state_test.dart`

**Interfaces — Consumes** `cheatsheetRepositoryModeProvider`. **Produces:** `class CheatsheetsState extends AsyncNotifier<List<CheatsheetCard>> { Future<List<CheatsheetCard>> build(); Future<void> refresh(); Future<void> save(CheatsheetCard); Future<void> remove(String id); }` + `cheatsheetsStateProvider`. Mirror `gas_logs_state.dart`.

- [ ] **Step 1: Write the failing test** — `ProviderContainer(overrides: [cheatsheetRepositoryModeProvider.overrideWithValue(_FakeRepo(...))])`; `await container.read(cheatsheetsStateProvider.future)` returns the repo's cards; after `save`, re-read includes the new card. (`_FakeRepo` implements `ICheatsheetRepository` over an in-memory `Map`.)
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** — `build()` = `await ref.read(cheatsheetRepositoryModeProvider).getCards()`; `save`/`remove` call the repo then `ref.invalidateSelf()`; `refresh` = `ref.invalidateSelf()`.
- [ ] **Step 4: Run green + analyze.**
- [ ] **Step 5: Commit** — `git commit -m "feat(cheatsheet): list state"`

---

### Task 8: Designer editor state

**Files:** Create `lib/features/cheatsheet/states/cheatsheet_editor_state.dart`; Test `test/features/cheatsheet/states/cheatsheet_editor_state_test.dart`

**Interfaces — Produces:** `class CheatsheetEditor extends Notifier<CheatsheetCard>` (its `build()` returns an empty blank card; a `family` or an explicit `load(card)`/`startFromTemplate(templateId, newId)` initializer) with `setTitle`, `setWalletGroup`, `setTags`, `setQuickAccess`, `addRow(String label)`, `removeRow(int)`, `bindRow(int, CheatsheetSource)`, `unbindRow(int)`, `reorderRow(int,int)`, `Future<void> commit(WidgetRef/Ref ref)` -> `ref.read(cheatsheetsStateProvider.notifier).save(state)`. Partial binding allowed.

- [ ] **Step 1: Write the failing test** — `startFromTemplate('accidentClaim', 'c1')` yields unbound rows; `bindRow(0, src)` sets row 0's source and leaves the rest unbound; `commit` calls an overridden list-state `save` with the working card (assert via a fixed-subclass `CheatsheetsState` capturing the arg).
- [ ] **Step 2–5:** implement (pure `state = state.copyWith(rows: ...)` manipulation; `commit` delegates), green, analyze, commit `feat(cheatsheet): designer editor state`.

---

### Task 9: Launch actions (tel: / maps:)

**Files:** Create `lib/core/util/launch_actions.dart`; Test `test/core/util/launch_actions_test.dart`

**Interfaces — Produces:** `Uri telUri(String phone)`, `Uri mapsUri(String address)`, `Future<void> launchAction(ValueAction action, String value)` (wraps `launchUrl(..., mode: LaunchMode.externalApplication)`, mirroring `note_markdown_body.dart`). Keep URI building pure + unit-tested; the `launchUrl` call is a thin wrapper (not unit-tested).

- [ ] **Step 1: test** — `telUri('(555) 123-4567').toString() == 'tel:5551234567'`; `mapsUri('1 Main St').toString()` contains `maps.apple.com/?q=1%20Main%20St` (use `Uri.encodeComponent`).
- [ ] **Step 2–5:** implement, green, analyze, commit `feat(cheatsheet): tel/maps launch helpers`.

---

### Task 10: Source picker widget

**Files:** Create `lib/features/cheatsheet/presentation/widgets/source_picker.dart`; Test `test/features/cheatsheet/presentation/source_picker_test.dart`

**Behavior:** a modal returning a `CheatsheetSource?`. Step 1: choose a note (searchable list via `hmmNoteRepositoryProvider.getNotes` / `watchNotes` — reuse the existing notes-list idiom). Step 2: choose granularity — if `NotePieceExtractor.fieldPaths(note.content)` non-empty, show **field** options (the dotted paths); if `sectionHeadings(note.description ?? note.content)` non-empty, show **section** options; always offer **Whole**. Returns `CheatsheetSource(noteUuid: note.uuid, kind: ..., locator: ...)`.

- [ ] **Step 1: widget test** — override the note repo to return one structured note; drive the picker to a field selection; assert the returned source `(kind: field, locator: '<path>', noteUuid: '<uuid>')`. `ProviderScope` overrides only; never fake `WidgetRef`.
- [ ] **Step 2–5:** implement following the bottom-sheet idiom (`catalog_filter_sheet.dart`) + notes list; green, analyze, commit `feat(cheatsheet): source picker`.

---

### Task 11: Designer screen

**Files:** Create `lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart`; Test `test/features/cheatsheet/presentation/cheatsheet_designer_screen_test.dart`

**Behavior:** on create, a template chooser (`CheatsheetTemplates.all`); then editable rows (label + a bound-source summary, or "Tap to bind" -> opens T10 picker -> `editor.bindRow`); title/walletGroup/tags/quickAccess fields; reorder/add/remove rows; a **Save** that calls `editor.commit`. Mirror `service_record_form_screen.dart`. Uses `cheatsheetEditorProvider` (T8).

- [ ] **Step 1: widget test** — start from `accidentClaim`; assert labeled rows render "Tap to bind"; inject a picker result binding row 0; tap Save; assert the (overridden) list-state `save` received a card with row 0 bound and the rest unbound (partial save).
- [ ] **Step 2–5:** implement, green, analyze, commit `feat(cheatsheet): designer screen`.

---

### Task 12: Wallet screen

**Files:** Create `lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart`; Test `test/features/cheatsheet/presentation/cheatsheet_wallet_screen_test.dart`

**Behavior:** `ref.watch(cheatsheetsStateProvider)` -> `AsyncValue.when`; group `.value ?? const []` by `walletGroup` into labeled stacks; a tag filter/search; tap a card -> push detail (T13); a `+` -> designer (T11). Handle empty/loading/error.

- [ ] **Step 1: widget test** — override list state with two cards in "Vehicle"/"Health"; assert both group headers + titles render; tapping a card pushes the detail route.
- [ ] **Step 2–5:** implement, green, analyze, commit `feat(cheatsheet): wallet screen`.

---

### Task 13: Detail screen (live, actionable)

**Files:** Create `lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart`; Test `test/features/cheatsheet/presentation/cheatsheet_detail_screen_test.dart`

**Behavior:** add `final cheatsheetResolverProvider = Provider((ref) => CheatsheetResolver(ref.watch(hmmNoteRepositoryProvider)));`. For the card, resolve each row (a `FutureBuilder`/`AsyncNotifier` per row) -> label -> value, muted "—" when `unbound`, "source removed" when `missing`; if `valueAction == call/map`, the value is tappable -> `launchAction` (T9); an "open source" affordance when `openSource` (navigate to the source note by uuid). Read-only; an Edit action routes to the designer.

- [ ] **Step 1: widget test** — override the resolver-backing note repo so row 0 resolves to "ABC123" and row 1's note is missing; assert "ABC123" renders and row 1 shows "source removed"; a `call` row's value is inside a tappable (assert a fake `launchAction` invoked, e.g. via an injected callback provider).
- [ ] **Step 2–5:** implement, green, analyze, commit `feat(cheatsheet): detail screen`.

---

### Task 14: Navigation + entry point

**Files:** Modify `lib/core/navigation/route_names.dart` (+`cheatsheets`, `cheatsheetCreate`, `cheatsheetDetail`), `lib/core/navigation/router_config.dart` (GoRoute tree: `cheatsheets` -> wallet, `new` -> designer, `:id` -> detail), `lib/features/dashboard/presentation/screens/dashboard_screen.dart` (`_allFunctions` tile `AppFunction(icon: Icons.style_outlined, title: 'Cheatsheets', description: 'Quick-reference cards', route: 'cheatsheets')` + `case 'cheatsheets': context.pushNamed(RouterNames.cheatsheets.name);`).

- [ ] **Step 1: test** — a router test that navigating `cheatsheets` builds `CheatsheetWalletScreen`; a dashboard test asserting the Cheatsheets tile exists and its `case` pushes the route (follow existing dashboard/router tests).
- [ ] **Step 2: Run to green.**
- [ ] **Step 3: Run the FULL `flutter test` (all green) + `flutter analyze` clean.**
- [ ] **Step 4: Commit** — `git commit -m "feat(cheatsheet): navigation + dashboard entry"`

---

## Self-Review (author checklist — completed)

- **Spec coverage:** entities/codec (T1–T2) · note-content storage (T3) · field/section/whole resolution (T4–T5) · templates (T6) · list+designer states (T7–T8) · actionable values (T9,T13) · source picker/designer/wallet/detail (T10–T13) · nav (T14). Roadmap/Phase-2 (image/ID + protection) and the backend `/v1/cheatsheets` module are **out of this plan** (noted). ✓
- **Spec correction encoded:** `field` binding uses **JSON-path introspection** of note content (no catalog schema exists client-side) — Global Constraints + T4. **Flag to the human:** the spec's "reads the note's schema" wording is superseded by JSON-path introspection; update the spec's Data-model note when convenient.
- **Type consistency:** `CheatsheetCard/Row/Source`, `SourceGranularity{field,section,whole}`, `ValueAction{call,map,none}`, `CheatsheetCodec`, `NotePieceExtractor`, `CheatsheetResolver`/`ResolvedValue`, `ICheatsheetRepository`, `cheatsheetsStateProvider`, `cheatsheetEditorProvider`, `cheatsheetResolverProvider` consistent across tasks. ✓
- **Riverpod 3.0.3 / sealed WidgetRef / `.value ??`** honored in every state + widget task. ✓
- **Never-crash resolution** (unbound/missing/malformed) covered in T4/T5 tests. ✓

## Notes for the executor

Tasks 1–9 are headless and fully TDD'd (complete code given). Tasks 10–13 are widget-heavy — the plan gives exact behavior, interfaces, provider wiring, and the existing files to mirror (`service_record_form_screen.dart`, `catalog_filter_sheet.dart`, `note_markdown_body.dart`, dashboard/router tests). Where the real `IHmmNoteRepository`/`PageList`/`HmmNoteCreate` accessors differ from the snippets, **follow the tree and adapt** (flag DONE_WITH_CONCERNS if a pattern can't be matched cleanly). Each task ends green + `flutter analyze` clean; run the full suite at T14.

---

## Amendments (AUTHORITATIVE — from the 2026-07-26 plan-defect review)

These supersede the task bodies above wherever they conflict. Apply them when executing (or when regenerating this plan in a fresh session). User scope calls: **defer quickAccess + sortOrder**; **lightweight field filter now, adapter registry later**.

- **A1 — Drop `quickAccess` and `sortOrder` from v1 (defects #2, #4).** Remove both fields from `CheatsheetCard` (T1), the codec (T2), `instantiate` (T6), the editor (T8), and the designer control (T11). Keep `protected` (Phase-2 reserved). The wallet (T12) does not sort by `sortOrder`; use a deterministic order (e.g. `title`, then `id`). Reason: the Quick Access Panel is an action-button registry, not a card surface — card integration is deferred to a later phase.

- **A2 — Stable subject `Cheatsheet:${card.id}` (defect #5).** In `LocalCheatsheetRepository` (T3) write `subject: 'Cheatsheet:${card.id}'` on both create and update (title lives only in the JSON). Add a repo test asserting the created note's `subject == 'Cheatsheet:${card.id}'` and that renaming the card's title does NOT change the subject.

- **A3 — Card ID generation (defect #6).** New-card ids come from the repo's existing `generateUuid()` (`lib/core/util/uuid.dart`) — inject it into the editor (T8): `startFromTemplate(String templateId)` generates a fresh id internally; do NOT take an id from callers in production. Tests may pass a fixed id via an injected `String Function() idGen` (default `generateUuid`). Test: two `startFromTemplate` calls yield distinct ids; **editing an existing card retains its id**.

- **A4 — Edit lifecycle (defect #3).** Editor (T8) gains `load(CheatsheetCard existing)` (sets `state = existing`, preserving `id`). Routes (T14): `cheatsheets` -> wallet, `cheatsheets/new` -> designer(create), `cheatsheets/:id/edit` -> designer(load existing), `cheatsheets/:id` -> detail. Detail's Edit action pushes `:id/edit`. Test (T11): load an existing card, change the title, commit -> the repo `updateNote` path runs, `getCards()` still returns exactly one card with the same id (no duplicate).

- **A5 — Mandatory cross-device resolve test (defect #1).** Add to T5 (or a dedicated task) an integration test using a **real** `LocalHmmNoteRepository` over an in-memory Drift DB: insert a source note with a known `uuid` but a **non-1 local int id** (insert a filler note first so ids differ), build a card referencing that `uuid`, and assert the `CheatsheetResolver` resolves it correctly **by uuid regardless of the int id**; also assert a not-yet-present uuid resolves to `missing` (late-arriving source) and starts resolving once inserted.

- **A6 — Field introspection filters internal keys (defect #10, lightweight).** In `NotePieceExtractor.fieldPaths` (T4), exclude leaf keys that are internal/audit: any segment in `{'_v','id','uuid','authorId','parentNoteId','version'}` or ending in `Date`/`At` (case-insensitive), or matching `RegExp(r'(?:^_|Id$)')`. `field(content, path)` still resolves any explicit path (so already-bound refs keep working). Add tests: an internal key (`_v`, `createdDate`) is NOT offered by `fieldPaths` but `station` is. Document a catalog-keyed `CheatsheetBindingAdapter` registry as the v2 robustness path (out of v1).

- **A7 — No silent pagination cap (defect #11).** `LocalCheatsheetRepository._allNotes` (T3) must page until exhausted (loop `page++` while a full page returns) or use `watchNotes()` filtered by catalog — never a fixed `pageSize: 500` cap. The **source picker** (T10) must paginate/stream + search notes, not cap. Add a T3 page-boundary test (create > one page of cards, assert `getCards()` returns all).

- **A8 — Codec robustness (defect #12).** Add `'schemaVersion': 1` to `CheatsheetCodec.toMap` and read it (default 1) in `fromMap`. Decode field-by-field defensively: wrap each row's decode in a try/catch that drops only the malformed row (not the whole card); coerce `tags` elements to `String` and skip non-strings. Tests: a card with one malformed row decodes the rest; an unknown future `schemaVersion` still decodes known fields; a non-string tag element is skipped.

- **A9 — Wallet filter/search coverage (defect #7).** T12 tests must cover: case-insensitive title/tag search, tag filter semantics (a tag filter shows only cards carrying it), combined title+tag filter, empty-result state, and tag normalization (trim + case-insensitive dedupe when displaying the filter set).

- **A10 — Detail interaction coverage (defect #8).** T13 tests (via injected launch + navigation adapters — e.g. a `launchActionProvider`/`onOpenSource` callback overridable in tests): a `call` value taps -> tel launch; a `map` value taps -> maps launch; an `openSource` row taps -> navigates to the source note by uuid; an unbound row shows "-"; a `missing` row shows "source removed"; `section` and `whole` rows render their text; a launch failure surfaces a message and does not crash.

- **A11 — Value actions are explicit (defect #9).** No inference in v1; the spec's testing note is reconciled to match. (`ValueAction` stays `call`/`map`/`none`, set explicitly in the designer.)

- **A12 — Acceptance test (review recommendation #9).** Add a final end-to-end widget/integration test that creates a card from a template, binds a row, saves, reloads (fresh resolver), opens the detail, resolves + acts on a value, edits + re-saves (same id), and deletes it.

**Net task-count change:** T1/T2/T6/T8/T11/T12/T13/T14 are amended in place; A5 (cross-device) and A12 (acceptance) add two test-focused tasks. Re-run the plan self-review after applying.
