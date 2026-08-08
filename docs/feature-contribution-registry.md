# Feature contribution registry — design note

**Status:** proposal, not built. Written 2026-08-08 after a real drift bug.
**Trigger to act:** the third feature that needs to appear on more than one
surface, or the first contributor that shouldn't live in `core/`.

## The problem, with evidence

The app has **three independent, hardcoded catalogues of "things the user can
do"**, in three shapes, in three places:

| Surface | Catalogue | Shape |
| --- | --- | --- |
| Dashboard tiles | `_allFunctions` in `features/dashboard/.../dashboard_screen.dart` | `AppFunction(icon, title, description, route)` — `icon` is an emoji **String** |
| Universal launcher | `launcherDestinations` in `features/launcher/domain/launcher_registry.dart` | `LauncherDestination(id, title, synonyms, icon, routeName, needsVehicle, usesVehiclePathId)` — `icon` is `IconData` |
| Quick Access Panel | `quickPanelActionsFor(path)` in `core/widgets/quick_panel/` | `if` rules on **literal route path strings** |

They have already drifted. Cheatsheets shipped to `main`, was added to the
dashboard, and was **never registered as a launcher destination** — so a
feature that exists and is navigable was not findable in universal search.
Confirmed at the time by `grep -c -i cheatsheet`: 4 in the dashboard, 0 in the
launcher registry. Fixed in the same commit as this note.

Nothing caught it. `launcher_registry_test.dart` verifies that every
`routeName` is a real `RouterNames` value — good, it catches renames — but no
test can currently detect a feature that was simply never added, because the
three catalogues key on different things (`route: 'notes'` vs
`routeName: 'notesList'` vs the path literal `'/notes'`). **Absence is
undetectable until the catalogues share a key.** That, more than the
duplication itself, is the argument for unifying.

## The model we're borrowing, and the half that doesn't apply

The mental model is the WinForms / Visual Studio add-in one:
`ToolStripManager.Merge` / `RevertMerge` with `MergeAction` and `MergeIndex`,
MEF `[Export]` / `[ImportMany]` catalogues, Prism `IModule` +
`IRegionManager`. A host owns the menu; modules contribute items when loaded
and revert them when unloaded.

**The unload half does not translate.** Flutter is AOT-compiled and iOS
forbids runtime code loading — there is no `Assembly.Load`, no runtime
catalogue, no module you can drop in or remove while running. Every feature is
compiled in.

**The contribution half translates, and improves.** Rather than *register on
load / revert on unload*, features **declare** a contribution with an
availability rule, and presence is **derived**:

- feature flag off → not produced
- wrong `DataMode` → not produced
- no vehicle selected → not produced (`needsVehicle` already does this)
- wrong platform → not produced

The payoff over the WinForms model is that **there is no unregister to
forget**. The classic plugin defect is an orphaned menu item after a failed
`RevertMerge`. Here nobody performs removal, so nobody can skip it — Riverpod
recomputes and the surfaces follow.

## Proposed contract

`LauncherDestination` is already ~80% of this; `needsVehicle` *is* an
availability predicate. The unified type would be roughly:

```dart
class FeatureContribution {
  final String id;              // stable — favourites/recents persist this
  final String title;
  final IconData icon;
  final String routeName;       // RouterNames value, test-enforced
  final List<String> synonyms;  // launcher search
  final String? description;    // dashboard tile subtitle

  /// Is this feature usable at all right now? (flag, data mode, platform,
  /// vehicle selected …) Replaces "module loaded".
  final bool Function(FeatureContext) available;

  /// Should the panel offer this feature's *create* action on this route?
  /// Null = never (feature is navigable but has no global create).
  final bool Function(String routePath)? createsOn;

  /// Explicit ordering. Learn from MergeIndex: implicit registration order
  /// is where plugin menus go to die.
  final int priority;
}
```

Each surface then filters the one catalogue by what it cares about: the
dashboard takes everything `available`, the launcher matches on
`title`/`synonyms`, the panel takes `createsOn(currentPath)`.

Once the catalogues share a key, the drift bug above becomes a **test**:
"every dashboard-visible feature has a launcher destination."

## Constraints to decide before opening it up

1. **Panel real estate.** A WinForms menu bar is hierarchical and absorbs
   fifty items. The Quick Access Panel is a small floating column reached by a
   gesture. Decide a **hard cap** (4–5 visible?) and what happens past it.
2. **Ordering.** Explicit `priority`, never registration order.
3. **Relevance.** "Available" and "relevant here" are different questions —
   Settings is always available, never route-relevant. Keep them separate
   predicates, as sketched above.
4. **Junk drawer risk.** The panel is good *because* it holds three or four
   obviously useful things. An extension point that anyone may push into will
   erode that unless (1)–(3) are enforced.

## Staged plan

1. **Done (this commit):** register Cheatsheets as a launcher destination —
   a bug fix, not a refactor.
2. **Next, small:** have the panel derive its create-actions from route
   *constants* rather than literal `'/notes'` / `'/gas-logs'` strings, so a
   route rename is a compile error rather than a silently missing button.
   Same class of fragility as the drift above.
3. **At the trigger:** unify `AppFunction` and `LauncherDestination` into
   `FeatureContribution`; point all three surfaces at it; add the
   drift-detection test that is impossible today.

Deliberately **not** doing (1)–(3) as one change: there are four panel actions
and roughly ten destinations today. The abstraction earns its keep at the
third multi-surface contributor, not before.
