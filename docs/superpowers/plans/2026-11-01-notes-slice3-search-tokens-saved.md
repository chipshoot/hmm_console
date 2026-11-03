# Notes Redesign Slice 3 — Search Tokens + Saved Searches Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Notes search box gains removable token chips with suggestions while typing, a scope toggle, recent searches, and saved searches (smart filters) that sync across devices.

**Architecture:** Slice 2 already models every token in `NoteQuery` and evaluates them in `InMemoryNoteQueryEngine`. Slice 3 adds the pieces around that engine:
- Pure modules for saved searches, recent searches, token labels and suggestions.
- A resolver that expands `SmartSource(savedId)` into the saved query in front of the engine, at the `notesResultsProvider` seam.
- The UI around the search field.

Saved searches ride in the synced settings bundle (G5: whole-bundle last-writer-wins). Recent searches are per device.

**Tech Stack:** Flutter, Riverpod 3, Drift, shared_preferences, gen-l10n (en + zh).

**Spec:** `docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md`. The relevant sections are "Settings", "Query engine and search → `NoteQuery`" and "Search behaviour", "Errors and edge cases" (the saved-search line), "Help", "Testing", and G4/G5. Slice 2 plan, for context: `docs/superpowers/plans/2026-11-01-notes-slice2-query-rows-headers.md`.

**Branch:** `feat/notes-list-slice3`, from `main` at `e8f25b6` or later.

## Global Constraints

- Icon buttons are always `HmmIconButton` with a localized tooltip. `test/core/help/icon_button_guard_test.dart` must stay green, and its allow-list only shrinks.
- Dialogs, sheets and segmented controls branch on `Theme.of(context).platform`: Cupertino on iOS, Material 3 on Android. `flutter_platform_widgets` is not a dependency.
- Do not import `flutter_slidable` or `share_plus`; they arrive in slice 5.
- Every new user-facing string goes in `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb` using the exact copy given in the tasks, then `flutter gen-l10n`. Reuse existing keys where they already say the same thing (e.g. `flagColorRed`…`flagColorGrey`, `domainLabel(key, l)`).
- Actions that hide data use `showUndoableAction` (`lib/core/help/undoable_action.dart`). Deleting a saved search is one of them.
- Changing a control means updating its `HelpId.notesList` entry. New entries use the control's own `Icons.*` constant.
- Never log note content. Errors log `runtimeType` only.
- Saved searches live in `SyncableSettings`, each a serialized `NoteQuery` with `id`, `name` and `order`. **Unknown fields are preserved.** Recent searches are per device, **max 10**.
- Search typing is debounced **~150 ms**, as the existing `_SearchField` does. That behaviour must not regress: a returning user sees the active query, tokens and scope.
- `flutter analyze` adds no new issues beyond the 2 baseline infos. Default `flutter test` is green. The `benchmark`-tagged timing test (`flutter test --tags benchmark --run-skipped`) still passes.

## Decisions this plan makes

Where the spec is silent, this plan decides as follows.

1. **Saved-search resolution happens before the engine.** `resolveSmartQuery(live, saved)` turns a live query whose source is `SmartSource(id)` into the effective query, and `notesResultsProvider` evaluates that. The engine never sees a `SmartSource` it can resolve.
   - **Source:** the saved query's source. A saved source that is itself a `SmartSource` becomes `AllSource`, so saved searches never nest.
   - **Text:** the saved text and the live text, joined with a space.
   - **Tokens:** the saved tokens, then any live tokens not already among them.
   - **Scope and sort:** the live ones. Sort is the View menu's choice; a saved search's stored `sort` is kept in its JSON but not applied.
   - **Missing id:** the live query passes through unchanged. The engine matches nothing for a `SmartSource`, and the screen shows "This saved search was deleted".
2. **Opening a saved search** sets the live query to `NoteQuery(source: SmartSource(id), scope: live.scope, sort: live.sort)`, which has empty text and tokens. Anything typed then narrows the saved search.
3. **Saving** stores the *effective* query, with `scope: NoteScope.currentSource` and the live sort. A search saved while a saved search is open therefore contains no `SmartSource`.
   - **Default name:** the trimmed text if non-empty, else the first token's label, else the source's label.
   - **When the save button shows:** only when the effective query has text, tokens, or a source other than `AllSource`.
4. **Scope covers tokens too.** The engine's `useSource` becomes `!(query.scope == NoteScope.all && (words.isNotEmpty || query.tokens.isNotEmpty))`. Picking "All notes" while a token-only search runs therefore searches all notes.
5. **The scope toggle** shows only while searching (text or tokens) **and** the source is not `AllSource`. Its segments are "All notes" and "In {source label}".
6. **Removed references are ignored, not fatal** (spec, Errors).
   - A `TagToken` whose tag is not active, or a `ParentToken` whose note is not in `corpus.all`, passes every note.
   - Its chip renders struck through as "{label} (removed)".
   - `NotesListData.liveTagNames` (`Map<int, String>?`) carries the active tags. `null` means "unknown": every tag counts as live, so a corpus built without it, as in existing tests, keeps today's behaviour.
7. **Token chips** sit in a `Wrap` directly under the text field. They are not inline inside it.
   - Each chip has a delete button.
   - Backspace in an empty field removes the last chip **on a hardware keyboard**, detected with a `Focus.onKeyEvent` handler.
   - Flutter's iOS soft keyboard sends no key event for backspace in an empty field, so on-screen-keyboard users use the chip's ✕. This is a known, accepted limitation.
8. **Suggestions and recent searches are list sections**, not overlays. Both render as a block between the search field and the results.
   - **Suggestions:** shown while the field has text, at most 8.
   - **Recent searches:** shown while the field is focused and has no text and no tokens.
   - **Tapping a suggestion** adds its token and clears the text, cancelling any pending debounce.
9. **When a search is recorded as recent:**
   - When the user opens a note from the list while the query has text or tokens.
   - When the user submits from the keyboard.

   A recent entry is `{text, tokens}` only: applying it keeps the current source. It is stored most-recent first, deduplicated by trimmed text plus token list, and capped at 10.
10. **Saved-search management in slice 3** lives in a new "Saved searches" section of the existing `_FilterDrawer`.
    - **Tap** opens the saved search.
    - **Long-press** offers Rename, Move up, Move down and Delete.
    - Slice 4 rebuilds the drawer and keeps this section. The built-in smart filters (With photos / With place / Last 7 days) arrive with that drawer in slice 4, not here.
11. **The bundle never wipes saved searches by omission.** `SyncableSettings.notesSavedSearches` is `null` when the key is absent from a bundle; `apply()` then leaves the local list untouched. An explicit `[]` does clear it. `toJson()` always writes the list.

## Review Focus

These five input classes are the most likely to break for a user. Each has a test in its owning task.

1. **A saved search references a since-deleted tag.** The list still shows the other matches, and the chip reads "(removed)". Tests: Task 1 (engine), Task 7 (chip).
2. **The open saved search is deleted** (here, or by sync from another device). The list shows "This saved search was deleted" with "Show all notes", not a blank list. Test: Task 8.
3. **A settings bundle from a device without saved searches** (key absent) is applied. Local saved searches survive. Test: Task 2.
4. **The user leaves the Notes screen and returns.** The tokens and scope are still visible and still applied. Test: Task 7.
5. **The user taps a suggestion within 150 ms of typing.** The stale typed text is never sent after the token is added. Test: Task 6.

---

### Task 1: Engine — live tags, removed references, scope over tokens

**Files:**
- Modify: `lib/core/data/local/local_tag_repository.dart`. Add `Stream<Map<int, String>> watchLiveTagNames()` to the interface and the local implementation. It returns active (`isActivated` and `deletedAt` null) tag id → name.
- Modify: `lib/features/notes/states/notes_list_state.dart`. Add the field `final Map<int, String>? liveTagNames;` to `NotesListData`, defaulting to `null`, with `copyWith` support. `build()` watches a new `_liveTagNamesStreamProvider` and passes it; `refresh()` invalidates it.
- Modify: `lib/features/notes/query/note_query_engine.dart`. Apply decisions 4 and 6.
- Test: `test/features/notes/query/note_query_engine_test.dart`, plus a test in `test/core/data/local/local_tag_repository_watch_test.dart`.

**Interfaces:**
- Produces:
  - `NotesListData.liveTagNames` (`Map<int, String>?`).
  - `ITagRepository.watchLiveTagNames()`.
  - `bool isRemovedToken(NoteToken t, NotesListData c)`, a top-level function in `note_query_engine.dart`. It is true for a `TagToken` whose id is missing from a non-null `liveTagNames`, and for a `ParentToken` whose uuid matches no note in `c.all`.

- [ ] **Step 1: Write the failing tests** in `note_query_engine_test.dart`, using the file's existing corpus helpers:
  - `a tag token for a removed tag is ignored`: the corpus has `liveTagNames: {1: 'car'}` and the query has `tokens: [TagToken(1), TagToken(99)]`. Expect exactly the notes tagged 1. Also `isRemovedToken(TagToken(99), corpus)` is true and `isRemovedToken(TagToken(1), corpus)` is false.
  - `with unknown live tags every tag token filters`: with `liveTagNames: null`, `TagToken(99)` matches no note, as today.
  - `a parent token for a note not in the corpus is ignored`: `ParentToken('gone')` returns every note in the source, and `isRemovedToken` is true for it.
  - `scope all with only tokens ignores the source`: source `DomainSource(key: 'AutomobileMan')`, `tokens: [HasPhotoToken()]`, `scope: NoteScope.all`, empty text. The result includes a General note that has a photo. With `scope: NoteScope.currentSource` it does not.
- [ ] **Step 2: Run** `flutter test test/features/notes/query/note_query_engine_test.dart`. Expected: the new tests FAIL. `isRemovedToken` is undefined, and the scope test returns the domain notes only.
- [ ] **Step 3: Implement.** `_passesToken` returns `true` for a token where `isRemovedToken` holds. Build the uuid set once per `evaluate` with the existing lazy `uuidById` pattern.
- [ ] **Step 4: Write and run the repository test** `watchLiveTagNames emits active tags only`. Use an in-memory `HmmDatabase` with one active tag, one deactivated tag and one soft-deleted tag. Expected: `{activeId: 'name'}`. Then run the whole notes test folder: `flutter test test/features/notes`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): ignore removed tag/parent tokens and widen scope to tokens`.

### Task 2: Saved searches — model, synced storage, notifier

**Files:**
- Create: `lib/features/notes/query/saved_search.dart`.
- Modify: `lib/features/settings/domain/syncable_settings.dart`. Add the field `final List<SavedSearch>? notesSavedSearches;`. Its JSON key is `notesSavedSearches`, a list of maps. `fromJson` gives `null` when the key is absent. `toJson` always writes it, as `[]` when null. Add it to `copyWith`.
- Modify: `lib/features/settings/data/syncable_settings_repository.dart`. Add the key `static const notesSavedSearchesKey = 'notes.saved_searches';`, a JSON string.
  - `read()` loads it. Unreadable JSON gives `[]` and logs `runtimeType`.
  - `apply()` writes it only when the bundle's field is non-null (decision 11).
- Create: `lib/features/notes/states/saved_searches_provider.dart`.
- Test: `test/features/notes/query/saved_search_test.dart`, `test/features/notes/states/saved_searches_provider_test.dart`, and a new `test/features/settings/syncable_settings_saved_searches_test.dart` (modelled on `syncable_settings_launcher_test.dart`).

**Interfaces:**
- Produces:
  - **The model:**
    ```dart
    class SavedSearch {
      const SavedSearch({required this.id, required this.name, required this.order,
          required this.query, this.extra = const {}});
      final String id; final String name; final int order; final NoteQuery query;
      final Map<String, Object?> extra; // unknown fields, re-emitted
      factory SavedSearch.fromJson(Map<String, Object?> json);
      Map<String, Object?> toJson(); // {id, name, order, query, ...extra}
      SavedSearch copyWith({String? name, int? order});
    }
    List<SavedSearch> parseSavedSearches(Object? json); // skips entries without a String id + String name
    ```
  - **The provider:** `savedSearchesProvider`, a `NotifierProvider<SavedSearchesNotifier, List<SavedSearch>>`, sorted by `order`. It has the same shape as `ContactSortByNotifier`: a synchronous `[]`, then hydrated from prefs, and it re-reads on `settingsBusProvider`.
  - **Notifier methods:**
    - `Future<SavedSearch> add(String name, NoteQuery query)` gives a new `generateUuid()` id (`lib/core/util/uuid.dart`) and appends last.
    - `Future<void> rename(String id, String name)`.
    - `Future<void> move(String id, int delta)`, where `delta` is -1 or +1 and clamps at the ends.
    - `Future<void> remove(String id)`.
    - `Future<void> restore(SavedSearch s)` reinserts at `s.order`.

    Every write renumbers `order` to 0..n-1, persists, and calls `bumpLastModified()`.

- [ ] **Step 1: Write the failing tests.**
  - `saved_search_test.dart`:
    - `round-trips with unknown fields`: `{'id':'a','name':'Oil','order':0,'query':{...},'color':'x'}` → `toJson` keeps `'color':'x'`.
    - `an entry without a name is skipped`.
    - `the query keeps an unknown token` (through `NoteQuery.fromJson`).
  - **syncable settings:**
    - `a bundle without notesSavedSearches leaves local saved searches untouched`: seed prefs with one saved search, then `apply(SyncableSettings.fromJson({...no key...}))` → prefs still hold it.
    - `an explicit empty list clears them`.
    - `toJson always writes notesSavedSearches`.
  - `saved_searches_provider_test.dart`, using `SharedPreferences.setMockInitialValues`:
    - add / rename / move up / move down / remove / restore. Each persists, renumbers `order`, and bumps `settings.last_modified`.
    - `move clamps at the ends`.
- [ ] **Step 2: Run** these three test files. Expected: FAIL, since nothing exists yet.
- [ ] **Step 3: Implement** as specified above.
- [ ] **Step 4: Run** those tests and `flutter test test/features/settings`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): saved searches in the synced settings bundle`.

### Task 3: Resolve smart sources at the results seam

**Files:**
- Create: `lib/features/notes/query/smart_query.dart`.
- Modify: `lib/features/notes/states/notes_results_provider.dart`. Add `notesEffectiveQueryProvider`. `notesResultsProvider` evaluates the effective query, and the index-revision watch keys off the **effective** text.
- Test: `test/features/notes/query/smart_query_test.dart`, `test/features/notes/states/notes_results_provider_test.dart`.

**Interfaces:**
- Consumes: `SavedSearch` and `savedSearchesProvider` (Task 2).
- Produces:
  - `NoteQuery resolveSmartQuery(NoteQuery live, List<SavedSearch> saved)` implements decision 1.
  - `SavedSearch? savedSearchFor(NoteSource s, List<SavedSearch> saved)` is non-null only for a `SmartSource` whose id exists.
  - `final notesEffectiveQueryProvider = Provider.autoDispose<NoteQuery?>(...)` is null while the list is loading.

- [ ] **Step 1: Write the failing tests** in `smart_query_test.dart`:
  - `non-smart queries pass through` (identical object).
  - `expands to the saved source, text and tokens`: saved `{source: Domain('AutomobileMan'), text: 'oil', tokens: [HasPhotoToken()]}`; live `{SmartSource(id), text: 'filter', tokens: [PinnedToken()], sort: subjectAZ, scope: all}`. Expect source `Domain('AutomobileMan')`, text `'oil filter'`, tokens `[HasPhotoToken(), PinnedToken()]`, sort `subjectAZ`, scope `all`.
  - `a duplicated live token is not repeated`.
  - `a nested smart source becomes All`.
  - `a missing id passes the live query through`.

  In `notes_results_provider_test.dart`, `a smart source lists the saved search's notes` overrides `savedSearchesProvider`.
- [ ] **Step 2: Run** both. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/notes` and `flutter test --tags benchmark --run-skipped`. Expected: PASS, with a median ≤ 50 ms.
- [ ] **Step 5: Commit** `feat(notes): resolve saved searches before the query engine`.

### Task 4: Recent searches (per device)

**Files:**
- Modify: `lib/core/settings/app_settings.dart`. Add `final List<Map<String, Object?>> notesRecentSearches;`, defaulting to `const []`. Its JSON key is `notesRecentSearches`; non-map entries are dropped on read. Add it to `copyWith`.
- Modify: `lib/core/settings/settings_controller.dart`. Add `Future<void> setNotesRecentSearches(List<Map<String, Object?>> v)`.
- Create: `lib/features/notes/states/recent_searches.dart`.
- Test: `test/features/notes/states/recent_searches_test.dart`.

**Interfaces:**
- Produces:
  - `typedef RecentSearch = ({String text, List<NoteToken> tokens});`.
  - `List<RecentSearch> pushRecent(List<RecentSearch> list, RecentSearch r)` is pure. It trims the text and ignores an entry whose text and tokens are both empty. It moves an equal entry to the front, keeps at most `kMaxRecentSearches = 10`, and puts the newest first.
  - `recentSearchesProvider`, an `AsyncNotifierProvider<RecentSearchesNotifier, List<RecentSearch>>` with methods `record(NoteQuery q)` (uses `q.text` and `q.tokens`) and `clear()`. Entries are stored as `{'text':…, 'tokens':[…token json…]}`, so unknown tokens round-trip.

- [ ] **Step 1: Write the failing tests**:
  - `pushRecent dedups and moves to the front`.
  - `caps at 10, dropping the oldest`.
  - `ignores an empty search`.
  - `equal ignoring surrounding spaces`.
  - `record persists and survives a reload` (new container, same mock prefs).
  - `clear empties the list`.
  - `an unknown token round-trips`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Follow `FilterUsageNotifier` for the read-from-controller-then-write pattern.
- [ ] **Step 4: Run** the test and `flutter test test/core/settings`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): remember the last 10 searches on this device`.

### Task 5: Token labels and suggestions (pure)

**Files:**
- Create: `lib/features/notes/query/note_token_labels.dart`.
- Create: `lib/features/notes/query/note_token_suggestions.dart`.
- Modify: both ARB files. Add the keys below, then run `flutter gen-l10n`.
- Test: `test/features/notes/query/note_token_suggestions_test.dart`.

**ARB keys (en / zh):**

| Key | en | zh |
|-----|----|----|
| `notesTokenHasPhoto` | Has photos | 含照片 |
| `notesTokenHasPlace` | Has place | 含地点 |
| `notesTokenHasAttachment` | Has attachments | 含附件 |
| `notesTokenPinned` | Pinned | 已置顶 |
| `notesTokenLast7d` | Last 7 days | 最近 7 天 |
| `notesTokenLast30d` | Last 30 days | 最近 30 天 |
| `notesTokenLast90d` | Last 90 days | 最近 90 天 |
| `notesTokenFlag` (`{color}`) | {color} flag | {color}旗标 |
| `notesTokenParent` (`{subject}`) | Attached to {subject} | 附属于{subject} |
| `notesTokenTag` (`{name}`) | #{name} | #{name} |
| `notesTokenDateRange` (`{from}`, `{to}`) | {from} – {to} | {from} – {to} |
| `notesTokenRemoved` (`{label}`) | {label} (removed) | {label}（已移除） |
| `notesTokenUnknown` | Unknown filter | 未知条件 |

**Interfaces:**
- Consumes: `isRemovedToken` and `liveTagNames` (Task 1).
- Produces:
  - `typedef TokenLabel = ({String text, bool removed});`.
  - `TokenLabel tokenLabel(NoteToken t, NotesListData c, AppLocalizations l, {required String Function(HmmNote) titleOf, required DateFormat dateFormat})`. How each token is labelled:

    | Token | Label |
    |-------|-------|
    | Tag | its live name; a removed tag uses `notesTokenRemoved` around `#<id>` |
    | Domain | `domainLabel(key, l)` |
    | Catalog | the catalog's name from `c.catalogsById`, or `#<id>` |
    | Parent | `notesTokenParent(titleOf(note))`; removed → `notesTokenRemoved(notesTokenParent('…'))` |
    | Flag | `notesTokenFlag` with the `flagColor*` name |
    | Date range | `notesTokenDateRange` with `dateFormat`; a missing end is an empty string |
    | Unknown | `notesTokenUnknown` |
  - `class TokenSuggestion { final NoteToken token; final String label; final IconData icon; }`.
  - `List<TokenSuggestion> suggestTokens(String text, NotesListData c, List<NoteToken> existing, AppLocalizations l, {required String Function(HmmNote) titleOf})`.

**Suggestion rules:**
- The fragment is `normalizeForSearch(text).trim()`. An empty fragment gives `[]`.
- A candidate matches when `normalizeForSearch(label).contains(fragment)`.
- Candidates already in `existing` are excluded.
- Candidates come in this kind order:
  1. live tags (`Icons.sell_outlined`);
  2. domains present in `c.countsByDomain` (`Icons.folder_outlined`);
  3. flag colours (`Icons.flag`);
  4. parents, meaning notes that at least one note in `c.all` is attached to, at most 3 (`Icons.link`);
  5. Has photos (`Icons.photo_outlined`), Has place (`Icons.place_outlined`), Has attachments (`Icons.attach_file`), Pinned (`Icons.push_pin_outlined`);
  6. Last 7/30/90 days (`Icons.date_range`).
- At most 8 in total.

- [ ] **Step 1: Write the failing tests**:
  - `suggests a tag by a substring, case- and accent-insensitive` (`'CAFE'` → tag `café`).
  - `suggests a Chinese tag by one character` (`'保'` → `保养`).
  - `suggests a domain by its localized label` (en `'auto'` → Automobile).
  - `suggests flag colours by name` (`'red'` → `FlagToken(0)`).
  - `suggests a parent note by its title, at most 3`.
  - `suggests attributes and date ranges` (`'photo'` → `HasPhotoToken`; `'7'` → `last7d`).
  - `excludes tokens already applied`.
  - `never more than 8`.
  - `empty text suggests nothing`.
  - Label tests: `tokenLabel marks a removed tag` (`removed: true`, text contains `(removed)`) and `tokenLabel names a flag`.

  Use `lookupAppLocalizations(const Locale('en'))` for `l`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the test and `flutter analyze`. Expected: PASS, with no new issues.
- [ ] **Step 5: Commit** `feat(notes): token labels and search suggestions`.

### Task 6: `NoteSearchField` — text, token chips, debounce, keyboard backspace

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_search_field.dart`. It replaces the private `_SearchField` in `notes_list_screen.dart`; delete that class in Task 7, not here.
- Modify: both ARB files. Add `notesTokenRemoveTooltip` (`{label}`): en "Remove {label}", zh "移除{label}".
- Test: `test/features/notes/presentation/widgets/note_search_field_test.dart`.

**Interfaces:**
- Produces:
  ```dart
  class NoteSearchField extends StatefulWidget {
    const NoteSearchField({super.key, required this.text, required this.chips,
      required this.hintText, required this.clearTooltip,
      required this.onTextChanged, required this.onRemoveLastToken,
      this.onSubmitted, this.focusNode});
    final String text;                 // the applied text (from the notifier)
    final List<Widget> chips;          // token chips, built by the screen
    final String hintText, clearTooltip;
    final ValueChanged<String> onTextChanged; // debounced 150 ms
    final VoidCallback onRemoveLastToken;     // hardware Backspace on empty text
    final ValueChanged<String>? onSubmitted;
    final FocusNode? focusNode;
  }
  ```
  - `NoteSearchFieldState.clearAndCancel()` clears the box and cancels the pending debounce, without sending. The screen calls it through a `GlobalKey` when a suggestion is tapped.
  - Keep the existing `_SearchField` behaviours and its `Key('notesSearchClear')` clear button: echoes do not move the caret, and an outside change is copied in.

- [ ] **Step 1: Write the failing tests**. Port the existing `_SearchField` tests from `notes_list_screen_test.dart` that exercise the field alone. Then add:
  - `sends text 150 ms after the last keystroke, not before`.
  - `hardware backspace on empty text removes the last token`: `sendKeyEvent(LogicalKeyboardKey.backspace)` with empty text → `onRemoveLastToken` called once. With text present it is not called.
  - `clearAndCancel drops a pending keystroke`: type `'oil'`, call `clearAndCancel()` within 150 ms, pump 300 ms → `onTextChanged` was never called with `'oil'` (Review Focus 5).
  - `renders the chips under the field`.
  - `submit sends immediately`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Use a `Column(TextField, Wrap(chips))`. The `Focus(onKeyEvent:)` handler wraps the `TextField` and returns `KeyEventResult.handled` only when it removed a token.
- [ ] **Step 4: Run** the test file and `flutter test test/core/help/icon_button_guard_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): search field with token chips`.

### Task 7: List screen — chips, suggestions, recent searches, scope toggle

**Files:**
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`.
  - Replace `_SearchField` with `NoteSearchField`.
  - Build the chips with `tokenLabel`, as `InputChip`s on Android and `Chip` with a delete icon on iOS. Each has the delete tooltip `notesTokenRemoveTooltip`, and a removed label is drawn with `TextDecoration.lineThrough`.
  - Add the suggestions section (`ListTile`s: icon, label). Tapping one does `notifier.setQuery(q.copyWith(text: '', tokens: [...q.tokens, s.token]))` and calls `clearAndCancel()`.
  - Add the recent-searches section, shown when the field has focus and no text or tokens.
    - It has the header `notesRecentSearches` and a `TextButton` `notesRecentSearchesClear`.
    - Each row shows the text plus token labels joined with " · ". Tapping applies `text` and `tokens`.
  - Add the scope toggle (decision 5). On iOS it's a `CupertinoSlidingSegmentedControl`; on Android a `SegmentedButton`.
  - Record a recent search on opening a note while text or tokens are non-empty, and on submit.
  - Highlight words come from the **effective** query's text (`notesEffectiveQueryProvider`).
- Modify: `lib/features/notes/states/notes_list_state.dart`. Add `void setTokens(List<NoteToken> t)` and `void setScope(NoteScope s)`.
- Modify: both ARB files.

  | Key | en | zh |
  |-----|----|----|
  | `notesRecentSearches` | Recent searches | 最近搜索 |
  | `notesRecentSearchesClear` | Clear | 清除 |
  | `notesScopeAll` | All notes | 全部笔记 |
  | `notesScopeCurrent` (`{source}`) | In {source} | 在{source}中 |
  | `notesSuggestionsHeader` | Suggestions | 建议 |

- Modify: `lib/core/help/help_registry.dart`. Add an entry to `HelpId.notesList` with icon `Icons.manage_search`, also used as the leading icon of the Suggestions header. Its keys are `helpNotesListTokensTitle` and `helpNotesListTokensBody`:
  - en title: "Search tokens".
  - en body: "As you type, suggestions appear for tags, domains, flags, attached-to notes, photos, places and date ranges. Tap one to add it as a chip; tap a chip's ✕ (or press Backspace in an empty box on a keyboard) to remove it. While a filter is active, choose whether the search covers all notes or only that filter. Tap the empty search box to see your recent searches."
  - zh title: "搜索条件".
  - zh body: "输入时会出现标签、领域、旗标、所属笔记、照片、地点和日期范围的建议。点按建议即可添加为条件；点按条件上的 ✕（或在外接键盘上于空白搜索框中按退格键）即可移除。启用筛选时，可选择在全部笔记或仅在该筛选中搜索。点按空白搜索框可查看最近的搜索。"
- Test: `test/features/notes/presentation/notes_list_screen_test.dart`, plus a new `test/features/notes/presentation/notes_search_tokens_test.dart`.

**Interfaces:**
- Consumes:
  - Tasks 1–6.
  - `NotesListState.setQuery`, `setText` and `setSource` (slice 2).

- [ ] **Step 1: Write the failing widget tests** in `notes_search_tokens_test.dart`. Use the corpus and override pattern of `notes_list_screen_test.dart`.
  - `typing shows suggestions and tapping one adds a chip and filters`: type `'car'`, then tap the `#car` suggestion. The chip `#car` is shown, the box is empty, and only car-tagged rows are listed.
  - `removing a chip restores the list`.
  - `a removed tag's chip is struck out and ignored`: query `tokens: [TagToken(99)]` with `liveTagNames` lacking 99. The chip text contains "(removed)", its style has `lineThrough`, and every note is listed (Review Focus 1).
  - `tokens and scope are still shown after leaving and returning`: push another route, pop, and the chip and selected scope segment are present (Review Focus 4).
  - `the scope toggle appears only while searching inside a filter`, and choosing "All notes" lists notes outside the domain.
  - `focusing the empty box shows recent searches; tapping one applies it`.
  - `opening a note from a search records a recent search`.
  - `iOS and Android variants render` (both platforms, `debugDefaultTargetPlatformOverride`).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Delete `_SearchField` and move or update the tests that targeted it.
- [ ] **Step 4: Run** `flutter test test/features/notes test/core/help` and `flutter analyze`. Expected: PASS, with only the 2 baseline infos.
- [ ] **Step 5: Commit** `feat(notes): token search with suggestions, recents and scope`.

### Task 8: Save search, open it, manage it from the drawer

**Files:**
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`.
  - **Save button:** add a `HmmIconButton` (`Icons.bookmark_add_outlined`, tooltip `notesSaveSearchTooltip`) at the end of the search row, shown per decision 3.
  - **Name dialog:** a `CupertinoAlertDialog` with a `CupertinoTextField` on iOS, an `AlertDialog` with a `TextField` on Android. It is prefilled with the default name, and Save is disabled while the name is blank. On Save it calls `savedSearchesProvider.notifier.add(name, effectiveQuery)` and shows the `notesSavedSearchSaved(name)` snackbar.
  - **Drawer section:** add a "Saved searches" section to `_FilterDrawer` with the header `notesSavedSearchesHeader`, shown only when the list is non-empty.
    - Each row has icon `Icons.bookmark_outline`, the name, and selected state when `query.source == SmartSource(id)`.
    - **Tap** follows decision 2, then closes the drawer.
    - **Long-press** opens a platform action sheet with Rename (a dialog like the save dialog), Move up, Move down (hidden at the ends), and Delete.
    - **Delete** uses `showUndoableAction` with `remove` / `restore` and the four messages below.
  - **Missing saved search:** when `query.source is SmartSource` and `savedSearchFor` is null, the empty state shows `notesSavedSearchMissing` with action `notesShowAllNotes` → `setSource(const AllSource())` (Review Focus 2).
  - **Scope label:** the scope toggle's "In {source}" uses the saved search's name for a smart source.
- Modify: both ARB files.

  | Key | en | zh |
  |-----|----|----|
  | `notesSaveSearchTooltip` | Save search | 保存搜索 |
  | `notesSaveSearchTitle` | Save search | 保存搜索 |
  | `notesSaveSearchNameLabel` | Name | 名称 |
  | `notesSaveSearchSave` | Save | 保存 |
  | `notesSavedSearchSaved` (`{name}`) | Saved "{name}" | 已保存“{name}” |
  | `notesSavedSearchesHeader` | Saved searches | 已保存的搜索 |
  | `notesSavedSearchRename` | Rename | 重命名 |
  | `notesSavedSearchRenameTitle` | Rename saved search | 重命名已保存的搜索 |
  | `notesSavedSearchMoveUp` | Move up | 上移 |
  | `notesSavedSearchMoveDown` | Move down | 下移 |
  | `notesSavedSearchDelete` | Delete | 删除 |
  | `notesSavedSearchDeleted` (`{name}`) | Deleted "{name}" | 已删除“{name}” |
  | `notesSavedSearchDeleteFailed` | Couldn't delete the saved search | 无法删除已保存的搜索 |
  | `notesSavedSearchRestored` (`{name}`) | Restored "{name}" | 已恢复“{name}” |
  | `notesSavedSearchRestoreFailed` | Couldn't restore the saved search | 无法恢复已保存的搜索 |
  | `notesSavedSearchMissing` | This saved search was deleted | 此已保存的搜索已被删除 |
  | `notesShowAllNotes` | Show all notes | 显示全部笔记 |

  Reuse an existing Cancel key if there is one; otherwise add `notesCancel` (Cancel / 取消).
- Modify: `lib/core/help/help_registry.dart`. Add a `HelpId.notesList` entry with icon `Icons.bookmark_add_outlined` and keys `helpNotesListSavedTitle` / `helpNotesListSavedBody`:
  - en: "Saved searches" / "Tap the bookmark beside the search box to save the current search, filters and tokens included. Saved searches appear in the side panel; tap one to open it, or long-press it to rename, move or delete it. They sync to your other devices."
  - zh: "已保存的搜索" / "点按搜索框旁的书签图标即可保存当前搜索，包括筛选和条件。已保存的搜索显示在侧边栏中；点按即可打开，长按可重命名、移动或删除。它们会同步到你的其他设备。"
- Test: `test/features/notes/presentation/notes_saved_searches_test.dart`.

**Interfaces:**
- Consumes:
  - `savedSearchesProvider` (Task 2).
  - `resolveSmartQuery`, `savedSearchFor` and `notesEffectiveQueryProvider` (Task 3).
  - `tokenLabel` (Task 5).

- [ ] **Step 1: Write the failing widget tests**:
  - `save button appears only with something to save`.
  - `saving stores the effective query and it opens from the drawer`: search `'oil'` with `HasPhotoToken()`, save as "Oil photos", clear the search, open the drawer, tap "Oil photos". Only the matching notes are listed, and the search box is empty.
  - `saving while a saved search is open stores no SmartSource`.
  - `rename, move down and delete with undo from the long-press menu`. Delete shows "Deleted "Oil photos"", and Undo brings it back in the same position.
  - `deleting the open saved search shows the deleted message with Show all notes`. Tapping it lists every note (Review Focus 2).
  - `the save dialog is Cupertino on iOS and Material on Android`.
  - `help lists the Search tokens and Saved searches entries`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full default `flutter test`, then `flutter analyze` and `flutter test --tags benchmark --run-skipped`. Expected: all green, the 2 baseline infos, and a median ≤ 50 ms.
- [ ] **Step 5: Commit** `feat(notes): save searches and manage them from the drawer`.

### Task 9: Docs

**Files:**
- Modify: hmm_console `CLAUDE.md`, the `notes/` row of the feature table. Append: "Search takes tokens (chips with suggestions), a scope toggle and recent searches (per device); saved searches are `SavedSearch` entries in `SyncableSettings`, expanded by `resolveSmartQuery` before the engine."
- Modify: the spec, under "### Search behaviour". Add a dated paragraph: "**2026-11-01 (Slice 3 decisions):** see 'Decisions this plan makes' in `docs/superpowers/plans/2026-11-01-notes-slice3-search-tokens-saved.md` — notably backspace-removes-chip works on hardware keyboards only (Flutter's iOS soft keyboard sends no key event on an empty field; chips have ✕), and built-in smart filters move to slice 4 with the drawer."

- [ ] **Step 1: Edit** both files.
- [ ] **Step 2: Commit** `docs(notes): record the slice 3 search decisions`.
