# In-App Help (Phases 1–2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every icon button carries a localized label, the vehicle-notes Detach action explains itself with an honest Undo snackbar, and the Automobile hub and vehicle notes screens get a "?" help sheet.

**Architecture:** A shared `HmmIconButton` (tooltip required) plus a guard test that stops new raw icon buttons. A `lib/core/help/` module holds `HelpEntry`/`ScreenHelp`, an exhaustive `helpFor(HelpId)` registry, a platform-aware `showHelpSheet`, a `HelpButton`, and `showUndoableAction`. Two screens adopt it; CLAUDE.md records the rules.

**Tech Stack:** Flutter 3.41.9, Riverpod 3 (`flutter_riverpod ^3.0.3`), GoRouter, gen-l10n (`lib/l10n/app_en.arb` template, `app_zh.arb`, generated into `lib/l10n/gen/`, committed).

**Spec:** `docs/superpowers/specs/2026-09-27-in-app-help-design.md`

## Global Constraints

- **Precondition — clean ARB files.** At plan time `lib/l10n/app_en.arb`, `app_zh.arb` and `lib/l10n/gen/*` carry *uncommitted* changes from the sync-error work (plus `onedrive_graph_client.dart`, `sync_status_card.dart`, two untracked tests). Before Task 3, those must be committed or shelved by the user — otherwise this plan's commits sweep them in. Do not commit or stash them yourself; stop and ask.
- Stage only the files each task names (`git add <paths>`), never `git add -A`.
- Every user-visible string goes in **both** `app_en.arb` and `app_zh.arb`; run `flutter gen-l10n` after ARB edits and commit the regenerated `lib/l10n/gen/` files. zh text is unreviewed (see Task 7).
- Help ARB keys: `help<Screen>Title`, `help<Screen>Summary`, `help<Screen><Control>Title`, `help<Screen><Control>Body`.
- A help entry uses the same `Icons.*` constant as the control it explains.
- `showUndoableAction`: action commits immediately; four outcomes, four distinct messages; `onChanged` only on success; nothing used after an `await` may belong to a disposed screen.
- Snackbars with an action must set `persist: false` — on Flutter 3.41 `SnackBar.persist` defaults to `true` when `action != null` (`snack_bar.dart:303`), which would leave Undo on screen forever.
- `flutter_platform_widgets` is **not** a dependency despite CLAUDE.md; platform branching uses `Theme.of(context).platform`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Undo snackbar never leaves** (Flutter's `persist` default with an action) — expected: gone after ~5 s. Pinned in Task 4.
2. **Undo tapped after the user left the screen** — expected: undo runs, "Note is back" shows, nothing throws. Pinned in Task 4.
3. **Detach fails (offline in cloudApi mode)** — expected: "Couldn't detach the note", no Undo, list unchanged. Pinned in Tasks 4 and 5.
4. **Chinese help on a small phone** — expected: sheet renders at 320×568 in zh with no overflow and scrolls. Pinned in Task 3.
5. **A new screen adds a raw `IconButton`** — expected: guard test fails naming the file. Pinned in Task 2.

---

### Task 1: `HmmIconButton`

**Files:**
- Create: `lib/core/widgets/hmm_icon_button.dart`
- Test: `test/core/widgets/hmm_icon_button_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum HmmIconButtonStyle { standard, filled, filledTonal }
  class HmmIconButton extends StatelessWidget {
    const HmmIconButton({Key? key, required IconData icon, required String tooltip,
      required VoidCallback? onPressed, int? badgeCount,
      HmmIconButtonStyle style = HmmIconButtonStyle.standard});
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/hmm_icon_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/widgets/hmm_icon_button.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('long-press shows the tooltip', (tester) async {
    await tester.pumpWidget(_host(HmmIconButton(
        icon: Icons.link_off, tooltip: 'Detach note', onPressed: () {})));
    expect(find.byTooltip('Detach note'), findsOneWidget);
    await tester.longPress(find.byType(HmmIconButton));
    await tester.pumpAndSettle();
    expect(find.text('Detach note'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // let the tooltip timer end
  });

  testWidgets('tap calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(HmmIconButton(
        icon: Icons.add, tooltip: 'Add', onPressed: () => taps++)));
    await tester.tap(find.byType(HmmIconButton));
    expect(taps, 1);
  });

  testWidgets('badge only for a count of 1 or more', (tester) async {
    for (final (count, badged) in [(null, false), (0, false), (2, true)]) {
      await tester.pumpWidget(_host(HmmIconButton(
          icon: Icons.sticky_note_2_outlined,
          tooltip: 'Notes',
          badgeCount: count,
          onPressed: () {})));
      expect(find.byType(Badge), badged ? findsOneWidget : findsNothing,
          reason: 'count=$count');
      if (badged) expect(find.widgetWithText(Badge, '2'), findsOneWidget);
    }
  });

  testWidgets('each style renders an IconButton', (tester) async {
    for (final style in HmmIconButtonStyle.values) {
      await tester.pumpWidget(_host(HmmIconButton(
          icon: Icons.add, tooltip: 'Add', style: style, onPressed: () {})));
      expect(find.byType(IconButton), findsOneWidget, reason: '$style');
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/widgets/hmm_icon_button_test.dart`
Expected: FAIL — `hmm_icon_button.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/hmm_icon_button.dart
import 'package:flutter/material.dart';

enum HmmIconButtonStyle { standard, filled, filledTonal }

/// The app's only icon button. [tooltip] is required and must be a localized
/// string: long-press shows it and screen readers announce it, so an icon is
/// never the only explanation of what a button does. A test
/// (test/core/help/icon_button_guard_test.dart) keeps raw IconButtons out.
class HmmIconButton extends StatelessWidget {
  const HmmIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount,
    this.style = HmmIconButtonStyle.standard,
  }) : assert(tooltip != '', 'HmmIconButton needs a localized tooltip');

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Shown as a badge when 1 or more; null and 0 draw no decoration.
  final int? badgeCount;
  final HmmIconButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final n = badgeCount;
    final Widget glyph = n != null && n > 0
        ? Badge(label: Text('$n'), child: Icon(icon))
        : Icon(icon);
    return switch (style) {
      HmmIconButtonStyle.standard =>
        IconButton(tooltip: tooltip, icon: glyph, onPressed: onPressed),
      HmmIconButtonStyle.filled =>
        IconButton.filled(tooltip: tooltip, icon: glyph, onPressed: onPressed),
      HmmIconButtonStyle.filledTonal => IconButton.filledTonal(
          tooltip: tooltip, icon: glyph, onPressed: onPressed),
    };
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/core/widgets/hmm_icon_button_test.dart`
Expected: all 4 PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/hmm_icon_button.dart test/core/widgets/hmm_icon_button_test.dart
git commit -m "feat(help): HmmIconButton, the icon button that requires a label

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Icon-button guard test

**Files:**
- Test: `test/core/help/icon_button_guard_test.dart`

**Interfaces:**
- Consumes: `lib/core/widgets/hmm_icon_button.dart` (excluded from the scan).
- Produces: the `_allowed` map that Tasks 5 and 6 shrink.

- [ ] **Step 1: Write the test**

The allow-list is the per-file count of raw icon buttons on 2026-09-27 (55 total).

```dart
// test/core/help/icon_button_guard_test.dart
//
// Every icon button must be an HmmIconButton, which cannot be built without a
// localized tooltip. Files that predate it are allow-listed with their count;
// phase 3 of docs/superpowers/specs/2026-09-27-in-app-help-design.md empties
// this list. Never add to it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowed = <String, int>{
  'lib/core/contact_block/widgets/contact_info_editor.dart': 1,
  'lib/core/data/attachments/widgets/attachments_section.dart': 3,
  'lib/core/widgets/editable_info_card.dart': 1,
  'lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart': 2,
  'lib/features/automobile_records/presentation/screens/insurance_policies_screen.dart': 2,
  'lib/features/automobile_records/presentation/screens/scheduled_services_screen.dart': 2,
  'lib/features/automobile_records/presentation/screens/service_record_form_screen.dart': 1,
  'lib/features/automobile_records/presentation/screens/service_records_screen.dart': 2,
  'lib/features/automobile_records/presentation/widgets/optional_date_picker.dart': 1,
  'lib/features/automobile_records/presentation/widgets/service_line_item_row.dart': 1,
  'lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart': 2,
  'lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart': 3,
  'lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart': 1,
  'lib/features/cheatsheet/presentation/widgets/source_picker.dart': 1,
  'lib/features/driver_licence/presentation/screens/driver_licence_screen.dart': 2,
  'lib/features/gas_log/presentation/screens/automobile_edit_screen.dart': 2,
  'lib/features/gas_log/presentation/screens/automobile_management_screen.dart': 1,
  'lib/features/gas_log/presentation/screens/gas_log_list_screen.dart': 2,
  'lib/features/gas_log/presentation/screens/gas_station_management_screen.dart': 1,
  'lib/features/gas_log/presentation/widgets/gas_log_list_tile.dart': 1,
  'lib/features/gas_log/presentation/widgets/manageable_automobile_tile.dart': 1,
  'lib/features/gas_log/presentation/widgets/manageable_gas_station_tile.dart': 2,
  'lib/features/gas_log/presentation/widgets/station_dropdown.dart': 2,
  'lib/features/launcher/presentation/launcher_manage_screen.dart': 2,
  'lib/features/notes/presentation/screens/notes_list_screen.dart': 4,
  'lib/features/notes/presentation/screens/raw_content_screen.dart': 1,
  'lib/features/notes/presentation/widgets/attached_notes_section.dart': 3,
  'lib/features/notes/presentation/widgets/media_toolbar.dart': 6,
  'lib/features/notes/presentation/widgets/note_audio_card.dart': 2,
};

// `\b` keeps HmmIconButton( out; PlatformIconButton( is matched explicitly.
final _raw =
    RegExp(r'\bIconButton(\(|\.filled|\.outlined)|PlatformIconButton\(');

Map<String, int> _scan() {
  final found = <String, int>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    final path = f.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') ||
        path.contains('/l10n/gen/') ||
        path.endsWith('core/widgets/hmm_icon_button.dart')) {
      continue;
    }
    final n = _raw.allMatches(f.readAsStringSync()).length;
    if (n > 0) found[path] = n;
  }
  return found;
}

void main() {
  test('icon buttons go through HmmIconButton', () {
    final found = _scan();
    final offenders = [
      for (final e in found.entries)
        if (e.value > (_allowed[e.key] ?? 0))
          '${e.key}: ${e.value} raw (allowed ${_allowed[e.key] ?? 0})',
    ];
    expect(offenders, isEmpty,
        reason: 'Use HmmIconButton (lib/core/widgets/hmm_icon_button.dart) '
            'with a localized tooltip.');
  });

  test('allow-list shrinks as files are cleaned', () {
    final found = _scan();
    final stale = [
      for (final e in _allowed.entries)
        if ((found[e.key] ?? 0) < e.value)
          '${e.key}: allowed ${e.value}, now ${found[e.key] ?? 0} — lower it',
    ];
    expect(stale, isEmpty);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/core/help/icon_button_guard_test.dart`
Expected: both PASS. If a count differs, the tree changed since planning: set the entry to the current count, and say so in the commit message.

- [ ] **Step 3: Prove it bites (then revert)**

Temporarily add `IconButton(onPressed: null, icon: Icon(Icons.add))` inside any widget in `lib/core/widgets/gaps.dart`, re-run; expected FAIL naming `lib/core/widgets/gaps.dart`. Revert the edit (`git checkout lib/core/widgets/gaps.dart`) and re-run to PASS.

- [ ] **Step 4: Commit**

```bash
git add test/core/help/icon_button_guard_test.dart
git commit -m "test(help): guard against new raw icon buttons

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Help registry, sheet and button

**Stop first** if the Global Constraints precondition (clean ARB files) is not met.

**Files:**
- Create: `lib/core/help/help_models.dart`, `lib/core/help/help_registry.dart`, `lib/core/help/help_sheet.dart`, `lib/core/help/help_button.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (append before the closing `}`), regenerated `lib/l10n/gen/*`
- Test: `test/core/help/help_registry_test.dart`, `test/core/help/help_sheet_test.dart`

**Interfaces:**
- Consumes: `HmmIconButton` (Task 1).
- Produces:
  ```dart
  class HelpEntry { const HelpEntry({required IconData icon, required String title, required String body}); }
  class ScreenHelp { const ScreenHelp({required String title, required String summary, required List<HelpEntry> entries}); }
  enum HelpId { automobileHub, vehicleNotes }
  ScreenHelp helpFor(HelpId id, AppLocalizations l);
  Future<void> showHelpSheet(BuildContext context, ScreenHelp help);
  class HelpButton extends StatelessWidget { const HelpButton({Key? key, required HelpId helpId}); }
  ```
  ARB key `helpButtonTooltip` ("Help").

The spec's `Map` registry becomes an exhaustive `switch`: adding a `HelpId` without help is then a compile error rather than a runtime `null`.

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`, after the last entry (`"licenceNoImages": "No photo captured yet"`), add a comma and:

```json
  "helpButtonTooltip": "Help",
  "helpAutomobileHubTitle": "Automobile",
  "helpAutomobileHubSummary": "Your driver's licence and your vehicles in one place.",
  "helpAutomobileHubLicenceTitle": "Driver's licence",
  "helpAutomobileHubLicenceBody": "Tap the card to view or add your licence. Not shown in Cloud API mode.",
  "helpAutomobileHubVehicleTitle": "A vehicle",
  "helpAutomobileHubVehicleBody": "Tap a vehicle's row to see and edit its details.",
  "helpAutomobileHubNotesTitle": "Notes",
  "helpAutomobileHubNotesBody": "Opens this car's notes. The number is how many notes it has.",
  "helpAutomobileHubFuelTitle": "Gas log",
  "helpAutomobileHubFuelBody": "Opens this car's fuel log.",
  "helpAutomobileHubManageTitle": "Manage",
  "helpAutomobileHubManageBody": "Add vehicles and choose which ones are active.",
  "helpVehicleNotesTitle": "Car notes",
  "helpVehicleNotesSummary": "Everything written about this car. These notes are listed under Automobile in your notes.",
  "helpVehicleNotesNewTitle": "New note",
  "helpVehicleNotesNewBody": "Writes a note that is already attached to this car.",
  "helpVehicleNotesAttachTitle": "Attach existing note",
  "helpVehicleNotesAttachBody": "Pick a General note that isn't attached to anything and attach it to this car.",
  "helpVehicleNotesDetachTitle": "Detach",
  "helpVehicleNotesDetachBody": "Unlinks the note from this car. The note is kept and moves to General; attach it again any time.",
  "helpVehicleNotesOpenTitle": "Open a note",
  "helpVehicleNotesOpenBody": "Tap a note to read or edit it."
```

In `lib/l10n/app_zh.arb`, after `"licenceNoImages": "尚未拍摄照片"`, add a comma and:

```json
  "helpButtonTooltip": "帮助",
  "helpAutomobileHubTitle": "汽车",
  "helpAutomobileHubSummary": "驾驶证和车辆集中在这里。",
  "helpAutomobileHubLicenceTitle": "驾驶证",
  "helpAutomobileHubLicenceBody": "点击卡片查看或添加驾驶证。云端 API 模式下不显示。",
  "helpAutomobileHubVehicleTitle": "车辆",
  "helpAutomobileHubVehicleBody": "点击车辆所在行，查看和编辑车辆信息。",
  "helpAutomobileHubNotesTitle": "备注",
  "helpAutomobileHubNotesBody": "打开这辆车的备注。数字表示备注数量。",
  "helpAutomobileHubFuelTitle": "加油记录",
  "helpAutomobileHubFuelBody": "打开这辆车的加油记录。",
  "helpAutomobileHubManageTitle": "管理",
  "helpAutomobileHubManageBody": "添加车辆，并选择哪些车辆处于启用状态。",
  "helpVehicleNotesTitle": "车辆备注",
  "helpVehicleNotesSummary": "关于这辆车的所有记录。这些备注在备注列表中归入“汽车”。",
  "helpVehicleNotesNewTitle": "新建备注",
  "helpVehicleNotesNewBody": "新建一条已关联到这辆车的备注。",
  "helpVehicleNotesAttachTitle": "关联已有备注",
  "helpVehicleNotesAttachBody": "选择一条尚未关联的“常规”备注，把它关联到这辆车。",
  "helpVehicleNotesDetachTitle": "取消关联",
  "helpVehicleNotesDetachBody": "解除备注与这辆车的关联。备注会保留并移到“常规”，之后可随时重新关联。",
  "helpVehicleNotesOpenTitle": "打开备注",
  "helpVehicleNotesOpenBody": "点击备注即可查看或编辑。"
```

Run: `flutter gen-l10n`
Expected: no errors; `lib/l10n/gen/app_localizations.dart` now declares `helpButtonTooltip`.

- [ ] **Step 2: Write the failing tests**

```dart
// test/core/help/help_registry_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  for (final code in ['en', 'zh']) {
    test('every HelpId has complete help in $code', () {
      final l = lookupAppLocalizations(Locale(code));
      for (final id in HelpId.values) {
        final h = helpFor(id, l);
        expect(h.title.trim(), isNotEmpty, reason: '$id title');
        expect(h.summary.trim(), isNotEmpty, reason: '$id summary');
        expect(h.entries, isNotEmpty, reason: '$id entries');
        for (final e in h.entries) {
          expect(e.title.trim(), isNotEmpty, reason: '$id entry title');
          expect(e.body.trim(), isNotEmpty, reason: '$id ${e.title} body');
        }
      }
    });
  }

  test('zh help is translated, not copied from en', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    for (final id in HelpId.values) {
      expect(helpFor(id, zh).summary, isNot(helpFor(id, en).summary),
          reason: '$id');
    }
  });
}
```

```dart
// test/core/help/help_sheet_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

Widget _app({Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(actions: const [HelpButton(helpId: HelpId.vehicleNotes)]),
      ),
    );

void main() {
  testWidgets('the ? button opens that screen\'s help', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Car notes'), findsOneWidget);
    expect(find.text('Detach'), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
  });

  testWidgets('Material bottom sheet on Android', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Cupertino popup on iOS', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPopupSurface), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Chinese help fits a small phone and scrolls', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(locale: const Locale('zh')));
    await tester.tap(find.byTooltip('帮助'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no RenderFlex overflow
    expect(find.text('车辆备注'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('打开备注'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/core/help/`
Expected: FAIL — `help_registry.dart` / `help_button.dart` do not exist (guard test still PASSes).

- [ ] **Step 4: Implement**

```dart
// lib/core/help/help_models.dart
import 'package:flutter/widgets.dart';

/// One explained control. [icon] is the same constant the real control uses,
/// so the sheet shows what the user sees on screen.
class HelpEntry {
  const HelpEntry({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

/// A screen's help, built from localized strings.
class ScreenHelp {
  const ScreenHelp(
      {required this.title, required this.summary, required this.entries});
  final String title;
  final String summary;
  final List<HelpEntry> entries;
}
```

```dart
// lib/core/help/help_registry.dart
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'help_models.dart';

export 'help_models.dart';

/// Every screen that has a "?" help sheet. Adding a value without a case in
/// [helpFor] does not compile.
enum HelpId { automobileHub, vehicleNotes }

ScreenHelp helpFor(HelpId id, AppLocalizations l) => switch (id) {
      HelpId.automobileHub => ScreenHelp(
          title: l.helpAutomobileHubTitle,
          summary: l.helpAutomobileHubSummary,
          entries: [
            HelpEntry(
                icon: Icons.badge_outlined,
                title: l.helpAutomobileHubLicenceTitle,
                body: l.helpAutomobileHubLicenceBody),
            HelpEntry(
                icon: Icons.directions_car_outlined,
                title: l.helpAutomobileHubVehicleTitle,
                body: l.helpAutomobileHubVehicleBody),
            HelpEntry(
                icon: Icons.sticky_note_2_outlined,
                title: l.helpAutomobileHubNotesTitle,
                body: l.helpAutomobileHubNotesBody),
            HelpEntry(
                icon: Icons.local_gas_station_outlined,
                title: l.helpAutomobileHubFuelTitle,
                body: l.helpAutomobileHubFuelBody),
            HelpEntry(
                icon: Icons.settings,
                title: l.helpAutomobileHubManageTitle,
                body: l.helpAutomobileHubManageBody),
          ],
        ),
      HelpId.vehicleNotes => ScreenHelp(
          title: l.helpVehicleNotesTitle,
          summary: l.helpVehicleNotesSummary,
          entries: [
            HelpEntry(
                icon: Icons.add,
                title: l.helpVehicleNotesNewTitle,
                body: l.helpVehicleNotesNewBody),
            HelpEntry(
                icon: Icons.attach_file,
                title: l.helpVehicleNotesAttachTitle,
                body: l.helpVehicleNotesAttachBody),
            HelpEntry(
                icon: Icons.link_off,
                title: l.helpVehicleNotesDetachTitle,
                body: l.helpVehicleNotesDetachBody),
            HelpEntry(
                icon: Icons.touch_app_outlined,
                title: l.helpVehicleNotesOpenTitle,
                body: l.helpVehicleNotesOpenBody),
          ],
        ),
    };
```

```dart
// lib/core/help/help_sheet.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'help_models.dart';

/// Shows [help] as a Cupertino popup on iOS and a Material bottom sheet
/// elsewhere. Capped at 80% of the screen height; longer help scrolls.
Future<void> showHelpSheet(BuildContext context, ScreenHelp help) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
  final body = ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: _HelpBody(help: help),
  );
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoPopupSurface(
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(top: false, child: body),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(child: body),
  );
}

class _HelpBody extends StatelessWidget {
  const _HelpBody({required this.help});
  final ScreenHelp help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(help.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(help.summary,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (final e in help.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(e.icon),
            title: Text(e.title),
            subtitle: Text(e.body),
          ),
      ],
    );
  }
}
```

```dart
// lib/core/help/help_button.dart
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../widgets/hmm_icon_button.dart';
import 'help_registry.dart';
import 'help_sheet.dart';

/// The top-bar "?" that opens a screen's help sheet.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.helpId});
  final HelpId helpId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return HmmIconButton(
      icon: Icons.help_outline,
      tooltip: l.helpButtonTooltip,
      onPressed: () => showHelpSheet(context, helpFor(helpId, l)),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/help/`
Expected: all PASS. If the small-phone test reports an overflow, fix the sheet (not the test).

- [ ] **Step 6: Commit**

```bash
git add lib/core/help/ lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/ test/core/help/help_registry_test.dart test/core/help/help_sheet_test.dart
git commit -m "feat(help): per-screen help registry, sheet and ? button

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `showUndoableAction`

**Files:**
- Create: `lib/core/help/undoable_action.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, regenerated `lib/l10n/gen/*`
- Test: `test/core/help/undoable_action_test.dart`

**Interfaces:**
- Produces:
  ```dart
  Future<void> showUndoableAction(BuildContext context, {
    required Future<void> Function() run,
    required Future<void> Function() undo,
    required String done, required String failed,
    required String undone, required String undoFailed,
    VoidCallback? onChanged,
  });
  ```
  ARB keys `undoAction`, `undoNoteDetached`, `undoNoteDetachFailed`, `undoNoteRestored`, `undoNoteRestoreFailed`.

- [ ] **Step 1: Add the strings**

`app_en.arb`, after `"helpVehicleNotesOpenBody"` (add a comma to it):

```json
  "undoAction": "Undo",
  "undoNoteDetached": "Note moved to General",
  "undoNoteDetachFailed": "Couldn't detach the note",
  "undoNoteRestored": "Note is back",
  "undoNoteRestoreFailed": "Couldn't undo — the note is in General"
```

`app_zh.arb`, after `"helpVehicleNotesOpenBody"` (add a comma to it):

```json
  "undoAction": "撤销",
  "undoNoteDetached": "备注已移至“常规”",
  "undoNoteDetachFailed": "无法取消关联备注",
  "undoNoteRestored": "备注已恢复",
  "undoNoteRestoreFailed": "无法撤销，备注仍在“常规”中"
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

```dart
// test/core/help/undoable_action_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/undoable_action.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _Probe {
  bool failRun = false;
  bool failUndo = false;
  final calls = <String>[];
  int changed = 0;
}

/// Home screen with a "go" button that pushes a second screen, whose "act"
/// button triggers the undoable action. Lets a test leave the screen before
/// tapping Undo.
Widget _app(_Probe p) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (home) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(home).push(MaterialPageRoute(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  onPressed: () => showUndoableAction(
                    ctx,
                    run: () async {
                      p.calls.add('run');
                      if (p.failRun) throw StateError('offline');
                    },
                    undo: () async {
                      p.calls.add('undo');
                      if (p.failUndo) throw StateError('offline');
                    },
                    done: 'Moved',
                    failed: 'Move failed',
                    undone: 'Restored',
                    undoFailed: 'Restore failed',
                    onChanged: () => p.changed++,
                  ),
                  child: const Text('act'),
                ),
              ),
            )),
            child: const Text('go'),
          ),
        ),
      ),
    );

Future<void> _act(WidgetTester tester, _Probe p) async {
  await tester.pumpWidget(_app(p));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('act'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('success: says what happened and offers Undo', (tester) async {
    final p = _Probe();
    await _act(tester, p);
    expect(find.text('Moved'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(p.changed, 1);
  });

  testWidgets('failure: says so, no Undo, nothing reloaded', (tester) async {
    final p = _Probe()..failRun = true;
    await _act(tester, p);
    expect(find.text('Move failed'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(p.changed, 0);
  });

  testWidgets('Undo succeeds', (tester) async {
    final p = _Probe();
    await _act(tester, p);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(p.calls, ['run', 'undo']);
    expect(find.text('Restored'), findsOneWidget);
    expect(p.changed, 2);
  });

  testWidgets('Undo fails: says where the item is', (tester) async {
    final p = _Probe()..failUndo = true;
    await _act(tester, p);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Restore failed'), findsOneWidget);
    expect(p.changed, 1);
  });

  testWidgets('Undo still works after leaving the screen', (tester) async {
    final p = _Probe();
    await _act(tester, p);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget); // back on the home screen
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Restored'), findsOneWidget);
  });

  testWidgets('the Undo snackbar goes away by itself', (tester) async {
    final p = _Probe();
    await _act(tester, p);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Moved'), findsNothing);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/core/help/undoable_action_test.dart`
Expected: FAIL — `undoable_action.dart` does not exist.

- [ ] **Step 4: Implement**

```dart
// lib/core/help/undoable_action.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Runs [run] now and reports the outcome in a snackbar; on success the
/// snackbar offers Undo, which runs [undo]. Four outcomes, four messages:
/// [done], [failed], [undone], [undoFailed] — never one message for several
/// states. [onChanged] (e.g. reload a list) runs only after a success.
///
/// The snackbar outlives the calling screen, so everything it needs is
/// captured before the first await; [undo] and [onChanged] must not use the
/// caller's WidgetRef or BuildContext (capture a ProviderContainer instead).
Future<void> showUndoableAction(
  BuildContext context, {
  required Future<void> Function() run,
  required Future<void> Function() undo,
  required String done,
  required String failed,
  required String undone,
  required String undoFailed,
  VoidCallback? onChanged,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final undoLabel = AppLocalizations.of(context).undoAction;

  void say(String text, {SnackBarAction? action}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: action,
        // Flutter keeps a snackbar with an action up until dismissed unless
        // told otherwise; Undo is a short window, not a dialog.
        persist: false,
        duration: const Duration(seconds: 5),
      ));
  }

  Future<void> runUndo() async {
    try {
      await undo();
    } catch (e, st) {
      debugPrint('undo failed: $e\n$st');
      say(undoFailed);
      return;
    }
    onChanged?.call();
    say(undone);
  }

  try {
    await run();
  } catch (e, st) {
    debugPrint('undoable action failed: $e\n$st');
    say(failed);
    return;
  }
  onChanged?.call();
  say(done,
      action: SnackBarAction(
          label: undoLabel, onPressed: () => unawaited(runUndo())));
}
```

- [ ] **Step 5: Run it to verify it passes**

Run: `flutter test test/core/help/undoable_action_test.dart`
Expected: all 6 PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/help/undoable_action.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/ test/core/help/undoable_action_test.dart
git commit -m "feat(help): undoable actions report each outcome honestly

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Vehicle notes screen — help and Detach with Undo

**Files:**
- Modify: `lib/features/notes/presentation/widgets/attached_notes_section.dart` (the three `IconButton`s, lines ~46–58 and ~79–88)
- Modify: `lib/features/automobile_records/presentation/screens/vehicle_notes_screen.dart:30` (AppBar)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, regenerated `lib/l10n/gen/*`
- Modify: `test/core/help/icon_button_guard_test.dart` (remove the `attached_notes_section.dart` entry)
- Test: `test/features/notes/presentation/widgets/attached_notes_section_test.dart`, `test/features/automobile_records/vehicle_notes_screen_test.dart`

**Interfaces:**
- Consumes: `HmmIconButton` (Task 1), `HelpButton`/`HelpId.vehicleNotes` (Task 3), `showUndoableAction` + `undo*` strings (Task 4), `mutateNoteProvider` / `MutateNote.detachNote(int)` / `MutateNote.setParent(int, int?)` (`lib/features/notes/states/mutate_note_state.dart`), `attachedNotesProvider` (`lib/features/notes/states/attached_notes_state.dart`).
- Produces: ARB keys `notesAttachExistingTooltip`, `notesAddTooltip`, `notesDetachTooltip`.

`AttachedNotesSection` is shared with `subsystem_notes_screen.dart`; the Undo text ("moved to General") is correct there too, because a detached note always returns to General.

- [ ] **Step 1: Add the tooltip strings**

`app_en.arb`, after `"undoNoteRestoreFailed"` (add a comma to it):

```json
  "notesAttachExistingTooltip": "Attach existing note",
  "notesAddTooltip": "Add note",
  "notesDetachTooltip": "Detach note"
```

`app_zh.arb`, after `"undoNoteRestoreFailed"` (add a comma to it):

```json
  "notesAttachExistingTooltip": "关联已有备注",
  "notesAddTooltip": "添加备注",
  "notesDetachTooltip": "取消关联备注"
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

In `test/features/notes/presentation/widgets/attached_notes_section_test.dart`, add this import at the top:

```dart
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
```

this class and helper above `main()`:

```dart
class _FakeMutate extends MutateNote {
  _FakeMutate(super.ref, {this.failDetach = false});
  final bool failDetach;
  final calls = <String>[];
  static final _n = HmmNote(
      id: 1, uuid: 'u1', subject: 'Oil change receipt', authorId: 1,
      catalogId: 1, createDate: DateTime(2026, 1, 1));

  @override
  Future<HmmNote> detachNote(int noteId) async {
    calls.add('detach $noteId');
    if (failDetach) throw StateError('offline');
    return _n;
  }

  @override
  Future<HmmNote> setParent(int noteId, int? parentNoteId) async {
    calls.add('parent $noteId -> $parentNoteId');
    return _n;
  }
}

Future<_FakeMutate> _pumpWithNote(WidgetTester tester,
    {bool failDetach = false}) async {
  late _FakeMutate fake;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      attachedNotesProvider(7).overrideWith((ref) async => [_FakeMutate._n]),
      mutateNoteProvider.overrideWith(
          (ref) => fake = _FakeMutate(ref, failDetach: failDetach)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AttachedNotesSection(parentId: 7)),
    ),
  ));
  await tester.pumpAndSettle();
  return fake;
}
```

and inside `main()`:

```dart
  testWidgets('buttons carry localized tooltips', (tester) async {
    await _pumpWithNote(tester);
    expect(find.byTooltip('Attach existing note'), findsOneWidget);
    expect(find.byTooltip('Add note'), findsOneWidget);
    expect(find.byTooltip('Detach note'), findsOneWidget);
  });

  testWidgets('Detach says where the note went and Undo puts it back',
      (tester) async {
    final fake = await _pumpWithNote(tester);
    await tester.tap(find.byTooltip('Detach note'));
    await tester.pumpAndSettle();
    expect(find.text('Note moved to General'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['detach 1', 'parent 1 -> 7']);
    expect(find.text('Note is back'), findsOneWidget);
  });

  testWidgets('a failed Detach says so and offers no Undo', (tester) async {
    await _pumpWithNote(tester, failDetach: true);
    await tester.tap(find.byTooltip('Detach note'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't detach the note"), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Oil change receipt'), findsOneWidget);
  });
```

Append to `test/features/automobile_records/vehicle_notes_screen_test.dart`, inside `main()`:

```dart
  testWidgets('? opens the car-notes help', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Car notes'), findsOneWidget);
    expect(find.textContaining('moves to General'), findsOneWidget);
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/notes/presentation/widgets/attached_notes_section_test.dart test/features/automobile_records/vehicle_notes_screen_test.dart`
Expected: the four new tests FAIL (tooltips are the old English strings; no Undo; no Help button). Existing tests PASS.

- [ ] **Step 4: Implement**

In `attached_notes_section.dart`, add imports:

```dart
import '../../../../core/help/undoable_action.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
```

Replace the header's two buttons:

```dart
              HmmIconButton(
                tooltip: l.notesAttachExistingTooltip,
                icon: Icons.attach_file,
                onPressed: () => _attachExisting(context, ref),
              ),
              if (showAdd)
                HmmIconButton(
                  tooltip: l.notesAddTooltip,
                  icon: Icons.add,
                  onPressed: () async {
                    await context.push('/notes/new?parent=$parentId');
                    ref.invalidate(attachedNotesProvider(parentId));
                  },
                ),
```

Replace the row's `trailing: IconButton(...)` with:

```dart
                        trailing: HmmIconButton(
                          tooltip: l.notesDetachTooltip,
                          icon: Icons.link_off,
                          onPressed: () {
                            // The Undo snackbar outlives this screen, so it
                            // holds the container, not this widget's ref.
                            final mutate = ref.read(mutateNoteProvider);
                            final container = ProviderScope.containerOf(
                                context,
                                listen: false);
                            showUndoableAction(
                              context,
                              run: () => mutate.detachNote(n.id),
                              undo: () => mutate.setParent(n.id, parentId),
                              done: l.undoNoteDetached,
                              failed: l.undoNoteDetachFailed,
                              undone: l.undoNoteRestored,
                              undoFailed: l.undoNoteRestoreFailed,
                              onChanged: () => container
                                  .invalidate(attachedNotesProvider(parentId)),
                            );
                          },
                        ),
```

In `vehicle_notes_screen.dart`, add `import '../../../../core/help/help_button.dart';` and `import '../../../../core/help/help_registry.dart';`, then change line 30 to:

```dart
      appBar: AppBar(
        title: Text(name ?? l.recordsVehicleNotes),
        actions: const [HelpButton(helpId: HelpId.vehicleNotes)],
      ),
```

In `test/core/help/icon_button_guard_test.dart`, delete the line
`'lib/features/notes/presentation/widgets/attached_notes_section.dart': 3,`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/notes test/features/automobile_records/vehicle_notes_screen_test.dart test/core/help`
Expected: all PASS (including `subsystem_screens_test.dart` and both guard tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/notes/presentation/widgets/attached_notes_section.dart lib/features/automobile_records/presentation/screens/vehicle_notes_screen.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/ test/core/help/icon_button_guard_test.dart test/features/notes/presentation/widgets/attached_notes_section_test.dart test/features/automobile_records/vehicle_notes_screen_test.dart
git commit -m "feat(notes): Detach explains itself with Undo; car notes get help

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Automobile hub — help and labelled buttons

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart` (actions ~line 38; `_VehicleRow` trailing ~154–172; `_NotesButton` ~180–198)
- Modify: `test/core/help/icon_button_guard_test.dart` (remove the hub entry)
- Test: `test/features/automobile_records/automobile_hub_screen_test.dart`

**Interfaces:**
- Consumes: `HmmIconButton`, `HmmIconButtonStyle.filledTonal` (Task 1); `HelpButton`, `HelpId.automobileHub` (Task 3).

- [ ] **Step 1: Write the failing test**

Append inside the group that holds the "notes button" tests in `automobile_hub_screen_test.dart`:

```dart
    testWidgets('? opens the Automobile help', (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip('Help'));
      await tester.pumpAndSettle();
      expect(find.text("Your driver's licence and your vehicles in one place."),
          findsOneWidget);
      expect(find.text('Gas log'), findsOneWidget);
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/automobile_records/automobile_hub_screen_test.dart`
Expected: the new test FAILS (no Help tooltip); the rest PASS.

- [ ] **Step 3: Implement**

Add imports:

```dart
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
```

In `CommonScreenScaffold(actions: [...])`, after the Manage `TextButton.icon`, add:

```dart
        const HelpButton(helpId: HelpId.automobileHub),
```

In `_VehicleRow`, replace the fuel `IconButton.filledTonal(...)` with:

```dart
          HmmIconButton(
            style: HmmIconButtonStyle.filledTonal,
            tooltip: l.automobileHubGasLogFor(automobile.displayName),
            icon: Icons.local_gas_station_outlined,
            onPressed: () {
              // The gas-log list reads the SELECTED vehicle, so select first.
              ref
                  .read(selectedAutomobileIdProvider.notifier)
                  .select(automobile.id);
              context.push('/gas-logs');
            },
          ),
```

Replace `_NotesButton.build`'s body with:

```dart
    final l = AppLocalizations.of(context);
    final count =
        ref.watch(attachedNotesProvider(automobile.id)).value?.length;
    return HmmIconButton(
      style: HmmIconButtonStyle.filledTonal,
      tooltip: l.automobileHubNotesFor(automobile.displayName),
      icon: Icons.sticky_note_2_outlined,
      badgeCount: count,
      onPressed: () =>
          context.push('/automobiles/manage/${automobile.id}/notes'),
    );
```

In `test/core/help/icon_button_guard_test.dart`, delete the line
`'lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart': 2,`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/automobile_records test/core/help`
Expected: all PASS — including the existing "notes button badges" and "no badge" tests, which now exercise `HmmIconButton.badgeCount`. If "A RenderFlex overflowed" appears in the app bar, do not shrink anything to hide it; report it, because it would crowd a real phone too.

- [ ] **Step 5: Commit**

```bash
git add lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart test/core/help/icon_button_guard_test.dart test/features/automobile_records/automobile_hub_screen_test.dart
git commit -m "feat(automobile): hub help sheet; row buttons via HmmIconButton

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Whole-suite check, project rules, device hand-off

**Files:**
- Modify: `CLAUDE.md` ("Key Packages", "Shared Rules", "Shared code" sections)
- Modify: `/Users/fchy/.claude/projects/-Users-fchy-Projects-hmm-console/memory/i18n-chinese-unreviewed.md` (append one line)

- [ ] **Step 1: Run everything**

Run: `flutter analyze && flutter test`
Expected: no new analyzer issues; all tests PASS. Fix anything this plan broke before continuing.

- [ ] **Step 2: Record the rules in CLAUDE.md**

Under `### Shared Rules`, replace the line
`- Always use flutter_platform_widgets for: buttons, switches, dialogs, text fields`
with:

```markdown
- Always use flutter_platform_widgets for: switches, dialogs, text fields (note: not currently a pubspec dependency — platform branching uses `Theme.of(context).platform`)
- **Icon buttons:** always `HmmIconButton` (`lib/core/widgets/hmm_icon_button.dart`) with a localized tooltip. `test/core/help/icon_button_guard_test.dart` fails on new raw `IconButton`s; its allow-list only shrinks.
- **Screen help:** every new screen adds a `HelpId` + case in `lib/core/help/help_registry.dart` and a `HelpButton` in its top bar. ARB keys: `help<Screen>Title`, `help<Screen>Summary`, `help<Screen><Control>Title` / `Body`; the entry's icon is the control's own `Icons.*` constant. Changing a control means updating its help entry.
- **Actions that move or hide data** use `showUndoableAction` (`lib/core/help/undoable_action.dart`): commits immediately, distinct messages for done / failed / undone / undo-failed, no WidgetRef or BuildContext after an await. Permanent deletes keep their confirmation dialog.
```

Under `## Key Packages`, change the `flutter_platform_widgets` bullet's first line to:
``- `flutter_platform_widgets`: use for dialogs, switches, text fields, nav bars — icon buttons use `HmmIconButton` instead (see Shared Rules)``

Add to the `### Shared code (lib/core/)` list:
``- `help/` — in-app help: `HelpButton` + help registry/sheet, `showUndoableAction`. Spec/plan: `docs/superpowers/specs/2026-09-27-in-app-help-design.md`, `docs/superpowers/plans/2026-09-27-in-app-help.md` ``

- [ ] **Step 3: Note the unreviewed Chinese**

Append to the memory file `i18n-chinese-unreviewed.md`:
`- 2026-09-27: in-app help added ~30 zh strings (help*, undo*, notes*Tooltip) — also unreviewed; they are UI-only, nothing persists them.`

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record the icon-button, screen-help and undo rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Hand off for the device check (the phase-2 exit criterion)**

Tell the user the phase is ready for their iPhone check, and give the deploy command (it needs their approval; do not run it):
`! /Users/fchy/Projects/Hmm/scripts/hmm-release.sh --target iphone --deploy --backup-first`
Checklist for them, in English then Chinese (Settings → language):
1. Automobile hub → "?" → sheet lists licence, vehicle, notes, gas log, manage.
2. Long-press the notes and fuel buttons → labels appear.
3. A car's notes → "?" → Detach is explained.
4. Detach a note → "Note moved to General" + Undo → Undo → note is back.
5. Detach again, wait ~5 s → snackbar leaves on its own; the note is in General in the notes list.

---

## Phases 3–4 (follow-up plans, not in scope here)

- **Phase 3 checklist:** convert each file left in the guard allow-list to `HmmIconButton` with localized tooltips, one feature per commit, deleting its allow-list line.
- **Phase 4 checklist:** `HelpId` + help for gas log list, service records, insurance policies, scheduled services, settings (data mode), then the rest.
- **Undo candidates:** archiving a vehicle; deleting a synced gas log.
