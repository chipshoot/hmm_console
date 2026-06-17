# UI Design-System Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an Apple Mail-style design-system foundation (semantic tokens, blue theme, canonical widgets) and migrate the notes feature onto it as the reference.

**Architecture:** One tuned `MaterialApp`/GoRouter tree. A semantic token layer (`AppColors` ThemeExtension + type scale) feeds a blue `ColorScheme` (light+dark) and a small set of canonical widgets (`AppScaffold`, `AppListSection`, `AppListRow`, `AppEmptyState`) that branch chrome by platform. Notes screens adopt these; no data-layer changes.

**Tech Stack:** Flutter, Dart, Riverpod, flutter_platform_widgets, flutter_slidable, flutter_test (widget + golden tests).

**Spec:** `docs/superpowers/specs/2026-06-14-ui-design-system-layer-design.md`

**Deviations from spec (intentional, discovered during planning):**
- The spec's "notes shell bottom-nav swaps to MD3 NavigationBar" does **not** apply: the notes feature has no bottom nav (the tab bar is the app-level shell, out of scope). The notes shell is a list/detail split that already exists; we preserve it and restyle the panes.
- `CommonScreenScaffold` is marked `@Deprecated` pointing to `AppScaffold` but keeps its current Material implementation (NOT a behavioral delegate), so un-migrated screens are not visually changed by this work.

---

## File Structure

**Create:**
- `lib/core/theme/app_colors.dart` — `AppColors` ThemeExtension (light/dark semantic colors) + `context.appColors` accessor.
- `lib/core/widgets/app_list_row.dart` — 3-tier list row.
- `lib/core/widgets/app_list_section.dart` — grouped container with inset hairline separators.
- `lib/core/widgets/app_scaffold.dart` — platform-adaptive large-title scaffold.
- `lib/core/widgets/app_empty_state.dart` — centered glyph + message + optional action.
- `lib/features/notes/presentation/util/note_preview.dart` — `notePreview(content)` helper.
- Test files mirrored under `test/...` (one per unit) + golden baselines under `test/core/widgets/goldens/`.

**Modify:**
- `lib/core/theme/design_tokens.dart` — add semantic type-scale `TextStyle`s.
- `lib/core/theme/theme.dart` — blue seed (light+dark), `TextTheme`, register `AppColors`, `CupertinoThemeData`.
- `lib/core/widgets/gaps.dart` — add `h12`, `w4`, `w12`.
- `lib/core/widgets/screen_scaffold.dart` — `@Deprecated` annotation only.
- `lib/features/notes/presentation/widgets/note_list_tile.dart` — wrap `AppListRow` + `notePreview`.
- `lib/features/notes/presentation/screens/notes_list_screen.dart`, `note_detail_screen.dart`, `subsystem_notes_screen.dart`, `subsystems_screen.dart`, `note_editor_screen.dart` — adopt `AppScaffold`/`AppListSection`/`AppEmptyState`.

---

## Task 1: AppColors ThemeExtension + semantic type scale

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Test: `test/core/theme/app_colors_test.dart`
- Modify: `lib/core/theme/design_tokens.dart`
- Modify: `lib/core/widgets/gaps.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/theme/app_colors_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';

void main() {
  test('light and dark differ on label + background, share accent', () {
    expect(AppColors.light.label, const Color(0xFF1C1C1E));
    expect(AppColors.dark.label, const Color(0xFFFFFFFF));
    expect(AppColors.light.groupedBackground, const Color(0xFFF2F2F7));
    expect(AppColors.dark.groupedBackground, const Color(0xFF000000));
    expect(AppColors.light.accent, AppColors.dark.accent);
    expect(AppColors.light.accent, const Color(0xFF0A84FF));
  });

  test('lerp at t=0 returns this, t=1 returns other', () {
    final mid = AppColors.light.lerp(AppColors.dark, 1.0);
    expect(mid.label, AppColors.dark.label);
    final start = AppColors.light.lerp(AppColors.dark, 0.0);
    expect(start.label, AppColors.light.label);
  });

  testWidgets('context.appColors resolves the registered extension', (t) async {
    late AppColors resolved;
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Builder(builder: (c) {
        resolved = c.appColors;
        return const SizedBox();
      }),
    ));
    expect(resolved.label, AppColors.light.label);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_colors_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'app_colors.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// Semantic, brightness-adaptive colors for text hierarchy, separators, and
/// the grouped background. Resolved via `Theme.of(context).extension<AppColors>()`
/// (or the `context.appColors` shortcut). Values mirror the iOS system palette.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.groupedBackground,
    required this.accent,
  });

  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color groupedBackground;
  final Color accent;

  static const AppColors light = AppColors(
    label: Color(0xFF1C1C1E),
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFFAEAEB2),
    separator: Color(0xFFE5E5EA),
    groupedBackground: Color(0xFFF2F2F7),
    accent: Color(0xFF0A84FF),
  );

  static const AppColors dark = AppColors(
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFF636366),
    separator: Color(0xFF38383A),
    groupedBackground: Color(0xFF000000),
    accent: Color(0xFF0A84FF),
  );

  @override
  AppColors copyWith({
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? separator,
    Color? groupedBackground,
    Color? accent,
  }) {
    return AppColors(
      label: label ?? this.label,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
      separator: separator ?? this.separator,
      groupedBackground: groupedBackground ?? this.groupedBackground,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      groupedBackground:
          Color.lerp(groupedBackground, other.groupedBackground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  /// Shortcut for the registered [AppColors] extension. Asserts it is present.
  AppColors get appColors {
    final c = Theme.of(this).extension<AppColors>();
    assert(c != null, 'AppColors extension not registered on the theme');
    return c ?? AppColors.light;
  }
}
```

- [ ] **Step 4: Add semantic type scale to design_tokens.dart**

In `lib/core/theme/design_tokens.dart`, add inside the `DesignTokens` class (after the existing Font Weights block):

```dart
  // ---------------------------------------------------------------------------
  // Semantic Type Scale (color applied at use site via AppColors)
  // ---------------------------------------------------------------------------
  static const TextStyle titleLarge =
      TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const TextStyle rowTitle =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25);
  static const TextStyle rowPrimary =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle rowSecondary =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.3);
  static const TextStyle caption =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
```

- [ ] **Step 5: Add missing gaps to gaps.dart**

In `lib/core/widgets/gaps.dart`, add inside `GapWidgets`:

```dart
  static const h12 = SizedBox(height: 12.0);
  static const w4 = SizedBox(width: 4.0);
  static const w12 = SizedBox(width: 12.0);
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/theme/app_colors_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_colors.dart test/core/theme/app_colors_test.dart \
        lib/core/theme/design_tokens.dart lib/core/widgets/gaps.dart
git commit -m "feat(theme): add AppColors extension, semantic type scale, missing gaps"
```

---

## Task 2: Wire the blue theme

**Files:**
- Modify: `lib/core/theme/theme.dart`
- Test: `test/core/theme/theme_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/theme/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/theme/theme.dart';

void main() {
  test('light theme registers AppColors.light and a blue scheme', () {
    final t = AppTheme.lightThemeData;
    expect(t.extension<AppColors>(), isNotNull);
    expect(t.extension<AppColors>()!.label, AppColors.light.label);
    // Seeded from system blue → primary lands in the blue hue range.
    expect(t.colorScheme.brightness, Brightness.light);
  });

  test('dark theme registers AppColors.dark (not the old green seed)', () {
    final t = AppTheme.darkThemeData;
    expect(t.extension<AppColors>()!.label, AppColors.dark.label);
    expect(t.colorScheme.brightness, Brightness.dark);
  });

  test('text theme carries the row title size', () {
    final t = AppTheme.lightThemeData;
    expect(t.textTheme.titleMedium?.fontSize, 16);
    expect(t.textTheme.titleMedium?.fontWeight, FontWeight.w600);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/theme_test.dart`
Expected: FAIL — `extension<AppColors>()` is null (not yet registered).

- [ ] **Step 3: Replace theme.dart**

Replace the entire contents of `lib/core/theme/theme.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'design_tokens.dart';

class AppTheme {
  static const Color _seed = Color(0xFF0A84FF); // iOS system blue

  static bool get _isApplePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static TextTheme _textTheme(AppColors c) => TextTheme(
        titleLarge: DesignTokens.titleLarge.copyWith(color: c.label),
        titleMedium: DesignTokens.rowTitle.copyWith(color: c.label),
        bodyLarge: DesignTokens.rowPrimary.copyWith(color: c.label),
        bodyMedium: DesignTokens.rowSecondary.copyWith(color: c.secondaryLabel),
        bodySmall: DesignTokens.caption.copyWith(color: c.tertiaryLabel),
      );

  static ThemeData _build(Brightness brightness, AppColors c) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
      extensions: [c],
      textTheme: _textTheme(c),
      scaffoldBackgroundColor: c.groupedBackground,
      appBarTheme: AppBarTheme(
        centerTitle: _isApplePlatform,
        elevation: _isApplePlatform ? 0 : null,
        scrolledUnderElevation: _isApplePlatform ? 0.5 : null,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(primaryColor: _seed),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightThemeData =>
      _build(Brightness.light, AppColors.light);

  static ThemeData get darkThemeData =>
      _build(Brightness.dark, AppColors.dark);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/theme_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Verify the app still compiles**

Run: `flutter analyze lib/core/theme/`
Expected: No errors (warnings about deprecated legacy color constants are acceptable).

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/theme.dart test/core/theme/theme_test.dart
git commit -m "feat(theme): blue ColorScheme (light+dark), TextTheme, Cupertino accent"
```

---

## Task 3: notePreview helper

**Files:**
- Create: `lib/features/notes/presentation/util/note_preview.dart`
- Test: `test/features/notes/presentation/util/note_preview_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notes/presentation/util/note_preview_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/util/note_preview.dart';

void main() {
  test('null and empty content yield empty string', () {
    expect(notePreview(null), '');
    expect(notePreview(''), '');
    expect(notePreview('   \n  \n'), '');
  });

  test('returns first non-blank line', () {
    expect(notePreview('\n\nHello world\nsecond'), 'Hello world');
  });

  test('strips common markdown markers', () {
    expect(notePreview('# Heading'), 'Heading');
    expect(notePreview('- bullet item'), 'bullet item');
    expect(notePreview('> quote'), 'quote');
    expect(notePreview('**bold** text'), 'bold text');
    expect(notePreview('`code` snippet'), 'code snippet');
  });

  test('JSON domain payload yields empty (not human text)', () {
    expect(notePreview('{"make":"Toyota","model":"Camry"}'), '');
    expect(notePreview('[1,2,3]'), '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/util/note_preview_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/notes/presentation/util/note_preview.dart`:

```dart
/// Extracts a one-line human-readable preview from a note's content.
///
/// Returns the first non-blank line with common Markdown markers stripped.
/// Domain notes store a JSON blob in `content`; those are not human text, so a
/// payload that starts with `{` or `[` yields an empty string (the row then
/// shows only its title + secondary metadata).
String notePreview(String? content) {
  if (content == null) return '';
  final trimmed = content.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return '';

  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    return _stripMarkdown(line);
  }
  return '';
}

String _stripMarkdown(String line) {
  var s = line;
  // Leading block markers: heading #, blockquote >, list bullets -, *, +.
  s = s.replaceFirst(RegExp(r'^\s*(#{1,6}|>|[-*+])\s+'), '');
  // Inline emphasis/code markers.
  s = s.replaceAll(RegExp(r'[*_`]'), '');
  return s.trim();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/util/note_preview_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/util/note_preview.dart \
        test/features/notes/presentation/util/note_preview_test.dart
git commit -m "feat(notes): notePreview helper (first line, markdown-stripped, JSON-aware)"
```

---

## Task 4: AppListRow

**Files:**
- Create: `lib/core/widgets/app_list_row.dart`
- Test: `test/core/widgets/app_list_row_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/app_list_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_list_row.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders title, primary, secondary, trailing', (t) async {
    await t.pumpWidget(_host(const AppListRow(
      leading: CircleAvatar(radius: 6),
      title: Text('Toyota Camry'),
      primary: Text('Insurance renewal due June 30'),
      secondary: Text('Automobile'),
      trailing: Text('9:41 AM'),
    )));
    expect(find.text('Toyota Camry'), findsOneWidget);
    expect(find.text('Insurance renewal due June 30'), findsOneWidget);
    expect(find.text('Automobile'), findsOneWidget);
    expect(find.text('9:41 AM'), findsOneWidget);
  });

  testWidgets('tap fires onTap callback', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(AppListRow(
      title: const Text('Row'),
      onTap: () => tapped = true,
    )));
    await t.tap(find.text('Row'));
    expect(tapped, isTrue);
  });

  testWidgets('omitted optional slots are absent', (t) async {
    await t.pumpWidget(_host(const AppListRow(title: Text('Only title'))));
    expect(find.text('Only title'), findsOneWidget);
    // No crash, no extra text widgets beyond the title.
    expect(find.byType(Text), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/app_list_row_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/widgets/app_list_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Inset (logical px) from the row's leading edge to where text starts when a
/// [AppListRow.leading] is present. [AppListSection] uses this to align its
/// separators under the text, Apple-Mail style.
const double kRowInsetWithLeading = 52.0;

/// Text inset when there is no leading widget.
const double kRowInsetNoLeading = 16.0;

/// A 3-tier list row: leading slot, a bold title, an optional bold primary
/// content line, an optional muted secondary line, and an optional trailing
/// widget (e.g. a timestamp). Direction-aware so it mirrors correctly in RTL.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    this.leading,
    required this.title,
    this.primary,
    this.secondary,
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? primary;
  final Widget? secondary;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    Widget styled(Widget child, TextStyle style) => DefaultTextStyle.merge(
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: child,
        );

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2, end: 12),
            child: SizedBox(
              width: 24,
              child: Align(alignment: AlignmentDirectional.topStart, child: leading),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: styled(title, DesignTokens.rowTitle.copyWith(color: c.label)),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    styled(trailing!, DesignTokens.caption.copyWith(color: c.tertiaryLabel)),
                  ],
                ],
              ),
              if (primary != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: styled(primary!, DesignTokens.rowPrimary.copyWith(color: c.label)),
                ),
              if (secondary != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: styled(
                      secondary!, DesignTokens.rowSecondary.copyWith(color: c.secondaryLabel)),
                ),
            ],
          ),
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 11),
            child: content,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/app_list_row_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/app_list_row.dart test/core/widgets/app_list_row_test.dart
git commit -m "feat(widgets): AppListRow 3-tier row (direction-aware, haptic tap)"
```

---

## Task 5: AppListSection

**Files:**
- Create: `lib/core/widgets/app_list_section.dart`
- Test: `test/core/widgets/app_list_section_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/app_list_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_list_section.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('N rows produce N-1 separators (none after the last)', (t) async {
    await t.pumpWidget(_host(const AppListSection(
      children: [
        Text('a'),
        Text('b'),
        Text('c'),
      ],
    )));
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('single row has no separators', (t) async {
    await t.pumpWidget(_host(const AppListSection(children: [Text('only')])));
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('header label renders when provided', (t) async {
    await t.pumpWidget(_host(const AppListSection(
      header: 'RECENT',
      children: [Text('row')],
    )));
    expect(find.text('RECENT'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/app_list_section_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/widgets/app_list_section.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'app_list_row.dart';

/// A grouped list section, Apple-Mail style: an optional uppercase header label
/// followed by [children] separated by hairline dividers inset to align under
/// the row text. No divider after the last child.
class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    this.header,
    required this.children,
    this.separatorIndent = kRowInsetWithLeading,
  });

  final String? header;
  final List<Widget> children;

  /// Start inset for the dividers. Defaults to the leading-aware row inset so
  /// separators line up under the text. Pass [kRowInsetNoLeading] for rows
  /// without a leading widget.
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Divider(
          height: 1,
          thickness: 0.5,
          indent: separatorIndent,
          color: c.separator,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 6),
            child: Text(
              header!.toUpperCase(),
              style: DesignTokens.caption.copyWith(
                color: c.secondaryLabel,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ...rows,
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/app_list_section_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/app_list_section.dart test/core/widgets/app_list_section_test.dart
git commit -m "feat(widgets): AppListSection grouped container with inset separators"
```

---

## Task 6: AppScaffold (platform-adaptive)

**Files:**
- Create: `lib/core/widgets/app_scaffold.dart`
- Test: `test/core/widgets/app_scaffold_test.dart`
- Modify: `lib/core/widgets/screen_scaffold.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/app_scaffold_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_scaffold.dart';

Widget _host(TargetPlatform platform) => MaterialApp(
      theme: ThemeData(platform: platform, extensions: const [AppColors.light]),
      home: const AppScaffold(
        title: 'Notes',
        slivers: [
          SliverToBoxAdapter(child: Text('body')),
        ],
      ),
    );

void main() {
  testWidgets('iOS uses the Cupertino large-title nav bar', (t) async {
    await t.pumpWidget(_host(TargetPlatform.iOS));
    expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('Android uses the MD3 SliverAppBar', (t) async {
    await t.pumpWidget(_host(TargetPlatform.android));
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/app_scaffold_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/widgets/app_scaffold.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Platform-adaptive scaffold with a large title. iOS/macOS get a
/// [CupertinoSliverNavigationBar] (collapsing large title); Android gets an
/// MD3 [SliverAppBar.large]. Body is supplied as [slivers].
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.backgroundColor,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  bool _isApple(TargetPlatform p) =>
      p == TargetPlatform.iOS || p == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final bg = backgroundColor ?? context.appColors.groupedBackground;

    final Widget navBar = _isApple(platform)
        ? CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            leading: leading,
            trailing: actions == null
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions!),
            backgroundColor: bg,
            border: null,
          )
        : SliverAppBar.large(
            title: Text(title),
            leading: leading,
            actions: actions,
            pinned: true,
          );

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(slivers: [navBar, ...slivers]),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/app_scaffold_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Deprecate CommonScreenScaffold**

In `lib/core/widgets/screen_scaffold.dart`, add the annotation directly above the class declaration (leave the implementation unchanged so un-migrated screens are unaffected):

```dart
@Deprecated(
  'Use AppScaffold (lib/core/widgets/app_scaffold.dart) for new/migrated '
  'screens. Kept for un-migrated screens only.',
)
class CommonScreenScaffold extends StatelessWidget {
```

- [ ] **Step 6: Verify analyzer (self-deprecation warnings expected only at call sites)**

Run: `flutter test test/core/widgets/app_scaffold_test.dart && flutter analyze lib/core/widgets/`
Expected: tests PASS; analyze reports only `deprecated_member_use` infos at existing `CommonScreenScaffold` call sites (acceptable — those screens migrate later).

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/app_scaffold.dart test/core/widgets/app_scaffold_test.dart \
        lib/core/widgets/screen_scaffold.dart
git commit -m "feat(widgets): AppScaffold platform-adaptive large title; deprecate CommonScreenScaffold"
```

---

## Task 7: AppEmptyState

**Files:**
- Create: `lib/core/widgets/app_empty_state.dart`
- Test: `test/core/widgets/app_empty_state_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/widgets/app_empty_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_empty_state.dart';

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders icon and message', (t) async {
    await t.pumpWidget(_host(const AppEmptyState(
      icon: Icons.note_outlined,
      message: 'No notes yet',
    )));
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.byIcon(Icons.note_outlined), findsOneWidget);
  });

  testWidgets('action button fires when provided', (t) async {
    var pressed = false;
    await t.pumpWidget(_host(AppEmptyState(
      icon: Icons.note_outlined,
      message: 'No notes yet',
      actionLabel: 'Add note',
      onAction: () => pressed = true,
    )));
    await t.tap(find.text('Add note'));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/app_empty_state_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/widgets/app_empty_state.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Centered empty/placeholder state: a muted glyph, one line of muted text, and
/// an optional action button. Used for empty lists and feature placeholders.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.tertiaryLabel),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DesignTokens.rowSecondary.copyWith(color: c.secondaryLabel),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/app_empty_state_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/app_empty_state.dart test/core/widgets/app_empty_state_test.dart
git commit -m "feat(widgets): AppEmptyState centered glyph + message + optional action"
```

---

## Task 8: Golden tests for AppListRow + AppListSection

**Files:**
- Create: `test/core/widgets/goldens_test.dart`
- Create (generated): `test/core/widgets/goldens/*.png`

- [ ] **Step 1: Write the golden test**

Create `test/core/widgets/goldens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/theme/theme.dart';
import 'package:hmm_console/core/widgets/app_list_row.dart';
import 'package:hmm_console/core/widgets/app_list_section.dart';

Widget _sampleSection() => AppListSection(
      children: const [
        AppListRow(
          leading: CircleAvatar(radius: 6, backgroundColor: Color(0xFFFF9F0A)),
          title: Text('Toyota Camry'),
          primary: Text('Insurance renewal due June 30'),
          secondary: Text('Automobile · Intact #4471'),
          trailing: Text('9:41 AM'),
        ),
        AppListRow(
          leading: CircleAvatar(radius: 6, backgroundColor: Color(0xFF34C759)),
          title: Text('Costco gas'),
          primary: Text(r'$1.42 / L · 48.2 L'),
          secondary: Text('Gas Log · 84,210 km'),
          trailing: Text('Yesterday'),
        ),
      ],
    );

Future<void> _pump(WidgetTester t, ThemeData theme) async {
  await t.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(
      backgroundColor: theme.extension<AppColors>()!.groupedBackground,
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 390, child: _sampleSection()),
      ),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('AppListSection light golden', (t) async {
    await _pump(t, AppTheme.lightThemeData);
    await expectLater(
      find.byType(AppListSection),
      matchesGoldenFile('goldens/app_list_section_light.png'),
    );
  });

  testWidgets('AppListSection dark golden', (t) async {
    await _pump(t, AppTheme.darkThemeData);
    await expectLater(
      find.byType(AppListSection),
      matchesGoldenFile('goldens/app_list_section_dark.png'),
    );
  });
}
```

- [ ] **Step 2: Generate the golden baselines**

Run: `flutter test --update-goldens test/core/widgets/goldens_test.dart`
Expected: PASS; two PNGs created under `test/core/widgets/goldens/`.

- [ ] **Step 3: Verify goldens match on a normal run**

Run: `flutter test test/core/widgets/goldens_test.dart`
Expected: PASS (2 tests) comparing against the committed baselines.

- [ ] **Step 4: Commit (including the PNG baselines)**

```bash
git add test/core/widgets/goldens_test.dart test/core/widgets/goldens/
git commit -m "test(widgets): golden baselines for AppListSection (light + dark)"
```

---

## Task 9: Migrate NoteListTile onto AppListRow

**Files:**
- Modify: `lib/features/notes/presentation/widgets/note_list_tile.dart`
- Test: `test/features/notes/presentation/widgets/note_list_tile_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notes/presentation/widgets/note_list_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/core/widgets/app_list_row.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_list_tile.dart';

HmmNote _note({String? content}) => HmmNote(
      id: 1,
      uuid: 'u1',
      subject: 'Grocery list',
      authorId: 1,
      createDate: DateTime(2026, 6, 1),
      content: content,
    );

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders subject as title and content preview as primary',
      (t) async {
    await t.pumpWidget(_host(NoteListTile(
      note: _note(content: 'Milk, eggs, coffee'),
    )));
    expect(find.byType(AppListRow), findsOneWidget);
    expect(find.text('Grocery list'), findsOneWidget);
    expect(find.text('Milk, eggs, coffee'), findsOneWidget);
  });

  testWidgets('JSON content shows no primary preview line', (t) async {
    await t.pumpWidget(_host(NoteListTile(
      note: _note(content: '{"make":"Toyota"}'),
    )));
    expect(find.text('{"make":"Toyota"}'), findsNothing);
    expect(find.text('Grocery list'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(NoteListTile(
      note: _note(content: 'hi'),
      onTap: () => tapped = true,
    )));
    await t.tap(find.byType(AppListRow));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/widgets/note_list_tile_test.dart`
Expected: FAIL — `NoteListTile` still renders a `ListTile`, not `AppListRow`.

- [ ] **Step 3: Rewrite note_list_tile.dart**

Replace the contents of `lib/features/notes/presentation/widgets/note_list_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/data/local/database.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../../../core/widgets/app_list_row.dart';
import '../../data/models/hmm_note.dart';
import '../util/note_preview.dart';

/// A single note row. Fills [AppListRow]: catalog dot leading, subject title,
/// first content line as the bold primary line, and `catalog · date` secondary.
class NoteListTile extends StatelessWidget {
  const NoteListTile({super.key, required this.note, this.catalog, this.onTap});

  final HmmNote note;
  final NoteCatalog? catalog;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = CatalogPalette.styleFor(catalog?.name);
    final preview = notePreview(note.content);
    final date = note.createDate.toLocal().toString().split(' ').first;

    return AppListRow(
      onTap: onTap,
      leading: Container(
        width: 11,
        height: 11,
        margin: const EdgeInsetsDirectional.only(top: 4),
        decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      ),
      title: Text(note.subject),
      primary: preview.isEmpty ? null : Text(preview),
      secondary: Text('${style.displayName} · $date'),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/widgets/note_list_tile_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/widgets/note_list_tile.dart \
        test/features/notes/presentation/widgets/note_list_tile_test.dart
git commit -m "feat(notes): NoteListTile uses AppListRow + content preview"
```

---

## Task 10: Migrate the notes list screen onto AppScaffold + AppEmptyState

**Files:**
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`

> The screen keeps its existing providers, search field, chips, sort/filter sheets, FAB, and wide-mode selection behavior. Only the scaffold/chrome and the empty state change: `Scaffold`+`AppBar` → `AppScaffold` with the body as slivers, and the "No notes" centered text → `AppEmptyState`.

- [ ] **Step 1: Replace the build method's scaffold**

In `lib/features/notes/presentation/screens/notes_list_screen.dart`, change the import block to add:

```dart
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold.dart';
```

Replace the `return Scaffold(...)` (the outer widget returned from `build`, lines ~24-128) with:

```dart
    return AppScaffold(
      title: 'Notes',
      actions: [
        IconButton(
          tooltip: 'Sort',
          icon: const Icon(Icons.swap_vert),
          onPressed: async.hasValue
              ? () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => SortSheet(
                      current: async.value!.sort,
                      onSelected: notifier.setSort,
                    ),
                  )
              : null,
        ),
        IconButton(
          tooltip: 'Filter',
          icon: const Icon(Icons.filter_list),
          onPressed: async.hasValue
              ? () {
                  final data = async.value!;
                  final usage = ref.read(filterUsageProvider).value ?? const {};
                  final groups = groupByDomain(
                      data.catalogsById.values, data.countsByCatalog, usage);
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => CatalogFilterSheet(
                      groups: groups,
                      counts: data.countsByCatalog,
                      selected: data.catalogFilter,
                      onApply: notifier.setFilter,
                      onRecordDomain: (key) =>
                          ref.read(filterUsageProvider.notifier).record(key),
                    ),
                  );
                }
              : null,
        ),
        IconButton(
          tooltip: 'Subsystems',
          icon: const Icon(Icons.widgets_outlined),
          onPressed: () => context.push('/notes/subsystems'),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/notes/new'),
        child: const Icon(Icons.add),
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load notes: $e')),
            data: (data) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search subjects',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: notifier.setQuery,
                    ),
                  ),
                  _Chips(data: data),
                  Expanded(
                    child: data.visible.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.note_outlined,
                            message: 'No notes yet',
                          )
                        : ListView.builder(
                            itemCount: data.visible.length,
                            itemBuilder: (context, i) {
                              final note = data.visible[i];
                              return NoteListTile(
                                note: note,
                                catalog: note.catalogId == null
                                    ? null
                                    : data.catalogsById[note.catalogId],
                                onTap: () {
                                  final isWide = MediaQuery.of(context).size.width >=
                                      kNotesWideBreakpoint;
                                  if (isWide) {
                                    ref
                                        .read(selectedNoteIdProvider.notifier)
                                        .select(note.id);
                                  } else {
                                    context.push('/notes/${note.id}');
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
```

- [ ] **Step 2: Run the existing notes screen tests + analyze**

Run: `flutter test test/features/notes/ && flutter analyze lib/features/notes/presentation/screens/notes_list_screen.dart`
Expected: tests PASS; analyze clean (no errors).

- [ ] **Step 3: Commit**

```bash
git add lib/features/notes/presentation/screens/notes_list_screen.dart
git commit -m "feat(notes): notes list on AppScaffold + AppEmptyState"
```

---

## Task 11: Migrate remaining notes screens onto AppScaffold

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart`
- Modify: `lib/features/notes/presentation/screens/subsystem_notes_screen.dart`
- Modify: `lib/features/notes/presentation/screens/subsystems_screen.dart`
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`

> For each screen: read its current build, replace its top-level `Scaffold`+`AppBar` with `AppScaffold` (body wrapped as a single `SliverFillRemaining(hasScrollBody: true, child: <existing body>)`, or as `SliverList`/`SliverToBoxAdapter` if the body is already a list). Replace any bare empty/placeholder `Center(child: Text(...))` with `AppEmptyState`. Preserve all providers, actions, and form behavior. Do NOT touch `notes_shell_screen.dart` — its list/detail split stays as-is and simply renders the now-restyled panes.

- [ ] **Step 1: Read each screen and migrate it**

For each of the four files, read it first:

Run: `flutter test test/features/notes/` (baseline — note which pass before changes)

Then for each screen apply the pattern. Example for a simple list screen (`subsystems_screen.dart`) — wrap the existing scrollable body. If the screen currently returns:

```dart
return Scaffold(appBar: AppBar(title: const Text('Subsystems')), body: <body>);
```

change it to:

```dart
return AppScaffold(
  title: 'Subsystems',
  slivers: [
    SliverFillRemaining(hasScrollBody: true, child: <body>),
  ],
);
```

adding `import '../../../../core/widgets/app_scaffold.dart';` (and `app_empty_state.dart` where an empty state is introduced). Apply the equivalent change to `note_detail_screen.dart`, `subsystem_notes_screen.dart`, and `note_editor_screen.dart`, keeping their `actions`/form widgets intact.

- [ ] **Step 2: Run notes tests + analyze after each file**

Run: `flutter test test/features/notes/ && flutter analyze lib/features/notes/`
Expected: PASS; analyze reports no errors (deprecation infos for any remaining `CommonScreenScaffold` usage elsewhere are acceptable).

- [ ] **Step 3: Commit**

```bash
git add lib/features/notes/presentation/screens/
git commit -m "feat(notes): migrate detail/editor/subsystems screens onto AppScaffold"
```

---

## Task 12: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Analyze the whole project**

Run: `flutter analyze`
Expected: No errors. Acceptable: `deprecated_member_use` infos at `CommonScreenScaffold` call sites in non-notes features, and `deprecated_member_use` for the legacy `DesignTokens.textPrimary/Secondary/Tertiary` constants if still referenced.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS, including the new theme/widget/golden/notes tests and all pre-existing tests.

- [ ] **Step 3: Run on the iOS simulator and eyeball the notes feature**

Run: `flutter run` (per CLAUDE.md, iOS on macOS). Manually verify on the Notes tab:
- Large "Notes" title collapses on scroll (Cupertino nav bar).
- Rows show catalog dot + bold subject + preview line + `catalog · date`, with hairline separators inset under the text.
- Toggle the simulator to dark mode (Settings → Developer → Dark Appearance): background and text invert to the iOS dark palette, accent stays blue (NOT green).
- Empty/placeholder state shows the muted glyph + message.

Expected: Notes feature looks Apple-Mail-like; no overflow/RTL/contrast regressions.

- [ ] **Step 4: Final commit (if any manual fixes were needed)**

```bash
git add -A
git commit -m "fix(notes): polish pass from on-device verification"
```

---

## Self-Review Notes

- **Spec coverage:** tokens+gaps (T1), theme/TextTheme/Cupertino (T2), notePreview (T3), AppListRow (T4), AppListSection (T5), AppScaffold + deprecate shim (T6), AppEmptyState (T7), goldens light+dark (T8), notes migration (T9–T11), verification incl. dark-mode + RTL discipline baked into AppListRow/AppListSection (T12). Theming-readiness and localization-independence are documented disciplines (no const colors/styles in widgets; `EdgeInsetsDirectional` everywhere) — satisfied by the widget code in T4/T5/T7/T9.
- **Skeleton:** deliberately omitted (optional/stretch per spec).
- **Type consistency:** `AppColors` fields, `DesignTokens.row*`/`titleLarge`/`caption`, `kRowInsetWithLeading`, `notePreview`, `AppListRow`/`AppListSection`/`AppScaffold`/`AppEmptyState` signatures are used identically across tasks.
```
