# Quick Access Panel Redesign — Design

**Date:** 2026-07-16
**Status:** Approved (brainstorming); ready for planning.
**Supersedes:** the persistent-overlay presentation from
`docs/superpowers/specs/2026-07-15-sync-safety-persistent-access-design.md`
(§Part B / §4). The sync *engine*, auto-sync-on-write, pending-count, and
anti-loss *prompt* from that design are unchanged — only how Home + Sync are
surfaced on screen changes.

## Problem

Sync Safety Phase 1 shipped a persistent overlay (`HomeSyncOverlay`) that
renders an always-on Home circle + a sync status chip on **every** screen —
including a "Synced" chip when nothing needs attention. It reads as visually
heavy and clutters every screen. We want the controls **hidden by default**
and summoned by a gesture, styled as one cohesive **translucent panel**, and
**extensible** so future actions can be added trivially — *without* re-hiding
the anti-loss safety signal the feature exists to provide.

## Goals

- **Hidden by default** — clean screens, no always-on Home/Sync controls.
- **Summon on demand** via a discoverable, accessible gesture.
- **Preserve anti-loss** — an ambient indicator still appears when data is
  genuinely at risk (pending + can't reach cloud), so the incident class
  ("silently stranded data") stays covered.
- **One translucent panel** holding the actions (half-transparent surface).
- **Extensible** — adding a future action (e.g. New Note, Search) is a
  one-line registry addition, no layout rework.
- Presentation-layer only: the sync engine, `notifyLocalChange` auto-sync,
  `pendingSyncCountProvider`, and the blocked/failed **prompt dialog** are
  untouched.

## Non-goals

- Any change to sync logic, pending-count logic, or the anti-loss prompt.
- Any change to `local` / `cloudApi` tier behavior (Sync stays neutral; the
  at-risk dot never shows there because pending is always 0 without an active
  orchestrator).
- Draggable / repositionable panel (future).
- Per-screen or user-reorderable action sets (registry is global + fixed
  order in v1).

## Design

### 1. Interaction model

1. **Hidden default.** An invisible ~56×56 **long-press hot-zone** pinned
   bottom-trailing inside `SafeArea` (clear of the home indicator / bottom
   nav). Normal taps pass **through** to the content behind it — the zone
   reacts only to long-press (and to a tap when the at-risk dot is showing).
2. **Reveal.** Long-press opens the **Quick Access Panel** anchored above the
   corner.
3. **At-risk dot.** When `shouldPromptPendingSync(pendingCount,
   autoSyncSkippedForNetwork, lastSyncFailed)` is true, a small colored dot
   appears at the hot-zone corner as an ambient indicator. **Tapping the dot
   opens the panel** (one tap to reach Sync). Healthy/synced → nothing shown.
4. **Dismiss.** Tap outside (a transparent full-screen barrier), select an
   action (Home navigates away → gone; Sync fires → collapses), or after
   ~5 s of inactivity.
5. **Accessibility.** The hot-zone carries a `Semantics` **button** label
   ("Home and sync quick actions") so screen-reader / switch-access users can
   reach it without knowing the gesture — closing the invisible-gesture
   accessibility gap.

### 2. The translucent panel

- A rounded container filled with `colorScheme.surface.withValues(alpha:
  0.75)` (half-transparent), a subtle shadow/elevation, ~16 px corner radius,
  and comfortable padding. Optional `BackdropFilter` blur for a frosted look
  (kept optional so it can be dropped if it costs too much on low-end
  devices).
- Lays out its actions as a **vertical stack** (`Column`,
  `mainAxisSize: min`) growing **upward** from the corner, or a `Wrap` if it
  ever needs to hold many — it grows gracefully as actions are added, with no
  per-action layout code.
- Renders whatever the action registry provides (below).

### 3. Extensible action registry

- **`QuickPanelAction`** — a lightweight model describing one panel entry:
  - `IconData icon`, `String label`, and an `onTap` callback for simple
    actions; **or**
  - a `Widget Function(...)` **builder** for stateful/custom entries (Sync
    uses this to embed the existing mode-adaptive status pill instead of a
    plain icon).
  - optional `bool visible` / a predicate so an action can conditionally
    appear (e.g. Sync could be hidden or neutral by `DataMode`).
- **`quickPanelActionsProvider`** — a Riverpod `Provider<List<QuickPanelAction>>`
  returning the ordered list. **v1 = `[Home, Sync]`.** Adding a future button
  is appending one entry here; the panel maps the list to tiles, so **no
  layout change** is needed to add one. (Mirrors the launcher feature's
  existing destination-registry style.)
  - **Home** action → `ref.read(AppRouter.config).go('/')` (GoRouter instance,
    no `BuildContext` needed — same reason as today).
  - **Sync** action → the existing `SyncPill` (mode-adaptive status,
    tap-to-sync with cellular-confirm, long-press detail) rendered via the
    builder form.

### 4. Safety dot condition

Visible **iff** `shouldPromptPendingSync(pendingCount,
autoSyncSkippedForNetwork, lastSyncFailed)` — the exact predicate the
anti-loss prompt uses, so the ambient dot and the prompt agree. Colored from
the scheme (error/tertiary). No dot while merely syncing or pending-but-fine;
no dot in `local`/`cloudApi` (pending is 0 without an active orchestrator).

### 5. Discoverability & teaching

- **First-run coach mark** — shown once per install (persisted via a
  `quickPanelHintShown` bool in `shared_preferences`) the first time a main
  screen is reached: a lightweight hint pointing at the corner — *"Long-press
  here for Home & quick Sync."* → "Got it."
- **Settings row** — under the existing sync/data section:
  - **"Quick access panel"** toggle, default **ON** (persisted via
    `quickPanelEnabled`). When OFF, the hot-zone, dot, and panel are all
    suppressed.
  - **"Show me how"** action — replays the coach mark on demand.

### 6. Reused vs. new

- **Reused unchanged:** `SyncPill`, `HomeButton` logic, the anti-loss
  **prompt dialog** (background + threshold), `pendingSyncCountProvider`,
  `shouldPromptPendingSync`, `rootNavigatorKey`, and the controller-listener
  re-bind on DataMode switch (from the Phase 1 fix).
- **Rewritten:** `HomeSyncOverlay` changes from "always render a Home+Sync
  row" to "invisible hot-zone + long-press detector + conditional at-risk dot
  + reveal-on-demand translucent panel driven by the registry." It stays
  mounted once via `MaterialApp.router`'s `builder`; dialogs/navigation still
  go through `rootNavigatorKey` / the GoRouter instance.
- **New:** `QuickPanelAction` + `quickPanelActionsProvider`, a
  `QuickAccessPanel` widget, a coach-mark widget, the two prefs
  (`quickPanelHintShown`, `quickPanelEnabled`), and the Settings row.

## Error handling / edge cases

- The open panel uses a transparent full-screen barrier to catch outside-tap
  dismiss — briefly modal by intent (an explicit "open" state).
- The hot-zone is small and lives in the safe-area margin to minimize
  long-press collisions with underlying content (text selection, slidable
  rows, the note editor's own long-press).
- When hidden, the zone never intercepts normal taps — content behind stays
  fully interactive (regression-tested).
- The anti-loss prompt (background/threshold) is independent of this panel
  and continues to fire even when the panel/dot is dismissed or disabled.

## Testing

- **Hidden by default:** no panel / `SyncPill` / `HomeButton` in the tree
  until revealed; a tap in the corner region reaches content behind it.
- **Reveal/dismiss:** long-press reveals the panel; outside-tap, action
  selection, and inactivity timeout each dismiss it.
- **Safety dot:** appears only when `shouldPromptPendingSync` is true; tapping
  it opens the panel; absent in `local` mode.
- **Registry/extensibility:** the panel renders N actions from
  `quickPanelActionsProvider`; injecting a test action makes it appear with
  no layout-code change (proves the extension point).
- **Teaching:** coach mark shows once then not again (pref honored); Settings
  "Show me how" replays it; the toggle OFF suppresses hot-zone + dot + panel.
- **Translucency & a11y:** panel renders at the expected opacity; the
  hot-zone exposes the `Semantics` button.
- **No regressions:** existing Sync-Safety / anti-loss tests stay green (the
  prompt and engine are unchanged).

## Phasing

Single phase, one implementation plan — a focused presentation-layer
redesign with a clean extension point for future actions.
