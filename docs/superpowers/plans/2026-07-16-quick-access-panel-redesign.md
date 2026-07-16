# Quick Access Panel Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the always-on Home+Sync overlay with a hidden, gesture-revealed, half-transparent **Quick Access Panel** driven by an extensible action registry, keeping an at-risk safety dot so the anti-loss signal is never re-hidden.

**Architecture:** Presentation-layer only. Two device-local flags (`quickPanelEnabled`, `quickPanelHintShown`) join the existing `AppSettings`/`SettingsController`. A `quickPanelActionsProvider` registry returns an ordered `List<QuickPanelAction>` (v1 `[Home, Sync]`); a `QuickAccessPanel` renders it as a translucent tile stack. `HomeSyncOverlay` is rewritten from an always-on Row into an invisible bottom-right long-press hot-zone that reveals the panel, plus a conditional at-risk dot and a one-time coach mark — while preserving the existing anti-loss prompt logic (background + threshold) and the DataMode-switch controller re-bind verbatim. A Settings row toggles the feature and replays the coach mark.

**Tech Stack:** Flutter/Dart, Riverpod (`flutter_riverpod` 3.0.3, plain `Provider`/`NotifierProvider`, `.value` never `.valueOrNull`), `go_router` (via `AppRouter.config` + `rootNavigatorKey`), `shared_preferences` (through `SettingsController`, not directly).

## Global Constraints

- **Riverpod only**; new reactive state is a plain `Provider`/`NotifierProvider`. **`.value ?? default`, never `.valueOrNull`** (this project's `flutter_riverpod: ^3.0.3` has no `.valueOrNull`).
- **Presentation-only.** Do NOT touch the sync engine (`sync_controller.dart`, `sync_orchestrator.dart`), `pending_sync_count_provider.dart`, `pending_sync_prompt.dart`, `local_hmm_note_repository.dart`, or `mutate_note_state.dart`. The anti-loss **prompt** logic in `HomeSyncOverlay._maybePrompt` and its background/threshold `ref.listen`s move **verbatim** into the rewritten widget — do not alter their behavior.
- **Preserve the DataMode-switch fix.** The controller-listener re-bind (`_controller` mutable + initState initial bind + `ref.listen<SyncController>(syncControllerProvider, …)` in build + dispose removal) MUST be kept exactly — it fixes a real incident-path defect.
- **Flags are device-local.** `quickPanelEnabled`/`quickPanelHintShown` belong in `AppSettings` (device-local), NOT `SyncableSettings` (a per-install hint must not roam across devices).
- **No `flutter_platform_widgets`** (not a dependency). Use plain Material; the panel is a neutral rounded translucent surface.
- **Pass-through when hidden.** The overlay must never intercept normal taps outside the small hot-zone / open panel (regression-tested — same guarantee the current overlay has).
- **local/cloudApi unchanged.** Sync action stays neutral in those modes; the at-risk dot never shows there (pending is 0 without an active orchestrator).
- **No new dependencies.** The coach mark is built in-repo (no `showcaseview`/`tutorial_coach_mark`).

## Interfaces confirmed against the codebase (read before executing)

- Settings screen: `lib/features/settings/presentation/screens/settings_screen.dart` — `SettingsScreen extends ConsumerWidget`; a `Column` (crossAxisAlignment.stretch) of rows split by `const Divider()` + `GapWidgets`. Toggle template = `SwitchListTile.adaptive` reading an async provider (geo-capture, ~lines 309-323); action template = `ListTile` w/ `leading` icon + `trailing: Icon(Icons.chevron_right)` (Launcher row, ~270-277). "Data & Storage" section starts ~line 331; the sync block is inside `if (dataMode != DataMode.local) …[` at ~426-447.
- Persistence: `lib/core/settings/app_settings.dart` (immutable `AppSettings` — has `bool dashboardIntroCardSeen` default false to mirror), `lib/core/settings/settings_controller.dart` (`AsyncNotifier<AppSettings>` `settingsProvider`, `_update` persists the JSON blob), `lib/features/dashboard/providers/intro_card_provider.dart` (`IntroCardSeenNotifier extends Notifier<bool>` — the exact view-provider template).
- Router: `AppRouter.config` (`lib/core/navigation/router.dart:18`), `rootNavigatorKey` (`lib/core/navigation/router_config.dart:39`), `/settings` route exists (`RouterNames.settings`).
- Overlay mount: `lib/main.dart`'s `MaterialApp.router(builder: (context, child) => Stack([if (child != null) child, const HomeSyncOverlay()]))` — unchanged; `HomeSyncOverlay` must still return a valid `Stack` child.
- Reused widgets: `SyncPill` (`lib/core/widgets/sync_pill.dart`) stays (embedded by the Sync action). `HomeButton` (`lib/core/widgets/home_button.dart`) is superseded by the Home registry action and is **deleted** in Task 4.
- `confirmManualSyncIfOnCellular(BuildContext, WidgetRef) → Future<bool>` (`lib/features/settings/presentation/widgets/sync_status_card.dart:155`).

---

## Task 1: Device-local `quickPanelEnabled` / `quickPanelHintShown` settings + view providers

**Files:**
- Modify: `lib/core/settings/app_settings.dart`, `lib/core/settings/settings_controller.dart`
- Create: `lib/core/widgets/quick_panel/quick_panel_settings.dart` (the two view providers)
- Test: `test/core/settings/quick_panel_settings_test.dart` (new)

**Interfaces:**
- Consumes: `AppSettings`, `SettingsController`/`settingsProvider` (existing), `Notifier`/`NotifierProvider`.
- Produces:
  - `AppSettings.quickPanelEnabled` (bool, default **true**), `AppSettings.quickPanelHintShown` (bool, default **false**) — wired through constructor/field/fromJson/toJson/copyWith exactly like `dashboardIntroCardSeen`.
  - `SettingsController.setQuickPanelEnabled(bool)`, `setQuickPanelHintShown(bool)`.
  - `final quickPanelEnabledProvider = NotifierProvider<QuickPanelEnabledNotifier, bool>(…)` with `setEnabled(bool)`, and `final quickPanelHintShownProvider = NotifierProvider<QuickPanelHintShownNotifier, bool>(…)` with `markShown()` + `replay()`. Each `Notifier<bool>` reads `ref.watch(settingsProvider).value?.field ?? default`. Consumed by Tasks 4-7.

- [ ] **Step 1: Add the two fields to `AppSettings`** — read the file first, then mirror `dashboardIntroCardSeen` in the constructor (`this.quickPanelEnabled = true`, `this.quickPanelHintShown = false`), the field declarations (`final bool quickPanelEnabled;` / `final bool quickPanelHintShown;`), `fromJson` (`quickPanelEnabled: j['quickPanelEnabled'] as bool? ?? true`, `quickPanelHintShown: j['quickPanelHintShown'] as bool? ?? false`), `toJson` (`'quickPanelEnabled': quickPanelEnabled, 'quickPanelHintShown': quickPanelHintShown`), and `copyWith` (params + assignments). Match the file's exact style.

- [ ] **Step 2: Add the two setters to `SettingsController`** — mirror the existing `setDashboardIntroCardSeen`:

```dart
Future<void> setQuickPanelEnabled(bool v) =>
    _update(_current.copyWith(quickPanelEnabled: v));

Future<void> setQuickPanelHintShown(bool v) =>
    _update(_current.copyWith(quickPanelHintShown: v));
```

- [ ] **Step 3: Write the failing test**

Create `test/core/settings/quick_panel_settings_test.dart`. Read a sibling test under `test/core/settings/` first for the exact `SharedPreferences.setMockInitialValues({})` + `ProviderContainer` + `await container.read(settingsProvider.future)` harness. Assertions:

```dart
// 1. AppSettings defaults + json round-trip
final s = const AppSettings();
expect(s.quickPanelEnabled, isTrue);
expect(s.quickPanelHintShown, isFalse);
final round = AppSettings.fromJson(s.toJson());
expect(round.quickPanelEnabled, isTrue);
expect(round.quickPanelHintShown, isFalse);
expect(AppSettings.fromJson(const {}).quickPanelEnabled, isTrue,
    reason: 'missing key defaults to enabled');

// 2. view providers read + write through the controller
expect(container.read(quickPanelEnabledProvider), isTrue);
await container.read(quickPanelEnabledProvider.notifier).setEnabled(false);
expect(container.read(quickPanelEnabledProvider), isFalse);

expect(container.read(quickPanelHintShownProvider), isFalse);
await container.read(quickPanelHintShownProvider.notifier).markShown();
expect(container.read(quickPanelHintShownProvider), isTrue);
await container.read(quickPanelHintShownProvider.notifier).replay();
expect(container.read(quickPanelHintShownProvider), isFalse);
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/core/settings/quick_panel_settings_test.dart`
Expected: FAIL — `quickPanelEnabled` / provider symbols undefined.

- [ ] **Step 5: Create the view providers**

Create `lib/core/widgets/quick_panel/quick_panel_settings.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_controller.dart';

/// Whether the Quick Access Panel (hidden long-press Home+Sync panel) is
/// enabled. Device-local (see AppSettings); default true.
class QuickPanelEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsProvider).value?.quickPanelEnabled ?? true;

  Future<void> setEnabled(bool v) =>
      ref.read(settingsProvider.notifier).setQuickPanelEnabled(v);
}

final quickPanelEnabledProvider =
    NotifierProvider<QuickPanelEnabledNotifier, bool>(
        QuickPanelEnabledNotifier.new);

/// Whether the one-time "long-press here" coach mark has been shown.
/// Device-local; default false (a per-install first-run flag).
class QuickPanelHintShownNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsProvider).value?.quickPanelHintShown ?? false;

  Future<void> markShown() =>
      ref.read(settingsProvider.notifier).setQuickPanelHintShown(true);

  /// Resets the flag so the coach mark shows again ("Show me how").
  Future<void> replay() =>
      ref.read(settingsProvider.notifier).setQuickPanelHintShown(false);
}

final quickPanelHintShownProvider =
    NotifierProvider<QuickPanelHintShownNotifier, bool>(
        QuickPanelHintShownNotifier.new);
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/settings/quick_panel_settings_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the settings suite for regressions**

Run: `flutter test test/core/settings/`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/settings/app_settings.dart lib/core/settings/settings_controller.dart lib/core/widgets/quick_panel/quick_panel_settings.dart test/core/settings/quick_panel_settings_test.dart
git commit -m "$(cat <<'EOF'
feat(quick-panel): device-local enabled + hint-shown settings + providers

quickPanelEnabled (default true) and quickPanelHintShown (default false)
join the device-local AppSettings/SettingsController, with thin
Notifier<bool> view providers mirroring IntroCardSeenNotifier. Foundation
for the quick-access-panel redesign.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `QuickPanelAction` model + `quickPanelActionsProvider` registry

**Files:**
- Create: `lib/core/widgets/quick_panel/quick_panel_action.dart`, `lib/core/widgets/quick_panel/quick_panel_actions_provider.dart`
- Test: `test/core/widgets/quick_panel/quick_panel_actions_provider_test.dart` (new)

**Interfaces:**
- Consumes: `AppRouter.config` (`lib/core/navigation/router.dart`), `SyncPill` (`lib/core/widgets/sync_pill.dart`).
- Produces:
  - `class QuickPanelAction` with `QuickPanelAction.simple({required String label, required IconData icon, required void Function(WidgetRef ref) onTap})` and `QuickPanelAction.custom({required String label, required Widget Function(BuildContext, WidgetRef) builder})`. Fields: `label`, `icon` (nullable), `onTap` (nullable), `builder` (nullable). `bool get isCustom => builder != null;`
  - `final quickPanelActionsProvider = Provider<List<QuickPanelAction>>(…)` returning `[Home, Sync]`. Consumed by Task 3.

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/quick_panel/quick_panel_actions_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_action.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_actions_provider.dart';

void main() {
  test('registry ships Home + Sync in order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final actions = container.read(quickPanelActionsProvider);
    expect(actions.map((a) => a.label).toList(), ['Home', 'Sync']);
  });

  test('Home is a simple action; Sync is a custom builder action', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final actions = container.read(quickPanelActionsProvider);
    final home = actions.firstWhere((a) => a.label == 'Home');
    final sync = actions.firstWhere((a) => a.label == 'Sync');

    // Home: simple icon+tap action.
    expect(home.isCustom, isFalse);
    expect(home.icon, isNotNull);
    expect(home.onTap, isNotNull);
    expect(home.builder, isNull);

    // Sync: custom builder action (no icon/onTap).
    expect(sync.isCustom, isTrue);
    expect(sync.builder, isNotNull);
    expect(sync.icon, isNull);
    expect(sync.onTap, isNull);
    // NOTE: do NOT invoke sync.builder!(context, ref) here — WidgetRef is a
    // sealed class in flutter_riverpod 3.0.3 and cannot be faked/implemented
    // outside its library. That the Sync builder renders a live SyncPill is
    // verified end-to-end by Task 4's overlay reveal test, which pumps the
    // real registry through the real QuickAccessPanel.
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/quick_panel/quick_panel_actions_provider_test.dart`
Expected: FAIL — URIs don't exist.

- [ ] **Step 3: Create the model**

Create `lib/core/widgets/quick_panel/quick_panel_action.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One entry in the Quick Access Panel's extensible registry
/// (quickPanelActionsProvider). Two shapes:
///   - QuickPanelAction.simple: a uniform icon+label tile that runs onTap
///     (the panel handles dismiss).
///   - QuickPanelAction.custom: a caller-provided builder widget, for
///     stateful entries like the Sync status pill.
/// Adding a future button is appending one of these to the provider — no
/// panel-layout change needed.
class QuickPanelAction {
  const QuickPanelAction.simple({
    required this.label,
    required this.icon,
    required this.onTap,
  }) : builder = null;

  const QuickPanelAction.custom({
    required this.label,
    required this.builder,
  })  : icon = null,
        onTap = null;

  final String label;
  final IconData? icon;
  final void Function(WidgetRef ref)? onTap;
  final Widget Function(BuildContext context, WidgetRef ref)? builder;

  bool get isCustom => builder != null;
}
```

- [ ] **Step 4: Create the registry provider**

Create `lib/core/widgets/quick_panel/quick_panel_actions_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/router.dart';
import '../sync_pill.dart';
import 'quick_panel_action.dart';

/// Ordered list of actions the Quick Access Panel renders. v1 = Home +
/// Sync. Append here to add a future button (e.g. New Note, Search) — the
/// panel maps over this list, so no layout change is required.
final quickPanelActionsProvider = Provider<List<QuickPanelAction>>((ref) {
  return [
    QuickPanelAction.simple(
      label: 'Home',
      icon: Icons.home_outlined,
      // GoRouter instance .go() — runs from above the Router (the overlay
      // context has no GoRouter ancestor), same as the old HomeButton.
      onTap: (ref) => ref.read(AppRouter.config).go('/'),
    ),
    const QuickPanelAction.custom(
      label: 'Sync',
      builder: _buildSyncAction,
    ),
  ];
});

Widget _buildSyncAction(BuildContext context, WidgetRef ref) =>
    const SyncPill();
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/widgets/quick_panel/quick_panel_actions_provider_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/quick_panel/quick_panel_action.dart lib/core/widgets/quick_panel/quick_panel_actions_provider.dart test/core/widgets/quick_panel/quick_panel_actions_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(quick-panel): QuickPanelAction model + actions registry

Extensible registry (quickPanelActionsProvider) returning an ordered
[Home, Sync] list; simple icon+label actions and custom-builder actions
(Sync embeds the existing SyncPill). Adding a future button is a one-line
append.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `QuickAccessPanel` translucent widget

**Files:**
- Create: `lib/core/widgets/quick_panel/quick_access_panel.dart`
- Test: `test/core/widgets/quick_panel/quick_access_panel_test.dart` (new)

**Interfaces:**
- Consumes: `quickPanelActionsProvider` (Task 2), `QuickPanelAction` (Task 2).
- Produces: `class QuickAccessPanel extends ConsumerWidget` with `const QuickAccessPanel({required VoidCallback onDismiss, super.key})`. Renders the registry as a half-transparent rounded tile stack; a simple action's tile calls `onTap(ref)` then `onDismiss()`; a custom action embeds its `builder`. Consumed by Task 4.

- [ ] **Step 1: Write the failing tests**

Create `test/core/widgets/quick_panel/quick_access_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_access_panel.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_action.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_actions_provider.dart';

Future<void> _pump(WidgetTester tester,
    {required List<QuickPanelAction> actions,
    required VoidCallback onDismiss}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [quickPanelActionsProvider.overrideWithValue(actions)],
      child: MaterialApp(
        home: Scaffold(body: QuickAccessPanel(onDismiss: onDismiss)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders one tile per registry action, in order',
      (tester) async {
    await _pump(tester, onDismiss: () {}, actions: [
      QuickPanelAction.simple(
          label: 'Home', icon: Icons.home_outlined, onTap: (_) {}),
      QuickPanelAction.custom(
          label: 'Sync', builder: (c, r) => const Text('SYNC-WIDGET')),
    ]);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('SYNC-WIDGET'), findsOneWidget);
  });

  testWidgets('tapping a simple action runs onTap then onDismiss',
      (tester) async {
    var tapped = false;
    var dismissed = false;
    await _pump(tester, onDismiss: () => dismissed = true, actions: [
      QuickPanelAction.simple(
          label: 'Home', icon: Icons.home_outlined, onTap: (_) => tapped = true),
    ]);
    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(dismissed, isTrue);
  });

  testWidgets('extension point: an injected 3rd action appears', (tester) async {
    await _pump(tester, onDismiss: () {}, actions: [
      QuickPanelAction.simple(
          label: 'Home', icon: Icons.home_outlined, onTap: (_) {}),
      QuickPanelAction.simple(label: 'New note', icon: Icons.add, onTap: (_) {}),
      QuickPanelAction.simple(label: 'Search', icon: Icons.search, onTap: (_) {}),
    ]);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('panel surface is half-transparent', (tester) async {
    await _pump(tester, onDismiss: () {}, actions: [
      QuickPanelAction.simple(
          label: 'Home', icon: Icons.home_outlined, onTap: (_) {}),
    ]);
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(QuickAccessPanel),
        matching: find.byType(Material),
      ).first,
    );
    expect(material.color!.a, lessThan(1.0));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/widgets/quick_panel/quick_access_panel_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Create `QuickAccessPanel`**

Create `lib/core/widgets/quick_panel/quick_access_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quick_panel_action.dart';
import 'quick_panel_actions_provider.dart';

/// Half-transparent rounded panel that renders the
/// quickPanelActionsProvider registry as a vertical stack of tiles.
/// Revealed by the HomeSyncOverlay long-press hot-zone (Task 4). Simple
/// actions render as icon+label tiles that run their onTap then call
/// onDismiss; custom actions embed their builder widget as-is.
class QuickAccessPanel extends ConsumerWidget {
  const QuickAccessPanel({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final actions = ref.watch(quickPanelActionsProvider);
    return Material(
      color: cs.surface.withValues(alpha: 0.75), // half-transparent
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: action.isCustom
                    ? action.builder!(context, ref)
                    : _SimpleTile(
                        action: action,
                        onTap: () {
                          action.onTap!(ref);
                          onDismiss();
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  const _SimpleTile({required this.action, required this.onTap});

  final QuickPanelAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            Text(action.label,
                style: TextStyle(fontSize: 13, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/widgets/quick_panel/quick_access_panel_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/quick_panel/quick_access_panel.dart test/core/widgets/quick_panel/quick_access_panel_test.dart
git commit -m "$(cat <<'EOF'
feat(quick-panel): translucent QuickAccessPanel rendering the registry

Half-transparent rounded panel that maps quickPanelActionsProvider to
tiles (simple icon+label tiles run onTap then dismiss; custom actions
embed their builder). Grows with the registry — no per-action layout.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Rewrite `HomeSyncOverlay` — hidden hot-zone + reveal/dismiss + enabled gate

**Files:**
- Modify: `lib/core/widgets/home_sync_overlay.dart`
- Delete: `lib/core/widgets/home_button.dart`, `test/core/widgets/home_button_test.dart` (superseded by the Home registry action)
- Test: `test/core/widgets/home_sync_overlay_test.dart` (extend — keep the existing prompt tests, add reveal/dismiss/hidden/gate tests)

**Interfaces:**
- Consumes: `QuickAccessPanel` (Task 3), `quickPanelEnabledProvider` (Task 1), plus everything the current overlay already consumes.
- Produces: rewritten `HomeSyncOverlay` — returns `Positioned.fill(child: Stack([...]))` containing (1) a bottom-right invisible long-press hot-zone; (2) when open, a full-screen transparent dismiss barrier + the anchored `QuickAccessPanel`. Consumed by Tasks 5-6 (which add the dot + coach mark to the same Stack).

**Preserve verbatim (do NOT change behavior):** `_promptShowing`, `_armedForBackgroundPrompt`, the `_controller` field + initState bind + dispose removal, `didChangeAppLifecycleState`, `_onControllerChanged`, `_maybePrompt`, and the two `ref.listen`s (`syncControllerProvider` re-bind + `pendingSyncCountProvider` threshold/zero). Only the returned widget tree in `build` and the addition of reveal state change.

- [ ] **Step 1: Add the test helper + failing tests** (append to `test/core/widgets/home_sync_overlay_test.dart`; keep all existing tests)

Add a mutable bool notifier helper near the existing `_FixedDataMode`:

```dart
class _FixedBool extends Notifier<bool> {
  _FixedBool(this._v);
  final bool _v;
  @override
  bool build() => _v;
}
```

Then (reusing the file's existing `_FixedDataMode` / `_idleController` helpers and its `import` set; add imports for `quick_access_panel.dart` and `quick_panel_settings.dart`):

```dart
  testWidgets('hidden by default — no panel, taps pass through to content',
      (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);
    var tappedBehind = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        quickPanelEnabledProvider.overrideWith(() => _FixedBool(true)),
        quickPanelHintShownProvider.overrideWith(() => _FixedBool(true)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: Stack(children: [
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                  onPressed: () => tappedBehind = true,
                  child: const Text('behind')),
            ),
          ),
          const HomeSyncOverlay(),
        ]),
      ),
    ));
    await tester.pump();
    expect(find.byType(QuickAccessPanel), findsNothing);
    await tester.tap(find.text('behind'));
    expect(tappedBehind, isTrue);
  });

  testWidgets('long-press the corner reveals the panel; outside-tap dismisses',
      (tester) async {
    // pump the same overlay (cloudStorage, enabled, hint already shown) …
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.longPressAt(Offset(size.width - 20, size.height - 20));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessPanel), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessPanel), findsNothing);
  });

  testWidgets('disabled: long-press does nothing', (tester) async {
    // pump with quickPanelEnabledProvider.overrideWith(() => _FixedBool(false))
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.longPressAt(Offset(size.width - 20, size.height - 20));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessPanel), findsNothing);
  });
```

(Note: `quickPanelHintShownProvider` is overridden to `true` here so the coach mark — added in Task 6 — doesn't interfere with these reveal tests; harmless before Task 6 exists since the provider is referenced from Task 1.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/widgets/home_sync_overlay_test.dart`
Expected: FAIL — no reveal behavior / `QuickAccessPanel` not built.

- [ ] **Step 3: Rewrite the `build` return + add reveal state**

Add `bool _panelOpen = false;` and the imports (`quick_panel/quick_access_panel.dart`, `quick_panel/quick_panel_settings.dart`). Add:

```dart
  void _openPanel() => setState(() => _panelOpen = true);
  void _closePanel() {
    if (_panelOpen) setState(() => _panelOpen = false);
  }
```

**Keep the two `ref.listen`s and all prompt state/methods verbatim.** Replace only the returned tree (`return Positioned(… Row[HomeButton, SyncPill] …)`):

```dart
    final enabled = ref.watch(quickPanelEnabledProvider);

    // Positioned.fill so we can host corner children; a bare Stack does not
    // absorb pointer events in empty regions, so taps outside the hot-zone /
    // open panel fall through to content behind.
    return Positioned.fill(
      child: Stack(
        children: [
          if (_panelOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePanel,
              ),
            ),
          if (enabled && !_panelOpen)
            Positioned(
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(right: 8, bottom: 8),
                child: Semantics(
                  button: true,
                  label: 'Home and sync quick actions',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: _openPanel,
                    onTap: _openPanel, // a11y/tap fallback
                    child: const SizedBox(width: 56, height: 56),
                  ),
                ),
              ),
            ),
          if (_panelOpen)
            Positioned(
              right: 12,
              bottom: 12,
              child: SafeArea(
                minimum: const EdgeInsets.only(right: 8, bottom: 8),
                child: QuickAccessPanel(onDismiss: _closePanel),
              ),
            ),
        ],
      ),
    );
```

The 56×56 hot-zone accepts a plain tap too so assistive tech (which activates `Semantics(button)` as a tap) can open the panel; it never intercepts content taps because it occupies only the corner.

- [ ] **Step 4: Delete the superseded `HomeButton`**

`grep -rn "home_button" lib test` — the only references should be the overlay import and the deleted test. Remove `import 'home_button.dart';` from `home_sync_overlay.dart`, then delete `lib/core/widgets/home_button.dart` and `test/core/widgets/home_button_test.dart`.

- [ ] **Step 5: Run to verify pass + analyze**

Run: `flutter test test/core/widgets/home_sync_overlay_test.dart`
Run: `flutter analyze lib/core/widgets test/core/widgets`
Expected: tests PASS (existing prompt tests + new reveal/dismiss/hidden/disabled); analyze clean (no `home_button` references remain).

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/home_sync_overlay.dart test/core/widgets/home_sync_overlay_test.dart
git rm lib/core/widgets/home_button.dart test/core/widgets/home_button_test.dart
git commit -m "$(cat <<'EOF'
feat(quick-panel): hide the overlay behind a long-press hot-zone

HomeSyncOverlay no longer renders an always-on Home+Sync row; it's an
invisible bottom-right long-press hot-zone that reveals the translucent
QuickAccessPanel (outside-tap to dismiss), gated by quickPanelEnabled.
The anti-loss prompt logic and the DataMode-switch controller re-bind are
preserved verbatim. HomeButton is superseded by the Home registry action
and removed.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: At-risk safety dot

**Files:**
- Modify: `lib/core/widgets/home_sync_overlay.dart`
- Test: `test/core/widgets/home_sync_overlay_test.dart` (extend)

**Interfaces:**
- Consumes: `pendingSyncCountProvider`, `syncControllerProvider`, `shouldPromptPendingSync` (already imported), the reveal state from Task 4.
- Produces: a small `Key('quickPanelAtRiskDot')` colored dot in the corner, shown **iff** `shouldPromptPendingSync(pending, skippedForNetwork, lastSyncFailed)` is true, the panel is closed, and the feature is enabled; tapping it opens the panel.

- [ ] **Step 1: Write the failing tests** (append)

Reuse the existing file's helpers to build the "at-risk" state — a `SyncController` whose `status` has `lastAutoTriggerSkippedForNetwork == true` (or a failed `lastResult`) plus `pendingSyncCountProvider` overridden to `Stream.value(3)`. The existing prompt tests already construct a blocked/failed controller (e.g. driving `triggerAutoSync` with an injected gate/failing action) — mirror that.

```dart
  testWidgets('at-risk dot shows only when shouldPromptPendingSync is true',
      (tester) async {
    // pump: cloudStorage, enabled, hint shown, pending = 3, controller status
    // blocked-for-network (or failed) → shouldPromptPendingSync true.
    expect(find.byKey(const Key('quickPanelAtRiskDot')), findsOneWidget);
  });

  testWidgets('no dot on the healthy/synced path', (tester) async {
    // pump: cloudStorage, enabled, pending = 0, idle controller → false.
    expect(find.byKey(const Key('quickPanelAtRiskDot')), findsNothing);
  });

  testWidgets('tapping the dot opens the panel', (tester) async {
    // at-risk state as above:
    await tester.tap(find.byKey(const Key('quickPanelAtRiskDot')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessPanel), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/widgets/home_sync_overlay_test.dart`
Expected: FAIL — no dot widget.

- [ ] **Step 3: Add the dot to the Stack**

In `build`, after `final enabled = ...`, read the pending count and add a dot sibling in the Stack (shown only when enabled + closed + at-risk). Rebuild on controller notifications via `ListenableBuilder`:

```dart
    final pending = ref.watch(pendingSyncCountProvider).value ?? 0;

    // … as a Stack child, after the hot-zone, before the panel:
    if (enabled && !_panelOpen)
      Positioned(
        right: 0,
        bottom: 0,
        child: SafeArea(
          minimum: const EdgeInsets.only(right: 12, bottom: 12),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final status = _controller.status;
              final atRisk = shouldPromptPendingSync(
                pendingCount: pending,
                autoSyncSkippedForNetwork:
                    status.lastAutoTriggerSkippedForNetwork,
                lastSyncFailed:
                    status.lastResult != null && !status.lastResult!.success,
              );
              if (!atRisk) return const SizedBox.shrink();
              return GestureDetector(
                key: const Key('quickPanelAtRiskDot'),
                behavior: HitTestBehavior.opaque,
                onTap: _openPanel,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
      ),
```

The dot sits just inside the same corner as the hot-zone (larger `SafeArea` inset). When shown it gives a tappable target that opens the panel; the invisible hot-zone still handles long-press.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/widgets/home_sync_overlay_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/home_sync_overlay.dart test/core/widgets/home_sync_overlay_test.dart
git commit -m "$(cat <<'EOF'
feat(quick-panel): at-risk safety dot on the hidden overlay

A small error-colored dot appears in the corner only when
shouldPromptPendingSync is true (pending AND blocked/failed) — the same
predicate as the anti-loss prompt — so at-risk data is never fully
hidden. Tapping the dot opens the panel. Nothing shows on the healthy
path or in local/cloudApi.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: First-run coach mark

**Files:**
- Create: `lib/core/widgets/quick_panel/quick_panel_coach_mark.dart`
- Modify: `lib/core/widgets/home_sync_overlay.dart`
- Test: `test/core/widgets/quick_panel/quick_panel_coach_mark_test.dart` (new), `test/core/widgets/home_sync_overlay_test.dart` (extend)

**Interfaces:**
- Consumes: `quickPanelHintShownProvider` (Task 1).
- Produces: `class QuickPanelCoachMark extends StatelessWidget` (`const QuickPanelCoachMark({required VoidCallback onDismiss, super.key})`) — a scrim + a bubble pointing at the corner with a "Got it" button. `HomeSyncOverlay` shows it when `!quickPanelHintShown && quickPanelEnabled && !_panelOpen`, and calls `markShown()` on dismiss.

- [ ] **Step 1: Write the coach-mark widget test**

Create `test/core/widgets/quick_panel/quick_panel_coach_mark_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_coach_mark.dart';

void main() {
  testWidgets('shows the hint copy and fires onDismiss on "Got it"',
      (tester) async {
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        QuickPanelCoachMark(onDismiss: () => dismissed = true),
      ]),
    ));
    expect(find.textContaining('Long-press'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(dismissed, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/widgets/quick_panel/quick_panel_coach_mark_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Create the coach mark**

Create `lib/core/widgets/quick_panel/quick_panel_coach_mark.dart`:

```dart
import 'package:flutter/material.dart';

/// One-time first-run hint pointing at the bottom-right Quick Access
/// hot-zone. Shown by HomeSyncOverlay when quickPanelHintShown is false
/// and the feature is enabled; dismissed via onDismiss (which persists the
/// flag). Built in-repo — no coach-mark package.
class QuickPanelCoachMark extends StatelessWidget {
  const QuickPanelCoachMark({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss, // tapping the scrim also dismisses
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 80),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Material(
                  color: cs.inverseSurface,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 220,
                          child: Text(
                            'Long-press this corner for Home & quick Sync.',
                            style: TextStyle(color: cs.onInverseSurface),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/widgets/quick_panel/quick_panel_coach_mark_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the coach mark into the overlay**

In `home_sync_overlay.dart`, import the coach mark. In `build`, compute and add it as the **last** (top-most) Stack child:

```dart
    final showCoach =
        enabled && !_panelOpen && !ref.watch(quickPanelHintShownProvider);

    // … last child in the Stack:
    if (showCoach)
      QuickPanelCoachMark(
        onDismiss: () =>
            ref.read(quickPanelHintShownProvider.notifier).markShown(),
      ),
```

Because `quickPanelHintShownProvider` is reactive, `markShown()` (or Settings' "Show me how" `replay()`) re-renders the overlay and shows/hides the coach mark with no imperative Overlay management.

- [ ] **Step 6: Add the overlay coach-mark test** (append to `home_sync_overlay_test.dart`)

Override `quickPanelHintShownProvider` with a real settings-backed provider (mirror Task 1's harness: `SharedPreferences.setMockInitialValues({})` + resolved `settingsProvider`) so `markShown()` actually flips it, OR a small mutable `Notifier<bool>` test double. Pump overlay in cloudStorage + enabled + hint unseen:

```dart
  testWidgets('coach mark shows once, gone after "Got it"', (tester) async {
    // hint starts unseen → coach mark visible
    expect(find.byType(QuickPanelCoachMark), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickPanelCoachMark), findsNothing);
  });
```

- [ ] **Step 7: Run overlay + coach-mark tests**

Run: `flutter test test/core/widgets/quick_panel/ test/core/widgets/home_sync_overlay_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/widgets/quick_panel/quick_panel_coach_mark.dart lib/core/widgets/home_sync_overlay.dart test/core/widgets/quick_panel/quick_panel_coach_mark_test.dart test/core/widgets/home_sync_overlay_test.dart
git commit -m "$(cat <<'EOF'
feat(quick-panel): one-time first-run coach mark

A lightweight in-repo coach mark points at the hidden corner hot-zone the
first time (gated by device-local quickPanelHintShown); dismissing it
persists the flag. Reactive, so "Show me how" (Task 7) replays it by
resetting the flag.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Settings row — toggle + "Show me how"

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Test: `test/features/settings/quick_panel_settings_row_test.dart` (new)

**Interfaces:**
- Consumes: `quickPanelEnabledProvider`, `quickPanelHintShownProvider` (Task 1).
- Produces: a "Quick access panel" `SwitchListTile.adaptive` bound to `quickPanelEnabledProvider` + a "Show me how" `ListTile` calling `quickPanelHintShownProvider.notifier.replay()`, in the "Data & Storage" section.

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/quick_panel_settings_row_test.dart`. Read an existing `test/features/settings/` test first for the exact `SettingsScreen` pump harness (localization delegates, `CommonScreenScaffold`, SharedPreferences mock, resolved `settingsProvider`). Assertions:

```dart
expect(find.text('Quick access panel'), findsOneWidget);
final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile).first);
expect(sw.value, isTrue); // default on
await tester.tap(find.text('Quick access panel'));
await tester.pumpAndSettle();
expect(container.read(quickPanelEnabledProvider), isFalse);

await container.read(quickPanelHintShownProvider.notifier).markShown();
expect(container.read(quickPanelHintShownProvider), isTrue);
await tester.tap(find.text('Show me how'));
await tester.pumpAndSettle();
expect(container.read(quickPanelHintShownProvider), isFalse);
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/settings/quick_panel_settings_row_test.dart`
Expected: FAIL — rows not present.

- [ ] **Step 3: Add the rows to `SettingsScreen`**

Add `import '../../../../core/widgets/quick_panel/quick_panel_settings.dart';` (adjust relative depth to match the file). In the "Data & Storage" section (near the sync block, ~line 425-447 — after the sync `if (dataMode != DataMode.local)…` block, still inside the section), add:

```dart
Builder(builder: (context) {
  final enabled = ref.watch(quickPanelEnabledProvider);
  return SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: const Text('Quick access panel'),
    subtitle: const Text(
        'Long-press the bottom-right corner for Home & quick Sync'),
    value: enabled,
    onChanged: (v) =>
        ref.read(quickPanelEnabledProvider.notifier).setEnabled(v),
  );
}),
Builder(builder: (context) {
  final enabled = ref.watch(quickPanelEnabledProvider);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    enabled: enabled,
    leading: const Icon(Icons.touch_app_outlined),
    title: const Text('Show me how'),
    subtitle: const Text('Replay the quick-access hint'),
    onTap: enabled
        ? () => ref.read(quickPanelHintShownProvider.notifier).replay()
        : null,
  );
}),
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/settings/quick_panel_settings_row_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the settings suite + analyze**

Run: `flutter test test/features/settings/`
Run: `flutter analyze lib/features/settings lib/core/widgets`
Expected: PASS / clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/presentation/screens/settings_screen.dart test/features/settings/quick_panel_settings_row_test.dart
git commit -m "$(cat <<'EOF'
feat(quick-panel): Settings toggle + "Show me how"

A "Quick access panel" switch (default on) toggles quickPanelEnabled, and
"Show me how" replays the coach mark by resetting quickPanelHintShown.
Placed in the Data & Storage section next to the sync controls.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Final steps (after all tasks)

- [ ] Run the full suite: `flutter test` — expect green (existing Sync-Safety / anti-loss tests unchanged).
- [ ] `flutter analyze lib/ test/` — expect no new issues.
- [ ] Whole-branch review (superpowers:requesting-code-review), then finishing-a-development-branch.

## Self-review notes (plan author)

- **Spec coverage:** hidden default + long-press hot-zone (T4); translucent panel (T3); extensible registry (T2); at-risk dot = `shouldPromptPendingSync` (T5); coach mark + `quickPanelHintShown` (T6); Settings toggle + "Show me how" + `quickPanelEnabled` (T1, T7); `Semantics` a11y on the hot-zone (T4); anti-loss prompt + DataMode re-bind preserved verbatim (T4). Every spec section maps to a task.
- **Type consistency:** `QuickPanelAction.{simple,custom}` fields (`label`/`icon`/`onTap`/`builder`/`isCustom`) defined T2, consumed unchanged T3; `quickPanelEnabledProvider`/`quickPanelHintShownProvider` (+ `setEnabled`/`markShown`/`replay`) defined T1, consumed T4-T7; `QuickAccessPanel({onDismiss})` defined T3, consumed T4; `QuickPanelCoachMark({onDismiss})` defined T6.
- **Preserved behavior:** T4/T5/T6 modify only `HomeSyncOverlay.build`'s returned tree and add `_panelOpen`; the prompt state, `_controller` lifecycle, `didChangeAppLifecycleState`, `_maybePrompt`, and the two `ref.listen`s stay verbatim.
- **YAGNI:** no new package (coach mark in-repo); `BackdropFilter` blur intentionally omitted from v1 (plain translucent fill) — add later if desired.
