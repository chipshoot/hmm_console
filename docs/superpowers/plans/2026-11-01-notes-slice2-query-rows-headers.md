# Notes List Redesign — Slice 2: Query Engine, Rows, Date Headers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Notes list's ad-hoc filter/sort/title search with a `NoteQuery` evaluated by an in-memory query engine over a cached per-note search index, and render its grouped results (Pinned section, sticky date headers) as new density-aware `NoteRow`s with rendered-markdown previews.

**Architecture:** `NotesListState` already merges the notes and catalog streams into `NotesListData`; it now also carries every note's state (pin/flag) and tags and holds the user's `NoteQuery`. A pure `InMemoryNoteQueryEngine.evaluate(query, corpus, now)` filters, sorts, groups and counts, reading per-note search text from a `NoteTextIndexCache` that a warmer fills in the background. `notesResultsProvider` is the UI's only seam to the engine; the screen renders `NoteResults.groups` as `SliverMainAxisGroup`s with pinned headers.

**Tech Stack:** Flutter, Riverpod 3, Drift streams, `markdown` (already in the lock file via flutter_markdown; becomes a direct dependency), `intl` DateFormat, `pinyin_pro_flutter` through the existing `PinyinTranscriber`.

**Spec:** `docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md` — sections "Query engine and search", "Row (`NoteRow`)", "Phone", "Errors and edge cases", "Testing", and grilling decisions G1, G2, G3, G4 (slice 2 = "query engine, rows, date headers"), G14.

**Branch:** `feat/notes-list-slice2` (from main `7165aab`). Client only — no server change in this slice.

## Global Constraints

- Every icon button is `HmmIconButton` with a localized tooltip; `test/core/help/icon_button_guard_test.dart`'s allow-list entry `notes_list_screen.dart: 4` goes to **0** (remove the entry).
- iOS: Cupertino action sheet for the View menu, no FAB; Android: Material bottom sheet. Branch on `Theme.of(context).platform`.
- Every new string in `lib/l10n/app_en.arb` **and** `lib/l10n/app_zh.arb`; run `flutter gen-l10n` after ARB edits. Dates and times localized with `intl` using the app locale.
- Date grouping uses the device's local time zone and the note's effective date `noteDate ?? createDate` (`HmmNote.effectiveNoteDate`) — G1. The Last-modified sort groups by `lastModifiedDate ?? effectiveNoteDate` — G2.
- **G3:** the Pinned section is at the top of **every** view and every sort, holding only the pinned notes that match the view; pinned notes are not repeated below. When the source itself is `pinned`, there is no separate Pinned section.
- **G14:** pin and flag come from `NoteStates` (via `INoteStateRepository`), never from the note row.
- Unknown sources/tokens/fields from a newer client are preserved in JSON and ignored by the engine.
- Flag colours: stored int 0 red … 6 grey (`NoteFlagColor`); unknown ints display grey (`NoteFlagColor.fromStored`).
- Entity notes (contacts, cheatsheets, records…) contribute their **display-registry title and preview text** to search and rows — never raw JSON content.
- Row density is per device: `compact` / `standard` / `rich`, default `standard`; stored in `AppSettings` (device-local, like `notesFilterUsage`).
- Performance: ≤ 50 ms per evaluation for 5,000 notes with a warm index (benchmark test).
- Changing a control means updating its help entry; the Notes list gets `HelpId.notesList` + a `HelpButton`.
- Do not add `flutter_slidable` / `share_plus` (later slices). Never stage `hmm/CLAUDE.md`.

## Decisions this plan makes (spec leaves open)

- **Engine seam.** Spec D8 names `Stream<NoteResults> run(NoteQuery)`. The corpus is already reactive through Riverpod, so the engine interface is synchronous `evaluate(NoteQuery, NotesListData, {now, firstDayOfWeek})` and the replaceable seam is `notesResultsProvider` (`AsyncValue<NoteResults>`), which is all the UI reads. A future FTS5/server engine swaps that provider's body.
- **Text matching.** The query is split on whitespace after `normalizeForSearch`; **every** word must match (AND) one of: title, body, parent title, tag names (all folded), or the pinyin full / initials of title, parent title and tags. Body text is folded but **not** romanized (cost). A word containing Han characters matches Han substrings directly.
- **Scope default** is `currentSource` (keeps today's "search within the filter"); `all` ignores the source. The toggle UI is slice 3.
- **Sources not yet fed:** `recentlyDeleted` (slice 5) and `smart` (slice 3) evaluate to empty results. `tag(tagId)` works now.
- **Date buckets** (local time, `now` injected): Today; Yesterday; This week (same week as today, week start = `MaterialLocalizations.firstDayOfWeekIndex`, 0 = Sunday, excluding Today/Yesterday); This month (excluding the above); then one group per calendar month. **Future** dates group under their own month (never Today).
- **A–Z groups:** first letter of the folded title; a Han first character groups by its pinyin initial; digits, symbols, emoji and empty titles group under `#`, placed last.
- **Flag sort / groups:** red → grey in enum order; unknown colour values join the grey group; unflagged notes last in an "Unflagged" group.
- **Match ranges** only for direct (non-pinyin) matches, on the displayed title and the preview plain text, case- and accent-insensitive, per character (folding never changes length).
- **Counts** describe the library, not the view: computed over all live notes, ignoring source, tokens and text.
- **Pull-to-refresh** on the list calls `syncControllerProvider.triggerManualSync()`.
- **Meta line** order: domain · parent title · 🏷 first 2 tags + "+n" · 📎 attachment count (primary + images + files) · 📍 place (location label, or the icon alone).
- **Trailing time:** today → `DateFormat.jm`; this year → `DateFormat.MMMd`; otherwise `DateFormat.yMd` (app locale).

## Review Focus

1. **Future-dated note** (noteDate tomorrow): never in Today; groups under its month; sorts above Today in Date-newest. → Task 5 test `future dates group under their month, not Today`.
2. **Image-only or very long note** (`![p](hmm-attachment://…)` only; 100 KB of text): preview empty or cut to its budget — never `![`, `](`, `**`, `- [ ]` — and the row still shows its title. → Task 7 tests `image-only note has an empty preview`, `long note stops at the line budget`.
3. **Locale switch en↔zh while the list is open:** entity titles and date headers re-localize; cached search text rebuilds for the new locale. → Task 2 test `cache key includes version and locale`, Task 9 test `headers follow the locale`.
4. **Unknown flag colour (e.g. 9) in the Flag sort:** grouped with grey, shown grey, stored value untouched. → Task 5 test `unknown flag colour joins the grey group`.
5. **A–Z with Han, digit, emoji and empty titles:** 张三 → Z, 7-Eleven → #, 🙂 → #, '' → #; `#` last. → Task 5 test `A–Z groups Han by pinyin initial and symbols under #`.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/features/notes/query/note_query.dart` (new) | `NoteQuery`, `NoteSource`, `NoteToken`, `NoteScope`, `NoteSort`; JSON with unknown preservation |
| `lib/core/util/search_normalize.dart` (new) | `normalizeForSearch` (moved from contacts), `foldForMatch` |
| `lib/features/notes/query/markdown_text.dart` (new) | `markdownToPlainText` for the index |
| `lib/features/notes/query/note_text_index.dart` (new) | `NoteTextIndex`, `NoteTextIndexCache`, `buildNoteTextIndex` |
| `lib/features/notes/query/note_results.dart` (new) | `NoteResults`, `NoteGroup`, `NoteGroupKey`, `NoteHit`, `NoteCounts` |
| `lib/features/notes/query/note_query_engine.dart` (new) | `NoteQueryEngine`, `InMemoryNoteQueryEngine` |
| `lib/features/notes/query/note_grouping.dart` (new) | `dateGroupFor`, `letterGroupFor`, `flagGroupFor` (pure) |
| `lib/features/notes/query/note_index_warmer.dart` (new) | background chunked cache fill |
| `lib/features/notes/states/notes_results_provider.dart` (new) | `notesResultsProvider`, `notesViewEnvProvider` |
| `lib/features/notes/states/notes_list_state.dart` (modify) | carries states, tags, `NoteQuery`; `visibleFor`/`visible` removed |
| `lib/features/notes/presentation/widgets/note_preview_text.dart` (new) | `previewRuns` + `NotePreviewText` |
| `lib/features/notes/presentation/widgets/note_row.dart` (new) | `NoteRow` (replaces `note_list_tile.dart`, deleted) |
| `lib/features/notes/presentation/widgets/notes_view_menu.dart` (new) | View ▾ (density + sort), replaces `sort_sheet.dart` (deleted) |
| `lib/features/notes/presentation/screens/notes_list_screen.dart` (modify) | grouped sticky slivers, empty/error states, refresh, help |
| `lib/core/data/local/local_note_state_repository.dart`, `local_tag_repository.dart` (modify) | `watchAllStates()`, `watchNoteTags()` |
| `lib/core/settings/app_settings.dart`, `settings_controller.dart` (modify) | `notesRowDensity` |
| `lib/core/widgets/app_scaffold.dart` (modify) | optional `onRefresh` |
| `lib/core/help/help_registry.dart` (modify) | `HelpId.notesList` |

---

### Task 1: `NoteQuery` model and JSON

**Files:**
- Create: `lib/features/notes/query/note_query.dart`
- Modify: `lib/features/notes/states/notes_list_state.dart` (remove its `NoteSort`; `export '../query/note_query.dart' show NoteSort;`)
- Test: `test/features/notes/query/note_query_test.dart`

**Interfaces:**
- Produces:
  - `enum NoteSort { dateNewest, dateOldest, lastModified, subjectAZ, flagColor }`
  - `enum NoteScope { all, currentSource }`
  - `sealed class NoteSource`: `AllSource`, `PinnedSource`, `FlaggedSource({int? color})`, `TodaySource`, `DomainSource({required String key, int? catalogId})`, `TagSource({required int tagId})`, `SmartSource({required String savedId})`, `RecentlyDeletedSource`, `UnknownSource({required Map<String, Object?> raw})` — all const, value equality.
  - `sealed class NoteToken`: `TagToken(int tagId)`, `FlagToken(int color)`, `DomainToken(String key)`, `CatalogToken(int catalogId)`, `ParentToken(String noteUuid)`, `HasPhotoToken()`, `HasPlaceToken()`, `HasAttachmentToken()`, `DateRangeToken({DateTime? from, DateTime? to})`, `RelativeDateToken(RelativeRange range)` with `enum RelativeRange { last7d, last30d, last90d }`, `PinnedToken()`, `UnknownToken(Map<String, Object?> raw)` — value equality.
  - `class NoteQuery { final NoteSource source; final String text; final List<NoteToken> tokens; final NoteScope scope; final NoteSort sort; final Map<String, Object?> extra; }` with `const NoteQuery.initial()` (AllSource, '', [], currentSource, dateNewest, {}), `copyWith`, value `==`/`hashCode`, `Map<String, Object?> toJson()`, `factory NoteQuery.fromJson(Map<String, Object?>)`.
- JSON: `{"source": {"type": "domain", "key": "AutomobileMan", "catalogId": 4}, "text": "…", "tokens": [{"type": "flag", "color": 2}], "scope": "currentSource", "sort": "dateNewest"}`. Source types `all, pinned, flagged, today, domain, tag, smart, recentlyDeleted`; token types `tag, flag, domain, catalog, parent, hasPhoto, hasPlace, hasAttachment, date, relativeDate, pinned`. Dates UTC ISO-8601. Unknown source/token maps are kept whole and re-emitted; unknown top-level keys go to `extra` and are re-emitted; an unknown `sort`/`scope` string reads as the default while its raw string is kept and re-emitted unchanged.

- [ ] **Step 1: Write the failing tests**

```dart
test('round-trips every source and token', () {
  final q = NoteQuery(
    source: const DomainSource(key: 'AutomobileMan', catalogId: 4),
    text: 'tyres',
    tokens: [
      const TagToken(3), const FlagToken(2), const DomainToken('General'),
      const CatalogToken(7), const ParentToken('u-1'), const HasPhotoToken(),
      const HasPlaceToken(), const HasAttachmentToken(),
      DateRangeToken(from: DateTime.utc(2026, 1, 1), to: DateTime.utc(2026, 2, 1)),
      const RelativeDateToken(RelativeRange.last30d), const PinnedToken(),
    ],
    scope: NoteScope.all,
    sort: NoteSort.flagColor,
  );
  expect(NoteQuery.fromJson(jsonDecode(jsonEncode(q.toJson()))), q);
});

test('unknown source, token, sort and top-level fields survive a round trip', () {
  final raw = <String, Object?>{
    'source': {'type': 'calendar', 'day': '2026-11-01'},
    'tokens': [{'type': 'sharedWith', 'user': 7}, {'type': 'pinned'}],
    'sort': 'byMood', 'scope': 'currentSource', 'text': '', 'future': 1,
  };
  final q = NoteQuery.fromJson(raw);
  expect(q.source, isA<UnknownSource>());
  expect(q.tokens.first, isA<UnknownToken>());
  expect(q.sort, NoteSort.dateNewest);
  expect(q.toJson(), raw);
});

test('every source type round-trips', () { /* one case per NoteSource subtype */ });
```

- [ ] **Step 2: Run** `flutter test test/features/notes/query/note_query_test.dart` — Expected: FAIL (types missing).
- [ ] **Step 3: Implement** `note_query.dart` per Interfaces; move `NoteSort` with the re-export so existing importers compile.
- [ ] **Step 4: Run** the test file — PASS; `flutter analyze` — no new issues.
- [ ] **Step 5: Commit** `feat(notes): NoteQuery model with forward-compatible JSON`

---

### Task 2: Search text and the per-note text index

**Files:**
- Create: `lib/core/util/search_normalize.dart` (move `normalizeForSearch` with its `_fold`/`_ws` tables out of `lib/features/contacts/domain/contact_sort.dart`, which then imports it — no behaviour change)
- Create: `lib/features/notes/query/markdown_text.dart`, `lib/features/notes/query/note_text_index.dart`
- Modify: `pubspec.yaml` — add `markdown: ^<version resolved in pubspec.lock>`
- Test: `test/features/notes/query/markdown_text_test.dart`, `test/features/notes/query/note_text_index_test.dart`

**Interfaces:**
- Produces:
  - `String normalizeForSearch(String s)` (unchanged), `String foldForMatch(String s)` — lowercase + per-character fold through the same table; **output length == input length** (a fold entry that is not exactly one UTF-16 unit is skipped by this function); no whitespace collapsing.
  - `String markdownToPlainText(String markdown)` — `package:markdown` with `ExtensionSet.gitHubFlavored`; text of blocks joined by `\n`; images, tables, raw HTML omitted; link text kept, URLs dropped; task-list markers dropped.
  - `class NoteTextIndex { final String titleFolded; final String bodyFolded; final String parentTitleFolded; final List<String> tagNamesFolded; final String pinyinFull; final String pinyinInitials; final String body; }` (`body` = unfolded plain text, for previews of entity notes and range mapping)
  - `NoteTextIndex buildNoteTextIndex({required String title, required String body, String? parentTitle, List<String> tagNames = const [], required PinyinTranscriber pinyin})` — pinyin covers title, parent title and tags: `pinyinFull` holds each Han run both joined (`zhangsan`) and space-separated (`zhang san`), `pinyinInitials` the initials (`zs`); both empty without Han text. Uses `pinyin.given(text)`.
  - `typedef NoteTextKey = ({int noteId, String version, String locale, String parentTitle, String tags});` — `version` = hex of `HmmNote.version`, else `lastModifiedDate?.toIso8601String() ?? ''`; `tags` = sorted names joined by `\u0001`.
  - `class NoteTextIndexCache { NoteTextIndex? lookup(NoteTextKey key); void store(NoteTextKey key, NoteTextIndex index); void retainOnly(Set<int> noteIds); int get length; }` — one entry per note id; a different key for the same id is a miss.
  - Body source rule (applied in Task 6's builder): no display-registry entry for the catalog → `markdownToPlainText(note.content ?? '')`; with an entry → `registry.noteDisplay(note, catalogName, l).preview`.

- [ ] **Step 1: Write the failing tests**

```dart
test('strips markup, keeps link text, drops images and tables', () {
  const md = '# Trip\n**Bold** _it_ `code` [site](https://x.y)\n'
      '![p](hmm-attachment://attachments/a.jpg)\n\n| a | b |\n|---|---|\n| 1 | 2 |\n'
      '- [ ] milk\n- [x] eggs';
  final t = markdownToPlainText(md);
  expect(t, contains('Trip'));
  expect(t, contains('Bold it code site'));
  expect(t, contains('milk'));
  for (final bad in ['**', '`', '](', '![', '[ ]', '[x]', '| a', 'https://']) {
    expect(t, isNot(contains(bad)), reason: bad);
  }
});

test('foldForMatch keeps length', () {
  expect(foldForMatch('Crème BRÛLÉE'), 'creme brulee');
  expect(foldForMatch('Crème').length, 'Crème'.length);
});

test('Han title gets pinyin full and initials', () {   // fake: 张→zhang, 三→san
  final i = buildNoteTextIndex(title: '张三 notes', body: '', pinyin: fake);
  expect(i.pinyinFull, contains('zhangsan'));
  expect(i.pinyinInitials, contains('zs'));
});

test('cache key includes version and locale', () {
  final cache = NoteTextIndexCache();
  const k = (noteId: 1, version: 'a1', locale: 'en', parentTitle: '', tags: '');
  cache.store(k, idx);
  expect(cache.lookup(k), same(idx));
  expect(cache.lookup((noteId: 1, version: 'a2', locale: 'en', parentTitle: '', tags: '')), isNull);
  expect(cache.lookup((noteId: 1, version: 'a1', locale: 'zh', parentTitle: '', tags: '')), isNull);
});

test('retainOnly drops purged notes', () { /* store 1, 2; retainOnly({2}); length == 1 */ });
```

- [ ] **Step 2: Run** both files — FAIL.
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4: Run** both files and `flutter test test/features/contacts` — PASS (contacts unchanged).
- [ ] **Step 5: Commit** `feat(notes): search text normalization and per-note text index`

---

### Task 3: Corpus feeds — note states, tags and the query on `NotesListState`

**Files:**
- Modify: `lib/core/data/local/local_note_state_repository.dart`, `lib/core/data/local/local_tag_repository.dart`, `lib/features/notes/states/notes_list_state.dart`, `lib/features/notes/presentation/screens/notes_list_screen.dart` (minimal, to compile)
- Test: `test/core/data/local/local_note_state_repository_test.dart` (add), `test/core/data/local/local_tag_repository_watch_test.dart` (new), `test/features/notes/states/notes_list_reactive_test.dart` (extend), `test/features/notes/states/catalog_source_mapping_test.dart` (new)

**Interfaces:**
- Consumes: `NoteQuery`, `NoteSource`, `NoteSort` (Task 1); `DomainGroup` from `presentation/widgets/domain_groups.dart`.
- Produces:
  - `INoteStateRepository.watchAllStates()` → `Stream<Map<String, NoteState>>` (Drift `.watch()` on `noteStates`).
  - `typedef NoteTagLabel = ({int id, String name});` and `ITagRepository.watchNoteTags()` (impl in `LocalTagRepository`) → `Stream<Map<int, List<NoteTagLabel>>>`: note id → its tags with `isActivated` and `deletedAt == null`, sorted by name (join `NoteTagRefs` × `Tags`).
  - `NotesListData` gains `statesByUuid` (`Map<String, NoteState>`), `tagsByNoteId` (`Map<int, List<NoteTagLabel>>`), `query` (`NoteQuery`) and `NoteState stateOf(HmmNote n)` (`?? NoteState.none(n.uuid)`); it loses `catalogFilter`, `sort`, the `String query`, `visible`, `visibleFor`. Domain helpers and the two count getters stay unchanged.
  - `NotesListState`: `setQuery(NoteQuery)`, `setText(String)`, `setSort(NoteSort)`, `setSource(NoteSource)`; the `NoteQuery` lives on the notifier and survives data emissions. `setFilter` is removed.
  - `NoteSource sourceForCatalogSelection(Set<int>? ids, List<DomainGroup> groups)`: null/empty → `AllSource`; equals a group's `catalogIds` → `DomainSource(key: g.key)`; one id inside group g → `DomainSource(key: g.key, catalogId: id)`; anything else → `AllSource`. Inverse `Set<int>? catalogSelectionFor(NoteSource s, List<DomainGroup> groups)` (null for non-domain sources). Both in `notes_list_state.dart`.

- [ ] **Step 1: Write the failing tests**

```dart
test('watchAllStates emits after a sync putState', () async {
  final seen = <Map<String, NoteState>>[];
  final sub = states.watchAllStates().listen(seen.add);
  await pumpEventQueue();
  await states.putState(NoteState(noteUuid: 'u1', isPinned: true, flagColor: 2,
      lastModifiedDate: DateTime.utc(2026, 11, 1)));
  await pumpEventQueue();
  expect(seen.last['u1']!.isPinned, isTrue);
  await sub.cancel();
});

test('watchNoteTags lists only active, live tags, by name', () async {
  // tags b(active), a(active), c(deactivated), d(deletedAt); note 5 refs all four
  expect((await tags.watchNoteTags().first)[5]!.map((t) => t.name), ['a', 'b']);
});

test('the query survives a data emission and pin state reaches the list', () async {
  notifier.setText('milk');
  await states.setPinned(note.uuid, true);
  await pumpEventQueue();
  final d = container.read(notesListStateProvider).value!;
  expect(d.query.text, 'milk');
  expect(d.stateOf(note).isPinned, isTrue);
});

test('catalog selection maps to a domain source and back', () {
  expect(sourceForCatalogSelection(null, groups), const AllSource());
  expect(sourceForCatalogSelection(autoGroup.catalogIds, groups), const DomainSource(key: 'AutomobileMan'));
  expect(sourceForCatalogSelection({gasLogId}, groups), DomainSource(key: 'AutomobileMan', catalogId: gasLogId));
  expect(catalogSelectionFor(DomainSource(key: 'AutomobileMan', catalogId: gasLogId), groups), {gasLogId});
});
```

- [ ] **Step 2: Run** the four files — FAIL.
- [ ] **Step 3: Implement.** `NotesListState.build` awaits two new autoDispose stream providers (states, tags) beside the notes/catalogs ones. Delete `visible`/`visibleFor` and the old fields. Mark the tests that use `.visible` — `test/features/notes/states/notes_list_visible_test.dart`, `test/features/notes/notes_list_domain_test.dart`, `test/features/notes/states/notes_list_state_test.dart`, and the `.visible` case in `notes_list_reactive_test.dart` — `skip: 'ported to the engine in Task 4'`. In `notes_list_screen.dart` make only the change needed to compile: filter sheet/drawer → `setSource(sourceForCatalogSelection(...))`, selection highlight via `catalogSelectionFor`, sort sheet → `setSort`, list `data.all` as-is (Task 9 replaces the body).
- [ ] **Step 4: Run** `flutter test test/core/data/local test/features/notes` — PASS (only the named skips). `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(notes): list state carries note states, tags and a NoteQuery`

---

### Task 4: Engine — sources, tokens, scope, text, sorts

**Files:**
- Create: `lib/features/notes/query/note_results.dart`, `lib/features/notes/query/note_query_engine.dart`
- Test: `test/features/notes/query/note_query_engine_test.dart`; un-skip and port the four Task 3 skips

**Interfaces:**
- Consumes: `NotesListData` (Task 3), `NoteQuery` (Task 1), `NoteTextIndexCache`, `NoteTextIndex`, `normalizeForSearch`, `foldForMatch` (Task 2).
- Produces:
  - `class NoteHit { final HmmNote note; final String title; final NoteState state; final List<TextRange> titleMatches; final List<TextRange> previewMatches; }`
  - `class NoteGroup { final NoteGroupKey key; final List<NoteHit> hits; }`
  - `sealed class NoteGroupKey` (value equality): `PinnedGroup`, `TodayGroup`, `YesterdayGroup`, `ThisWeekGroup`, `ThisMonthGroup`, `MonthGroup(int year, int month)`, `LetterGroup(String letter)`, `FlagGroup(NoteFlagColor? color)`, `FlatGroup`.
  - `class NoteCounts { final int all; final int pinned; final Map<String, int> byDomain; final Map<int, int> byTag; final Map<int, int> byFlag; }` (`byFlag` keyed by display colour index; unknown → grey)
  - `class NoteResults { final List<NoteGroup> groups; final NoteCounts counts; final int total; bool get isEmpty => total == 0; }`
  - `abstract interface class NoteQueryEngine { NoteResults evaluate(NoteQuery query, NotesListData corpus, {required DateTime now, required int firstDayOfWeek}); }`
  - `class InMemoryNoteQueryEngine implements NoteQueryEngine { InMemoryNoteQueryEngine({required NoteTextIndexCache cache, required NoteTextKey Function(HmmNote) keyOf, required String Function(HmmNote) titleOf, required PinyinTranscriber pinyin}); }`
  - In this task `evaluate` returns one `FlatGroup` with the sorted hits and zero counts; Task 5 adds grouping, Pinned, counts and ranges.
- Rules:
  - Sources: `AllSource` every note in `corpus.all`; `PinnedSource` `stateOf(n).isPinned`; `FlaggedSource(color: null)` any flag, `(color: c)` `fromStored(flag) == fromStored(c)`; `TodaySource` effective date's local day == `now`'s; `DomainSource(key)` `effectiveDomain(n) == key`; `DomainSource(key, catalogId: c)` → when `parentDomainOf(n) != null && parentDomainOf(n) != ownDomainOf(n)`: `parentDomainOf(n) == key`, else `n.catalogId == c` (today's single-catalog rule); `TagSource(id)` note has the tag; `SmartSource` / `RecentlyDeletedSource` / `UnknownSource` → none.
  - Tokens AND-ed after the source: `TagToken` has tag; `FlagToken(c)` flag colour == c (display colour); `DomainToken(key)` effectiveDomain == key; `CatalogToken(id)` catalogId == id; `ParentToken(uuid)` the parent note's uuid == uuid; `HasPhotoToken` primaryImage or images; `HasPlaceToken` `n.location != null`; `HasAttachmentToken` primary, images or files; `DateRangeToken` effective local day in [from, to] inclusive (either end optional); `RelativeDateToken` effective date ≥ local start of day of `now` − 6 / 29 / 89 days; `PinnedToken` pinned; `UnknownToken` ignored.
  - Scope: `all` with non-empty text skips the source (tokens still apply); `currentSource` applies both.
  - Text: per "Decisions — Text matching". A note with no cache entry for its current key matches on `normalizeForSearch(titleOf(n))` and its parent's title only.
  - Sorts: dateNewest / dateOldest by `effectiveNoteDate`; lastModified by `lastModifiedDate ?? effectiveNoteDate` desc; subjectAZ by `foldForMatch(title)` (a Han first character sorts by its pinyin); flagColor by display colour index, unflagged last, ties by date newest. Final tie-break: note id desc.

- [ ] **Step 1: Write the failing tests** — one test per source and per token (`source <name>`, `token <name>`), plus:

```dart
test('a General note attached to a car lists under Automobile, not General', () {
  expect(ids(run(source: const DomainSource(key: 'AutomobileMan'))), containsAll([carId, attachedId]));
  expect(ids(run(source: const DomainSource(key: 'General'))), isNot(contains(attachedId)));
});
test('words are AND-ed across title, body, parent and tags', () {
  // title "Oil change", parent "Honda Civic", tag "garage", body "5W-30"
  expect(ids(run(text: 'honda 5w-30')), [noteId]);
  expect(ids(run(text: 'garage oil')), [noteId]);
  expect(ids(run(text: 'honda toyota')), isEmpty);
});
test('pinyin initials find a Han title', () => expect(ids(run(text: 'zs')), [zhangSanId]));
test('a Han word matches Han text directly', () => expect(ids(run(text: '买菜')), [groceryId]));
test('scope all ignores the source when searching', () {
  expect(ids(run(source: const PinnedSource(), text: 'oil', scope: NoteScope.all)), contains(unpinnedOilId));
});
test('entity note is searched by its display title, never its JSON', () {
  expect(ids(run(text: 'givenname')), isEmpty);  // a JSON key in content
  expect(ids(run(text: 'alice')), [contactNoteId]);
});
test('unindexed note still matches by title', () { /* empty cache */ });
test('unknown token is ignored, not a filter', () {});
test('sorts: each of the five orders', () {});
```

  Port every assertion of the four skipped files 1:1 (same fixtures; `.visible` → `ids(evaluate(...))`; `catalogFilter: {x}` → the `sourceForCatalogSelection` result) and remove their `skip:`.

- [ ] **Step 2: Run** `flutter test test/features/notes/query test/features/notes/states test/features/notes/notes_list_domain_test.dart` — FAIL.
- [ ] **Step 3: Implement** `evaluate` per the rules — pure (no Riverpod, no I/O).
- [ ] **Step 4: Run** the same command — PASS, no skips left.
- [ ] **Step 5: Commit** `feat(notes): in-memory query engine (sources, tokens, scope, text, sorts)`

---

### Task 5: Engine — groups, Pinned section, counts, match ranges

**Files:**
- Create: `lib/features/notes/query/note_grouping.dart`
- Modify: `lib/features/notes/query/note_query_engine.dart`
- Test: `test/features/notes/query/note_grouping_test.dart`, `test/features/notes/query/note_query_engine_groups_test.dart`

**Interfaces:**
- Consumes: Task 4 types.
- Produces:
  - `NoteGroupKey dateGroupFor(DateTime date, {required DateTime now, required int firstDayOfWeek})` — both `.toLocal()`; week start = local today minus `((now.weekday % 7) - firstDayOfWeek) % 7` days (Dart `weekday` 1 = Mon … 7 = Sun, so `% 7` makes Sunday 0).
  - `LetterGroup letterGroupFor(String title, PinyinTranscriber pinyin)`
  - `FlagGroup flagGroupFor(int? storedFlag)`
  - `evaluate` groups: `PinnedGroup` first (any pinned hit, source not `PinnedSource`), then by sort — date sorts `dateGroupFor(effectiveNoteDate)`; lastModified `dateGroupFor(lastModifiedDate ?? effectiveNoteDate)`; subjectAZ `LetterGroup` A…Z then `#`; flagColor `FlagGroup` red…grey then Unflagged. Empty groups omitted; Pinned hits keep the active sort order.
  - `counts` over all notes of the corpus (ignoring source, tokens, text): `all`, `pinned`, `byDomain` via `effectiveDomain`, `byTag`, `byFlag`.
  - `titleMatches`: every direct occurrence of every query word in `foldForMatch(hit.title)`; `previewMatches`: same over `foldForMatch(index.body)` limited to its first 400 chars. No ranges for pinyin-only matches.

- [ ] **Step 1: Write the failing tests**

```dart
// now = Wed 2026-11-04 10:00 local; week starts Monday (1)
test('today / yesterday / this week / this month / months', () {
  expect(g(DateTime(2026, 11, 4, 0, 0)), isA<TodayGroup>());
  expect(g(DateTime(2026, 11, 3, 23, 59)), isA<YesterdayGroup>());
  expect(g(DateTime(2026, 11, 2)), isA<ThisWeekGroup>());
  expect(g(DateTime(2026, 11, 1)), isA<ThisMonthGroup>());
  expect(g(DateTime(2026, 10, 31)), const MonthGroup(2026, 10));
});
test('Sunday-first week moves Sunday 1 Nov into this week', () {
  expect(dateGroupFor(DateTime(2026, 11, 1), now: now, firstDayOfWeek: 0), isA<ThisWeekGroup>());
});
test('future dates group under their month, not Today', () {
  expect(g(DateTime(2026, 11, 5)), const MonthGroup(2026, 11));
  expect(g(DateTime(2027, 1, 2)), const MonthGroup(2027, 1));
});
test('a UTC instant buckets by its local day', () {});
test('A–Z groups Han by pinyin initial and symbols under #', () {
  expect(letterGroupFor('张三', fake), const LetterGroup('Z'));
  expect(letterGroupFor('7-Eleven', fake), const LetterGroup('#'));
  expect(letterGroupFor('🙂 hi', fake), const LetterGroup('#'));
  expect(letterGroupFor('', fake), const LetterGroup('#'));
  expect(letterGroupFor('élan', fake), const LetterGroup('E'));
});
test('unknown flag colour joins the grey group', () {
  expect(flagGroupFor(9), const FlagGroup(NoteFlagColor.grey));
  expect(flagGroupFor(null), const FlagGroup(null));
});
test('pinned notes lead every sort and are not repeated', () {});
test('a pinned note outside the view is not in its Pinned section', () {
  final r = run(source: const DomainSource(key: 'General'));
  expect(r.groups.expand((g) => g.hits).map((h) => h.note.id), isNot(contains(pinnedCarNoteId)));
});
test('Pinned source has no separate Pinned section', () {});
test('# group is last in A–Z; Unflagged last in flag sort', () {});
test('counts: attached note under its parent domain; General = unattached', () {});
test('counts ignore the active source and text', () {});
test('title match ranges are case- and accent-insensitive', () {
  // title "Crème brûlée", text "BRULEE" → [TextRange(start: 6, end: 12)]
});
test('pinyin-only matches have no ranges', () {});
```

- [ ] **Step 2: Run** both files — FAIL.
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4: Run** `flutter test test/features/notes/query` — PASS.
- [ ] **Step 5: Commit** `feat(notes): grouped results, Pinned section, counts and match ranges`

---

### Task 6: Results provider, index warmer, benchmark

**Files:**
- Create: `lib/features/notes/query/note_index_warmer.dart`, `lib/features/notes/states/notes_results_provider.dart`
- Test: `test/features/notes/query/note_index_warmer_test.dart`, `test/features/notes/query/note_query_benchmark_test.dart`, `test/features/notes/states/notes_results_provider_test.dart`

**Interfaces:**
- Consumes: Tasks 2–5; `noteDisplayRegistryProvider` (`title(note, catalogName, l)`, `noteDisplay(note, catalogName, l).preview`, and whether the catalog has an entry), `pinyinTranscriberProvider` (contacts), `notesListStateProvider`, `lookupAppLocalizations(Locale)` (generated in `lib/l10n/gen/app_localizations.dart`).
- Produces:
  - `final noteTextIndexCacheProvider = Provider<NoteTextIndexCache>((ref) => NoteTextIndexCache());` (keep-alive)
  - `class NoteIndexWarmer { NoteIndexWarmer({required NoteTextIndexCache cache, required NoteTextKey Function(HmmNote) keyOf, required NoteTextIndex Function(HmmNote) build, int chunkSize = 200, void Function()? onChunk}); Future<void> warm(List<HmmNote> notes); void cancel(); }` — `retainOnly` the live ids, then builds missing/stale entries `chunkSize` at a time with `await Future<void>.delayed(Duration.zero)` between chunks and `onChunk` after each; a starting `warm` cancels the previous one; a build that throws leaves that note unindexed and logs `debugPrint('NoteIndexWarmer: index failed (${e.runtimeType})')` at most once per `warm` call — never content.
  - `typedef NotesViewEnv = ({Locale locale, int firstDayOfWeek});` and `final notesViewEnvProvider = NotifierProvider<NotesViewEnvNotifier, NotesViewEnv?>` with `void set(NotesViewEnv env)` (no-op when equal). The list screen sets it after its first frame (Task 9). Until set, results are `AsyncLoading`.
  - `final notesIndexRevisionProvider = NotifierProvider<…, int>` bumped by the warmer's `onChunk`.
  - `final notesResultsProvider = Provider.autoDispose<AsyncValue<NoteResults>>` — watches `notesListStateProvider`, `notesViewEnvProvider`, `notesIndexRevisionProvider`; builds `l = lookupAppLocalizations(env.locale)`, the engine (`titleOf` via the registry with `l`, `keyOf` per Task 2 with `env.locale.toLanguageTag()`), and returns `AsyncData(engine.evaluate(data.query, data, now: DateTime.now(), firstDayOfWeek: env.firstDayOfWeek))`; on each new corpus it starts the warmer (`ref.listen`).

- [ ] **Step 1: Write the failing tests**

```dart
test('warmer fills the cache in chunks and reports each chunk', () async {
  // 450 notes, chunkSize 200 → onChunk called 3 times; cache.length == 450
});
test('a note whose build throws stays unindexed and is logged once', () async {});
test('results update once the warmer makes body text searchable', () async {
  // text matches only note 1's body: first value empty, after warm → [1]
});
test('results wait for the view env', () { /* no env → AsyncLoading */ });
test('5,000 notes evaluate in ≤ 50 ms with a warm index', () {
  final corpus = syntheticCorpus(5000); // titles, 300-char markdown bodies, 10% Han, tags, states
  warmAll(corpus);
  engine.evaluate(q('oil'), corpus, now: now, firstDayOfWeek: 1); // JIT warm-up
  final sw = Stopwatch()..start();
  for (var i = 0; i < 10; i++) {
    engine.evaluate(q('oil change ${i % 3}'), corpus, now: now, firstDayOfWeek: 1);
  }
  expect(sw.elapsedMilliseconds / 10, lessThanOrEqualTo(50));
});
```

- [ ] **Step 2: Run** the three files — FAIL.
- [ ] **Step 3: Implement** per Interfaces; per `evaluate` call compute only cheap per-note fields, take folded text from the cache.
- [ ] **Step 4: Run** `flutter test test/features/notes` — PASS including the benchmark. If the benchmark fails, profile and fix the engine; do not raise the bound.
- [ ] **Step 5: Commit** `feat(notes): results provider with a background index warmer and benchmark`

---

### Task 7: Rendered-markdown preview

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_preview_text.dart`
- Test: `test/features/notes/presentation/widgets/note_preview_text_test.dart`

**Interfaces:**
- Consumes: `foldForMatch` (Task 2).
- Produces:
  - `enum PreviewStyle { plain, bold, italic, boldItalic, code, link }`, `typedef PreviewRun = ({String text, PreviewStyle style});`
  - `List<PreviewRun> previewRuns(String markdown, {int maxChars = 400})` — `package:markdown` AST: headings and strong → bold; em → italic; inline code → code; link text → link; list items prefixed `• `; task items `☐ ` / `☑ `; images, tables, HTML and fenced code omitted; blocks separated by one space; stops after `maxChars` characters.
  - `String previewPlain(List<PreviewRun> runs)` — concatenated text.
  - `class NotePreviewText extends StatelessWidget { const NotePreviewText({super.key, required String markdown, String? plainText, required int maxLines, List<String> highlightWords = const []}); }` — `plainText` given (entity notes) renders it as-is; otherwise `previewRuns(markdown)`; `maxLines` + ellipsis; no gesture recognizers; highlight = each word's occurrences in `foldForMatch(previewPlain(runs))`, splitting runs at range edges, background `context.appColors.accent.withValues(alpha: 0.25)`.

- [ ] **Step 1: Write the failing tests**

```dart
test('runs carry styles and no raw markers', () {
  final runs = previewRuns('# Head\n**b** _i_ `c` [l](https://x)\n- [ ] milk\n- one');
  expect(previewPlain(runs), 'Head b i c l ☐ milk • one');
  expect(runs.firstWhere((r) => r.text == 'b').style, PreviewStyle.bold);
  expect(runs.firstWhere((r) => r.text == 'l').style, PreviewStyle.link);
});
test('image-only note has an empty preview', () {
  expect(previewPlain(previewRuns('![p](hmm-attachment://attachments/a.jpg)')), isEmpty);
});
test('long note stops at the line budget', () {
  expect(previewPlain(previewRuns('word ' * 20000)).length, lessThanOrEqualTo(400));
});
testWidgets('highlights a matched word without changing the text', (t) async {
  // markdown 'Buy **Crème**', highlightWords ['creme'] → a span 'Crème' with a background colour;
  // the RichText's plain text is 'Buy Crème'
});
testWidgets('entity notes render their plain preview', (t) async {});
```

- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `feat(notes): rendered-markdown row preview with match highlighting`

---

### Task 8: Row density setting and `NoteRow`

**Files:**
- Modify: `lib/core/settings/app_settings.dart`, `lib/core/settings/settings_controller.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Create: `lib/features/notes/presentation/widgets/note_row.dart`
- Delete: `lib/features/notes/presentation/widgets/note_list_tile.dart` (switch `notes_list_screen.dart` to `NoteRow` minimally; Task 9 rewires the body)
- Test: `test/core/settings/app_settings_test.dart` (extend), `test/features/notes/presentation/widgets/note_row_test.dart`

**Interfaces:**
- Consumes: `NoteHit` (Task 4), `NotePreviewText` (Task 7), `NoteTagLabel` (Task 3), `noteDisplayRegistryProvider`, `attachmentResolverProvider`, `AttachmentImage`, `SensitiveAttachmentImage` (must **not** be built), `isSensitiveVaultPath`, `CatalogPalette.domainStyle` / `styleFor`, `NoteFlagColor`, `noteFlagColorLabel`.
- Produces:
  - `enum NoteRowDensity { compact, standard, rich }`; `AppSettings.notesRowDensity` (JSON `notesRowDensity` = enum name; absent/unknown → `standard`); `SettingsController.setNotesRowDensity(NoteRowDensity)`; `final notesRowDensityProvider = Provider<NoteRowDensity>` (from `settingsProvider`, default `standard` while loading).
  - `class NoteRow extends ConsumerWidget { const NoteRow({super.key, required NoteHit hit, required NoteRowDensity density, required String? domainKey, required String? catalogName, required String? parentTitle, required List<NoteTagLabel> tags, List<String> highlightWords = const [], required DateTime now, VoidCallback? onTap}); }`
- Layout: 4 pt full-height leading bar in `CatalogPalette.domainStyle(domainKey).color` (fallback `styleFor(catalogName).color`); line 1 = title (spans from `hit.titleMatches` highlighted) + `Icons.push_pin` 14 pt when pinned + trailing time (Decisions) + `Icons.flag` in `NoteFlagColor.fromStored(flag)!.color` when flagged; preview `NotePreviewText` with `maxLines` 2 standard / 4 rich / omitted compact, `plainText` = registry preview for entity notes; meta line per Decisions with `Icons.sell_outlined`, `Icons.attach_file`, `Icons.place_outlined` (omitted parts collapse, no stray `·`); rich only: 56×56 rounded thumbnail on the right for `primaryImage ?? images.first` — sensitive path → `Icons.lock_outline` on a tinted box, else `AttachmentImage` with the resolver (box placeholder while the resolver loads).
- Semantics: one merged `Semantics(label:)` = `notesRowSemantics(title, date)` + optional `notesRowSemanticsFlagged(colourName)` + optional `notesRowSemanticsPinned` + preview plain text, joined by `, `.
- ARB (en / zh): `notesDensityCompact` Compact / 紧凑; `notesDensityStandard` Standard / 标准; `notesDensityRich` Rich / 丰富; `notesRowSemantics` "{title}, {date}" / "{title}，{date}"; `notesRowSemanticsFlagged` "flagged {color}" / "已标记{color}"; `notesRowSemanticsPinned` pinned / 已置顶; `notesRowMoreTags` "+{count}" / "+{count}".

- [ ] **Step 1: Write the failing tests**

```dart
test('density round-trips and defaults to standard', () {
  expect(AppSettings.fromJson({}).notesRowDensity, NoteRowDensity.standard);
  expect(AppSettings.fromJson({'notesRowDensity': 'bogus'}).notesRowDensity, NoteRowDensity.standard);
  final s = const AppSettings().copyWith(notesRowDensity: NoteRowDensity.rich);
  expect(AppSettings.fromJson(s.toJson()).notesRowDensity, NoteRowDensity.rich);
});
testWidgets('standard shows 2 preview lines, compact none, rich 4 and a thumbnail', (t) async {});
testWidgets('no raw markdown in any density', (t) async {
  // content '**Bold** - [ ] task' → no Text/RichText contains '**' or '[ ]'
});
testWidgets('pin icon and coloured flag show; unknown flag shows grey', (t) async {});
testWidgets('meta line shows 2 tags and "+1", attachment count and place', (t) async {});
testWidgets('sensitive thumbnail shows a lock and never builds SensitiveAttachmentImage', (t) async {
  expect(find.byType(SensitiveAttachmentImage), findsNothing);
  expect(find.byIcon(Icons.lock_outline), findsOneWidget);
});
testWidgets('semantics label reads title, date, flagged colour, pinned, preview', (t) async {});
testWidgets('entity note row shows its display title and plain preview, not JSON', (t) async {});
```

- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter test test/core/settings test/features/notes/presentation/widgets/note_row_test.dart` — PASS.
- [ ] **Step 5: Commit** `feat(notes): NoteRow with densities, flags, pins, meta line and previews`

---

### Task 9: The list screen — grouped sticky sections, View menu, empty/error states, refresh, help

**Files:**
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`, `lib/core/widgets/app_scaffold.dart` (optional `Future<void> Function()? onRefresh`), `lib/core/help/help_registry.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `test/core/help/icon_button_guard_test.dart` (remove the `notes_list_screen.dart` entry)
- Create: `lib/features/notes/presentation/widgets/notes_view_menu.dart`
- Delete: `lib/features/notes/presentation/widgets/sort_sheet.dart`
- Test: `test/features/notes/presentation/notes_list_screen_test.dart` (update `NoteListTile` → `NoteRow`), `test/features/notes/presentation/notes_list_groups_test.dart` (new), `test/features/notes/presentation/notes_view_menu_test.dart` (new); keep `notes_filter_chips_test.dart` and `notes_filter_drawer_navigation_test.dart` passing

**Interfaces:**
- Consumes: `notesResultsProvider`, `notesViewEnvProvider` (Task 6), `notesListStateProvider` setters and `sourceForCatalogSelection` / `catalogSelectionFor` (Task 3), `NoteRow` and `notesRowDensityProvider` (Task 8), `HmmIconButton`, `HelpButton`, `syncControllerProvider.triggerManualSync()`.
- Produces:
  - `Future<void> showNotesViewMenu(BuildContext context, {required NoteRowDensity density, required NoteSort sort, required ValueChanged<NoteRowDensity> onDensity, required ValueChanged<NoteSort> onSort})` — iOS `showCupertinoModalPopup` + `CupertinoActionSheet` (two titled sections, ✓ on current values); Android `showModalBottomSheet` with two `RadioListTile` groups.
  - `HelpId.notesList` (`help_registry.dart`) with entries for View (`Icons.tune`), Pinned section (`Icons.push_pin`), Date sections (`Icons.calendar_today`), Flags (`Icons.flag`), Search (`Icons.search`), Filter (`Icons.filter_list`). ARB keys `helpNotesListTitle`, `helpNotesListSummary`, `helpNotesList<Control>Title` / `Body` for View, Pinned, Dates, Flags, Search, Filter (en + zh).
- Behaviour:
  - Top bar (all `HmmIconButton`, localized tooltips): View `Icons.tune` (`notesViewTooltip` View / 显示), Filter `Icons.filter_list` (existing sheet, through `setSource`), Subsystems (existing), `HelpButton(helpId: HelpId.notesList)`. The search-clear button keeps `Key('notesSearchClear')` and becomes `HmmIconButton` (`notesSearchClearTooltip`).
  - Search field → `setText`, debounced 150 ms (a `Timer` in the field state); it shows `data.query.text` on return.
  - After the first frame and whenever they change, write `(locale: Localizations.localeOf(context), firstDayOfWeek: MaterialLocalizations.of(context).firstDayOfWeekIndex)` to `notesViewEnvProvider` (post-frame callback; never during build).
  - Body: one `SliverMainAxisGroup` per `NoteGroup` = `SliverPersistentHeader(pinned: true)` header + `SliverList` of `NoteRow`s separated by `AppRowSeparator`. Header text: `notesGroupPinned` Pinned / 置顶; `notesGroupToday` Today / 今天; `notesGroupYesterday` Yesterday / 昨天; `notesGroupThisWeek` This week / 本周; `notesGroupThisMonth` This month / 本月; `MonthGroup` → `DateFormat.yMMM(locale)`; `LetterGroup` → its letter; `FlagGroup` → `noteFlagColorLabel` or `notesGroupUnflagged` Unflagged / 未标记.
  - Row tap unchanged (registry `open`; wide → `selectedNoteIdProvider`; else push `/notes/{id}`). `highlightWords` = `normalizeForSearch(query.text)` split on spaces. `domainKey` = `data.effectiveDomain(note)`; `parentTitle` = the parent's display title (existing 20-char cap) or the domain label for an anchor parent.
  - Empty / error: no notes at all → `AppEmptyState` with `notesEmpty` "No notes yet" / "还没有笔记"; empty results with text → `notesNoMatches` "No notes match “{query}”" / "没有符合“{query}”的笔记" plus `TextButton` `notesSearchClearAction` "Clear search" / "清除搜索" → `setText('')`; empty results without text → `notesNoneInView` "No notes here" / "这里没有笔记"; load error → `notesLoadFailed` + `TextButton` `notesRetry` "Retry" / "重试" → `notifier.refresh()`.
  - Pull-to-refresh: `AppScaffold(onRefresh:)` — iOS `CupertinoSliverRefreshControl` first sliver, Android `RefreshIndicator` around the scroll view → `triggerManualSync()`.
  - Localize the remaining hardcoded list strings: tooltips `'Sort'`/`'Filter'`/`'Subsystems'`, `'All'`, `'Filtered'`; sort labels `notesSortDateNewest` "Date — newest first" / 日期（最新优先）, `notesSortDateOldest` "Date — oldest first" / 日期（最早优先）, `notesSortLastModified` "Last modified" / 最近修改, `notesSortTitle` "Title — A → Z" / 标题（A → Z）, `notesSortFlag` "Flag colour" / 旗标颜色; section titles `notesViewRows` Rows / 行样式, `notesViewSort` Sort / 排序.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('pinned section first, then date sections with sticky headers', (t) async {
  // notes: pinned (last month), today, yesterday, 2026-10-03 → headers Pinned, Today, Yesterday, Oct 2026;
  // after scrolling into Yesterday's rows its header is still on screen
});
testWidgets('A–Z sort shows letter headers', (t) async {});
testWidgets('headers follow the locale', (t) async { /* zh → 今天, 2026年10月 */ });
testWidgets('View menu changes density and sort; density persists', (t) async {
  // run for TargetPlatform.iOS (CupertinoActionSheet) and TargetPlatform.android (bottom sheet)
});
testWidgets('no matches shows Clear search, which restores the list', (t) async {});
testWidgets('load failure shows Retry', (t) async {});
testWidgets('pull to refresh triggers a manual sync', (t) async {});
testWidgets('drawer and filter sheet still select a domain and its catalog', (t) async {});
testWidgets('search text stays visible after leaving and returning', (t) async {});
testWidgets('help button opens Notes list help', (t) async {});
```

- [ ] **Step 2: Run** `flutter test test/features/notes/presentation test/core/help` — FAIL.
- [ ] **Step 3: Implement** per Interfaces; remove the guard allow-list entry.
- [ ] **Step 4: Run** `flutter analyze` (no new issues) and `flutter test` (whole suite) — PASS.
- [ ] **Step 5: Commit** `feat(notes): grouped list with sticky headers, View menu, empty states and help`

---

### Task 10: Docs

**Files:**
- Modify: `CLAUDE.md` (hmm_console) — `notes/` row of the feature table, append: "The list is a `NoteQuery` evaluated by `InMemoryNoteQueryEngine` (`features/notes/query/`) over a background-warmed text index; `notesResultsProvider` is the seam a future FTS5/server engine replaces."
- Modify: `docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md` — under `### NoteQueryEngine`, a dated (2026-11-01) paragraph recording the synchronous-evaluate + provider-seam decision and pointing to this plan's "Decisions" list.

- [ ] **Step 1:** Make both edits.
- [ ] **Step 2: Run** `flutter analyze && flutter test` — clean / all pass.
- [ ] **Step 3: Commit** `docs(notes): record the slice 2 query engine decisions`

**After the plan (controller, not a subagent):** deploy to iPhone and iPad only when the user asks (`scripts/hmm-release.sh --target <ipad|iphone> --deploy --backup-first` from `~/Projects/hmm`, data kept). User checklist: Pinned section on top, date headers stick while scrolling, View ▾ densities and sorts, a Han title found by pinyin initials, a photo note in Rich shows a thumbnail, a sensitive photo shows a lock.
