# Notes Redesign Slice 5: Swipes, Long-Press Menu, Multi-Select and Recently Deleted (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Notes list gains:
- fixed swipe actions;
- a long-press menu, with a share action for ordinary notes;
- multi-select with bulk Pin, Flag and Delete, plus one Undo;
- a Recently Deleted screen (Restore, Delete Now, Empty…).

The note detail also handles a note that was deleted on another device, and the list labels a deleted parent note.

**Architecture:**
- **Already built in slice 1:** the data paths: soft delete, `restoreNote`, `NotePurgeService.purgeNow` and the daily purge. This slice is UI over them, plus two small additions:
  - a `watchDeletedNotes()` stream on the note repository;
  - a per-device "last flag colour" setting.
- **Bulk logic:** lives in one pure-Dart service (`NoteBulkActions`) that reports per-note outcomes, so the widgets only show messages.
- **Swipes:** use `flutter_slidable`.
- **Long-press:** shows a `CupertinoContextMenu` on iOS and a Material bottom sheet on Android.
- **Recently Deleted:** its own route, `/notes/deleted`, reached from the side panel. It is not a `NoteQuery` source; the engine stays unchanged.

**Tech Stack:** Flutter, Riverpod 3, Drift, gen-l10n (en + zh), `flutter_slidable`, `share_plus`.

**Spec:** `docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md`.
- **Relevant sections:**
  - "Data model and sync → Recently Deleted"
  - "Screens and interaction → Actions / Recently Deleted / Drawer / sidebar"
  - "Errors and edge cases"
  - "Platform rules"
  - "Help"
  - G4, G6, G7, G8, G11, G12 and G13
- **Previous plan:** `docs/superpowers/plans/2026-11-02-notes-slice4-drawer-chips-sidebar.md`, for context.

**Branch:** `feat/notes-list-slice5`, from `main` at `a41a983` or later.

## Global Constraints

- **Icon buttons:** always `HmmIconButton` with a localized tooltip. `test/core/help/icon_button_guard_test.dart` must stay green, and its allow-list only shrinks. Text buttons (Edit / Done / Select All) are `TextButton` on Android and `CupertinoButton` on iOS, never raw `IconButton`.
- **Platform widgets:** dialogs, sheets, menus and pickers branch on `Theme.of(context).platform`, with Cupertino on iOS/macOS and Material 3 on Android. `flutter_platform_widgets` is not a dependency.
- **Dependencies:** add exactly two packages, `flutter_slidable` and `share_plus` (G8), at the latest versions compatible with the current SDK. No PDF library.
- **G7 (verbatim):** "Entity notes cannot be deleted from Notes. Notes deletes only ordinary notes; contacts, cheatsheets, gas logs, cars, service records, licence and similar show "Manage in Contacts / Cheatsheets / Automobile …" instead of Delete (row action, long-press, multi-select and note detail). Pin, flag and tags work on every note. Multi-select bulk Delete skips entity notes and says how many were skipped." The only test for "ordinary" is `canDeleteFromNotes` / `managePlaceFor` in `lib/features/notes/states/note_delete_policy.dart`.
- **G13 (verbatim):** "Share only ordinary notes (markdown text); entity notes say "Share from Contacts / Cheatsheets / …"."
- **G11 (verbatim):** "Recently Deleted lists only ordinary notes deleted from Notes." Retention is fixed at 30 days (G6).
- **Moving or hiding data** goes through `showUndoableAction` (`lib/core/help/undoable_action.dart`); this covers delete, bulk delete and attach. Permanent deletes (Delete Now, Empty…) keep a confirmation dialog and have no Undo. Do not use a `WidgetRef` or `BuildContext` after an await.
- **Strings:** every new user-facing string goes in `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb` with the exact copy given in the tasks, then `flutter gen-l10n`. Reuse these existing keys and do not duplicate them:
  - `notesPin`, `notesUnpin`, `notesFlagAction`, `notesClearFlag`
  - `notesPinFailed`, `notesFlagFailed`, `notesDeleteFailed`
  - `notesManageIn`, `notesMovedToRecentlyDeleted`, `notesRestored`, `notesRestoreFailed`
  - `commonDelete`, `commonCancel`, `commonEdit`, `undoAction`
  - `managePlaceLabel(place, l)`
- **Help:** each changed or new control updates its help entry (`HelpId.notesList`, plus the new `HelpId.notesRecentlyDeleted`). An entry's icon is the control's own `Icons.*` constant, and every new screen has a `HelpButton` in its top bar.
- **Logging:** never log note content; errors log `runtimeType` only.
- **iOS:** respect safe areas, and keep the left-edge back swipe working. On iOS the swipe-right (start) pane must not start inside the 20 pt left edge; see Review Focus 5.
- **Tags:** `Tags…` (long-press and bulk) is **slice 6**. Leave it out here.
- **Commit trailer:** required on every commit, exactly `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not amend; a hook blocks it.
- **Verification:**
  - `flutter analyze` adds nothing beyond the 2 baseline infos;
  - the default `flutter test` run is green;
  - `flutter test test/features/notes/query/note_query_benchmark_test.dart --run-skipped` keeps a median ≤ 50 ms.

## Decisions this plan makes

Where the spec is silent or contradicts itself, this plan decides as follows.

1. **Android long-press opens the bottom sheet, and its first item is "Select".** The spec says both "Long-press: … Android bottom sheet" and "Multi-select: … Android long-press then tap". Tapping Select enters multi-select with that note selected; after that, a tap toggles notes.
   - On iOS, multi-select starts from the **Edit** button in the top bar. The context menu also has Select, for parity.
2. **Left swipe:**
   - **Flag** uses the last-used colour (default red). A note that is already flagged shows **Unflag** instead.
   - **Delete** appears for ordinary notes. Entity notes show **Manage** in that slot, which opens the note's own screen through `noteDisplayRegistryProvider.open`. If that returns false, it shows the existing `notesManageIn` text in a snackbar.
   - **Last-used colour:** any flag chosen from the flag sheet (long-press, bulk, note detail) becomes the last-used colour. It is stored per device in `AppSettings.notesLastFlagColor` (int, default 0 = red).
3. **Bulk Pin** pins every selected note unless all of them are already pinned, in which case it unpins them all (Apple Mail's behaviour). **Bulk Flag** opens the flag sheet; Clear flag unflags them all.
4. **Bulk results:**
   - **Pin and flag:** a full success shows no message, because the rows show it.
   - **Partial failure:** shows "Pinned 8 of 10 notes"-style copy. The failed notes stay selected and the rest are deselected. A full success leaves multi-select.
5. **Bulk Delete:**
   - **Eligibility first:** decided up front from `data.catalogsById` before anything is written. Entity notes are skipped and not deselected.
   - **Messages and Undo:** the message is chosen by `bulkDeleteMessage` (Task 1). One Undo restores every note the action deleted.
   - **Partial failure:** the action reports `failed` with the copy "Couldn't delete some notes. They stay selected." and offers no Undo. The notes it did delete stay in Recently Deleted, where they can be restored.
   - **Only entity notes selected:** a plain snackbar shows and nothing is written.
6. **Multi-select ends** on Done, on a full success, or when the side panel or a chip changes the source. **Select All** adds every hit in the current results, including the Pinned section. While multi-select is active, swipes and the long-press menu are off, and a row tap toggles the note.
7. **Recently Deleted** is a separate screen at `/notes/deleted`, not a `NoteQuery` source. `RecentlyDeletedSource` stays unmatched in the engine.
   - **Side panel:** a "Recently Deleted" row with a count, last in the panel (after Smart filters).
   - **Order:** most recently deleted first.
   - **Countdown:** "Deletes in N days", where `N = max(1, 30 - now.difference(deletedAt).inDays)`. A note deleted 30 days ago or more that hasn't been purged yet is **not listed**.
   - **Tapping a row** opens the note detail, which shows the deleted banner (Task 6).
8. **Attach to…** is only for ordinary notes, because an entity note's parent belongs to its feature. It uses the existing `showNoteLinkPicker(context, ref, excludeNoteId: id)` and `MutateNote.setParent`, and Undo restores the previous parent.
9. **Share text** is the subject, then a blank line, then the markdown body (`content`). The subject alone is used when the body is empty. It goes through `SharePlus.instance.share(ShareParams(text: …))` behind a `NoteSharer` provider, so tests can fake it.
10. **Deleted parent label (G12):** when a note's parent is soft-deleted, the row's parent label is "(deleted note)". Any soft-deleted note counts as a deleted parent. The source is the same `watchDeletedNotes()` stream, before the ordinary-note filter.

## Review Focus

1. **Bulk Delete with a mixed selection** (3 ordinary + 2 contacts):
   - the message reads "Deleted 3 · 2 skipped";
   - one Undo brings all 3 back;
   - the 2 contacts stay selected and untouched;
   - with only contacts selected, nothing is written and the "managed in their own screens" message shows.
   - *Test:* Task 1 `bulkDelete` cases and Task 4 widget test.
2. **Undo after the note has left the current view**, for example deleting from the Pinned view or a search: Undo restores by id even though the row is gone.
   - *Test:* Task 2 swipe-delete-then-Undo in a filtered view.
3. **Recently Deleted day boundaries:**
   - deleted 29 d 23 h ago reads "Deletes in 1 day";
   - deleted exactly now reads "Deletes in 30 days";
   - deleted 30 d 1 h ago (purge not yet run) is hidden;
   - an entity note deleted by its feature is never listed (G11).
   - *Test:* Task 5 provider tests.
4. **Wide screen, open note:**
   - swipe-deleting, bulk-deleting or Delete Now on the note open in the detail pane clears `selectedNoteIdProvider`, so the pane never shows a missing note;
   - a note deleted on another device shows the banner with Restore instead of an error.
   - *Test:* Task 2 / Task 4 wide tests and Task 6 banner test.
5. **iOS left-edge back swipe still pops Notes** while rows have a start (Pin) pane: a drag starting at x < 20 pt pops the route, and a drag starting mid-row opens Pin.
   - *Test:* Task 2 iOS widget test with a pushed `CupertinoPageRoute`.

---

### Task 1: Packages, last flag colour, bulk actions service

**Files:**
- Modify: `pubspec.yaml` (add `flutter_slidable`, `share_plus`)
- Modify: `lib/core/settings/app_settings.dart`, `lib/core/settings/settings_controller.dart`
- Create: `lib/features/notes/states/note_bulk_actions.dart`
- Test: `test/features/notes/states/note_bulk_actions_test.dart`, plus the existing `AppSettings` JSON test file (create `test/core/settings/app_settings_test.dart` if there is none)

**Interfaces:**
- **Produces:**
  - `AppSettings.notesLastFlagColor` (`int`, default `0`; JSON key `notesLastFlagColor`; an unknown value is kept).
  - `SettingsController.setNotesLastFlagColor(int)`.
  - `final notesLastFlagColorProvider = Provider<int>(...)`.
  - The code below, in `note_bulk_actions.dart`:

```dart
class BulkOutcome {
  const BulkOutcome({required this.succeeded, required this.failed});
  final List<int> succeeded; // note ids, input order
  final List<int> failed;
  int get total => succeeded.length + failed.length;
}

class BulkDeleteOutcome {
  const BulkDeleteOutcome({required this.deleted, required this.skipped, required this.failed});
  final List<int> deleted;  // moved to Recently Deleted
  final List<int> skipped;  // entity notes (G7), never written
  final List<int> failed;
}

class NoteBulkActions {
  NoteBulkActions(this._mutate);
  /// Pins all, unless every id is already pinned (then unpins all).
  Future<(bool pinned, BulkOutcome)> togglePinned(List<int> ids, Map<int, bool> isPinnedById);
  Future<BulkOutcome> setFlag(List<int> ids, int? flagColor);
  /// [isOrdinary] decides eligibility (from canDeleteFromNotes) before any write.
  Future<BulkDeleteOutcome> delete(List<int> ids, bool Function(int id) isOrdinary);
  Future<BulkOutcome> restore(List<int> ids);
}
final noteBulkActionsProvider = Provider<NoteBulkActions>(...);

/// The snackbar text for a bulk delete, or null when nothing was eligible
/// (the caller then shows notesBulkNothingDeleted instead).
String? bulkDeleteMessage(BulkDeleteOutcome o, AppLocalizations l);
```

- **Consumes:** `MutateNote.setPinned / setFlagColor / delete / restore` (`lib/features/notes/states/mutate_note_state.dart`).
- **Each id is attempted independently.** An exception on one id adds it to `failed` and the loop continues. The log line is `debugPrint('NoteBulkActions: … failed (${e.runtimeType})')`.

**ARB keys (en / zh):**

| Key | en | zh |
|---|---|---|
| `notesBulkDeleted` | `{count, plural, =1{Deleted 1 note} other{Deleted {count} notes}}` | `已删除 {count} 条笔记` |
| `notesBulkDeletedSkipped` | `Deleted {count} · {skipped} skipped` | `已删除 {count} 条 · 跳过 {skipped} 条` |
| `notesBulkNothingDeleted` | `{count, plural, =1{This note is managed in its own screen} other{These {count} notes are managed in their own screens}}` | `这些笔记需在各自的页面中管理` |
| `notesBulkDeleteSomeFailed` | `Couldn't delete some notes. They stay selected.` | `部分笔记无法删除，它们仍处于选中状态。` |
| `notesBulkRestored` | `{count, plural, =1{Restored 1 note} other{Restored {count} notes}}` | `已恢复 {count} 条笔记` |
| `notesBulkRestoreFailed` | `Couldn't restore the notes` | `无法恢复这些笔记` |
| `notesBulkPinPartial` | `Pinned {done} of {total} notes` | `已置顶 {done}/{total} 条笔记` |
| `notesBulkUnpinPartial` | `Unpinned {done} of {total} notes` | `已取消置顶 {done}/{total} 条笔记` |
| `notesBulkFlagPartial` | `Flagged {done} of {total} notes` | `已加旗标 {done}/{total} 条笔记` |
| `notesBulkUnflagPartial` | `Unflagged {done} of {total} notes` | `已移除旗标 {done}/{total} 条笔记` |

All placeholders are `int`.

- [ ] **Step 1: Write the failing tests.** Use a fake `MutateNote` (subclass with overrides) that records calls and throws for chosen ids.
  - `togglePinned pins all when any is unpinned`: ids `[1,2,3]`, pinned `{1:true,2:false,3:true}`. Expect `pinned == true`, `setPinned(id, true)` for all 3, and `succeeded == [1,2,3]`.
  - `togglePinned unpins all when all are pinned`: expect `pinned == false`.
  - `setFlag keeps going after a failure`: fake throws for 2. Expect `succeeded == [1,3]` and `failed == [2]`.
  - `delete skips entity notes without writing them`: ids `[1,2,3,4,5]`, `isOrdinary` true for 1–3. Expect `deleted == [1,2,3]`, `skipped == [4,5]`, and `MutateNote.delete` never called for 4 or 5.
  - `delete with only entity notes writes nothing`: `deleted` and `failed` are empty and `skipped == [4,5]`.
  - `bulkDeleteMessage`:
    - `(deleted 3, skipped 0)` → `'Deleted 3 notes'`;
    - `(3, 2)` → `'Deleted 3 · 2 skipped'`;
    - `(1, 0)` → `'Deleted 1 note'`;
    - `(0, 2)` → `null`.
  - `AppSettings.notesLastFlagColor`:
    - defaults to 0;
    - round-trips 4 through JSON;
    - keeps an unknown 9;
    - a missing key reads as 0.
- [ ] **Step 2:** Run `flutter test test/features/notes/states/note_bulk_actions_test.dart`. Expect FAIL, because the file doesn't exist yet.
- [ ] **Step 3:** Add the packages with `flutter pub add flutter_slidable share_plus`, then add the ARB keys, run `flutter gen-l10n`, and implement the interfaces above.
- [ ] **Step 4:** Run the tests and `flutter analyze`. Expect PASS and the 2 baseline infos only.
- [ ] **Step 5: Commit.** `feat(notes): bulk note actions and last flag colour`, with the trailer.

### Task 2: Swipe actions on list rows

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_swipe_actions.dart`
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`, in `row(NoteHit hit)` (around line 615): wrap `NoteRow` in `NoteSwipeActions`
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart` (`_delete` delegates to `deleteNoteWithUndo`)
- Modify: `lib/core/help/help_registry.dart` (`HelpId.notesList`: new swipes entry)
- Test: `test/features/notes/presentation/widgets/note_swipe_actions_test.dart`

**Interfaces:**
- **Consumes:**
  - `notesLastFlagColorProvider` and `MutateNote` (Task 1);
  - `canDeleteFromNotes`, `managePlaceFor`;
  - `noteDisplayRegistryProvider.open`;
  - `selectedNoteIdProvider`, `kNotesWideBreakpoint`.
- **Produces:**

```dart
class NoteSwipeActions extends ConsumerWidget {
  const NoteSwipeActions({super.key, required this.note, required this.state,
      required this.catalogName, required this.enabled, required this.child});
  final HmmNote note;
  final NoteState state;
  final String? catalogName;
  final bool enabled; // false during multi-select (Task 4)
  final Widget child;
}
/// Delete with Undo, clearing the wide-screen selection when the deleted note
/// is open there. Shared by swipe, long-press and note detail.
Future<void> deleteNoteWithUndo(BuildContext context, WidgetRef ref, int noteId);
```

**Behaviour:**
- `Slidable` has `key: ValueKey(note.id)`, and its `groupTag` is the list, so only one row is open at a time.
- **Start pane (swipe right):** one action, Pin/Unpin (`Icons.push_pin` / `Icons.push_pin_outlined`), labelled `notesPin` / `notesUnpin`.
- **End pane (swipe left):**
  - Flag or Unflag, labelled with the new key `notesUnflag` or `notesFlag`, with `Icons.flag` / `Icons.outlined_flag`.
  - For ordinary notes, Delete (`commonDelete`, `Icons.delete`, red, and full-swipe dismisses through `deleteNoteWithUndo`).
  - For entity notes, Manage (`notesManageShort`, `Icons.open_in_new`).
- **Failures:** a failed pin shows the `notesPinFailed` snackbar, and a failed flag shows `notesFlagFailed`.
- **iOS left edge:** the start pane is dragged from anywhere except the first 20 pt on iOS, so the route's edge back swipe wins there. Implement this with a `Listener` that disables the slidable when a pointer goes down at `x < 20`.
- **`deleteNoteWithUndo`:**
  - Move the body of `NoteDetailScreen._delete`'s `showUndoableAction` call here. Its `busyKey` is `('deleteNote', id)` and it uses the same four messages.
  - After a successful run on a wide screen, it calls `select(null)` when `selectedNoteIdProvider` equals the id.
  - `NoteDetailScreen._delete` keeps its pop (narrow) but delegates the undoable part to this helper.

**ARB keys:**

| Key | en | zh |
|---|---|---|
| `notesFlag` | `Flag` | `旗标` |
| `notesUnflag` | `Unflag` | `移除旗标` |
| `notesManageShort` | `Manage` | `管理` |
| `helpNotesListSwipesTitle` | `Swipe a note` | `滑动笔记` |
| `helpNotesListSwipesBody` | `Swipe right to pin or unpin. Swipe left to flag it in your last-used colour, or to delete it. Deleted notes go to Recently Deleted for 30 days. Notes that belong to Contacts, Cheatsheets or Automobile show Manage instead of Delete.` | `向右滑动可置顶或取消置顶。向左滑动可用上次使用的颜色加旗标，或删除笔记。删除的笔记会在“最近删除”中保留 30 天。属于通讯录、卡片或汽车的笔记显示“管理”而不是“删除”。` |

The help entry's icon is `Icons.swipe`.

- [ ] **Step 1: Write the failing widget tests.** Use the existing notes test harness and overrides from `test/features/notes/presentation/notes_list_screen_test.dart`.
  - `swipe right pins an unpinned note`: drag the row +300 px, tap Pin, expect `setPinned(id, true)`.
  - `swipe left on an ordinary note shows Flag and Delete`.
  - `swipe left on a contact note shows Manage, not Delete`.
  - `flag uses the last-used colour`: last colour 3 → `setFlagColor(id, 3)`.
  - `flagged note shows Unflag, which clears the flag`: `setFlagColor(id, null)`.
  - `swipe delete then Undo restores, even from the Pinned view`: source `PinnedSource`, the note is pinned; delete → `delete(id)`; tap `Undo` → `restore(id)` (Review Focus 2).
  - `wide: deleting the open note clears the selection`: width 1200, `selectedNoteIdProvider` = id; after the delete it is null (Review Focus 4).
  - `pin failure shows the snackbar`: fake throws → text `Couldn't pin the note`.
  - `iOS: a drag from the left edge pops the route; a mid-row drag opens Pin`: `TargetPlatform.iOS`, Notes pushed with a `CupertinoPageRoute`; a drag from x=5 pops, and a drag from x=100 shows `Pin` (Review Focus 5).
- [ ] **Step 2:** Run the tests. Expect FAIL.
- [ ] **Step 3:** Implement the widget, the list wiring, the refactor of the detail delete, and the help entry, then run `flutter gen-l10n`.
- [ ] **Step 4:** Run the new tests, `test/features/notes/`, and the help/icon guard tests. Expect PASS.
- [ ] **Step 5: Commit.** `feat(notes): swipe to pin, flag and delete`, with the trailer.

### Task 3: Long-press menu and share

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_actions_menu.dart`
- Create: `lib/features/notes/states/note_sharer.dart`
- Modify: `notes_list_screen.dart` (wrap the row: on iOS a `CupertinoContextMenu` around the swipe-wrapped row; on Android `NoteRow.onLongPress` opens the sheet). Add an `onLongPress` parameter to `NoteRow` if it has none.
- Modify: `help_registry.dart` (long-press entry)
- Test: `test/features/notes/presentation/widgets/note_actions_menu_test.dart`, `test/features/notes/states/note_sharer_test.dart`

**Interfaces:**
- **Produces:**

```dart
String shareTextFor(HmmNote note); // Decision 9
abstract interface class NoteSharer { Future<void> shareText(String text); }
final noteSharerProvider = Provider<NoteSharer>((ref) => const SharePlusNoteSharer());

enum NoteMenuAction { pin, flag, attach, share, select, delete, manage }
class NoteMenuItem { const NoteMenuItem(this.action, {this.enabled = true}); final NoteMenuAction action; final bool enabled; }
/// The menu items for a note, in order (labels are resolved by the widget).
List<NoteMenuItem> noteMenuItems({required bool ordinary});
Future<void> showNoteActionsSheet(BuildContext context, WidgetRef ref, {required HmmNote note,
    required NoteState state, required String? catalogName, required VoidCallback onSelect});
```

- **Consumes:**
  - `deleteNoteWithUndo` (Task 2);
  - `showNoteFlagSheet` (writing the chosen colour to `setNotesLastFlagColor` as well);
  - `showNoteLinkPicker`, `MutateNote.setParent`, `managePlaceFor`, `managePlaceLabel`.
- **Menu order (spec, minus Tags… for slice 6):** Pin/Unpin · Flag… · Attach to… · Share… · Select · Delete.
  - **Entity notes:** Attach to… is hidden. Share… is replaced by a disabled `notesShareFrom(place)`. Delete is replaced by a disabled `notesManageIn(place)`, as in the detail menu today.
  - **iOS:** `CupertinoContextMenuAction`s, with the row as the preview and Delete `isDestructiveAction`.
  - **Android:** `showModalBottomSheet` with `ListTile`s, with Select first (Decision 1).
- **Attach to…:**
  - Runs `showUndoableAction` with run = `setParent(id, picked.id)` and undo = `setParent(id, previousParentId)`.
  - Its `busyKey` is `('attach', id)`.
  - Messages are `notesAttached(title)`, `notesAttachFailed`, `notesAttachUndone` and `notesAttachUndoFailed`. The title comes from `noteDisplayRegistryProvider.title`.

**ARB keys:**

| Key | en | zh |
|---|---|---|
| `notesShareAction` | `Share…` | `分享…` |
| `notesShareFrom` | `Share from {place}` | `请在{place}中分享` |
| `notesShareFailed` | `Couldn't share the note` | `无法分享笔记` |
| `notesAttachToAction` | `Attach to…` | `附加到…` |
| `notesAttached` | `Attached to "{title}"` | `已附加到“{title}”` |
| `notesAttachFailed` | `Couldn't attach the note` | `无法附加笔记` |
| `notesAttachUndone` | `Attachment undone` | `已撤销附加` |
| `notesAttachUndoFailed` | `Couldn't undo the attachment` | `无法撤销附加` |
| `notesSelectAction` | `Select` | `选择` |
| `helpNotesListLongPressTitle` | `Touch and hold a note` | `长按笔记` |
| `helpNotesListLongPressBody` | `Opens a menu to pin, flag, attach the note to another note, share it as text, select it, or delete it. Notes from Contacts, Cheatsheets or Automobile are shared and deleted from their own screens.` | `打开菜单，可置顶、加旗标、附加到另一条笔记、以文本分享、选择或删除。来自通讯录、卡片或汽车的笔记需在各自的页面中分享和删除。` |

The help icon is `Icons.touch_app`. `place` and `title` are `String`.

- [ ] **Step 1: Write the failing tests.**
  - `shareTextFor`:
    - subject `Trip`, body `**Day 1**` → `'Trip\n\n**Day 1**'`;
    - an empty or null body → `'Trip'`.
  - `noteMenuItems ordinary`: the action order is `[pin, flag, attach, share, select, delete]`, all enabled.
  - `noteMenuItems entity`: `[pin, flag, share(disabled), select, manage(disabled)]`.
  - Android sheet:
    - long-press opens the sheet with `Select` first;
    - tapping `Share…` calls the fake sharer with `shareTextFor(note)`;
    - tapping `Flag…` then Blue → `setFlagColor(id, 4)` and last colour 4.
  - iOS:
    - long-press shows a `CupertinoContextMenu` holding `Delete` for an ordinary note;
    - a contact note shows the disabled `Manage in Contacts` and `Share from Contacts`.
  - `attach then Undo restores the previous parent`: a picker override returns note 9 → `setParent(id, 9)`; Undo → `setParent(id, null)`.
  - `share failure shows the snackbar`: the sharer throws → `Couldn't share the note`.
- [ ] **Step 2:** Run the tests. Expect FAIL.
- [ ] **Step 3:** Implement. `SharePlusNoteSharer` is the only file that imports `share_plus`. Run `flutter gen-l10n`.
- [ ] **Step 4:** Run `test/features/notes/` and the guard tests. Expect PASS.
- [ ] **Step 5: Commit.** `feat(notes): long-press menu with attach and share`, with the trailer.

### Task 4: Multi-select and bulk actions

**Files:**
- Create: `lib/features/notes/states/notes_multi_select.dart`
- Create: `lib/features/notes/presentation/widgets/notes_bulk_bar.dart`
- Modify: `notes_list_screen.dart`:
  - top bar: iOS `Edit`/`Done`; while active, the title is `notesSelectedCount`;
  - rows: a leading check circle while active;
  - the bulk bar at the bottom inside a `SafeArea`.
- Modify: `NoteRow` (a `selected: bool?` parameter; null = not in selection mode)
- Modify: `notes_sidebar.dart`, `note_chip_bar.dart`: picking a source calls `notesMultiSelectProvider.notifier.exit()`
- Modify: `help_registry.dart` (multi-select entry)
- Test: `test/features/notes/states/notes_multi_select_test.dart`, `test/features/notes/presentation/notes_multi_select_screen_test.dart`

**Interfaces:**
- **Produces:**

```dart
class NotesMultiSelect { const NotesMultiSelect({this.active = false, this.ids = const {}}); final bool active; final Set<int> ids; }
class NotesMultiSelectNotifier extends Notifier<NotesMultiSelect> {
  void enter([int? firstId]); void exit(); void toggle(int id);
  void selectAll(Iterable<int> ids); void keepOnly(Iterable<int> ids);
}
final notesMultiSelectProvider = NotifierProvider<NotesMultiSelectNotifier, NotesMultiSelect>(...);
```

- **Consumes:**
  - `NoteBulkActions` and `bulkDeleteMessage` (Task 1);
  - `showNoteFlagSheet`;
  - `notesResultsProvider` (for Select All: every `hit.note.id` across `results.groups`);
  - `canDeleteFromNotes` with `data.catalogsById`;
  - `NoteSwipeActions.enabled` (Task 2) set to `!active`; the long-press menu (Task 3) is off while active.
- **Bulk bar:** HmmIconButtons Pin (`Icons.push_pin_outlined`, tooltip `notesPin` or `notesUnpin` per Decision 3), Flag (`Icons.flag_outlined`, `notesFlagAction`) and Delete (`Icons.delete_outline`, `commonDelete`), plus a `Select All` text button. All are disabled while `ids` is empty.
- **Bulk Delete:**
  - **Only entity notes selected:** show the `notesBulkNothingDeleted(skipped)` snackbar and write nothing.
  - **Otherwise:** `showUndoableAction` with `done = bulkDeleteMessage(...)`, computed from eligibility before the run.
    - **run:** calls `delete`, then `keepOnly(skipped + failed)`. It throws if `failed` is non-empty, which shows `notesBulkDeleteSomeFailed`.
    - **undo:** `restore(deleted)`.
    - **Messages:** undone is `notesBulkRestored(n)` and undoFailed is `notesBulkRestoreFailed`.
  - **After success:** exits when nothing is left selected. On a wide screen, clear `selectedNoteIdProvider` if it was deleted.
- **Android entry:** the long-press sheet's Select (Task 3) calls `enter(id)`. While active, the app bar shows a close `HmmIconButton` (`Icons.close`, tooltip `notesDoneAction`) instead of the Edit text.

**ARB keys:**

| Key | en | zh |
|---|---|---|
| `notesSelectedCount` | `{count, plural, =0{Select notes} =1{1 selected} other{{count} selected}}` | `已选 {count} 项` |
| `notesSelectAll` | `Select All` | `全选` |
| `notesDoneAction` | `Done` | `完成` |
| `helpNotesListSelectTitle` | `Select several notes` | `选择多条笔记` |
| `helpNotesListSelectBody` | `Tap Edit (on Android, touch and hold a note and choose Select), then tap notes to select them. Pin, flag or delete them all at once; Select All picks every note in the current list. One Undo brings back a bulk delete. Notes from Contacts, Cheatsheets or Automobile are skipped when deleting.` | `点按“编辑”（Android 上长按笔记并选择“选择”），然后点按笔记进行选择。可一次置顶、加旗标或删除；“全选”会选中当前列表中的所有笔记。批量删除可一键撤销。删除时会跳过来自通讯录、卡片或汽车的笔记。` |

The help icon is `Icons.checklist`. `count` is `int`.

- [ ] **Step 1: Write the failing tests.**
  - Notifier:
    - `enter(5)` → active with ids `{5}`;
    - `toggle` adds and removes;
    - `selectAll` unions;
    - `keepOnly` intersects;
    - `exit` clears.
  - Screen (iOS and Android variants where marked):
    - `iOS Edit enters selection; tapping rows toggles; Done exits` (iOS).
    - `Android: long-press → Select enters selection with that note` (Android).
    - `swipes and the long-press menu are off while selecting`.
    - `Select All selects every visible note including Pinned`: 2 pinned + 3 others → `5 selected`.
    - `bulk pin pins all when one is unpinned; full success exits`.
    - `bulk flag partial failure`: the fake fails 2 of 10 → snackbar `Flagged 8 of 10 notes`, ids == the 2 failed, still active.
    - `bulk delete mixed`: 3 ordinary + 2 contacts → `Deleted 3 · 2 skipped`; Undo → `restore` for the 3; the 2 contacts stay selected (Review Focus 1).
    - `bulk delete only contacts writes nothing`: `These 2 notes are managed in their own screens` and `delete` is never called.
    - `picking a sidebar source exits selection`.
    - `wide: bulk-deleting the open note clears the selection` (Review Focus 4).
- [ ] **Step 2:** Run the tests. Expect FAIL.
- [ ] **Step 3:** Implement and run `flutter gen-l10n`.
- [ ] **Step 4:** Run `test/features/notes/`, the guard tests, and the benchmark command from Global Constraints. Expect PASS and a median ≤ 50 ms.
- [ ] **Step 5: Commit.** `feat(notes): multi-select with bulk pin, flag and delete`, with the trailer.

### Task 5: Recently Deleted screen

**Files:**
- Modify: `lib/core/data/local/local_hmm_note_repository.dart`: add `Stream<List<HmmNote>> watchDeletedNotes()` to `IHmmNoteRepository` and implement it (the current author, `deletedAt IS NOT NULL`, ordered by `deletedAt` desc). Add it to every test fake that `implements IHmmNoteRepository` without `noSuchMethod`: `test/core/navigation/cheatsheet_routes_test.dart`, `test/features/contacts/cheatsheet_binding_test.dart`, `test/features/contacts/data/contact_repository_fakes.dart` and `test/features/notes/states/mutate_note_state_test.dart`; each returns `Stream.value(const [])`.
- Create: `lib/features/notes/states/recently_deleted_provider.dart`
- Create: `lib/features/notes/presentation/screens/recently_deleted_screen.dart`
- Modify: `lib/core/navigation/router_config.dart`: add `GoRoute(path: 'deleted', name: RouterNames.notesRecentlyDeleted.name, …)` under `/notes`, **before** `':id'`, plus the `RouterNames` entry.
- Modify: `notes_sidebar.dart`: a last row, "Recently Deleted" (`Icons.delete_outline`, count = `recentlyDeletedProvider` length). Tapping it calls `onPicked()` and then `context.push('/notes/deleted')`.
- Modify: `help_registry.dart`: add `HelpId.notesRecentlyDeleted` and its entries, plus a `HelpId.notesList` Recently Deleted entry.
- Test: `test/features/notes/states/recently_deleted_provider_test.dart`, `test/features/notes/presentation/recently_deleted_screen_test.dart`, and extend the existing local note repository test file.

**Interfaces:**
- **Produces:**

```dart
const int kRecentlyDeletedDays = 30;
/// Decision 7. Callers hide notes deleted ≥ 30 days ago before calling.
int daysLeftFor(DateTime deletedAt, DateTime now);
class DeletedNoteItem { const DeletedNoteItem({required this.note, required this.daysLeft}); final HmmNote note; final int daysLeft; }
/// Ordinary notes (G11) deleted < 30 days ago, newest deletion first.
final recentlyDeletedProvider = StreamProvider.autoDispose<List<DeletedNoteItem>>(...);
/// Every soft-deleted note id, any catalog (G12 parent label, Task 6).
final deletedNoteIdsProvider = StreamProvider.autoDispose<Set<int>>(...);
```

- **Clock:** `recentlyDeletedProvider` takes `now` from the existing date/time provider in `lib/core/services/`, so tests can pin it.
- **Consumes:**
  - `NotePurgeService.purgeNow(id)` → `PurgeOutcome` (`notePurgeServiceProvider`);
  - `MutateNote.restore`;
  - the catalog stream, for the ordinary-note test via `canDeleteFromNotes`;
  - a `ListTile`-style row showing the display title (`noteDisplayRegistryProvider.title`), with the subtitle `notesDeletesInDays(daysLeft)`.
- **Screen:**
  - **Top bar:** title `notesRecentlyDeletedTitle`; `HelpButton(helpId: HelpId.notesRecentlyDeleted)`; an `Empty…` text button, disabled when the list is empty.
  - **Rows:** each sits in a `Slidable`. The start pane is Restore (`Icons.restore`); the end pane is Delete Now (`Icons.delete_forever`, red).
  - **Restore:** calls `restore` and shows the `notesRestored` snackbar, or `notesRestoreFailed` on failure.
  - **Delete Now:**
    - opens a platform confirmation dialog (`notesDeleteNowTitle` / `notesDeleteForGoodBody`, with buttons `commonCancel` and `notesDeleteNow`, destructive);
    - then calls `purgeNow`;
    - outcomes: `purged` → `notesDeletedForGood`; `keptLiveOnServer` → `notesKeptLiveElsewhere`; `failed` → `notesDeleteFailed`; `notEligible` → no message.
  - **Empty…:**
    - asks for confirmation (`notesEmptyTitle(count)` / `notesDeleteForGoodBody`);
    - then calls `purgeNow` for each listed id;
    - reports `notesEmptied(purged)`, or `notesEmptyPartial(purged, total)` if any did not purge.
  - **Wide screens:** a purged id equal to `selectedNoteIdProvider` clears it.
  - **Tapping a row** pushes `/notes/<id>` (Decision 7).
  - **Empty state:** `AppEmptyState(icon: Icons.delete_outline, message: notesRecentlyDeletedEmpty)`.

**ARB keys:**

| Key | en | zh |
|---|---|---|
| `notesRecentlyDeletedTitle` | `Recently Deleted` | `最近删除` |
| `notesDeletesInDays` | `{days, plural, =1{Deletes in 1 day} other{Deletes in {days} days}}` | `{days} 天后删除` |
| `notesRestoreAction` | `Restore` | `恢复` |
| `notesDeleteNow` | `Delete Now` | `立即删除` |
| `notesDeleteNowTitle` | `Delete this note now?` | `立即删除这条笔记？` |
| `notesDeleteForGoodBody` | `It will be removed from all your devices. This can't be undone.` | `它将从你的所有设备上移除，且无法撤销。` |
| `notesEmptyAction` | `Empty…` | `清空…` |
| `notesEmptyTitle` | `{count, plural, =1{Delete 1 note now?} other{Delete {count} notes now?}}` | `立即删除 {count} 条笔记？` |
| `notesDeletedForGood` | `Note deleted for good` | `笔记已永久删除` |
| `notesEmptied` | `{count, plural, =1{Deleted 1 note for good} other{Deleted {count} notes for good}}` | `已永久删除 {count} 条笔记` |
| `notesEmptyPartial` | `Deleted {done} of {total} notes for good` | `已永久删除 {done}/{total} 条笔记` |
| `notesKeptLiveElsewhere` | `This note was restored on another device, so it was kept` | `这条笔记已在其他设备上恢复，因此被保留` |
| `notesRecentlyDeletedEmpty` | `No recently deleted notes` | `没有最近删除的笔记` |
| `helpNotesRecentlyDeletedTitle` | `Recently Deleted` | `最近删除` |
| `helpNotesRecentlyDeletedSummary` | `Notes you delete stay here for 30 days, then are removed for good.` | `删除的笔记会在这里保留 30 天，之后被永久删除。` |
| `helpNotesRecentlyDeletedRestoreTitle` | `Restore` | `恢复` |
| `helpNotesRecentlyDeletedRestoreBody` | `Swipe a note right and tap Restore to put it back in your notes.` | `向右滑动笔记并点按“恢复”，即可将其放回笔记中。` |
| `helpNotesRecentlyDeletedDeleteNowTitle` | `Delete Now` | `立即删除` |
| `helpNotesRecentlyDeletedDeleteNowBody` | `Swipe a note left and tap Delete Now to remove it from all your devices right away. This can't be undone.` | `向左滑动笔记并点按“立即删除”，即可立即从所有设备上移除。此操作无法撤销。` |
| `helpNotesRecentlyDeletedEmptyTitle` | `Empty` | `清空` |
| `helpNotesRecentlyDeletedEmptyBody` | `Removes every note listed here from all your devices. This can't be undone.` | `从所有设备上移除此处列出的所有笔记。此操作无法撤销。` |
| `helpNotesListRecentlyDeletedTitle` | `Recently Deleted` | `最近删除` |
| `helpNotesListRecentlyDeletedBody` | `Open the side panel and tap Recently Deleted to restore a deleted note within 30 days.` | `打开侧边栏并点按“最近删除”，可在 30 天内恢复已删除的笔记。` |

Help icons are `Icons.restore`, `Icons.delete_forever` and `Icons.delete_sweep`, and `Icons.delete_outline` for the notesList entry. `days`, `count`, `done` and `total` are `int`.

- [ ] **Step 1: Write the failing tests.**
  - Repository: `watchDeletedNotes emits soft-deleted notes newest first, never live ones` (Drift in-memory).
  - `daysLeftFor`:
    - `now - 0 h` → 30;
    - `now - 29 d 23 h` → 1;
    - `now - 1 d` → 29.
  - Provider:
    - a note deleted `30 d 1 h` ago is hidden;
    - a deleted contact or gas-log note is hidden (G11);
    - a deleted General note is listed;
    - the order is newest deletion first (Review Focus 3).
  - Screen:
    - rows show `Deletes in 30 days`;
    - Restore calls `restore(id)` and shows `Note restored`;
    - Delete Now → Cancel does nothing;
    - Delete Now → confirm calls `purgeNow(id)` and shows `Note deleted for good`;
    - `keptLiveOnServer` shows the kept message;
    - Empty… with 3 notes, where 1 fails → `Deleted 2 of 3 notes for good`;
    - an empty list shows `No recently deleted notes`, and `Empty…` is disabled;
    - the help button opens the Recently Deleted help.
  - Sidebar: a `Recently Deleted` row with count 2 pushes `/notes/deleted`.
  - Route: `/notes/deleted` is not parsed as a note id.
- [ ] **Step 2:** Run the tests. Expect FAIL.
- [ ] **Step 3:** Implement and run `flutter gen-l10n`.
- [ ] **Step 4:** Run the full `flutter test`. Expect green, including every test file that has a repository fake.
- [ ] **Step 5: Commit.** `feat(notes): Recently Deleted screen with restore, delete now and empty`, with the trailer.

### Task 6: Deleted-note banner, deleted parent label, docs

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart`:
  - when `d.note.isDeleted`, show a banner above the title: `MaterialBanner` on Android, a tinted `Container` row on iOS. The text is `notesMovedToRecentlyDeletedBanner`, with a `notesRestoreAction` button.
  - The menu then offers only `Restore` (and View raw); Edit, Pin, Flag and Delete are hidden.
  - Restore calls `MutateNote.restore` and invalidates `noteDetailProvider(noteId)`. A failure shows the `notesRestoreFailed` snackbar.
- Modify: `notes_list_screen.dart` `parentTitleOf`: when `note.parentNoteId` is not in `notesById` but is in `deletedNoteIdsProvider` (Task 5), return `l.notesParentDeleted` (G12).
- Modify: `docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md`: add a dated paragraph, "**2026-11-03 (Slice 5 decisions):** see 'Decisions this plan makes' in `docs/superpowers/plans/2026-11-03-notes-slice5-actions-recently-deleted.md` — Android long-press opens the menu with Select first; Recently Deleted is its own screen, not a query source; Tags… waits for slice 6.", under "Screens and interaction → Actions".
- Modify: `CLAUDE.md` (hmm_console only; **never** `../hmm/CLAUDE.md`):
  - in the Key Packages bullet, `flutter_slidable` and `share_plus` are now dependencies (swipes; share sheet);
  - add one Slice 5 sentence to the `notes/` feature row (swipes, long-press menu, multi-select, Recently Deleted at `/notes/deleted`).
- Test: extend the existing note detail screen test file and `notes_list_screen_test.dart`.

**ARB keys:**

| Key | en | zh |
|---|---|---|
| `notesMovedToRecentlyDeletedBanner` | `This note was moved to Recently Deleted` | `这条笔记已移到“最近删除”` |
| `notesParentDeleted` | `(deleted note)` | `（已删除的笔记）` |

- [ ] **Step 1: Write the failing tests.**
  - `detail of a deleted note shows the banner and Restore` (iOS and Android); `Restore calls restore(id) and the banner goes`.
  - `detail menu of a deleted note offers Restore, not Delete`.
  - `row whose parent is soft-deleted reads "(deleted note)"`; `after the parent is restored it shows the parent's title again`.
- [ ] **Step 2:** Run the tests. Expect FAIL.
- [ ] **Step 3:** Implement and run `flutter gen-l10n`. Then edit the docs.
- [ ] **Step 4:** Run the full verification from Global Constraints: analyze, the full suite and the benchmark.
- [ ] **Step 5: Commit.** `feat(notes): deleted-note banner and deleted-parent label; slice 5 docs`, with the trailer.
