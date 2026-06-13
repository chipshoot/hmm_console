# Cross-Subsystem Note Surfacing (B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a free-form (General) note be attached — via `parentNoteId` — to a specific entity (a car) or a subsystem "anchor" note, surfaced on that target's Notes screen while still appearing in the general notes list.

**Architecture:** `parentNoteId` is the single attachment link. Subsystems are seeded "anchor notes" (catalog `Hmm.System.Subsystem`, a deterministic uuid so each subsystem is one shared record across devices). A generic `AttachedNotesSection` widget surfaces `getNotes(parentNoteId, catalog=General)` and offers Add / Attach-existing / detach. The note keeps the General catalog (so it stays in the general list); being a child of the parent surfaces it on the target's screen. Sync already carries `parentNoteUuid`, so re-linking needs no wire change. cloudStorage + local only; `cloudApi` unaffected.

**Tech Stack:** Flutter + Dart, Drift, Riverpod, go_router. Tests: `flutter_test` + in-memory Drift (`NativeDatabase.memory()`) + `ProviderContainer`/`overrideWith`.

**Reused, already in the codebase (do not recreate):**
- `IHmmNoteRepository` / `LocalHmmNoteRepository(_db, _currentAuthor)` in `lib/core/data/local/local_hmm_note_repository.dart`: `getNotes({int? catalogId, int? parentNoteId, int page=1, int pageSize=20, bool includeDeleted=false}) → Future<PageList<HmmNote>>`, `getNoteById(int)`, `getNoteByUuid(String)`, `createNote(HmmNoteCreate)`, `updateNote`, `deleteNote`, `watchNotes()`. Private `_versionStamp()`; `HmmNoteMapper.fromDriftRow`. Author filter via `_currentAuthor()`.
- `HmmNoteCreate({required String subject, required int catalogId, String? content, int? parentNoteId, String? description, NoteAttachments? attachments})` in `lib/core/data/hmm_note_input.dart`. `createNote` inserts `NotesCompanion.insert(subject:, content: Value(...), authorId:, catalogId: Value(...), parentNoteId: Value(...), ...)` — note: it does NOT currently set `uuid` (relies on the column's `clientDefault(generateUuid)`).
- `HmmNote` (`lib/features/notes/data/models/hmm_note.dart`): `id, uuid, subject, content?, authorId, catalogId?, parentNoteId?, ...`.
- Drift `Notes` table: `uuid` (`text().nullable().clientDefault(generateUuid)`, unique index), `parentNoteId` (`integer().nullable().references(Notes,#id)`), `catalogId` (`integer().nullable().references(NoteCatalogs,#id)`).
- `noteCatalogRepositoryProvider` → `INoteCatalogRepository` (`getCatalogByName`, `createCatalog(NoteCatalogsCompanion)`, `getCatalogs`). `ensureGeneralCatalog(Ref) → Future<NoteCatalog>` + `generalCatalogProvider` in `lib/features/notes/data/general_catalog.dart` (the seeding pattern to mirror).
- `generateUuid()` (v4) in `lib/core/util/uuid.dart`.
- `hmmNoteRepositoryProvider`, `hmmDatabaseProvider` (`lib/core/data/repository_providers.dart`, `database.dart`).
- `MutateNote(this.ref)` + `mutateNoteProvider` in `lib/features/notes/states/mutate_note_state.dart`: `createGeneral({required String subject, String? markdownBody})`, `updateGeneral`, `delete`, `addImage`.
- `notesListStateProvider` / `NotesListData` / `NotesListState.build()` in `lib/features/notes/states/notes_list_state.dart` (reactive: build awaits `_notesStreamProvider.future` (= `watchNotes`) and `_catalogsStreamProvider.future`, returns `NotesListData(all: notes, catalogsById: {...}, ...)`).
- `NoteEditorScreen` (ConsumerStatefulWidget, `_save()`, `build()`) and `NoteDetailScreen` in `lib/features/notes/presentation/screens/`. Routes `/notes/new`, `/notes/:id`, `/notes/:id/edit` in `router_config.dart`; `RouterNames` enum in `route_names.dart`.
- Router `/automobiles/manage/:id` has nested `:id/insurance`, `:id/services`, `:id/scheduled-services` (each `builder` parses `int id = int.parse(state.pathParameters['id']!)`). `AutomobileRecordsSummary(automobileId)` (`lib/features/automobile_records/presentation/widgets/automobile_records_summary.dart`), hosted on `automobile_edit_screen.dart`, renders cards that `context.push('/automobiles/manage/$automobileId/insurance')` etc. **`automobileId` IS the vehicle's note id** (automobiles are stored as notes).

---

## Task 1: Repo — explicit-uuid create, `setParentNote`, `getUnattachedNotes`

**Files:**
- Modify: `lib/core/data/hmm_note_input.dart` (add `uuid` to `HmmNoteCreate`)
- Modify: `lib/core/data/local/local_hmm_note_repository.dart` (honor uuid; add two methods + interface entries)
- Test: `test/core/data/local/local_hmm_note_repository_parent_test.dart`

- [ ] **Step 1: Add `uuid` to `HmmNoteCreate`**

In `lib/core/data/hmm_note_input.dart`, add an optional `uuid` field to `HmmNoteCreate` (constructor + field):

```dart
  const HmmNoteCreate({
    required this.subject,
    required this.catalogId,
    this.content,
    this.parentNoteId,
    this.description,
    this.attachments,
    this.uuid,
  });
```
and add the field near the others:
```dart
  /// Optional explicit stable uuid. When null, the DB assigns a v4 uuid via
  /// the column's clientDefault. Used to seed records with a deterministic id
  /// (e.g. subsystem anchors).
  final String? uuid;
```

- [ ] **Step 2: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository repo;
  late Author author;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final id = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    author = await (db.select(db.authors)..where((a) => a.id.equals(id)))
        .getSingle();
    repo = LocalHmmNoteRepository(db, () async => author);
  });
  tearDown(() => db.close());

  test('createNote honors an explicit uuid', () async {
    // catalogId 0 has no matching catalog row, but the in-memory test db does
    // not enforce the FK, so this is fine for asserting the uuid.
    final note = await repo.createNote(
        const HmmNoteCreate(subject: 'anchor', catalogId: 0, uuid: 'fixed-uuid'));
    expect(note.uuid, 'fixed-uuid');
  });

  test('setParentNote sets then clears parentNoteId and bumps lastModified',
      () async {
    final parent = await repo.createNote(
        const HmmNoteCreate(subject: 'parent', catalogId: 0));
    final child = await repo.createNote(
        const HmmNoteCreate(subject: 'child', catalogId: 0));

    final linked = await repo.setParentNote(child.id, parent.id);
    expect(linked.parentNoteId, parent.id);

    final detached = await repo.setParentNote(child.id, null);
    expect(detached.parentNoteId, isNull);
  });

  test('getUnattachedNotes returns only null-parent notes of the catalog',
      () async {
    // Seed a catalog to scope by.
    final catId = await db.into(db.noteCatalogs).insert(
        NoteCatalogsCompanion.insert(name: 'General', schema: '{}'));
    final a = await repo
        .createNote(HmmNoteCreate(subject: 'free', catalogId: catId));
    final parent = await repo
        .createNote(HmmNoteCreate(subject: 'parent', catalogId: catId));
    await repo.createNote(HmmNoteCreate(
        subject: 'attached', catalogId: catId, parentNoteId: parent.id));

    final unattached = await repo.getUnattachedNotes(catId);
    final subjects = unattached.map((n) => n.subject).toSet();
    expect(subjects, contains('free'));
    expect(subjects, contains('parent')); // parent itself has null parent
    expect(subjects, isNot(contains('attached')));
    expect(a.id, isNotNull);
  });
}
```

> Note on `catalogId: 0`: the `catalogId` column is nullable with an FK to `NoteCatalogs`; SQLite does not enforce the FK here (foreign_keys pragma off by default in the in-memory test db), so a non-existent catalog id is fine for the uuid/parent assertions. The `getUnattachedNotes` test uses a real seeded catalog.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/data/local/local_hmm_note_repository_parent_test.dart`
Expected: FAIL — `setParentNote`/`getUnattachedNotes` not defined (and uuid not honored).

- [ ] **Step 4: Honor uuid + add the two methods**

In `lib/core/data/local/local_hmm_note_repository.dart`:

(a) In `createNote`, add `uuid` to the `NotesCompanion.insert(...)` call (place it with the other fields):
```dart
          uuid: input.uuid == null ? const Value.absent() : Value(input.uuid),
```

(b) Add to the `IHmmNoteRepository` interface (after `deleteNote`):
```dart
  /// Re-link a note to a new parent (or detach with null). Mutates
  /// parentNoteId — the one field updateNote intentionally won't touch —
  /// bumping lastModifiedDate so sync collects it; the wire already carries
  /// parentNoteUuid.
  Future<HmmNote> setParentNote(int id, int? parentNoteId);

  /// Notes of [catalogId] with no parent (attachable candidates).
  Future<List<HmmNote>> getUnattachedNotes(int catalogId);
```

(c) Add to `LocalHmmNoteRepository` (after `deleteNote`, before `_versionStamp`):
```dart
  @override
  Future<HmmNote> setParentNote(int id, int? parentNoteId) async {
    final author = await _currentAuthor();
    final now = DateTime.now().toUtc();
    await (_db.update(_db.notes)
          ..where((n) => n.id.equals(id) & n.authorId.equals(author.id)))
        .write(NotesCompanion(
      parentNoteId: Value(parentNoteId),
      lastModifiedDate: Value(now),
      version: Value(_versionStamp()),
    ));
    return (await getNoteById(id))!;
  }

  @override
  Future<List<HmmNote>> getUnattachedNotes(int catalogId) async {
    final author = await _currentAuthor();
    final rows = await (_db.select(_db.notes)
          ..where((n) =>
              n.authorId.equals(author.id) &
              n.deletedAt.isNull() &
              n.parentNoteId.isNull() &
              n.catalogId.equals(catalogId))
          ..orderBy([(n) => OrderingTerm.desc(n.createDate)]))
        .get();
    return rows.map(HmmNoteMapper.fromDriftRow).toList();
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/data/local/local_hmm_note_repository_parent_test.dart`
Expected: PASS

- [ ] **Step 6: Update existing fakes that implement `IHmmNoteRepository`**

Adding interface methods breaks fakes that `implements IHmmNoteRepository`. Find them:
Run: `grep -rl "implements IHmmNoteRepository" test`
For EACH fake found (e.g. in `test/features/notes/states/mutate_note_state_test.dart`), add:
```dart
  @override
  Future<HmmNote> setParentNote(int id, int? parentNoteId) async =>
      throw UnimplementedError();
  @override
  Future<List<HmmNote>> getUnattachedNotes(int catalogId) async => const [];
```
Then run `flutter analyze` and `flutter test test/features/notes` to confirm nothing else broke.

- [ ] **Step 7: Commit**

```bash
git add lib/core/data/hmm_note_input.dart lib/core/data/local/local_hmm_note_repository.dart test/core/data/local/local_hmm_note_repository_parent_test.dart test/features/notes/states/mutate_note_state_test.dart
git commit -m "feat(notes): explicit-uuid create + setParentNote/getUnattachedNotes"
```

---

## Task 2: Subsystem anchors

**Files:**
- Create: `lib/features/notes/data/subsystem_anchor.dart`
- Test: `test/features/notes/data/subsystem_anchor_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('subsystemAnchorUuid is deterministic', () {
    expect(subsystemAnchorUuid('automobile'),
        subsystemAnchorUuid('automobile'));
    expect(subsystemAnchorUuid('automobile'),
        isNot(subsystemAnchorUuid('health')));
  });

  test('ensureSubsystemAnchor is idempotent (one anchor, stable uuid)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
        overrides: [hmmDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);

    final first = await ensureSubsystemAnchor(container,
        key: 'automobile', displayName: 'Automobile');
    final second = await ensureSubsystemAnchor(container,
        key: 'automobile', displayName: 'Automobile');

    expect(first.uuid, subsystemAnchorUuid('automobile'));
    expect(second.id, first.id); // not duplicated
    final anchors = await container.read(subsystemAnchorsProvider.future);
    expect(anchors.map((a) => a.subject), ['Automobile']);
  });
}
```

> `ensureSubsystemAnchor` takes a `ProviderContainer`-or-`Ref`. In the test we pass the `container` and call it as `ensureSubsystemAnchor(container, ...)`; in production it's called with a `Ref`. Implement the parameter type as `Ref` and pass `container` (which exposes `read`) — Riverpod's `ProviderContainer` is not a `Ref`, so instead the test should call it via a provider. To keep it simple, implement `ensureSubsystemAnchor(Ref ref, ...)` and in the test read it through `automobileAnchorProvider` (Step 3 defines that). Replace the second test body's two `ensureSubsystemAnchor(container, ...)` calls with `container.read(automobileAnchorProvider.future)` called twice.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/data/subsystem_anchor_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement `subsystem_anchor.dart`**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/local/database.dart';
import '../../../core/data/repository_providers.dart';

/// Catalog marking subsystem anchor notes. Anchors are infrastructure notes a
/// General note can be attached to (parentNoteId) for subsystem-level surfacing.
const String kSubsystemAnchorCatalogName = 'Hmm.System.Subsystem';
const String _anchorSchema = '{"type":"subsystem"}';

/// Deterministic, stable, cross-device uuid for a subsystem's anchor note.
/// A literal keyed by subsystem — every device produces the same id, so the
/// anchor is one shared record (sync dedups by uuid) and child notes resolve
/// to a single anchor everywhere.
String subsystemAnchorUuid(String key) => 'hmm-subsystem-$key';

Future<int> _ensureAnchorCatalogId(Ref ref) async {
  final repo = ref.read(noteCatalogRepositoryProvider);
  final existing = await repo.getCatalogByName(kSubsystemAnchorCatalogName);
  if (existing != null) return existing.id;
  final created = await repo.createCatalog(NoteCatalogsCompanion.insert(
    name: kSubsystemAnchorCatalogName,
    schema: _anchorSchema,
  ));
  return created.id;
}

/// Ensure the anchor catalog + the anchor note for [key] exist (idempotent by
/// the deterministic uuid). Returns the anchor note.
Future<HmmNote> ensureSubsystemAnchor(
  Ref ref, {
  required String key,
  required String displayName,
}) async {
  final noteRepo = ref.read(hmmNoteRepositoryProvider);
  final uuid = subsystemAnchorUuid(key);
  final existing = await noteRepo.getNoteByUuid(uuid);
  if (existing != null) return existing;
  final catalogId = await _ensureAnchorCatalogId(ref);
  return noteRepo.createNote(HmmNoteCreate(
    subject: displayName,
    catalogId: catalogId,
    uuid: uuid,
  ));
}

/// The Automobile subsystem anchor (the reference subsystem). Future
/// subsystems add their own analogous provider.
final automobileAnchorProvider = FutureProvider<HmmNote>((ref) =>
    ensureSubsystemAnchor(ref, key: 'automobile', displayName: 'Automobile'));

/// All subsystem anchor notes.
final subsystemAnchorsProvider = FutureProvider<List<HmmNote>>((ref) async {
  // Ensure the reference anchor exists, then list by the anchor catalog.
  await ref.watch(automobileAnchorProvider.future);
  final catalogRepo = ref.read(noteCatalogRepositoryProvider);
  final anchorCatalog =
      await catalogRepo.getCatalogByName(kSubsystemAnchorCatalogName);
  if (anchorCatalog == null) return [];
  final page = await ref
      .read(hmmNoteRepositoryProvider)
      .getNotes(catalogId: anchorCatalog.id, pageSize: 200);
  return page.items;
});
```

Apply the test note from Step 1: in the test, replace the two `ensureSubsystemAnchor(container, ...)` calls with `await container.read(automobileAnchorProvider.future)` (called twice), and `first`/`second` are those results.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/data/subsystem_anchor_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/data/subsystem_anchor.dart test/features/notes/data/subsystem_anchor_test.dart
git commit -m "feat(notes): subsystem anchor notes (deterministic uuid, Automobile seed)"
```

---

## Task 3: MutateNote attach helpers

**Files:**
- Modify: `lib/features/notes/states/mutate_note_state.dart`
- Test: `test/features/notes/states/mutate_note_attach_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await db.select(db.authors).getSingle();
    container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      localHmmNoteRepositoryProvider
          .overrideWithValue(LocalHmmNoteRepository(db, () async => author)),
    ]);
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('createGeneral with a parent sets parentNoteId', () async {
    final parentId = await db.into(db.notes).insert(
        NotesCompanion.insert(subject: 'P', authorId: 1));
    final note = await container
        .read(mutateNoteProvider)
        .createGeneral(subject: 'child', parentNoteId: parentId);
    expect(note.parentNoteId, parentId);
  });

  test('attachExisting then detach', () async {
    final parentId = await db.into(db.notes).insert(
        NotesCompanion.insert(subject: 'P', authorId: 1));
    final note = await container
        .read(mutateNoteProvider)
        .createGeneral(subject: 'free');
    expect(note.parentNoteId, isNull);

    final attached =
        await container.read(mutateNoteProvider).attachExisting(note.id, parentId);
    expect(attached.parentNoteId, parentId);

    final detached =
        await container.read(mutateNoteProvider).detachNote(note.id);
    expect(detached.parentNoteId, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/states/mutate_note_attach_test.dart`
Expected: FAIL — `createGeneral` has no `parentNoteId`; `attachExisting`/`detachNote` undefined.

- [ ] **Step 3: Extend `MutateNote`**

In `lib/features/notes/states/mutate_note_state.dart`, change `createGeneral` to accept an optional `parentNoteId`, and add `attachExisting`/`detachNote`. Replace the `createGeneral` method and add the two methods:

```dart
  Future<HmmNote> createGeneral({
    required String subject,
    String? markdownBody,
    int? parentNoteId,
  }) async {
    final catalog = await ensureGeneralCatalog(ref);
    final note = await ref.read(hmmNoteRepositoryProvider).createNote(
          HmmNoteCreate(
            subject: subject.trim(),
            catalogId: catalog.id,
            content: markdownBody,
            parentNoteId: parentNoteId,
          ),
        );
    return note;
  }

  /// Re-link an existing note onto [parentNoteId].
  Future<HmmNote> attachExisting(int noteId, int parentNoteId) =>
      ref.read(hmmNoteRepositoryProvider).setParentNote(noteId, parentNoteId);

  /// Detach a note (back to standalone).
  Future<HmmNote> detachNote(int noteId) =>
      ref.read(hmmNoteRepositoryProvider).setParentNote(noteId, null);
```

(`ensureGeneralCatalog` is already imported in this file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/states/mutate_note_attach_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/states/mutate_note_state.dart test/features/notes/states/mutate_note_attach_test.dart
git commit -m "feat(notes): MutateNote create-with-parent + attach/detach helpers"
```

---

## Task 4: `attachedNotesProvider`

**Files:**
- Create: `lib/features/notes/states/attached_notes_state.dart`
- Test: `test/features/notes/states/attached_notes_state_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('attachedNotesProvider lists General notes under a parent', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    final author = await db.select(db.authors).getSingle();
    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      localHmmNoteRepositoryProvider
          .overrideWithValue(LocalHmmNoteRepository(db, () async => author)),
    ]);
    addTearDown(container.dispose);

    final parentId = await db.into(db.notes).insert(
        NotesCompanion.insert(subject: 'parent', authorId: 1));
    await container
        .read(mutateNoteProvider)
        .createGeneral(subject: 'attached', parentNoteId: parentId);
    await container.read(mutateNoteProvider).createGeneral(subject: 'free');

    final attached =
        await container.read(attachedNotesProvider(parentId).future);
    expect(attached.map((n) => n.subject), ['attached']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/states/attached_notes_state_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../data/general_catalog.dart';
import '../data/models/hmm_note.dart';

/// General notes attached to a given parent note (an entity or a subsystem
/// anchor). The list the AttachedNotesSection renders.
final attachedNotesProvider =
    FutureProvider.family<List<HmmNote>, int>((ref, parentId) async {
  final general = await ensureGeneralCatalog(ref);
  final page = await ref.read(hmmNoteRepositoryProvider).getNotes(
        parentNoteId: parentId,
        catalogId: general.id,
        pageSize: 500,
      );
  return page.items;
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/states/attached_notes_state_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/states/attached_notes_state.dart test/features/notes/states/attached_notes_state_test.dart
git commit -m "feat(notes): attachedNotesProvider (general notes under a parent)"
```

---

## Task 5: `AttachedNotesSection` widget

**Files:**
- Create: `lib/features/notes/presentation/widgets/attached_notes_section.dart`
- Test: `test/features/notes/presentation/attached_notes_section_test.dart`

- [ ] **Step 1: Implement the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/repository_providers.dart';
import '../../data/general_catalog.dart';
import '../../data/models/hmm_note.dart';
import '../../states/attached_notes_state.dart';
import '../../states/mutate_note_state.dart';

/// Reusable "Notes" section for any parent note (an entity or a subsystem
/// anchor). Lists attached General notes and offers Add / Attach existing /
/// Detach. Drop it on any host screen with the parent's note id.
class AttachedNotesSection extends ConsumerWidget {
  const AttachedNotesSection({
    super.key,
    required this.parentId,
    this.title = 'Notes',
  });

  final int parentId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attachedNotesProvider(parentId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Attach existing note',
                icon: const Icon(Icons.attach_file),
                onPressed: () => _attachExisting(context, ref),
              ),
              IconButton(
                tooltip: 'Add note',
                icon: const Icon(Icons.add),
                onPressed: () => context.push('/notes/new?parent=$parentId'),
              ),
            ],
          ),
        ),
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(16), child: Text('Failed: $e')),
          data: (notes) => notes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16), child: Text('No notes yet'))
              : Column(
                  children: [
                    for (final n in notes)
                      ListTile(
                        title: Text(n.subject,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => context.push('/notes/${n.id}'),
                        trailing: IconButton(
                          tooltip: 'Detach',
                          icon: const Icon(Icons.link_off),
                          onPressed: () async {
                            await ref
                                .read(mutateNoteProvider)
                                .detachNote(n.id);
                            ref.invalidate(attachedNotesProvider(parentId));
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _attachExisting(BuildContext context, WidgetRef ref) async {
    final general = await ref.read(generalCatalogProvider.future);
    final candidates = await ref
        .read(hmmNoteRepositoryProvider)
        .getUnattachedNotes(general.id);
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<HmmNote>(
      context: context,
      builder: (_) => SafeArea(
        child: candidates.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No unattached notes'))
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final n in candidates)
                    ListTile(
                      title: Text(n.subject),
                      onTap: () => Navigator.of(context).pop(n),
                    ),
                ],
              ),
      ),
    );
    if (picked == null) return;
    await ref.read(mutateNoteProvider).attachExisting(picked.id, parentId);
    ref.invalidate(attachedNotesProvider(parentId));
  }
}
```

- [ ] **Step 2: Write the widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';

void main() {
  testWidgets('lists attached notes; empty state otherwise', (tester) async {
    final note = HmmNote(
        id: 1, uuid: 'u1', subject: 'Oil change receipt', authorId: 1,
        catalogId: 1, createDate: DateTime(2026, 1, 1));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(7).overrideWith((ref) async => [note]),
      ],
      child: const MaterialApp(
          home: Scaffold(body: AttachedNotesSection(parentId: 7))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Oil change receipt'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test + analyze**

Run: `flutter test test/features/notes/presentation/attached_notes_section_test.dart`
Expected: PASS
Run: `flutter analyze lib/features/notes`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/notes/presentation/widgets/attached_notes_section.dart test/features/notes/presentation/attached_notes_section_test.dart
git commit -m "feat(notes): AttachedNotesSection widget"
```

---

## Task 6: Exclude anchor catalog from the general notes list

**Files:**
- Modify: `lib/features/notes/states/notes_list_state.dart`
- Test: `test/features/notes/states/notes_list_excludes_anchors_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('general notes list excludes subsystem anchor notes', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    final author = await db.select(db.authors).getSingle();
    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      localHmmNoteRepositoryProvider
          .overrideWithValue(LocalHmmNoteRepository(db, () async => author)),
    ]);
    addTearDown(container.dispose);
    container.listen(notesListStateProvider, (_, __) {});

    // Seed the Automobile anchor (an anchor-catalog note) + a real general note.
    await container.read(automobileAnchorProvider.future);
    final general = await db.into(db.noteCatalogs).insert(
        NoteCatalogsCompanion.insert(name: 'General', schema: '{}'));
    await db.into(db.notes).insert(NotesCompanion.insert(
        subject: 'grocery', authorId: 1, catalogId: Value(general)));

    // Allow the reactive stream to settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final data = await container.read(notesListStateProvider.future);
    final subjects = data.all.map((n) => n.subject).toSet();
    expect(subjects, contains('grocery'));
    expect(subjects, isNot(contains('Automobile'))); // anchor excluded
  });
}
```

(`Value` import: add `import 'package:drift/drift.dart' show Value;` to the test.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/states/notes_list_excludes_anchors_test.dart`
Expected: FAIL — the anchor note "Automobile" appears in `data.all`.

- [ ] **Step 3: Exclude the anchor catalog in `build`**

In `lib/features/notes/states/notes_list_state.dart`, add the import:
```dart
import '../data/subsystem_anchor.dart';
```
Replace the `build` method body's `return NotesListData(...)` so it filters out anchor-catalog notes:

```dart
  @override
  Future<NotesListData> build() async {
    final notes = await ref.watch(_notesStreamProvider.future);
    final catalogs = await ref.watch(_catalogsStreamProvider.future);
    final byId = {for (final c in catalogs) c.id: c};
    final anchorCatalogId = catalogs
        .where((c) => c.name == kSubsystemAnchorCatalogName)
        .map((c) => c.id)
        .firstOrNull;
    final visibleNotes = anchorCatalogId == null
        ? notes
        : notes.where((n) => n.catalogId != anchorCatalogId).toList();
    return NotesListData(
      all: visibleNotes,
      catalogsById: byId,
      catalogFilter: _filter,
      sort: _sort,
      query: _query,
    );
  }
```

(`firstOrNull` comes from `package:collection`; if it's not already imported in this file, use `.isEmpty ? null : .first` instead: replace the `anchorCatalogId` line with:
```dart
    final anchorMatches =
        catalogs.where((c) => c.name == kSubsystemAnchorCatalogName);
    final anchorCatalogId =
        anchorMatches.isEmpty ? null : anchorMatches.first.id;
```
Use whichever compiles cleanly under `flutter analyze`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/states/notes_list_excludes_anchors_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/states/notes_list_state.dart test/features/notes/states/notes_list_excludes_anchors_test.dart
git commit -m "feat(notes): hide subsystem anchors from the general notes list"
```

---

## Task 7: Per-vehicle Notes screen + route + entry

**Files:**
- Create: `lib/features/automobile_records/presentation/screens/vehicle_notes_screen.dart`
- Modify: `lib/core/navigation/route_names.dart` (add `vehicleNotes`)
- Modify: `lib/core/navigation/router_config.dart` (add `:id/notes`)
- Modify: `lib/features/automobile_records/presentation/widgets/automobile_records_summary.dart` (add a Notes card)
- Test: `test/features/automobile_records/vehicle_notes_screen_test.dart`

- [ ] **Step 1: Create the screen**

```dart
// lib/features/automobile_records/presentation/screens/vehicle_notes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notes/presentation/widgets/attached_notes_section.dart';

class VehicleNotesScreen extends ConsumerWidget {
  const VehicleNotesScreen({super.key, required this.automobileId});

  /// The automobile's id IS its note id (automobiles are stored as notes).
  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Notes')),
      body: SingleChildScrollView(
        child: AttachedNotesSection(parentId: automobileId, title: 'Notes'),
      ),
    );
  }
}
```

- [ ] **Step 2: Add the route name + route**

In `route_names.dart`, add `vehicleNotes,` to the `RouterNames` enum.

In `router_config.dart`, add the import:
```dart
import 'package:hmm_console/features/automobile_records/presentation/screens/vehicle_notes_screen.dart';
```
and add a `:id/notes` GoRoute as a sibling of `:id/insurance` (inside the `manage`/`:id`-bearing `routes:` list — the same list that holds `:id/insurance`, `:id/services`, `:id/scheduled-services`):
```dart
              GoRoute(
                path: ':id/notes',
                name: RouterNames.vehicleNotes.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return VehicleNotesScreen(automobileId: id);
                },
              ),
```

- [ ] **Step 3: Add a Notes card to the per-vehicle hub**

In `automobile_records_summary.dart`, the build returns a list of summary cards (`_InsuranceSummaryCard`, `_ServiceSummaryCard`, `_ScheduleSummaryCard`). Add a fourth tappable entry that navigates to the notes route. After the existing cards in the returned `Column`/list children, add:
```dart
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: const Text('Notes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('/automobiles/manage/$automobileId/notes'),
          ),
        ),
```
Ensure `automobileId` is in scope (the build method is on `_AutomobileRecordsSummaryState`; use `widget.automobileId`) and `go_router` is imported (`import 'package:go_router/go_router.dart';`). Match the file's existing card styling if it differs.

- [ ] **Step 4: Write the widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/vehicle_notes_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';

void main() {
  testWidgets('vehicle notes screen hosts AttachedNotesSection for the car',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachedNotesProvider(42).overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: VehicleNotesScreen(automobileId: 42)),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AttachedNotesSection), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run test + analyze**

Run: `flutter test test/features/automobile_records/vehicle_notes_screen_test.dart`
Expected: PASS
Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/automobile_records/presentation/screens/vehicle_notes_screen.dart lib/core/navigation/route_names.dart lib/core/navigation/router_config.dart lib/features/automobile_records/presentation/widgets/automobile_records_summary.dart test/features/automobile_records/vehicle_notes_screen_test.dart
git commit -m "feat(notes): per-vehicle Notes screen + route + hub entry"
```

---

## Task 8: Subsystem Notes screen + Subsystems list + routes + entry

**Files:**
- Create: `lib/features/notes/presentation/screens/subsystem_notes_screen.dart`
- Create: `lib/features/notes/presentation/screens/subsystems_screen.dart`
- Modify: `lib/core/navigation/route_names.dart` (add `subsystems`, `subsystemNotes`)
- Modify: `lib/core/navigation/router_config.dart` (add routes)
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart` (app-bar entry to Subsystems)
- Test: `test/features/notes/presentation/subsystem_screens_test.dart`

- [ ] **Step 1: Create `SubsystemNotesScreen`**

```dart
// lib/features/notes/presentation/screens/subsystem_notes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/attached_notes_section.dart';

class SubsystemNotesScreen extends ConsumerWidget {
  const SubsystemNotesScreen({
    super.key,
    required this.anchorId,
    required this.anchorName,
  });

  final int anchorId;
  final String anchorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('$anchorName notes')),
      body: SingleChildScrollView(
        child: AttachedNotesSection(parentId: anchorId, title: '$anchorName notes'),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `SubsystemsScreen`**

```dart
// lib/features/notes/presentation/screens/subsystems_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/subsystem_anchor.dart';

class SubsystemsScreen extends ConsumerWidget {
  const SubsystemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subsystemAnchorsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subsystems')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed: $e')),
        data: (anchors) => ListView(
          children: [
            for (final a in anchors)
              ListTile(
                title: Text(a.subject),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                    '/notes/subsystems/${a.id}?name=${Uri.encodeComponent(a.subject)}'),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add route names + routes**

In `route_names.dart`, add `subsystems,` and `subsystemNotes,` to the enum.

In `router_config.dart`, add imports:
```dart
import 'package:hmm_console/features/notes/presentation/screens/subsystems_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/subsystem_notes_screen.dart';
```
and add these as children under the existing `/notes` GoRoute's `routes:` list (sibling of `new`, `:id`):
```dart
          GoRoute(
            path: 'subsystems',
            name: RouterNames.subsystems.name,
            builder: (context, state) => const SubsystemsScreen(),
            routes: [
              GoRoute(
                path: ':anchorId',
                name: RouterNames.subsystemNotes.name,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['anchorId']!);
                  final name = state.uri.queryParameters['name'] ?? 'Subsystem';
                  return SubsystemNotesScreen(anchorId: id, anchorName: name);
                },
              ),
            ],
          ),
```

> NOTE on route ordering: go_router matches `:id` greedily, so a path `/notes/subsystems` could match the `:id` route with `id="subsystems"`. Place the `subsystems` GoRoute BEFORE the `:id` GoRoute in the `routes:` list so it takes precedence. Verify by navigating `/notes/subsystems` resolves to `SubsystemsScreen` (the test in Step 5 covers the screen directly; also confirm `flutter analyze` is clean and manually that the order is subsystems-before-`:id`).

- [ ] **Step 4: Add a Subsystems entry to the notes list app bar**

In `notes_list_screen.dart`, add an `IconButton` to the `AppBar.actions` (alongside the sort/filter icons):
```dart
          IconButton(
            tooltip: 'Subsystems',
            icon: const Icon(Icons.widgets_outlined),
            onPressed: () => context.push('/notes/subsystems'),
          ),
```
(`context` and `go_router` are already in scope in that screen.)

- [ ] **Step 5: Write the widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/subsystem_notes_screen.dart';
import 'package:hmm_console/features/notes/presentation/screens/subsystems_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/attached_notes_section.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';

void main() {
  testWidgets('SubsystemsScreen lists anchors', (tester) async {
    final anchor = HmmNote(
        id: 5, uuid: 'hmm-subsystem-automobile', subject: 'Automobile',
        authorId: 1, catalogId: 9, createDate: DateTime(2026, 1, 1));
    await tester.pumpWidget(ProviderScope(
      overrides: [subsystemAnchorsProvider.overrideWith((ref) async => [anchor])],
      child: const MaterialApp(home: SubsystemsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Automobile'), findsOneWidget);
  });

  testWidgets('SubsystemNotesScreen hosts the anchor notes section',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [attachedNotesProvider(5).overrideWith((ref) async => const [])],
      child: const MaterialApp(
          home: SubsystemNotesScreen(anchorId: 5, anchorName: 'Automobile')),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AttachedNotesSection), findsOneWidget);
    expect(find.text('Automobile notes'), findsWidgets);
  });
}
```

- [ ] **Step 6: Run test + analyze**

Run: `flutter test test/features/notes/presentation/subsystem_screens_test.dart`
Expected: PASS
Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/notes/presentation/screens/subsystem_notes_screen.dart lib/features/notes/presentation/screens/subsystems_screen.dart lib/core/navigation/route_names.dart lib/core/navigation/router_config.dart lib/features/notes/presentation/screens/notes_list_screen.dart test/features/notes/presentation/subsystem_screens_test.dart
git commit -m "feat(notes): subsystem notes screen + subsystems list + routes"
```

---

## Task 9: Editor "Attach to" + preset parent

The editor honors a `?parent=<id>` query param (used by AttachedNotesSection's "Add note") so a created note is attached, and offers a subsystem picker.

**Files:**
- Modify: `lib/core/navigation/router_config.dart` (pass `parent` query param to the editor)
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart` (preset parent + "Attach to" picker)
- Test: `test/features/notes/presentation/note_editor_attach_test.dart`

- [ ] **Step 1: Pass the preset parent through the route**

In `router_config.dart`, the `/notes/new` GoRoute builder currently is `(context, state) => const NoteEditorScreen()`. Change it to read an optional `parent` query param:
```dart
            builder: (context, state) {
              final p = state.uri.queryParameters['parent'];
              return NoteEditorScreen(presetParentId: p == null ? null : int.tryParse(p));
            },
```

- [ ] **Step 2: Editor accepts a preset parent and a subsystem picker**

In `note_editor_screen.dart`:

(a) Add the constructor param to `NoteEditorScreen`:
```dart
  const NoteEditorScreen({super.key, this.noteId, this.presetParentId});
  final int? noteId; // null = create
  final int? presetParentId; // preset attach target for a new note
```

(b) In `_NoteEditorScreenState`, add a selected-parent field and initialize it:
```dart
  int? _parentId;
```
In `initState`, after `_noteId = widget.noteId;`, add `_parentId = widget.presetParentId;`.

(c) In `_save()`, pass the parent when creating. Find the `createGeneral(...)` call and add `parentNoteId: _parentId`:
```dart
        final note = await mutate.createGeneral(
            subject: subject, markdownBody: _bodyCtrl.text,
            parentNoteId: _parentId);
```
For the update branch, re-link only when a subsystem is selected:
```dart
      } else {
        await mutate.updateGeneral(_noteId!,
            subject: subject, markdownBody: _bodyCtrl.text);
        if (_parentId != null) {
          await ref.read(mutateNoteProvider).attachExisting(_noteId!, _parentId!);
        }
        ref.invalidate(noteDetailProvider(_noteId!));
      }
```

(d) Add a subsystem "Attach to" dropdown to the body `Column` (above the subject field). It lists subsystem anchors and "None":
```dart
            Consumer(builder: (context, ref, _) {
              final anchorsAsync = ref.watch(subsystemAnchorsProvider);
              return anchorsAsync.maybeWhen(
                data: (anchors) => DropdownButtonFormField<int?>(
                  value: _parentId,
                  decoration: const InputDecoration(
                      labelText: 'Attach to subsystem',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('None')),
                    for (final a in anchors)
                      DropdownMenuItem<int?>(value: a.id, child: Text(a.subject)),
                  ],
                  onChanged: (v) => setState(() => _parentId = v),
                ),
                orElse: () => const SizedBox.shrink(),
              );
            }),
            const SizedBox(height: 12),
```
Add the imports at the top of the file:
```dart
import '../../data/subsystem_anchor.dart';
```
(`Consumer` comes from `flutter_riverpod`, already imported.)

> Boundary note: if `_parentId` is a specific entity (a car, not an anchor), it won't match any dropdown item — `DropdownButtonFormField` shows it blank. For this version that's acceptable (the preset-parent path is create-from-vehicle, where the user isn't expected to re-pick a subsystem). Do NOT add special entity-label handling now; it's listed as a deferred boundary in the spec.

- [ ] **Step 3: Write the widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';

class _FakeMutate implements MutateNote {
  int? createdParent;
  bool createCalled = false;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<HmmNote> createGeneral(
      {required String subject, String? markdownBody, int? parentNoteId}) async {
    createCalled = true;
    createdParent = parentNoteId;
    return HmmNote(
        id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1), parentNoteId: parentNoteId);
  }
}

void main() {
  testWidgets('preset parent is used on create', (tester) async {
    final fake = _FakeMutate();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mutateNoteProvider.overrideWithValue(fake),
        subsystemAnchorsProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: NoteEditorScreen(presetParentId: 7)),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Subject'), 'Hi');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(fake.createCalled, isTrue);
    expect(fake.createdParent, 7);
  });
}
```
> Router note: the editor's Save flow calls `context.pop()` after create. `fake.createdParent` is set during `createGeneral`, which runs *before* the pop, so the assertion holds after `tester.pump()`. If `context.pop()` throws without a router in the tree, wrap the home in `MaterialApp.router` with a 2-route GoRouter (home `/` → editor) exactly as the existing `test/features/notes/presentation/note_editor_screen_test.dart` does, and reuse that setup.

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/features/notes/presentation/note_editor_attach_test.dart`
Expected: PASS
Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 5: Full suite**

Run: `flutter test`
Expected: all pass; report the total. If any pre-existing test outside this feature fails, report it but do not fix unrelated failures.

- [ ] **Step 6: Commit**

```bash
git add lib/core/navigation/router_config.dart lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/note_editor_attach_test.dart
git commit -m "feat(notes): editor preset parent + attach-to-subsystem picker"
```

---

## Done

After Task 9: a General note can be attached (via `parentNoteId`) to a specific vehicle (from the vehicle's Notes screen) or to a subsystem (from the editor's "Attach to" picker), surfaced on the target's Notes screen while still in the general list. Subsystems are seeded anchor notes with deterministic uuids; the Automobile anchor is the reference. Re-link (attach/detach) is supported; sync carries the parent via the existing `parentNoteUuid`.

**Deferred (per spec):** multi-subsystem membership (tags), subsystem-list aggregation of entity notes, the editor-side cross-subsystem *entity* picker, an entity-parent label in the editor dropdown, a direct "move" affordance, and `cloudApi`.
