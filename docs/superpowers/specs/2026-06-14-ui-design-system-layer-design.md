# UI Design-System Layer — Design

**Date:** 2026-06-14
**Status:** Approved (brainstorm) — pending implementation plan
**Scope:** Foundation (tokens + theme + canonical widgets) plus migration of the **notes** feature as the proven reference. Other features (`automobile_records`, `gas_log`, `dashboard`, `settings`) adopt the system in their own follow-up plans.

## Goal

Close the gap between "works" and "looks professional like Apple Mail / Outlook" by establishing a real design-system layer the app currently lacks. Today `theme.dart` defines **no `TextTheme` and no `CupertinoThemeData`**, seeds deepPurple/green (reads "Material demo"), and `note_list_tile.dart` is a plain 2-tier `ListTile`. The polish gap is spacing, typography, hierarchy, and platform-correct chrome — not new frameworks.

Per `CLAUDE.md`: iOS is the primary target (Apple Mail is the reference app), Cupertino nav + large titles on iOS, Material 3 on Android, `flutter_platform_widgets` for all leaf controls.

## Decisions (locked during brainstorm)

1. **Scope** — Foundation + notes as the single reference feature. No other screens migrate in this spec.
2. **List feel** — Apple Mail direction: airy, content-first, hairline inset separators, 3-tier type — **with a bolder primary content line** (the one line that matters reads strong, not muted).
3. **Accent** — iOS **System Blue** (`#0A84FF`), both light and dark. Replaces the deepPurple/green seeds.
4. **Platform strategy** — One tuned theme + adaptive chrome widgets. Keep the single `MaterialApp`/GoRouter tree; a few canonical widgets branch the *chrome* internally by platform. No parallel CupertinoApp tree.
5. **iPad** — Single-pane push navigation now, but keep list and detail decoupled so an adaptive two-pane shell can be layered on later without rework.
6. **Skeleton loading widget** — Optional/stretch; build only if it falls out cheaply.
7. **Golden tests** — Included as the visual-regression guard for the row + section.

## Architecture overview

```
MaterialApp.router (unchanged)
  └ AppTheme            — blue ColorScheme (light+dark), TextTheme, AppColors ext, CupertinoThemeData
  └ AppScaffold         — platform-adaptive nav chrome (Cupertino large title / MD3 SliverAppBar.large)
      └ AppListSection  — Mail-style grouped container, hairline inset separators
          └ AppListRow  — 3-tier row (catalog dot · title · bold primary · secondary · trailing)
  └ AppEmptyState       — centered glyph + muted line + optional action
  └ leaf controls       — flutter_platform_widgets (unchanged mandate)
```

Each unit is independently understandable and testable: rows don't know about scaffolds, sections don't know about data, the scaffold doesn't know about rows.

## Component 1 — Token layer (`lib/core/theme/design_tokens.dart`)

Existing spacing/radius/elevation constants stay. Add a **semantic** layer:

### Type scale (semantic names, not raw sizes)

| Token | Size / weight | Use |
|-------|---------------|-----|
| `titleLarge` | 30 / w700, letter-spacing -0.5 | Large nav title ("Notes") |
| `rowTitle` | 16 / w600 | Row primary identifier (note subject) |
| `rowPrimary` | 15 / w600 | **Bold content line** (the emphasized blend from B) |
| `rowSecondary` | 14 / w400 | Muted metadata line |
| `caption` | 13 / w400 | Timestamp / trailing meta |

### Semantic colors — `AppColors` `ThemeExtension`

Adapts per brightness, resolved via `Theme.of(context).extension<AppColors>()`:

| Token | Light | Dark (iOS equivalent) |
|-------|-------|------------------------|
| `label` | `#1C1C1E` | `#FFFFFF` |
| `secondaryLabel` | `#8E8E93` | `#8E8E93` |
| `tertiaryLabel` | `#AEAEB2` | `#636366` |
| `separator` | `#E5E5EA` | `#38383A` |
| `groupedBackground` | `#F2F2F7` | `#000000` |
| `accent` | `#0A84FF` | `#0A84FF` |

Legacy `textPrimary/textSecondary/textTertiary` constants are **deprecated** (kept temporarily for un-migrated screens) in favor of `AppColors`.

### Spacing

Add the missing `gap12`, `w4`, `w12` to `GapWidgets` so all gaps route through the 4pt grid.

Catalog dot colors remain in `CatalogPalette` — independent of the accent.

## Component 2 — Theme wiring (`lib/core/theme/theme.dart`)

- **Single blue seed** per brightness: `ColorScheme.fromSeed(seedColor: systemBlue, brightness: …)`. This is an intentional, app-wide visual change — every screen's dark mode shifts from green to blue.
- **`TextTheme`** maps the type scale onto Material styles so stock widgets inherit hierarchy: `rowTitle → titleMedium`, `rowPrimary → bodyLarge` (w600), `rowSecondary → bodyMedium`, `caption → bodySmall`, plus `titleLarge`.
- **Register `AppColors`** extension on both themes with the light/dark values above.
- **`CupertinoThemeData` override** so flutter_platform_widgets Cupertino leaf controls (switches, buttons, dialogs, date pickers) inherit the same blue — no Material/Cupertino accent drift within a screen.
- **Keep** the existing `pageTransitionsTheme` (Cupertino transitions) and apple `appBarTheme` tweaks. Large-title behavior moves into `AppScaffold`.
- **Nav theming** aligned to MD3 `NavigationBarThemeData` per CLAUDE.md. The bottom-nav *widget* swap happens only in the notes shell (reference scope); other shells stay until their own plans.

## Component 3 — Canonical widgets (`lib/core/widgets/`)

### `AppScaffold`
Platform-adaptive chrome inside a `CustomScrollView`:
- **iOS** → `CupertinoSliverNavigationBar` (large title, collapses on scroll).
- **Android** → `SliverAppBar.large` (MD3 large title).
- Shared: `groupedBackground` token, `SafeArea` (bottom home indicator), `title`, `actions`, optional `leading`, body as slivers.
- `CommonScreenScaffold` becomes a **thin deprecated shim** delegating to `AppScaffold` so non-notes screens keep working unchanged.
- Platform branch via `Theme.of(context).platform` / `defaultTargetPlatform` (so widget tests can pump both).

### `AppListSection`
Mail-style grouped container. Optional uppercase header label (`secondaryLabel`). Renders row children with **hairline separators inset 39px** to align under the text, none after the last row. Owns the inset math.

### `AppListRow`
The 3-tier row. Slots:
- `leading` — catalog dot / avatar (optional)
- `title` — `rowTitle`
- `primary` — `rowPrimary` bold content line (optional)
- `secondary` — `rowSecondary` muted meta (optional)
- `trailing` — time text / chevron (optional)
- `onTap` — fires `HapticFeedback.selectionClick()` then callback
- `swipeActions` — optional, wired to existing `flutter_slidable`

Min height 44 (HIG tap target), padding from tokens.

### `AppEmptyState`
Centered glyph + one muted line + optional action button. Replaces the bare notes placeholder icon and covers empty lists.

### `AppListSkeleton` (optional / stretch)
Static placeholder rows so lists never flash blank. Build only if cheap; otherwise deferred.

## Component 4 — Notes reference migration (presentation layer only)

No data, repository, or mapper changes.

- Screens move onto `AppScaffold`; lists use `AppListSection` + `AppListRow`; placeholder/empty states use `AppEmptyState`:
  `notes_list_screen`, `subsystem_notes_screen`, `subsystems_screen`, `note_detail_screen`, `note_editor_screen`, `notes_shell_screen`.
- `note_list_tile.dart` becomes a thin wrapper filling `AppListRow` slots:
  - **title** = note subject
  - **bold primary** = first non-empty content line
  - **secondary** = `catalog · date`
- New helper `notePreview(content)` — first non-blank line, markdown stripped. Small, pure, unit-testable.
- Notes shell bottom nav swaps to MD3 `NavigationBar` on Android.

## Testing strategy (TDD — tests first)

- **Widget tests**
  - `AppListRow` — slots render; separator inset present; tap fires callback + haptic.
  - `AppListSection` — separators *between* rows, none after the last.
  - `AppScaffold` — pump with iOS vs Android `targetPlatform`, assert the correct nav widget appears.
  - `AppEmptyState` — glyph, message, optional action render.
- **Unit test**
  - `notePreview()` — blank lines, markdown, empty content edge cases.
- **Golden tests**
  - `AppListRow` and `AppListSection` in **light and dark**, as the visual-regression guard.
- Existing notes tests must stay green.

## Theming readiness (future custom-UI support)

This spec is not building user theming, but its structure is chosen so that future
theming is a small change rather than a presentation-layer rewrite. Two facts to
preserve:

- **Accent + typography customization = a provider swap, no widget rework.** Colors
  resolve through `ColorScheme` / the `AppColors` ThemeExtension and text through the
  semantic `TextTheme`, all read from `context` at runtime. Letting a user pick an
  accent or text size later means feeding the seed / `TextTheme` from a Riverpod
  provider instead of a `const` — the canonical widgets need no changes because they
  never hardcode colors or `TextStyle`s. ThemeExtension is exactly Flutter's mechanism
  for additional/per-user theme objects.
- **Runtime density would require promoting spacing tokens.** `GapWidgets.*` and
  `DesignTokens.spacing*` are `const`, which is correct for a fixed design but cannot
  vary per-user at runtime. If "custom UI" later includes a user-adjustable density
  (compact vs comfortable), those const tokens must become a context-resolved
  `AppDimensions` ThemeExtension. Colors/typography customization needs no such change.

**Implication for this work:** keep the discipline of never hardcoding colors, text
styles, or (where a widget's spacing is layout-significant) raw spacing literals in the
canonical widgets — route everything through the tokens/theme. That keeps the cheap
path open.

## Localization independence

Theme and language are fully separate axes — separate providers, separate
`MaterialApp` params (`theme`/`darkTheme` vs `locale`/`localizationsDelegates`), no
cross-references. Any theme works with any locale. This spec entangles neither.

The one place locale touches the **widgets** (not the theme) is layout:

- **Text direction.** Locale drives `Directionality` (RTL for Arabic/Hebrew). The
  canonical widgets must use **`EdgeInsetsDirectional` + `start`/`end`**, never
  `left`/`right` — e.g. the `AppListRow`/`AppListSection` separator inset is a
  directional *start* inset. Only `en`/`zh` (both LTR) ship today, but writing the
  widgets direction-aware now is nearly free and avoids a rework if RTL ever lands.
- **String length.** Translations vary text length; rows already handle this with
  ellipsis + `Flexible` and make no fixed-width assumptions.

Both are widget-layout disciplines, independent of both the theme and the locale
systems.

## Out of scope (explicit)

- Migration of `automobile_records`, `gas_log`, `dashboard`, `settings` (follow-up plans).
- iPad two-pane master-detail shell (designed-for, not built here).
- Any data-layer, sync, or repository changes.
- Animated skeleton/shimmer (the optional skeleton, if built, is static).

## Risks / notes

- The green→blue dark-mode seed change is the broadest single visual effect; intended, but touches every screen's dark appearance.
- Golden tests add baseline files to maintain; accepted as the cost of guarding visual consistency.
- `CommonScreenScaffold` shim must faithfully preserve current behavior to avoid regressing un-migrated screens.
