# Notes Redesign Slice 4 — Drawer, Chip Bar, Wide-Screen Sidebar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Notes list gains four things:
- a mailbox-style side panel (drawer on phones, a docked sidebar on wide screens) with counts;
- an automatic, usage-ordered chip bar under the search box;
- built-in smart filters;
- a visible read-only view of an open saved search's own tokens.

It also retires the old domain chip, the sub-filter popup and the funnel sheet.

**Architecture:**
- **Side panel:** the current private `_FilterDrawer` becomes a public `NotesSidebar` widget. It is fed by the library counts the query engine already returns (`NoteResults.counts`). It renders inside a `Drawer` on phones and narrow tablets, and docked at 240 pt at ≥ 1000 pt.
- **Chip bar:** chosen by a pure function from usage counts (extending `filterUsageProvider`) and library counts.
- **Built-in smart filters:** fixed `SavedSearch` entries that `resolveSmartQuery` already knows how to expand, so the engine is unchanged.

**Tech Stack:** Flutter, Riverpod 3, gen-l10n (en + zh).

**Spec:** `docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md`.
- **Relevant sections:**
  - "Screens and interaction → Phone / Wide screens / Drawer / sidebar / Replaced from today"
  - "Settings" (chip usage counts)
  - "Query engine → Counts"
  - "Help"
  - G3 and G4
- **Slice 3 dated note:** read the dated "2026-11-01 (Slice 3 decisions)" paragraph under "Search behaviour", which defers showing an open saved search's tokens to this slice.
- **Previous plan:** `docs/superpowers/plans/2026-11-01-notes-slice3-search-tokens-saved.md`, for context.

**Branch:** `feat/notes-list-slice4`, from `main` at `2cadc77` or later.

## Global Constraints

- **Icon buttons:** always `HmmIconButton` with a localized tooltip. `test/core/help/icon_button_guard_test.dart` must stay green, and its allow-list only shrinks.
- **Platform widgets:** dialogs, sheets and pickers branch on `Theme.of(context).platform`, with Cupertino on iOS and Material 3 on Android. `flutter_platform_widgets` is not a dependency.
- **Imports:** do not import `flutter_slidable` or `share_plus`; they arrive in slice 5. Recently Deleted (slice 5) and the Tags UI / Manage tags (slice 6) are **not** in this slice.
- **Strings:** every new user-facing string goes in `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb` with the exact copy given in the tasks, then `flutter gen-l10n`. Reuse the existing keys listed in the tasks.
- **Help:** changing a control means updating its `HelpId.notesList` entry. An entry's icon is the control's own `Icons.*` constant.
- **Logging:** never log note content; errors log `runtimeType` only.
- **iOS rules:** respect safe areas. Swipe-from-left-edge back must keep working, so do not replace the iOS back button and keep `drawerEnableOpenDragGesture: false` (`AppScaffold`).
- **Layout widths** (spec, verbatim): "≥ 1000 pt: **sidebar (240) | list (360) | detail**. 720–1000: list | detail, sidebar as a slide-over. < 720: phone layout."
- **Chip bar** (spec, verbatim): "All · Pinned · 🚩 Flagged · top 3 most-used domains/tags · ＋ (opens drawer)". Chip usage counts are per device and extend today's `filter_usage`.
- **Drawer content** (spec, verbatim): "All · Pinned · Flagged (with a sub-row per colour in use, showing its name) · Today · **Domains** (counts) · **Tags** (counts; Manage tags…) · **Smart filters** (saved + built-in With photos / With place / Last 7 days; reorder and rename by long-press) · Recently Deleted". Manage tags… and Recently Deleted are left out until slices 6 and 5.
- **Commit trailer**, required on every commit, exactly: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not amend; a hook blocks it.
- **Verification:** `flutter analyze` adds nothing beyond the 2 baseline infos, the default `flutter test` is green, and `flutter test test/features/notes/query/note_query_benchmark_test.dart --run-skipped` keeps a median ≤ 50 ms.

## Decisions this plan makes

Where the spec is silent, this plan decides as follows.

1. **Built-in smart filters are fixed saved searches.** `builtInSmartFilters` is a `const List<SavedSearch>` with ids `builtin.withPhotos` (`tokens: [HasPhotoToken()]`), `builtin.withPlace` (`[HasPlaceToken()]`) and `builtin.last7d` (`[RelativeDateToken(RelativeRange.last7d)]`). Each has `source: AllSource` and an empty `name`; names are localized at display time.
   - `notesEffectiveQueryProvider` resolves against `[...builtInSmartFilters, ...saved]`, and so does `savedSearchFor` wherever the screen calls it.
   - Built-ins are never stored, renamed, moved or deleted, and long-press on them does nothing.
2. **Usage keys.** `filterUsageProvider` keeps its existing domain keys (e.g. `AutomobileMan`), so existing counts carry over. Tags use `tag:<id>`.
   - Usage is recorded when the user picks a domain or tag from the side panel or the chip bar.
   - Pinned, Flagged, Today and smart filters are not counted, because they are fixed chips or panel-only.
3. **Chip bar order.**
   - All · Pinned · Flagged, then a **current-source chip** if the active source is not one of the visible chips (a non-top domain or tag, Today, a flag colour, or a smart filter). It is shown selected and named after the source, so the active filter is always visible.
   - Then the top 3 domains/tags: candidates are domains with notes and live tags with notes, ranked by usage count, then note count, then label.
   - Then ＋. ＋ is hidden when the sidebar is docked.
   - Tapping the selected chip returns to All. Pinned → `PinnedSource`, Flagged → `FlaggedSource()`, a domain → `DomainSource(key)`, a tag → `TagSource(tagId)`.
4. **The ☰ button** is an action (`HmmIconButton`, `Icons.menu`, first in `actions`), not a leading widget, so the iOS back button and edge swipe stay intact. It is hidden when the sidebar is docked.
5. **Retired:**
   - `_FilterBar` (the "tune" ActionChip with the main label) and `_SubFilterButton`;
   - the funnel `HmmIconButton` (`Icons.filter_list`) and `lib/features/notes/presentation/widgets/catalog_filter_sheet.dart`.

   The per-catalog filter survives as a `catalog` token: `suggestTokens` gains catalog candidates (`Icons.category_outlined`, label `catalogLabel(name, l)`), ranked after domains. Existing `DomainSource(catalogId:)` queries (e.g. in saved searches) keep working, because the engine still evaluates them.
6. **The open saved search's own tokens** render as read-only chips (no delete button, outlined, with a leading `Icons.bookmark_outline` on the first chip) before the live chips. Their text renders as one read-only chip with the text in quotes when non-empty. Removed ones use the same struck-out "(removed)" label as live chips (`tokenLabel`), which closes the slice 3 deviation.
7. **Side panel picks.**
   - `NotesSidebar` takes `onPicked` (`VoidCallback`). The drawer passes `() => Navigator.of(context).pop()`; the docked sidebar passes a no-op. The sidebar never calls `Navigator.pop` itself.
   - On a saved search, a delete closes the panel by calling `onPicked` (not `Navigator.pop`) before the undo snackbar, so the docked sidebar never pops the Notes route.
8. **Counts:**
   - Come from `ref.watch(notesResultsProvider).value?.counts` (`NoteCounts`): All = `all`, Pinned = `pinned`, Flagged = sum of `byFlag`, each colour = `byFlag[i]`, domains = `byDomain`, tags = `byTag`.
   - Today and smart filters show no count.
   - While results load, counts are hidden, not shown as 0.
   - Flag sub-rows list only colours with count > 0, named with `flagName` (default colour names).
9. **Wide layout.**
   - `NotesShellScreen` uses `kNotesWideBreakpoint = 720` (unchanged) and a new `kNotesSidebarBreakpoint = 1000`.
   - At ≥ 1000 the row is `NotesSidebar` (240) | divider | `NotesListScreen(sidebarDocked: true)` (360) | divider | detail.
   - The detail pane and `selectedNoteIdProvider` are unchanged. Crossing a breakpoint keeps the query and the selected note, because both live in providers.

## Review Focus

1. **Picking a filter in the docked sidebar must not pop the Notes route**, which a stray `Navigator.pop` would do. Test: Task 6.
2. **Resizing across 1000 pt and 720 pt** (iPad rotation) keeps the query, tokens and selected note, and does not duplicate the sidebar. Test: Task 6.
3. **A non-top domain/tag, Today, a flag colour or a smart filter** is the active source, so the chip bar shows it as a selected chip and never shows "All" selected while filtered. Test: Task 2.
4. **A usage entry for a tag that has since been deleted** (`tag:<id>` with no live tag) never produces a chip or a count row. Test: Task 2.
5. **Built-in smart filters can't be renamed or deleted, and are never "missing"**: opening one never shows "This saved search was deleted", and long-press on one does nothing. Tests: Tasks 1 and 3.

---

### Task 1: Built-in smart filters

**Files:**
- Create: `lib/features/notes/query/built_in_smart_filters.dart`.
- Modify: `lib/features/notes/states/notes_results_provider.dart`. `notesEffectiveQueryProvider` resolves against `[...builtInSmartFilters, ...saved]`.
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`. Every `savedSearchFor(...)` call passes the combined list. Read it through `notesSmartFiltersProvider` (below).
- Modify: both ARB files.

  | Key | en | zh |
  |-----|----|----|
  | `notesSmartWithPhotos` | With photos | 含照片 |
  | `notesSmartWithPlace` | With place | 含地点 |
  | `notesSmartLast7d` | Last 7 days | 最近 7 天 |
- Test: `test/features/notes/query/built_in_smart_filters_test.dart`, and extend `test/features/notes/states/notes_results_provider_test.dart`.

**Interfaces:**
- Produces:
  - `const List<SavedSearch> builtInSmartFilters` (decision 1).
  - `bool isBuiltInSmartFilter(String id)` (true when `id.startsWith('builtin.')`).
  - `String builtInSmartFilterName(String id, AppLocalizations l)`.
  - `final notesSmartFiltersProvider = Provider<List<SavedSearch>>((ref) => [...builtInSmartFilters, ...ref.watch(savedSearchesProvider)])`.

- [ ] **Step 1: Write the failing tests**:
  - `the three built-ins expand to their tokens`: `resolveSmartQuery(NoteQuery(source: SmartSource(savedId: 'builtin.withPhotos')), builtInSmartFilters).tokens == [HasPhotoToken()]`, and likewise for place and last7d.
  - `a built-in is never missing`: `savedSearchFor(SmartSource(savedId: 'builtin.last7d'), ref.read(notesSmartFiltersProvider))` is non-null with an empty saved list.
  - `names are localized`: en "With photos", zh "含照片".
  - In `notes_results_provider_test.dart`, `a built-in smart filter lists only notes with photos`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/notes`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): built-in smart filters`.

### Task 2: Chip-bar model (pure)

**Files:**
- Create: `lib/features/notes/states/note_chip_bar.dart`.
- Modify: `lib/features/notes/states/filter_usage.dart`. Add `String usageKeyForTag(int tagId) => 'tag:$tagId'`. The `record(key)` signature is unchanged.
- Test: `test/features/notes/states/note_chip_bar_test.dart`.

**Interfaces:**
- Consumes: `NoteCounts` (`lib/features/notes/query/note_results.dart`), `NotesListData` (`liveTagNames`, `tagsByNoteId`, `countsByDomain`), and `NoteQuery.source`.
- Produces:
  ```dart
  sealed class ChipBarEntry { const ChipBarEntry(); }
  class ChipBarSource extends ChipBarEntry {          // a chip that sets a source
    const ChipBarSource(this.source, {required this.selected, this.usageKey});
    final NoteSource source; final bool selected; final String? usageKey;
  }
  class ChipBarMore extends ChipBarEntry { const ChipBarMore(); } // ＋
  List<ChipBarEntry> chipBarEntries({
    required NoteSource active, required NotesListData data,
    required NoteCounts? counts, required Map<String, int> usage,
    required bool sidebarDocked, String Function(String domainKey)? domainLabelOf,
    String Function(int tagId)? tagLabelOf,
  });
  ```
  The order is decision 3. Ranking ties on label use `domainLabelOf` / `tagLabelOf` when they are given, and fall back to the key otherwise. Tag candidates are only tags present in `liveTagNames` (or in `tagsByNoteId` when `liveTagNames` is null) with count > 0.

- [ ] **Step 1: Write the failing tests**:
  - `fixed chips come first`: All, Pinned, Flagged, in that order.
  - `top 3 by usage, then count, then label`: 5 domains/tags with usage `{A:5, tag:2:5, B:1}` and counts. Expect A and tag:2 (by count), then B.
  - `a deleted tag in usage never appears` (Review Focus 4): usage `{'tag:99': 50}`, tag 99 is not live → not among the entries.
  - `a non-top active source gets a selected chip` (Review Focus 3), for each of `TagSource` (not in the top 3), `TodaySource`, `FlaggedSource(color: 2)` and `SmartSource('builtin.withPhotos')`: exactly one `ChipBarSource` with `selected: true` equal to it, inserted right after Flagged. `AllSource` is not selected.
  - `the active top-3 domain is selected in place, not duplicated`.
  - `＋ is last, and absent when docked`.
  - `domains with no notes are not candidates`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the test file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): chip bar model`.

### Task 3: `NotesSidebar` — the side panel with counts

**Files:**
- Create: `lib/features/notes/presentation/widgets/notes_sidebar.dart`. Move `_FilterDrawer`'s content here, including the saved-search section, its long-press menu and the undo delete, then extend it.
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`. `drawer:` becomes `Drawer(child: NotesSidebar(data: data, onPicked: () => Navigator.of(context).pop()))`. Delete `_FilterDrawer`.
- Modify: both ARB files.

  | Key | en | zh |
  |-----|----|----|
  | `notesSidebarDomains` | Domains | 领域 |
  | `notesSidebarTags` | Tags | 标签 |
  | `notesSidebarSmartFilters` | Smart filters | 智能筛选 |

  Reuse `notesAll`, `notesTokenPinned` ("Pinned"), `notesGroupToday` ("Today"), `flagName(color, l)`, `domainLabel`, `notesSavedSearchesHeader` and the slice 3 saved-search strings. For the "Flagged" row, add `notesSidebarFlagged`: en "Flagged", zh "已标记". The existing `notesFlaggedLabel` takes a colour.
- Modify: `lib/core/help/help_registry.dart` and both ARB files. The existing entry (icon `Icons.filter_list`, keys `helpNotesListFilterTitle` / `helpNotesListFilterBody`) now describes the side panel. Change its icon to `Icons.menu` and its copy to:
  - en: "Side panel" / "Open the side panel (☰) to filter by Pinned, Flagged (by colour), Today, a domain, a tag or a smart filter; the numbers show how many notes each holds. Long-press one of your saved searches to rename, move or delete it. On a wide screen the panel stays open beside the list."
  - zh: "侧边栏" / "打开侧边栏（☰）即可按已置顶、已标记（按颜色）、今天、领域、标签或智能筛选来筛选；数字表示各项包含的笔记数。长按你保存的搜索可重命名、移动或删除。在宽屏上，侧边栏会一直显示在列表旁。"
- Test: `test/features/notes/presentation/widgets/notes_sidebar_test.dart`. Move or update the relevant drawer tests in `notes_filter_drawer_navigation_test.dart`, `notes_saved_searches_test.dart` and `notes_filter_chips_test.dart`.

**Interfaces:**
- Consumes: `notesSmartFiltersProvider`, `builtInSmartFilterName`, `isBuiltInSmartFilter` (Task 1), `usageKeyForTag` (Task 2), and `NoteCounts` via `notesResultsProvider`.
- Produces: `class NotesSidebar extends ConsumerWidget { const NotesSidebar({super.key, required this.data, required this.onPicked}); final NotesListData data; final VoidCallback onPicked; }`.
  - **Sections**, in this order: All · Pinned · Flagged, plus a sub-row per colour with count > 0 · Today · Domains · Tags (live tags with count > 0, name-sorted) · Smart filters (the built-ins first, then saved searches).
  - **Counts:** trailing per decision 8.
  - **Picking** sets the source (decision 3 mapping; a smart filter follows slice 3's decision 2), records usage for domains and tags (decision 2), then calls `onPicked`.

- [ ] **Step 1: Write the failing widget tests**:
  - `lists the sections in order with counts`.
  - `flag sub-rows show only colours in use, by name`.
  - `counts are hidden while results load`.
  - `picking a tag sets TagSource, records tag:<id> usage and calls onPicked once`.
  - `a built-in smart filter opens; long-press does nothing` (Review Focus 5).
  - `saved-search rename / move / delete with undo still work` (ported).
  - `the help entry shows "Side panel" with the menu icon`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/notes test/core/help` and `flutter analyze`. Expected: PASS, with only the 2 baseline infos.
- [ ] **Step 5: Commit** `feat(notes): side panel with counts, tags, flags and smart filters`.

### Task 4: Chip bar on the list; retire the old filter bar and funnel

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_chip_bar.dart`. A horizontally scrolling row of `ChoiceChip`s built from `chipBarEntries`.
  - **Labels:** All → `notesAll`; Pinned → `notesTokenPinned`; Flagged → `notesSidebarFlagged`; a flag colour → `flagName`; a domain → `domainLabel`; a tag → `notesTokenTag(name)`; Today → `notesGroupToday`; a smart filter → its name (built-in or saved).
  - **＋:** an `ActionChip` with `Icons.add` and tooltip `notesChipMoreTooltip`, which calls `Scaffold.of(context).openDrawer()`.
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`.
  - Replace `_filterBar` / `_FilterBar` / `_SubFilterButton` with `NoteChipBar`.
  - Remove the funnel `HmmIconButton` and its `CatalogFilterSheet` call.
  - Add the ☰ `HmmIconButton` (`Icons.menu`, tooltip `notesMenuTooltip`) first in `actions` (decision 4).
  - Add the constructor flag `NotesListScreen({super.key, this.sidebarDocked = false})`. When docked, the screen has no drawer, no ☰ and no ＋.
- Delete: `lib/features/notes/presentation/widgets/catalog_filter_sheet.dart`, and any test that only targets it.
- Modify: both ARB files.

  | Key | en | zh |
  |-----|----|----|
  | `notesMenuTooltip` | Filters and lists | 筛选和列表 |
  | `notesChipMoreTooltip` | More filters | 更多筛选 |
- Modify: `lib/core/help/help_registry.dart`. Add a `HelpId.notesList` entry with icon `Icons.add` and keys `helpNotesListChipsTitle` / `helpNotesListChipsBody`:
  - en: "Quick filters" / "The row under the search box switches between All, Pinned, Flagged and the domains and tags you use most; it learns from what you pick. Tap a selected chip again to go back to All, or tap ＋ to open the side panel with every filter."
  - zh: "快速筛选" / "搜索框下方的一行可在全部、已置顶、已标记以及你最常用的领域和标签之间切换；它会根据你的选择自动调整。再次点按已选中的条件即可回到全部，点按 ＋ 打开包含所有筛选的侧边栏。"
- Test: `test/features/notes/presentation/widgets/note_chip_bar_test.dart`. Update `notes_filter_chips_test.dart` and `notes_list_screen_test.dart` for the new bar.

**Interfaces:**
- Consumes: `chipBarEntries` and `usageKeyForTag` (Task 2); `NotesSidebar` (Task 3), which is what ☰ and ＋ open.
- Produces: `NotesListScreen.sidebarDocked` and `class NoteChipBar extends ConsumerWidget { const NoteChipBar({super.key, required this.data, required this.sidebarDocked}); }`.

- [ ] **Step 1: Write the failing tests**:
  - `the bar shows All, Pinned, Flagged, the top domain and ＋`.
  - `tapping a domain chip filters and records usage; tapping it again returns to All`.
  - `＋ opens the side panel`.
  - `☰ opens the side panel`.
  - `there is no funnel button and no sub-filter popup`.
  - `an open built-in smart filter shows as a selected chip`.
  - `iOS keeps its back button`: the leading widget is not replaced, so push the list from a dummy route and find `CupertinoNavigationBarBackButton`.
  - `the help entry "Quick filters" uses Icons.add`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/notes test/core/help` and `flutter analyze`. Expected: PASS, with only the 2 baseline infos and the icon-button guard green.
- [ ] **Step 5: Commit** `feat(notes): automatic chip bar replaces the filter chip and funnel`.

### Task 5: Catalog tokens; read-only chips for an open saved search

**Files:**
- Modify: `lib/features/notes/query/note_token_suggestions.dart`. Add catalog candidates per decision 5: catalogs in `data.catalogsById` that have at least one note, ranked after domains and before flags. They share the overall cap of 8.
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart` (`_chips`). Decision 6.
- Test: extend `test/features/notes/query/note_token_suggestions_test.dart` and `test/features/notes/presentation/notes_search_tokens_test.dart`.

**Interfaces:**
- Consumes:
  - `tokenLabel` (slice 3).
  - `savedSearchFor` together with `notesSmartFiltersProvider` (Task 1).
  - `catalogLabel(name, l)` (`lib/features/notes/presentation/catalog_labels.dart`).

- [ ] **Step 1: Write the failing tests**:
  - `suggests a catalog by its label`: `'gas'` → `CatalogToken(<gas log catalog id>)`.
  - `a catalog token filters to that catalog`: an end-to-end widget test, typing then tapping the suggestion.
  - `an open saved search shows its tokens as read-only chips`: no delete button, and the live chips follow.
  - `an open saved search's removed tag shows "(removed)"`: struck through, which closes the slice 3 deviation.
  - `the saved text shows as one quoted read-only chip`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/notes`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(notes): catalog tokens and read-only saved-search chips`.

### Task 6: Wide layouts — docked sidebar at ≥ 1000 pt

**Files:**
- Modify: `lib/features/notes/states/note_selection.dart`. Add `const double kNotesSidebarBreakpoint = 1000;`.
- Modify: `lib/features/notes/presentation/screens/notes_shell_screen.dart`. Decision 9: at ≥ 1000, `Row(SizedBox(240, NotesSidebar(data, onPicked: () {})), VerticalDivider(width: 1), SizedBox(360, NotesListScreen(sidebarDocked: true)), VerticalDivider(width: 1), Expanded(detail))`. The 720–1000 and < 720 layouts are unchanged.
  - The sidebar needs `NotesListData`. Watch `notesListStateProvider` in the shell, and show a blank 240 pane while it loads.
  - Wrap the docked sidebar in `SafeArea(right: false)` and `Material`.
- Test: extend `test/features/notes/presentation/notes_shell_screen_test.dart`.

**Interfaces:**
- Consumes: `NotesSidebar` (Task 3) and `NotesListScreen(sidebarDocked:)` (Task 4).

- [ ] **Step 1: Write the failing widget tests**:
  - `at 1100 pt the sidebar is docked and the list has no ☰`: the 240 and 360 panes are present and no `Icons.menu` is found.
  - `at 800 pt the layout is list and detail, and ☰ opens the drawer`.
  - `at 400 pt the phone layout`.
  - `picking a filter in the docked sidebar filters the list and keeps the route` (Review Focus 1): `Navigator.canPop` stays the same and the Notes screen is still shown.
  - `resizing from 1100 to 800 to 1100 keeps the query, tokens and selected note` (Review Focus 2): set a token and select a note, resize with `tester.view.physicalSize`, and assert that the token chip, the selected note's detail and exactly one `NotesSidebar` are present.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full `flutter test`, `flutter analyze` and the benchmark file with `--run-skipped`. Expected: all green, only the 2 baseline infos, and a median ≤ 50 ms.
- [ ] **Step 5: Commit** `feat(notes): docked sidebar on wide screens`.

### Task 7: Docs

**Files:**
- Modify: hmm_console `CLAUDE.md`, the `notes/` row. Append: "The side panel (`NotesSidebar`: counts, flags, tags, smart filters incl. built-ins) is a drawer on phones and docked at ≥ 1000 pt; the chip bar under the search box is chosen from per-device usage (`chipBarEntries`)."
- Modify: the spec, under "### Drawer / sidebar". Add the paragraph: "**2026-11-02 (Slice 4 decisions):** see 'Decisions this plan makes' in `docs/superpowers/plans/2026-11-02-notes-slice4-drawer-chips-sidebar.md` — built-in smart filters are fixed saved searches; the funnel and sub-filter popup are gone (the per-catalog filter is a `catalog` token); an open saved search's tokens show as read-only chips; ☰ is an action so the iOS back button stays."

- [ ] **Step 1: Edit** both files.
- [ ] **Step 2: Commit** `docs(notes): record the slice 4 decisions`.
