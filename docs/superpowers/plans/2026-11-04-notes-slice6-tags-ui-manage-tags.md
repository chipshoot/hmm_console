# Notes Redesign Slice 6: Tags UI and Manage Tags (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tags become usable from the Notes UI:
- a tag field in the note editor, with autocomplete and inline creation;
- **Tags…** in the long-press menu and in the multi-select bar;
- a **Manage tags** screen (rename, merge, delete), reached from the side panel;
- a new note started while a tag is open starts with that tag.

**Architecture:**
- **One write primitive.** Every membership change goes through `ITagRepository.setNoteTags(noteId, tagIds)`. It set-replaces the note's tags and **bumps the note** (`lastModifiedDate` via `restoreStamp`, plus a new `version`), then fires the debounced auto-sync.
  - The bump is required. Membership rides only in the note blob (`'tags': [names]`), and a note is pushed only when `lastModifiedDate > cursor` (`sync_orchestrator.dart` `_collectChangedNotes`). Tags are note content, so unlike pins and flags (G14), a tag change *is* a note edit.
- **Name-keyed definitions.** Across devices a tag is identified by its normalized name (`tags.json`, per-name LWW). So:
  - **rename** = the row keeps its id (local saved searches keep working) and takes the new name; a tombstone row is written for the old name; every note carrying the tag is bumped;
  - **merge** = the notes move to the kept tag; the merged tag is tombstoned; the affected notes are bumped;
  - **delete** = refs removed, tag tombstoned, affected notes bumped.
- **UI:** one shared tag picker sheet (single note and bulk, with tri-state rows). `NoteBulkActions.applyTags` reports per-note outcomes, like the other bulk actions. Manage tags is its own route, `/notes/tags`.

**Tech Stack:** Flutter, Riverpod 3, Drift, gen-l10n (en + zh), GoRouter.

**Spec:** `docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md`.
- **Relevant sections:**
  - "Data model and sync → Tags"
  - "Screens and interaction → Actions / Drawer / sidebar / Tags / Phone (New note)"
  - "Errors and edge cases"
  - "Help"
  - G4, G7 ("Pin, flag and tags work on every note") and G10
- **Previous plan:** `docs/superpowers/plans/2026-11-03-notes-slice5-actions-recently-deleted.md`.

**Branch:** `feat/notes-list-slice6`, from `main` at `cbf9458` or later.

## Global Constraints

- **Icon buttons:** always `HmmIconButton` with a localized tooltip. `test/core/help/icon_button_guard_test.dart` stays green, and its allow-list only shrinks.
- **Platform widgets:** dialogs, sheets and menus branch on `Theme.of(context).platform`, with Cupertino on iOS/macOS and Material 3 on Android. `flutter_platform_widgets` is not a dependency.
- **No new dependencies.**
- **G7 (verbatim, the tag half):** "Pin, flag and tags work on every note." Tags… appears for entity notes too, in the long-press menu and in bulk.
- **Permanent changes** (Merge, Delete tag) use a confirmation dialog and have no Undo. Tag membership edits are not "move or hide" actions, so they get no Undo. Do not use a `WidgetRef` or `BuildContext` after an await.
- **Strings:** every new string goes in `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb` with the exact copy in the tasks, then `flutter gen-l10n`. Reuse these and do not duplicate them:
  - `notesSidebarTags`, `notesRowMoreTags`
  - `commonDelete`, `commonCancel`, `commonEdit`
  - `notesTokenRemoved`
- **Help:** each changed control updates its help entry (`HelpId.notesList`), and the new screen gets `HelpId.manageTags` and a `HelpButton`. An entry's icon is the control's own `Icons.*` constant.
- **Logging:** never log note content or tag names; errors log `runtimeType` only.
- **Do not stage** `ios/Podfile.lock` (a pre-existing local change from device builds) or `/Users/fchy/Projects/hmm/CLAUDE.md`.
- **Never run `dart format` on a directory.** Format only the files you changed.
- **Commit trailer:** required on every commit, exactly `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not amend; a hook blocks it.
- **Verification:**
  - `flutter analyze` adds nothing beyond the 2 baseline infos;
  - the default `flutter test` run is green;
  - `flutter test test/features/notes/query/note_query_benchmark_test.dart --run-skipped` keeps a median ≤ 50 ms.

## Decisions this plan makes

Where the spec is silent or contradicts itself, this plan decides as follows.

1. **A tag change is a note edit.** It bumps the note's `lastModifiedDate` and `version`, so the note moves in the Last-modified sort and is pushed. Under whole-note last-writer-wins, a tag change on one device and a text edit on another can lose one of the two. That is the same as any two concurrent edits, and is accepted.
   - An unchanged set is a no-op: no write, no bump.
2. **Rename keeps the tag's local id**, so this device's saved searches that use `TagToken(id)` / `TagSource(id)` keep working.
   - **New name already used by a live tag** (case-insensitive) → `TagNameTaken(existingId)`. The UI offers to merge into that tag instead.
   - **Case-only rename** ("work" → "Work") is an in-place name change with a newer `lastModified`. No tombstone is written, because the normalized key is unchanged.
3. **Merge** asks which tag to keep, via "Merge into…" on the tag being removed. The merged tag's local saved-search tokens show "(removed)". They are **not** remapped to the kept tag (YAGNI; cost: re-save one search).
4. **Re-using a dead name.** Creating or renaming to a name that only a tombstoned or deactivated row holds revives that row (`deletedAt = null`, `isActivated = true`, newer `lastModified`). This avoids the unique-name constraint and matches LWW, because a newer live record beats the tombstone.
5. **Tag name rules:** trimmed, internal runs of whitespace collapsed to one space, 1–50 characters; matching is case-insensitive.
   - The table allows 200 characters; 50 is a UI limit, so long names don't break rows and chips.
   - A name that breaks these rules throws `ArgumentError`. The UI disables the action instead of calling.
6. **Counts on Manage tags** are totals over live (not soft-deleted) notes, from a new `watchTagUsage()`, not the query-scoped `counts.byTag`. The screen also lists tags with 0 notes, which the side panel hides.
   - **Notes in Recently Deleted:** rename, merge and delete re-tag them as well, so a restored note carries the new name.
7. **Picker semantics.** The shared sheet shows every live tag with a tri-state mark:
   - **States:** all of the selected notes have it, some have it, none has it.
   - **Tapping a row:** all → none; some or none → all.
   - **Done** applies only the rows that changed (`add` / `remove` sets); **Cancel** applies nothing.
   - **Typing:** the field at the top filters the list. When no tag matches the trimmed text exactly (case-insensitive), a "Create “name”" row creates the tag at once and marks it "all".
   - **Single note:** the same sheet with one id, so rows are only all or none.
8. **Bulk Tags…** follows Slice 5's pattern:
   - **Full success:** no message; leave multi-select.
   - **Partial failure:** "Tagged {done} of {total} notes"; failed notes stay selected and the others are deselected.
   - **A note whose set doesn't change** counts as succeeded.
9. **New-note tag prefill.** A **new** note (`/notes/new`, no `parent` preset) starts with tag T when the Notes list's current source is `TagSource(T)` and T is live. No other context pre-fills tags. Domain and car pre-selection from the spec's "New note" bullet are not in this slice; they're listed under Known gaps.
10. **cloudApi / API transport (G10, partly deferred):**
    - **Membership** already syncs (`PUT /v1/notes/{id}/tags`). Rename, merge and delete reach the server as membership changes on the bumped notes, so the server's notes carry the right names.
    - **Tag definitions do not sync** over the API (`pullTags`/`pushTags` are no-ops), because server tags are global with no author column. After a rename or delete, another device on the API transport keeps the old tag as a live tag with 0 notes until removed there. A real fix needs per-author tags on the server, a separate `hmm` change that is not in this slice.
    - **`DataMode.cloudApi`** still has no `ITagRepository` (the provider throws, as do the note-state and other repos), and the Notes UI is already unusable in that mode. This slice does not change that.
11. **Side panel:** the Tags header is always shown, and its last row is **Manage tags…**, which pushes `/notes/tags`, mirroring the Recently Deleted row. Tag rows still hide tags with 0 notes in the current view.
12. **Menu order:**
    - **Long-press:** Pin · Flag… · **Tags…** · Attach to… · Share… · Select · Delete/Manage (Android keeps Select first).
    - **Bulk bar:** Pin · Flag · **Tags** · Delete · (spacer) · Select All.

## Known gaps (not fixed here; tell the user)

- **Synced saved searches use device-local tag ids.** Saved searches live in `SyncableSettings` and store `TagToken(tagId)` / `TagSource(tagId)` with local `Tags.id` values, which differ per device. A saved tag search made on the iPhone may point at the wrong tag, or show "(removed)", on the iPad. This predates Slice 6. Fixing it means storing tag names in saved queries, which is its own small change.
- **Domain and car pre-selection** for a new note created inside a domain (spec "Phone → New note") is not built.
- **API-transport tag definitions** (Decision 10).

## Review Focus

1. **Re-creating a dead name.** The user deletes "Work", later types "work" in a picker. Expected: the old row is revived, with no unique-constraint crash and no duplicate (Task 1 test `ensureTag revives a tombstoned name`).
2. **Renaming onto an existing name**, or by case only. Expected: onto another live tag → `TagNameTaken` and the UI offers Merge; case-only → renamed in place with no tombstone (Task 1 tests; Task 5 widget test `rename to an existing name offers merge`).
3. **Same-second edits must still propagate.** Two tag changes to one note within one second must give strictly increasing `lastModifiedDate` values (Drift stores whole seconds), or peers keep the older set (Task 1 test `setNoteTags stamps strictly later within the same second`).
4. **Deleted and entity notes.** Renaming a tag re-tags a note that is in Recently Deleted. Manage tags counts exclude it. Tags… works on a contact note (Task 1 test `rename re-tags a soft-deleted note; usage excludes it`; Task 2 test `Tags… is offered for entity notes`).
5. **Messy input in the picker.** "  Work " when "work" exists matches it and shows no Create row. An empty or 51-character name cannot be created (Task 1 `ensureTag` validation tests; Task 2 picker test `Create row hidden on case-insensitive match`).

---

### Task 1: Tag write primitives in the data layer

**Files:**
- Modify: `lib/core/data/local/local_tag_repository.dart` (interface `ITagRepository` L9-34; `LocalTagRepository`; `localTagRepositoryProvider` L241)
- Modify: `lib/features/notes/states/mutate_note_state.dart` (add `setTags`)
- Test: `test/core/data/local/local_tag_repository_manage_test.dart` (new)
- Test: `test/core/data/sync/tag_rename_sync_test.dart` (new)

**Interfaces:**
- Produces (on `ITagRepository`, implemented by `LocalTagRepository`):
  - `typedef TagUsage = ({int id, String name, int noteCount});`
  - `class TagNameTaken implements Exception { const TagNameTaken(this.existingId); final int existingId; }`
  - `String? normalizeTagName(String raw)`: a top-level function. It returns the trimmed, whitespace-collapsed name, or null if the result is empty or longer than 50 characters.
  - `Stream<List<TagUsage>> watchTagUsage()`: live tags (`isActivated && deletedAt == null`), each with the count of non-deleted notes carrying it, sorted case-insensitively by name. Tags with 0 notes are included.
  - `Future<Tag> ensureTag(String name)`: normalizes; returns the live tag with that name (case-insensitive), else revives a dead row with that name, else creates one. Throws `ArgumentError` when `normalizeTagName` returns null.
  - `Future<void> setNoteTags(int noteId, Set<int> tagIds)`: set-replace in one transaction; if the set changed, bumps the note (`lastModifiedDate = restoreStamp(previous ?? createDate, now)`, `version` = a fresh stamp, as `LocalHmmNoteRepository` does), then calls `onLocalWrite`.
  - `Future<void> renameTag(int id, String newName)`: Decisions 2 and 4.
  - `Future<void> mergeTags({required int keepId, required int mergeId})`: Decision 3.
  - `Future<void> deleteTag(int id)`
- Produces (on `MutateNote`): `Future<void> setTags(int noteId, Set<int> tagIds)`, delegating to `tagRepositoryProvider`.
- Consumes: `restoreStamp(DateTime previous, DateTime now)` from `local_hmm_note_repository.dart`; the existing `tombstoneTagByName`-style columns (`deletedAt`, `lastModified`).

- [ ] **Step 1: Write the failing repository tests** in `local_tag_repository_manage_test.dart`, over an in-memory `HmmDatabase` (copy the setup used by `local_tag_repository_watch_test.dart`). The tests:
  - `normalizeTagName trims, collapses and bounds`: `'  Work  trip '` → `'Work trip'`; `'   '` → null; 51 × `'a'` → null; 50 × `'a'` → 50 × `'a'`.
  - `ensureTag returns the live tag case-insensitively`: create "Work", then `ensureTag(' work ')` has the same id, and the table still has 1 row.
  - `ensureTag revives a tombstoned name`: create "Work", `deleteTag`, then `ensureTag('work')` gives the same id, with `deletedAt == null`, `isActivated == true`, and `lastModified` later than the tombstone's.
  - `ensureTag rejects empty and overlong names`: `throwsArgumentError`.
  - `setNoteTags set-replaces and bumps the note`: the note has tags {A, B}; `setNoteTags(n, {B, C})` gives `getTagsForNote` = {B, C}. The note's `lastModifiedDate` is later than before and its `version` changed.
  - `setNoteTags with an unchanged set does not bump`: `lastModifiedDate` and `version` stay identical.
  - `setNoteTags stamps strictly later within the same second`: two calls back to back, with different sets, give a strictly increasing `lastModifiedDate`.
  - `setNoteTags fires onLocalWrite once per change`: a counter callback is passed to `LocalTagRepository(db, onLocalWrite: …)`; it is 1 after a change and still 1 after a no-op.
  - `renameTag keeps the id, renames, tombstones the old name, bumps carriers`: there is a row with the old name, `deletedAt != null`. The renamed row has the new name and the same id. Every note carrying it has a later `lastModifiedDate`.
  - `renameTag case-only renames in place without a tombstone`
  - `renameTag onto a live name throws TagNameTaken(existingId)`
  - `renameTag onto a dead name reuses that name`: the dead row is removed or replaced, with no unique-constraint error; the renamed row keeps its id.
  - `mergeTags moves notes to the kept tag and tombstones the other`: a note with both tags ends with just the kept tag, with no duplicate ref. The merged row has `deletedAt != null` and no refs.
  - `deleteTag removes refs, tombstones, bumps carriers`
  - `rename re-tags a soft-deleted note; usage excludes it`: a note in Recently Deleted carrying the tag keeps the (renamed) tag; `watchTagUsage().first` counts only live notes.
  - `watchTagUsage lists zero-note tags and hides dead ones`

- [ ] **Step 2: Write the failing sync test** in `tag_rename_sync_test.dart`, reusing the setup of `test/core/data/sync/tag_sync_service_test.dart`:
  - `rename produces a new-name record and an old-name tombstone in tags.json`: after `renameTag`, the document built by `TagSyncService` has the new name with `deleted: false` and the old name with `deleted: true`. The tombstone's `last_modified` is ≥ the rename time.
  - `a peer applying that document ends with only the new name live`: feed the document into a second DB's `mergeDefinitions`.

- [ ] **Step 3: Run the tests to verify they fail**
  Run: `flutter test test/core/data/local/local_tag_repository_manage_test.dart test/core/data/sync/tag_rename_sync_test.dart`
  Expected: FAIL (the methods are not defined).

- [ ] **Step 4: Implement** the Interfaces above in `local_tag_repository.dart`.
  - **Stamps:** each tag stamp (`lastModified`, `deletedAt`) uses `restoreStamp(row.lastModified, now)`.
  - **Atomicity:** rename, merge and delete each run in one `_db.transaction`, and call `onLocalWrite` once at the end.
  - **Constructor:** `LocalTagRepository(HmmDatabase db, {void Function()? onLocalWrite})`.
  - **Provider:** `localTagRepositoryProvider` passes the same `onLocalWrite` closure as `localNoteStateRepositoryProvider` (`local_note_state_repository.dart` L144-148).
  - **`MutateNote.setTags`:** add it.

- [ ] **Step 5: Run the tests to verify they pass**, then run all existing tag tests: `flutter test test/core/data/local test/core/data/sync`.
  Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/local/local_tag_repository.dart lib/features/notes/states/mutate_note_state.dart test/core/data/local/local_tag_repository_manage_test.dart test/core/data/sync/tag_rename_sync_test.dart
git commit -m "feat(tags): set, rename, merge and delete tags with note bumps for sync

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Shared tag picker sheet and long-press Tags…

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_tag_picker.dart`
- Modify: `lib/features/notes/presentation/widgets/note_actions_menu.dart` (enum `NoteMenuAction`, `noteMenuItems`, `_labelOf`, `_iconOf`, the Cupertino icon function, `_runAction`)
- Modify: `lib/core/help/help_registry.dart` (`HelpId.notesList` long-press entry body), `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/notes/presentation/widgets/note_tag_picker_test.dart` (new), `test/features/notes/presentation/widgets/note_actions_menu_test.dart` (extend)

**Interfaces:**
- Consumes: Task 1's `watchTagUsage`, `ensureTag`, `normalizeTagName`, `MutateNote.setTags`.
- Produces:
  - `enum TagMark { all, some, none }`
  - `typedef TagPickResult = ({Set<int> add, Set<int> remove});`
  - `Future<TagPickResult?> showNoteTagPicker(BuildContext context, {required Map<int, TagMark> initial})`: `initial` lists only the tags with `all` or `some` (absent = none). It returns null on Cancel or dismiss, and an empty add/remove when nothing changed. It reads tags through `tagRepositoryProvider` inside the sheet (`Consumer`).
  - `NoteMenuAction.tags`

**Strings (en / zh):**
- `notesTagsAction`: "Tags…" / "标签…"
- `notesTagPickerTitle`: "Tags" / "标签"
- `notesTagPickerHint`: "Find or create a tag" / "查找或新建标签"
- `notesTagCreate`: "Create “{name}”" / "新建“{name}”"
- `notesTagPickerEmpty`: "No tags yet. Type a name to create one." / "还没有标签。输入名称即可新建。"
- `notesTagFailed`: "Couldn't change the note's tags" / "无法更改笔记的标签"
- `commonDone` exists? Reuse it if present; otherwise add `commonDone`: "Done" / "完成".

**Help:** the `HelpId.notesList` long-press entry body gains Tags…:
- en: "Long-press a note for Pin, Flag, Tags, Attach to, Share, Select and Delete."
- zh: "长按笔记可置顶、旗标、标签、附加到、分享、选择和删除。"

Keep the existing entry's icon. If its current wording differs, change only the action list.

- [ ] **Step 1: Write the failing widget tests.**
  - `note_tag_picker_test.dart`, with the picker over a real `LocalTagRepository` on an in-memory DB through `ProviderScope` overrides:
    - `shows live tags with their marks`: initial {A: all, B: some} shows A checked, B as a dash/indeterminate, and C unchecked.
    - `tapping all → none, some → all, none → all; Done returns only changes`: tap A, B and C → `add == {B, C}` and `remove == {A}`.
    - `Cancel returns null`
    - `typing filters; Create row creates and marks the tag`: type "Trip", tap `Create “Trip”` → the tag exists in the DB, and Done returns `add` containing its id.
    - `Create row hidden on case-insensitive match`: tag "Work" exists; typing "  work " shows no Create row.
    - `Create row hidden for an overlong name`: 51 characters.
  - `note_actions_menu_test.dart`:
    - `menu order includes Tags… after Flag`: ordinary → pin, flag, tags, attach, share, select, delete.
    - `Tags… is offered for entity notes`: entity → pin, flag, tags, share(disabled), select, manage(disabled).
    - `Tags… writes the picked set through setTags`
    - `a failed write shows notesTagFailed`

- [ ] **Step 2: Run them to verify they fail.**
  Run: `flutter test test/features/notes/presentation/widgets/note_tag_picker_test.dart test/features/notes/presentation/widgets/note_actions_menu_test.dart`
  Expected: FAIL.

- [ ] **Step 3: Implement the picker.**
  - **Shell:** a modal bottom sheet on both platforms, since a list of checkable rows isn't an action sheet. On iOS use `CupertinoListTile` with a trailing check / `minus` icon, `CupertinoSearchTextField`, and `CupertinoButton` Cancel/Done. On Android use `CheckboxListTile(tristate: true)`, a `TextField`, and `TextButton`s.
  - **Safe area:** respect it and the keyboard inset.
  - **Menu:** add `NoteMenuAction.tags` (icon `Icons.label_outline`, Cupertino `CupertinoIcons.tag`).
  - **`_runAction`:** builds `initial` from `notesListStateProvider`'s `tagsByNoteId[note.id]`, awaits the picker, computes the new set, and calls `mutate.setTags`. Capture the messenger and mutate before the await. A catch shows the `notesTagFailed` snackbar.

- [ ] **Step 4: Run the tests to verify they pass**, plus `flutter test test/core/help`.

- [ ] **Step 5: Commit** with the files above:
  - message: `feat(notes): tag picker sheet and Tags… in the long-press menu`
  - trailer: the required one

### Task 3: Bulk Tags… in multi-select

**Files:**
- Modify: `lib/features/notes/states/note_bulk_actions.dart` (add `applyTags`)
- Modify: `lib/features/notes/presentation/widgets/notes_bulk_bar.dart` (the button Row at L55-75; follow `_flag` at L148-179)
- Modify: `lib/core/help/help_registry.dart` (`HelpId.notesList` multi-select entry), ARB files
- Test: `test/features/notes/states/note_bulk_actions_test.dart`, `test/features/notes/presentation/widgets/notes_bulk_bar_test.dart` (extend)

**Interfaces:**
- Consumes: `showNoteTagPicker`, `TagMark`, `TagPickResult` (Task 2); `MutateNote.setTags` (Task 1); the existing `BulkOutcome`, `_each`, `multi.exit()`, `multi.keepOnly(...)`, `_ids(ref)`.
- Produces: `Future<BulkOutcome> applyTags(List<int> ids, Map<int, Set<int>> currentById, {required Set<int> add, required Set<int> remove})`. For each note, the new set is `(current ∪ add) − remove`; an unchanged set is succeeded without a write.

**Strings (en / zh):**
- `notesBulkTagPartial`: "Tagged {done} of {total} notes" / "已为 {done}/{total} 条笔记设置标签" (placeholders `done` and `total`, int)
- `notesBulkTagsTooltip`: "Tags" / "标签"

**Help:** the multi-select entry body lists Tags:
- en: "…then Pin, Flag, Tags or Delete the selected notes."
- zh: "…然后置顶、旗标、设置标签或删除所选笔记。"

Edit only the action list in the existing sentence.

**Initial marks for the picker:** a tag is `all` if every selected note has it, and `some` if at least one but not all do.

- [ ] **Step 1: Write the failing tests:**
  - `applyTags adds and removes per note`: notes {A}, {A, B} with add {C} and remove {A} → setTags calls give {C} and {B, C}.
  - `applyTags skips unchanged notes as succeeded`: the fake `MutateNote` records no call for that id.
  - `applyTags reports failures in input order`
  - **Bar:** `Tags button opens the picker with tri-state marks`; `full success exits multi-select silently`; `partial failure keeps failed notes selected and shows notesBulkTagPartial`.
- [ ] **Step 2: Run them to verify they fail.**
  Run: `flutter test test/features/notes/states/note_bulk_actions_test.dart test/features/notes/presentation/widgets/notes_bulk_bar_test.dart`
- [ ] **Step 3: Implement.** Add a `HmmIconButton(icon: Icons.label_outline, tooltip: l.notesBulkTagsTooltip)` between Flag and Delete (Decision 12). It is disabled when nothing is ticked, like Pin, Flag and Delete.
- [ ] **Step 4: Run the tests to verify they pass.**
- [ ] **Step 5: Commit**:
  - message: `feat(notes): bulk Tags… in multi-select`
  - trailer: the required one

### Task 4: Tag field in the note editor, and new-note prefill

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_tag_field.dart`
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart` (state class at L53; the save path at L185-225)
- Modify: ARB files
- Test: `test/features/notes/presentation/widgets/note_tag_field_test.dart` (new), `test/features/notes/presentation/screens/note_editor_tags_test.dart` (new)

**Interfaces:**
- Consumes: Task 1's `watchTagUsage`, `ensureTag`, `normalizeTagName`, `MutateNote.setTags`, and `ITagRepository.watchNoteTags()`; `notesListStateProvider`'s `query.source` / `liveTagNames`.
- Produces: `class NoteTagField extends StatefulWidget`, constructed as `NoteTagField({required List<String> names, required ValueChanged<List<String>> onChanged})`. It works on **names**, because new tags aren't created until Save. It shows each name as a removable chip, followed by a text field with autocomplete suggestions from live tag names, case-insensitive prefix-then-contains, at most 6, excluding names already chosen.
  - **Commit keys:** Enter, a comma, or tapping a suggestion.
  - **Duplicates:** a name equal (case-insensitive, after `normalizeTagName`) to a chosen one is ignored.
  - **Invalid names** are ignored.

**Strings (en / zh):**
- `notesEditorTagsLabel`: "Tags" / "标签"
- `notesEditorTagsHint`: "Add a tag" / "添加标签"
- `notesEditorRemoveTag`: "Remove tag {name}" / "移除标签 {name}" (the chip's delete tooltip / semantics)

**Save behaviour:**
- **Write order:** after the note is created or updated (so `_noteId` is known), resolve each name with `ensureTag` and call `mutate.setTags(noteId, ids)`. This happens inside the existing save `try`, before navigation.
- **Existing notes:** their initial names come from `watchNoteTags().first[noteId]`.
- **Unchanged names:** no `setTags` call (Task 1 makes it a no-op anyway).
- **Prefill (Decision 9):** in `initState` for a new note with `presetParentId == null`, if `ref.read(notesListStateProvider).value?.query.source` is `TagSource(t)` and `liveTagNames` contains t (or is null), the initial names are `[that name]`.

- [ ] **Step 1: Write the failing tests:**
  - **Field:**
    - `suggests live names, excluding chosen`
    - `Enter and comma commit a chip`
    - `duplicate and blank input ignored`
    - `chip ✕ removes`
  - **Editor**, using the existing editor test setup (find it through `mutate_note_state_test.dart`'s fakes or the editor's current tests):
    - `saving a new note with two tags creates them and sets membership`
    - `editing an existing note shows its tags and saves changes`
    - `new note opened while TagSource(t) is current starts with t`
    - `new note with a parent preset does not prefill`
- [ ] **Step 2: Run them to verify they fail.**
  Run: `flutter test test/features/notes/presentation/widgets/note_tag_field_test.dart test/features/notes/presentation/screens/note_editor_tags_test.dart`
- [ ] **Step 3: Implement.** Place the field below the subject/body controls, next to the existing date and location controls. Follow the editor's current layout; use one field row, and don't redesign the editor.
- [ ] **Step 4: Run the tests to verify they pass**, plus the existing editor tests: `flutter test test/features/notes`.
- [ ] **Step 5: Commit**:
  - message: `feat(notes): tag field in the note editor with new-note prefill`
  - trailer: the required one

### Task 5: Manage tags screen, route, side-panel row, help and docs

**Files:**
- Create: `lib/features/notes/presentation/screens/manage_tags_screen.dart`
- Modify: `lib/core/navigation/route_names.dart` (add `notesManageTags` after `notesRecentlyDeleted`)
- Modify: `lib/core/navigation/router_config.dart`: add `GoRoute(path: 'tags', name: RouterNames.notesManageTags.name, builder: (_, __) => const ManageTagsScreen())` next to `deleted`, **before** `path: ':id'`, which `int.parse`s
- Modify: `lib/features/notes/presentation/widgets/notes_sidebar.dart` (the Tags section at L254-263; copy the Recently Deleted row's navigation at L289-299)
- Modify: `lib/core/help/help_registry.dart` (add `HelpId.manageTags` and its case), ARB files
- Modify: `docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md` (a dated paragraph under "### Tags"), `CLAUDE.md` (the `notes/` row of the feature table: one sentence on tags)
- Test: `test/features/notes/presentation/screens/manage_tags_screen_test.dart` (new), `test/features/notes/presentation/widgets/notes_sidebar_test.dart` (extend), `test/core/navigation/` (add a route test that `/notes/tags` builds `ManageTagsScreen`, wherever the existing `/notes/deleted` route test lives; create `notes_routes_test.dart` if none)

**Interfaces:**
- Consumes: Task 1's `watchTagUsage`, `renameTag`, `mergeTags`, `deleteTag`, `TagNameTaken`, `normalizeTagName`.
- Produces: `class ManageTagsScreen extends ConsumerWidget`; `HelpId.manageTags`; `RouterNames.notesManageTags`.

**Screen:**
- **Shell:** `AppScaffold`, titled `notesManageTagsTitle`, with `HelpButton(helpId: HelpId.manageTags)` in the top bar.
- **List:** a list of `TagUsage` rows showing the name and `notesManageTagsCount(count)` trailing.
- **Row actions:** tapping a row opens its action sheet (Cupertino action sheet on iOS, Material bottom sheet on Android) with:
  - **Rename…:** a text dialog prefilled with the name. Save is disabled while `normalizeTagName` is null or the name is unchanged. If it throws `TagNameTaken(id)`, show the merge-confirmation dialog for "merge into that tag".
  - **Merge into…:** a picker sheet listing the other live tags; picking one opens the confirmation `notesMergeTagConfirm`, then `mergeTags(keepId: picked, mergeId: this)`.
  - **Delete…:** the confirmation `notesDeleteTagConfirm` (destructive action), then `deleteTag`.
- **Empty state:** `notesManageTagsEmpty`.
- **Failures:** each shows the snackbar `notesManageTagsFailed`. Capture the messenger before awaits.

**Strings (en / zh):**
- `notesManageTagsTitle`: "Manage Tags" / "管理标签"
- `notesManageTagsRow`: "Manage tags…" / "管理标签…" (side panel)
- `notesManageTagsCount`: "{count, plural, =0{No notes} =1{1 note} other{{count} notes}}" / "{count, plural, other{{count} 条笔记}}"
- `notesManageTagsEmpty`: "No tags yet. Add tags in a note's editor or from its long-press menu." / "还没有标签。可在笔记编辑器或长按菜单中添加。"
- `notesRenameTag`: "Rename…" / "重命名…"
- `notesRenameTagTitle`: "Rename Tag" / "重命名标签"
- `notesMergeTag`: "Merge into…" / "合并到…"
- `notesMergeTagConfirm`: "Move {count, plural, =1{1 note} other{{count} notes}} from “{from}” to “{to}” and delete “{from}”?" / "将 {count} 条笔记从“{from}”移到“{to}”，并删除“{from}”？"
- `notesMergeTagAction`: "Merge" / "合并"
- `notesTagNameTaken`: "A tag named “{name}” already exists. Merge into it?" / "已有名为“{name}”的标签。要合并到它吗？"
- `notesDeleteTag`: "Delete…" / "删除…"
- `notesDeleteTagConfirm`: "Delete the tag “{name}”? It is removed from {count, plural, =1{1 note} other{{count} notes}}. The notes stay." / "删除标签“{name}”？它将从 {count} 条笔记中移除，笔记本身会保留。"
- `notesManageTagsFailed`: "Couldn't change the tag" / "无法更改标签"
- **Help:**
  - `helpManageTagsTitle`: "Manage Tags" / "管理标签"
  - `helpManageTagsSummary`: "Rename, merge or delete your tags. Changes apply to every note that has the tag." / "重命名、合并或删除标签。更改会应用到所有带有该标签的笔记。"
  - **Rename:** `helpManageTagsRenameTitle` / `Body`, icon `Icons.edit_outlined`:
    - title: "Rename" / "重命名"
    - body: "Tap a tag, then Rename. If the new name is taken, you can merge the two." / "点按标签，然后选择重命名。如果新名称已被使用，可以把两个标签合并。"
  - **Merge:** `helpManageTagsMergeTitle` / `Body`, icon `Icons.merge`:
    - title: "Merge" / "合并"
    - body: "Moves every note to the tag you pick and deletes the other tag." / "把所有笔记移到你选择的标签，并删除另一个标签。"
  - **Delete:** `helpManageTagsDeleteTitle` / `Body`, icon `Icons.delete_outline`:
    - title: "Delete" / "删除"
    - body: "Removes the tag from its notes. The notes themselves are kept." / "从笔记中移除该标签，笔记本身会保留。"
- **`HelpId.notesList`:** add a tags entry, `helpNotesListTagsTitle` / `Body`, with icon `Icons.label_outline` (if the entry already exists, update its body):
  - title: "Tags" / "标签"
  - body: "Add tags in a note's editor or with Tags… on its long-press menu. Pick a tag in the side panel to see its notes; Manage tags… renames, merges or deletes them." / "可在笔记编辑器中或通过长按菜单的“标签…”添加标签。在侧边栏选择标签可查看其笔记；“管理标签…”可重命名、合并或删除标签。"

**Side panel row:** the Tags header is always shown. Its last row is `ListTile(leading: Icon(Icons.edit_outlined), title: Text(l.notesManageTagsRow))`, which runs `final router = GoRouter.of(context); onPicked(); router.push('/notes/tags');`.

**Docs:**
- **Spec**, under "### Tags": "**2026-11-04 (Slice 6 decisions):** see 'Decisions this plan makes' in `docs/superpowers/plans/2026-11-04-notes-slice6-tags-ui-manage-tags.md` — a tag change is a note edit (bumps and re-pushes the note); rename keeps the local id and tombstones the old name; tag definitions don't sync over the API transport until the server has per-author tags."
- **CLAUDE.md,** at the end of the `notes/` cell: "Slice 6 adds tags: an editor tag field, Tags… in the long-press menu and bulk bar, and Manage tags at `/notes/tags` (rename, merge, delete); a tag change bumps the note so it syncs."

- [ ] **Step 1: Write the failing tests:**
  - **Screen:**
    - `lists tags with totals including zero-note tags`
    - `rename saves through renameTag`
    - `rename to an existing name offers merge`
    - `merge confirms then merges`
    - `delete confirms; cancel writes nothing`
    - `empty state`
    - `has a help button`
  - **Sidebar:**
    - `Manage tags… row pushes /notes/tags`
    - `Tags header shows with no tags`
  - **Route:** `/notes/tags builds ManageTagsScreen and /notes/5 still opens a note`
- [ ] **Step 2: Run them to verify they fail.**
- [ ] **Step 3: Implement**, then run `flutter gen-l10n`.
- [ ] **Step 4: Full verification:**
  - `flutter analyze`: only the 2 baseline infos;
  - `flutter test`: all green;
  - `flutter test test/features/notes/query/note_query_benchmark_test.dart --run-skipped`: median ≤ 50 ms.
- [ ] **Step 5: Commit** the files above (not `ios/Podfile.lock`):
  - message: `feat(notes): Manage tags screen, side-panel entry, help and docs`
  - trailer: the required one
