# In-App Help — Design

**Date:** 2026-09-27
**Status:** approved in conversation (sections 1–3); written spec awaiting review

## Problem

Function buttons in the app are bare icons. What a button does is often not
guessable from its icon, and sometimes not even from its label: the
vehicle-notes **Detach** button (`Icons.link_off`) unlinks a note from the car
instantly, with no confirmation and no undo, and the note silently moves to
**General** — nothing on screen says it survived or where it went.

The app is used both by its builder (who returns to a screen after weeks and
forgets what an icon does) and by other people on their own devices who have
never seen the screens. Help must therefore work for a first-time user, in
English and Chinese.

Current state (2026-09-27):

- 55 icon buttons in `lib/`; 37 set a `tooltip`, 22 of those tooltips are
  hard-coded English. None use `PlatformIconButton`, despite CLAUDE.md's rule.
- No help / info UI exists anywhere.
- 19 screens use `CommonScreenScaffold` (which has an `actions` slot); others
  build a plain `AppBar` (e.g. `vehicle_notes_screen.dart`).
- Snackbars exist in a few places; none offers Undo.

## Why not "long-press any button for help"

Flutter already shows an `IconButton`'s `tooltip` on long-press, so the
mechanism half-exists — but long-press is invisible (nothing hints it exists,
so the users who most need help never find it), conflicts with the iOS
convention that long-press opens a context menu, collides with the app's
existing long-press and swipe gestures, and a tooltip holds only a few words.
Long-press tooltips stay as the *baseline* (layer 1 below); explanation lives
elsewhere.

## Approach: three layers

1. **Labels everywhere (enforced).** One shared `HmmIconButton` that cannot be
   built without a localized tooltip. Long-press shows it; screen readers read
   it.
2. **Explain at the moment of consequence.** Actions that move or hide data
   show a snackbar stating what happened, with **Undo**.
3. **A "?" help sheet per screen.** A top-bar button opening a bottom sheet
   that lists the screen's controls — icon, title, one or two sentences each.

Out of scope: first-run coach marks / new-feature hints, and searching help
from the launcher. The registry (below) is the seam for both later.

## Section 1 — Components

All new code lives in `lib/core/help/`, plus the button in `lib/core/widgets/`.

| Unit | Does | Depends on |
|---|---|---|
| `HmmIconButton` (`core/widgets/hmm_icon_button.dart`) | The app's only icon button. Required: `icon`, `tooltip` (localized `String`), `onPressed`. Optional: `badgeCount` (badge shown when ≥ 1), `style` (`standard` / `filled` / `filledTonal`). | Flutter |
| `HelpEntry` | One explained control: `IconData icon`, `String title`, `String body`. The icon is the same constant the real button uses. | — |
| `ScreenHelp` | A screen's help: `title`, one-line `summary`, `List<HelpEntry> entries`. Built from `AppLocalizations`, so a missing translation fails generation, not the user. | `AppLocalizations` |
| `HelpId` + `helpRegistry` (`core/help/help_registry.dart`) | `enum HelpId`; `Map<HelpId, ScreenHelp Function(AppLocalizations)>`. The single list of which screens have help. | `ScreenHelp` |
| `HelpButton` | Top-bar "?" (`Icons.help_outline`); itself a `HmmIconButton` with tooltip "Help". Tapping opens `HelpSheet` for its `helpId`. | registry, `HelpSheet` |
| `HelpSheet` | Bottom sheet: summary, then one row per entry (icon, title, body). Cupertino modal popup on iOS, Material modal bottom sheet on Android. Scrolls when long. | `ScreenHelp` |

**Screen opt-in:** add `HelpButton(helpId: HelpId.x)` to the top bar's actions
(works for `CommonScreenScaffold` and a plain `AppBar` alike), add a registry
entry and its ARB strings.

**ARB naming:** `help<Screen>Title`, `help<Screen>Summary`,
`help<Screen><Control>Title`, `help<Screen><Control>Body`. Example:
`helpVehicleNotesDetachBody` = "Unlinks the note from this car. The note is
kept and moves to General; attach it again any time."

## Section 2 — Undo snackbar

**Unit:** `showUndoableAction` (`core/help/undoable_action.dart`):

```dart
await showUndoableAction(
  context,
  run:    () => mutate.detachNote(n.id),            // the action
  undo:   () => mutate.setParent(n.id, parentId),   // restores exactly
  done:   l.undoNoteDetached,                       // "Note moved to General"
  failed: l.undoNoteDetachFailed,                   // "Couldn't detach the note"
  undone: l.undoNoteRestored,                       // "Note is back"
  undoFailed: l.undoNoteRestoreFailed,              // "Couldn't undo — the note is in General"
  onChanged: () => ref.invalidate(attachedNotesProvider(parentId)),
);
```

Four outcomes, four distinct messages — never one confident message covering
several states (the lesson from the licence screen):

| Outcome | User sees |
|---|---|
| Action succeeds | `done` + **Undo** action, ~5 s |
| Action fails | `failed`; no Undo; list unchanged (`onChanged` runs only on success) |
| Undo succeeds | `undone`; `onChanged` runs |
| Undo fails | `undoFailed`, naming where the item actually is |

Rules:

- **The action commits immediately.** Undo reverses it; nothing is deferred,
  so an app kill or an expired snackbar never loses the change, and sync sees
  it at once.
- **Undo is an ordinary write** of the previous value through the same
  repository call (`setParentNote`), so it works in every `DataMode` and is
  collected by sync like any edit.
- **Safe after navigation.** The snackbar outlives the screen; `undo` and
  `onChanged` must not use a disposed `WidgetRef`/`BuildContext`. Capture the
  `ScaffoldMessengerState` and a container-level reference (e.g.
  `ProviderScope.containerOf`) before the first `await`.
- **No undo history.** When the snackbar is gone, so is Undo; the help sheet
  explains how to reattach.
- **Permanent deletes keep their confirmation dialogs.** Undo does not replace
  them.

First adopter: Detach only. Later candidates (tracked, not built now):
archiving a vehicle; deleting a synced gas log.

## Section 3 — Rollout and testing

| Phase | Contents | Done when |
|---|---|---|
| **1. Foundation** | `HmmIconButton`, `HelpEntry` / `ScreenHelp` / `helpRegistry`, `HelpSheet`, `HelpButton`, `showUndoableAction`, guard test | unit + widget tests green; no screen changed |
| **2. First adopters** | Vehicle notes screen: "?" help; Detach via `HmmIconButton` + Undo. Automobile hub: "?" help; notes + fuel buttons via `HmmIconButton` (badge included). CLAUDE.md rules added. | user checks both screens on iPhone in en and zh |
| **3. Button migration** | Remaining raw icon buttons, feature by feature, each with a localized tooltip (incl. the 22 hard-coded English ones) | guard allow-list empty |
| **4. Help coverage** | "?" sheets for other screens, in order: gas log list, service records, insurance policies, scheduled services, settings (data mode), then the rest | every listed screen registered |

The first implementation plan covers phases 1–2. Phases 3–4 get their own
short plans on request.

### Tests

- **Guard** (`test/core/help/icon_button_guard_test.dart`): scans `lib/` (excluding
  `lib/l10n/gen/` and `hmm_icon_button.dart`) for `IconButton(`,
  `IconButton.filled`, `IconButton.outlined`, `PlatformIconButton(`. Existing
  occurrences live in a per-file allow-list with counts; a file exceeding its
  count, or a new file, fails. Phase 3 shrinks the list; a cleaned file cannot
  regress.
- **`HmmIconButton`:** long-press shows the tooltip; semantics label present;
  badge shown for ≥ 1, absent for 0 and null; each style renders.
- **Help:** every `HelpId` builds non-empty strings in `en` and `zh`; the sheet
  is Cupertino under `TargetPlatform.iOS`, Material under Android; tapping
  `HelpButton` opens the matching sheet.
- **Undo:** each of the four outcomes shows its own message; undo calls
  `setParent` with the original parent; `onChanged` runs only on success;
  tapping Undo after the screen is popped does not throw.
- **Screens:** existing hub and vehicle-notes tests stay green; new cases:
  "?" opens help, Detach shows Undo and Undo restores the note.

### Project documentation (end of phase 2)

Add to CLAUDE.md, beside "Key Packages" / "Shared Rules":

- Every icon button is an `HmmIconButton` with a localized tooltip (guard test).
- Every new screen registers a `ScreenHelp` and puts a `HelpButton` in its top
  bar.
- Actions that move or hide data use `showUndoableAction`, reporting failure
  honestly.
- Help ARB key naming as above.

and correct "Always use flutter_platform_widgets for: buttons…" — for icon
buttons, `HmmIconButton` supersedes it.

## Risks

- **Chinese help text is unreviewed**, like the rest of the zh strings; add it
  to the existing unreviewed-zh note.
- **The guard is textual**, so an unusual construction can slip past. It
  exists to stop habits, not adversaries.
- **Help text drifts from behaviour** when a button changes. Mitigation: the
  help entry's icon is the same constant as the button's, and the CLAUDE.md
  rule makes updating help part of changing a control.
