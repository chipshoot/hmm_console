# Cheatsheet Card Look Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every cheatsheet card its own look (theme, pattern, emoji icon, optional cover photo, Facts / Key points layout) stored as an optional `style` block in the card JSON, rendered as wallet tiles and a detail header, edited in a designer "Look" section, and carried through the Cloud API by a server pass-through.

**Architecture:** A pure `CardStyle` value wraps the raw `style` map (so unknown values and keys survive verbatim) and resolves against a per-template defaults table; the codec gains `style`, row `emoji` and top-level/row unknown-key preservation, and the cover is a `VaultRef` in the card note's `attachments` column with only its path in content (the driver-licence pattern). One `CardSurface` widget draws theme + pattern or cover + scrim for both the wallet tile and the detail header, and the designer edits the look through `CheatsheetEditor` plus a small cover-draft provider that `CheatsheetsState` persists. The Hmm backend maps `Style` ⇄ note `style` and `Emoji` ⇄ row `emoji` verbatim.

**Tech Stack:** Flutter 3.41.9, Dart `^3.11.0`, Riverpod 3 (`flutter_riverpod ^3.0.3`), Drift (in-memory `NativeDatabase.memory()` in tests), gen-l10n (`lib/l10n/app_en.arb` template + `app_zh.arb`, generated into the committed `lib/l10n/gen/`); backend .NET 10, xUnit, AutoMapper, Newtonsoft.Json (API wire) + System.Text.Json (note content), Moq.

**Spec:** docs/superpowers/specs/2026-10-11-cheatsheet-card-look-design.md

## Global Constraints

- Cards are a semantic definition rendered natively — **never stored HTML** (cheatsheet spec 2026-07-23 § Rendering). No web view, no CSS, no markup in `style`.
- `style` (and each of its keys) is written **only when it differs from the template default**; `pattern: none`, the template theme/icon/layout and an absent cover are never stored. A row `emoji` is written only when set.
- A card opened and saved without edits is written back **byte-identical** (canonical key order: `schemaVersion, id, title, walletGroup, tags, templateId, protected, rows, style, <unknown keys>`; rows: `label, valueAction, openSource, source, emoji, <unknown keys>`).
- Unknown values (a newer theme/pattern/layout, a non-emoji icon, unknown keys inside `style`, unknown top-level and row keys) render as the default and are **preserved raw** until the user changes that field.
- The cover is a `VaultRef` in the **card note's `attachments` column** (the only column `VaultGc` reads); content holds only its path at `style.cover`. Replace, remove, reset and delete release it.
- Every theme's title and subtitle colours meet **WCAG AA (≥ 4.5:1)** against its light **and** dark background, including the background with the pattern ink composited over it, and for the cover header bar.
- Rendering a wallet tile **never prompts for an unlock**; only the detail header offers the shared tap-to-unlock tile.
- Icon buttons are `HmmIconButton` with a localized tooltip only; `test/core/help/icon_button_guard_test.dart` stays green and its allow-list only shrinks.
- In-app help on **three** screens, each with a `HelpId`, a registry case in `lib/core/help/help_registry.dart`, a `HelpButton` in its top bar and en + zh ARB keys (`help<Screen>Title`, `help<Screen>Summary`, `help<Screen><Control>Title/Body`): wallet `HelpId.cheatsheetWallet` (Task 7), detail `HelpId.cheatsheetDetail` (Task 8), designer `HelpId.cheatsheetDesigner` (Task 9). Each entry's icon is the control's own `Icons.*` constant; a control that draws no Material icon (a tile, a chip, the header) uses the closest stand-in, as `vehicleNotes`' "Open" entry does.
- Platform controls branch on `Theme.of(context).platform` (`CupertinoSlidingSegmentedControl` / `CupertinoActionSheet` / `showCupertinoModalPopup` on iOS, `SegmentedButton` / `showModalBottomSheet` elsewhere). `flutter_platform_widgets` is not a dependency.
- Every new user-visible string goes into both `app_en.arb` and `app_zh.arb` (key parity). Run `flutter gen-l10n` after every ARB edit and commit `lib/l10n/gen/`.
- Logs carry ids and error **types** only (`${e.runtimeType}`) — never paths, titles, values or JSON.
- `flutter analyze` stays at exactly the 2 pre-existing infos (`onboarding_screen.dart`, `main.dart`).
- Full `flutter test` baseline is **2060** passing; it may only grow, with 0 failures.
- Backend: `Hmm.Cheatsheet.Tests` (baseline 94) and `Hmm.ServiceApi.Core.Tests` (baseline 420) stay green and grow; `dotnet test Hmm.sln` green.
- Deploy order: the server pass-through (Task 4) ships **before or with** the client release that writes `style` in Cloud API mode. **No backend deploy in this plan.**
- Stage only the files each task names (`git add <paths>`), never `git add -A`. The hmm repo has an unrelated uncommitted `CLAUDE.md` change — never stage it.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No push and no merge. Client branch stays `feat/contacts-client`; backend commits go on a new hmm branch **`feat/cheatsheet-style-passthrough`**, created from `main` at the start of Task 4 — never commit on `main`.

## Review Focus

1. **A cover whose vault file is gone or will not decrypt** (cloudStorage note synced before its bytes, a restored backup, a corrupt sensitive file). The tile and header must silently fall back to the theme background, show no broken-image icon, and log the card id plus the error type only — never the path. Pinned in Task 6 (`card_surface_test.dart`: `a cover whose vault file is gone falls back to the theme`, `a cover that fails to decrypt falls back and logs the type only`).
2. **A card edited on a device running an older app version** (the old codec writes fixed keys, so `style` and row `emoji` vanish; it never writes `attachments`, so the cover ref stays in the column). The new client must render the template look, show no cover, and release the orphaned cover on its next save; via the Cloud API an old client's PUT (no `Style` key) must not wipe the stored style. Pinned in Task 3 (`local_cheatsheet_repository_cover_test.dart`: `a card saved by an older app version shows no cover and the next save releases it`) and Task 4 (`ForUpdate_WithoutStyleKey_KeepsTheStoredStyle`).
3. **Switching layout Key points → Facts → Key points.** Row emoji are hidden in Facts but must survive the round trip and the save. Pinned in Task 9 (`cheatsheet_editor_state_test.dart`: `a layout round trip keeps every row emoji`; `cheatsheet_designer_look_test.dart`: `row emoji survive Key points -> Facts -> Key points and are saved`).
4. **Deleting a card that has a cover.** `LocalHmmNoteRepository.deleteNote` is a soft delete and `collectReferencedVaultPaths` counts soft-deleted notes, so without an explicit release the photo stays live forever. Pinned in Task 3 (`deleteCard releases the cover so VaultGc no longer counts it`; state test `removing a card deletes its cover bytes`).
5. **Very long titles and multi-code-point emoji on a tile** (200-character title, `👩🏽‍💻` skin-tone + ZWJ, `🇨🇦` flag, `#️⃣` keycap). The tile must clamp the title to 2 lines with no overflow, and each sequence must count as one icon. Pinned in Task 1 (`isSingleEmoji accepts one grapheme of any emoji shape`) and Task 6 (`a long title and a ZWJ skin-tone icon render on a tile without overflow`).

### Deviations from the spec (forced by the code)

- **Covers are local/cloudStorage only for now** (confirmed in plan review 2026-10-12, Q1 a). `/v1/cheatsheets` exposes neither the backing note id (`ApiVaultStore` paths are `/v1/notes/{noteId}/vault/...`) nor the note's `attachments` column, so the client cannot attach a cover in Cloud API mode. The designer hides Cover when `dataMode == cloudApi` (`cheatsheetCoversSupportedProvider`), `ICheatsheetRepository.noteIdFor` answers `null` there, and a `style.cover` written on another device passes through verbatim and renders the theme. Everything else in the look works in all three modes.
- **Who marks a cover sensitive is unspecified.** The cover is stored `sensitive: card.protected` (the existing flag; confirmed in plan review, Q2 a). Any sensitive cover — including one synced from elsewhere — follows the spec's lock rules.
- **`CardTheme` would collide with Material's `CardTheme`.** The enum is `CardThemeId` and the colour table is `CheatsheetPalette`.
- **Delete must release explicitly.** Soft delete keeps a note's attachments live for `VaultGc`, so `LocalCheatsheetRepository.deleteCard` clears the column before deleting and `CheatsheetsState.remove` deletes the bytes.
- **The detail and wallet screens have no help today.** "Existing edit/delete/help actions remain" — there was no help action to keep there. Per plan review (2026-10-12, Q6 b) help is added to all three screens: the wallet (`HelpId.cheatsheetWallet`: tiles, group chips, tag chips, lock badge — Task 7), the detail (`HelpId.cheatsheetDetail`: Facts layout, Key points layout, cover header, lock tile — Task 8) and the designer (`HelpId.cheatsheetDesigner` — Task 9).
- **Backend PUT semantics for `Style`** (confirmed in plan review, Q3 a). The update map runs onto the stored card (`MergeExtras` precedent), so `ApiCheatsheetForUpdate` records whether `Style` was present: absent ⇒ keep the stored style (older clients), explicit `null` ⇒ clear it (Reset look). The current client always sends the key.
- **Byte-identity is for canonical order.** Both this codec and the backend serializer write the canonical order, so every card they wrote round-trips byte-identical. A card whose *unreadable* rows sit between readable rows is still reordered (unreadable rows are appended — pre-existing behaviour, out of scope).
- **The Look section is an `ExpansionTile` whose leading is the live mini-tile, expanded when creating a card and collapsed when editing one** (plan review 2026-10-12, Q4 b). On create the look is part of making the card; on edit the preview alone shows the current look and the rows stay in the first viewport. Because the expanded section pushes the rows below the default test view, the existing create-path tests (`cheatsheet_designer_screen_test.dart`, `cheatsheet_acceptance_test.dart`) get a tall view and a `cheatsheetCoversSupportedProvider` override (Task 9 Step 23).
- **Group chips are single-select `ChoiceChip`s**; the existing tag `FilterChip`s stay below them.

---

### Task 1: Style model and theme palette

**Files:**
- Create: `lib/features/cheatsheet/domain/entities/card_style.dart`
- Create: `lib/features/cheatsheet/presentation/look/cheatsheet_palette.dart`
- Test: `test/features/cheatsheet/domain/card_style_test.dart`
- Test: `test/features/cheatsheet/presentation/look/cheatsheet_palette_test.dart`

**Interfaces:**
- Consumes: nothing from the app (pure Dart + `dart:ui` colours; `StringCharacters` re-exported by `package:flutter/widgets.dart`, line 15).
- Produces:
  - `enum CardThemeId { blue, green, orange, red, purple, teal, pink, amber, slate, indigo, brown, black }`
  - `enum CardPattern { none, dots, stripes, grid, waves }`
  - `enum CardLayout { facts, keyPoints }`
  - `class CardLookDefaults { final CardThemeId theme; final String icon; final CardLayout layout; static CardLookDefaults of(String templateId); static const car, medical, book, dividers; }`
  - `class CardLook { final CardThemeId theme; final CardPattern pattern; final String icon; final CardLayout layout; }`
  - `class CardStyle { const CardStyle([Map<String, dynamic> raw = const {}]); static const empty; bool get isEmpty; Map<String, dynamic> toMap(); CardThemeId? get theme; CardPattern? get pattern; CardLayout? get layout; String? get icon; String? get coverPath; CardStyle withTheme(CardThemeId, {required String templateId}); CardStyle withPattern(CardPattern); CardStyle withIcon(String?, {required String templateId}); CardStyle withLayout(CardLayout, {required String templateId}); CardStyle withCoverPath(String?); CardLook resolve(String templateId); }`
  - `bool isSingleEmoji(String s)`, `bool jsonValueEquals(Object? a, Object? b)`, `int jsonValueHash(Object? v)`
  - `const double kPatternInkOpacity = 0.10; const double kCardSubtitleOpacity = 0.90; const double kCoverScrimOpacity = 0.50;`
  - `class CardColors { final Color background; final Color foreground; Color get subtitle; Color get patternInk; }`
  - `class CheatsheetPalette { static CardColors of(CardThemeId, Brightness); static CardColors forCover(CardThemeId, Brightness); }`
  - `double contrastRatio(Color a, Color b)`

- [ ] **Step 1: Write the failing style-model test**

Create `test/features/cheatsheet/domain/card_style_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';

void main() {
  group('template defaults', () {
    test('match the spec table', () {
      final claim = CardLookDefaults.of('accidentClaim');
      expect(claim.theme, CardThemeId.blue);
      expect(claim.icon, '\u{1F697}');
      expect(claim.layout, CardLayout.facts);

      final health = CardLookDefaults.of('healthInfo');
      expect(health.theme, CardThemeId.green);
      expect(health.icon, '⚕️');
      expect(health.layout, CardLayout.facts);

      final doc = CardLookDefaults.of('document');
      expect(doc.theme, CardThemeId.orange);
      expect(doc.icon, '\u{1F4D6}');
      expect(doc.layout, CardLayout.keyPoints);

      for (final id in ['blank', 'someFutureTemplate', '']) {
        final d = CardLookDefaults.of(id);
        expect(d.theme, CardThemeId.slate, reason: id);
        expect(d.icon, '\u{1F5C2}️', reason: id);
        expect(d.layout, CardLayout.facts, reason: id);
      }
    });

    test('an empty style resolves to the template look with no pattern', () {
      final look = CardStyle.empty.resolve('document');
      expect(look.theme, CardThemeId.orange);
      expect(look.pattern, CardPattern.none);
      expect(look.icon, '\u{1F4D6}');
      expect(look.layout, CardLayout.keyPoints);
    });
  });

  group('unknown values', () {
    test('an unknown theme renders the default and is kept raw', () {
      const s = CardStyle({'theme': 'turquoise', 'pattern': 'hexagons'});
      final look = s.resolve('accidentClaim');
      expect(look.theme, CardThemeId.blue);
      expect(look.pattern, CardPattern.none);
      expect(s.toMap(), {'theme': 'turquoise', 'pattern': 'hexagons'});
    });

    test('wrong-typed values render the default and are kept raw', () {
      const s = CardStyle({'theme': 5, 'layout': ['x'], 'icon': 7});
      final look = s.resolve('blank');
      expect(look.theme, CardThemeId.slate);
      expect(look.layout, CardLayout.facts);
      expect(look.icon, '\u{1F5C2}️');
      expect(s.toMap(), {'theme': 5, 'layout': ['x'], 'icon': 7});
    });

    test('a non-emoji icon renders the template icon and is kept raw', () {
      const s = CardStyle({'icon': 'abc'});
      expect(s.resolve('document').icon, '\u{1F4D6}');
      expect(s.icon, 'abc');
      expect(s.toMap(), {'icon': 'abc'});
    });
  });

  group('edits write only what differs from the template', () {
    test('choosing the template theme removes the key', () {
      final s = const CardStyle({'theme': 'red'})
          .withTheme(CardThemeId.blue, templateId: 'accidentClaim');
      expect(s.isEmpty, isTrue);
    });

    test('choosing another theme stores its name', () {
      final s = CardStyle.empty
          .withTheme(CardThemeId.purple, templateId: 'accidentClaim');
      expect(s.toMap(), {'theme': 'purple'});
      expect(s.resolve('accidentClaim').theme, CardThemeId.purple);
    });

    test('pattern none is never stored', () {
      expect(const CardStyle({'pattern': 'dots'})
          .withPattern(CardPattern.none)
          .isEmpty, isTrue);
      expect(CardStyle.empty.withPattern(CardPattern.waves).toMap(),
          {'pattern': 'waves'});
    });

    test('the template icon and a cleared icon are not stored', () {
      expect(CardStyle.empty
          .withIcon('\u{1F4D6}', templateId: 'document')
          .isEmpty, isTrue);
      expect(const CardStyle({'icon': '\u{1F984}'})
          .withIcon(null, templateId: 'document')
          .isEmpty, isTrue);
      expect(CardStyle.empty.withIcon('', templateId: 'document').isEmpty,
          isTrue);
      expect(CardStyle.empty
          .withIcon('\u{1F984}', templateId: 'document')
          .toMap(), {'icon': '\u{1F984}'});
    });

    test('the template layout is not stored', () {
      expect(CardStyle.empty
          .withLayout(CardLayout.keyPoints, templateId: 'document')
          .isEmpty, isTrue);
      expect(CardStyle.empty
          .withLayout(CardLayout.facts, templateId: 'document')
          .toMap(), {'layout': 'facts'});
    });

    test('cover path is set and cleared', () {
      final s = CardStyle.empty.withCoverPath('attachments/note-1/a.jpg');
      expect(s.coverPath, 'attachments/note-1/a.jpg');
      expect(s.withCoverPath(null).isEmpty, isTrue);
      expect(s.withCoverPath('').isEmpty, isTrue);
    });

    test('an edit keeps unknown keys and replaces in place, preserving order',
        () {
      const s = CardStyle({'sparkle': {'a': 1}, 'theme': 'red', 'z': true});
      final edited =
          s.withTheme(CardThemeId.teal, templateId: 'accidentClaim');
      expect(edited.toMap().keys.toList(), ['sparkle', 'theme', 'z']);
      expect(edited.toMap()['theme'], 'teal');
      expect(edited.toMap()['sparkle'], {'a': 1});
    });

    test('toMap is a copy; the style cannot be mutated through it', () {
      const s = CardStyle({'theme': 'red'});
      s.toMap()['theme'] = 'blue';
      expect(s.toMap(), {'theme': 'red'});
    });
  });

  group('isSingleEmoji accepts one grapheme of any emoji shape', () {
    const valid = {
      'book': '\u{1F4D6}',
      'medical with VS16': '⚕️',
      'dividers with VS16': '\u{1F5C2}️',
      'skin tone': '\u{1F44D}\u{1F3FD}',
      'ZWJ family': '\u{1F468}‍\u{1F469}‍\u{1F467}',
      'skin tone + ZWJ technologist': '\u{1F469}\u{1F3FD}‍\u{1F4BB}',
      'flag': '\u{1F1E8}\u{1F1E6}',
      'keycap': '#️⃣',
      'star': '⭐',
    };
    const invalid = {
      'empty': '',
      'letter': 'a',
      'word': 'abc',
      'two emoji': '\u{1F4D6}\u{1F4D6}',
      'digit': '1',
      'Han character': '中',
      'emoji plus text': '\u{1F4D6}x',
    };
    for (final e in valid.entries) {
      test('accepts ${e.key}', () => expect(isSingleEmoji(e.value), isTrue));
    }
    for (final e in invalid.entries) {
      test('rejects ${e.key}', () => expect(isSingleEmoji(e.value), isFalse));
    }
  });

  test('equality is structural and key-order sensitive', () {
    expect(const CardStyle({'theme': 'red', 'pattern': 'dots'}),
        const CardStyle({'theme': 'red', 'pattern': 'dots'}));
    expect(const CardStyle({'theme': 'red', 'pattern': 'dots'}).hashCode,
        const CardStyle({'theme': 'red', 'pattern': 'dots'}).hashCode);
    expect(const CardStyle({'theme': 'red', 'pattern': 'dots'}),
        isNot(const CardStyle({'pattern': 'dots', 'theme': 'red'})));
    expect(const CardStyle({'x': {'a': [1, 2]}}),
        const CardStyle({'x': {'a': [1, 2]}}));
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/domain/card_style_test.dart`
Expected: compilation fails — `Error when reading 'lib/features/cheatsheet/domain/entities/card_style.dart': No such file or directory`.

- [ ] **Step 3: Implement the style model**

Create `lib/features/cheatsheet/domain/entities/card_style.dart`:

```dart
import 'package:flutter/widgets.dart' show StringCharacters;

/// The twelve hand-picked colour themes. Stored by [Enum.name]; a stored
/// value this version does not know renders as the template default and is
/// written back unchanged (see [CardStyle]).
enum CardThemeId {
  blue,
  green,
  orange,
  red,
  purple,
  teal,
  pink,
  amber,
  slate,
  indigo,
  brown,
  black,
}

/// Drawn over the theme colour. [none] is the default and is never stored.
enum CardPattern { none, dots, stripes, grid, waves }

/// How the detail screen lays out rows: [facts] (label -> value, the original
/// layout) or [keyPoints] (numbered, theme-coloured, optional row emoji).
enum CardLayout { facts, keyPoints }

/// The look a template gives a card whose style says nothing.
class CardLookDefaults {
  const CardLookDefaults({
    required this.theme,
    required this.icon,
    required this.layout,
  });

  final CardThemeId theme;
  final String icon;
  final CardLayout layout;

  // Escapes, not literals: "is this the default icon?" is a byte comparison
  // (a default is never stored), and an editor silently dropping the U+FE0F
  // variation selector from a literal would break it.
  static const car = '\u{1F697}'; // car
  static const medical = '⚕️'; // staff of Aesculapius
  static const book = '\u{1F4D6}'; // open book
  static const dividers = '\u{1F5C2}️'; // card index dividers

  static CardLookDefaults of(String templateId) => switch (templateId) {
        'accidentClaim' => const CardLookDefaults(
            theme: CardThemeId.blue, icon: car, layout: CardLayout.facts),
        'healthInfo' => const CardLookDefaults(
            theme: CardThemeId.green, icon: medical, layout: CardLayout.facts),
        'document' => const CardLookDefaults(
            theme: CardThemeId.orange,
            icon: book,
            layout: CardLayout.keyPoints),
        _ => const CardLookDefaults(
            theme: CardThemeId.slate, icon: dividers, layout: CardLayout.facts),
      };
}

/// The look a card actually renders with: stored values where they are
/// valid, template defaults everywhere else.
class CardLook {
  const CardLook({
    required this.theme,
    required this.pattern,
    required this.icon,
    required this.layout,
  });

  final CardThemeId theme;
  final CardPattern pattern;
  final String icon;
  final CardLayout layout;
}

/// A card's `style` block, kept as the raw map it was read from.
///
/// Holding the raw map rather than typed fields is what makes preservation
/// free: a newer theme name, a wrong-typed value, or a key this version has
/// never heard of is simply carried along and written back, because nothing
/// ever re-derives the map from typed fields. An edit replaces one key in
/// place (keeping key order, so an untouched style stays byte-identical) and
/// removes it instead when the new value is the template default.
class CardStyle {
  const CardStyle([this._raw = const {}]);

  static const empty = CardStyle();

  static const themeKey = 'theme';
  static const patternKey = 'pattern';
  static const iconKey = 'icon';
  static const layoutKey = 'layout';
  static const coverKey = 'cover';

  final Map<String, dynamic> _raw;

  bool get isEmpty => _raw.isEmpty;

  /// A copy, in stored key order.
  Map<String, dynamic> toMap() => Map<String, dynamic>.of(_raw);

  CardThemeId? get theme => _byName(CardThemeId.values, _raw[themeKey]);
  CardPattern? get pattern => _byName(CardPattern.values, _raw[patternKey]);
  CardLayout? get layout => _byName(CardLayout.values, _raw[layoutKey]);

  /// The stored icon text, valid or not. Rendering goes through [resolve].
  String? get icon {
    final v = _raw[iconKey];
    return v is String ? v : null;
  }

  /// Vault path of the cover attachment, if any. The bytes are referenced
  /// from the note's `attachments` column, never from here.
  String? get coverPath {
    final v = _raw[coverKey];
    return v is String && v.isNotEmpty ? v : null;
  }

  CardStyle withTheme(CardThemeId t, {required String templateId}) => _with(
      themeKey, t == CardLookDefaults.of(templateId).theme ? null : t.name);

  CardStyle withPattern(CardPattern p) =>
      _with(patternKey, p == CardPattern.none ? null : p.name);

  CardStyle withIcon(String? icon, {required String templateId}) => _with(
      iconKey,
      icon == null ||
              icon.isEmpty ||
              icon == CardLookDefaults.of(templateId).icon
          ? null
          : icon);

  CardStyle withLayout(CardLayout l, {required String templateId}) => _with(
      layoutKey, l == CardLookDefaults.of(templateId).layout ? null : l.name);

  CardStyle withCoverPath(String? path) =>
      _with(coverKey, path == null || path.isEmpty ? null : path);

  CardLook resolve(String templateId) {
    final d = CardLookDefaults.of(templateId);
    final i = icon;
    return CardLook(
      theme: theme ?? d.theme,
      pattern: pattern ?? CardPattern.none,
      icon: i != null && isSingleEmoji(i) ? i : d.icon,
      layout: layout ?? d.layout,
    );
  }

  /// Replaces [key] where it already sits (order matters for byte identity),
  /// appends it when new, and removes it when [value] is null.
  CardStyle _with(String key, Object? value) {
    final next = <String, dynamic>{};
    var placed = false;
    for (final e in _raw.entries) {
      if (e.key == key) {
        placed = true;
        if (value != null) next[key] = value;
      } else {
        next[e.key] = e.value;
      }
    }
    if (!placed && value != null) next[key] = value;
    return CardStyle(next);
  }

  static T? _byName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardStyle && jsonValueEquals(_raw, other._raw);

  @override
  int get hashCode => jsonValueHash(_raw);

  @override
  String toString() => 'CardStyle(keys: ${_raw.keys.toList()})';
}

/// One emoji: exactly one grapheme cluster whose first code point is an
/// emoji (so skin tones, ZWJ sequences and flags count as one), or a keycap.
bool isSingleEmoji(String s) {
  if (s.isEmpty || s.characters.length != 1) return false;
  final runes = s.runes.toList();
  if (runes.contains(0x20E3)) return true; // keycap: #, *, 0-9 + U+20E3
  final r = runes.first;
  return (r >= 0x1F000 && r <= 0x1FAFF) ||
      (r >= 0x2600 && r <= 0x27BF) ||
      (r >= 0x2300 && r <= 0x23FF) ||
      (r >= 0x2B00 && r <= 0x2BFF) ||
      (r >= 0x2190 && r <= 0x21FF) ||
      r == 0x203C ||
      r == 0x2049 ||
      r == 0x2122 ||
      r == 0x2139 ||
      r == 0x3030 ||
      r == 0x303D ||
      r == 0x3297 ||
      r == 0x3299;
}

/// Structural equality for decoded JSON. Map key ORDER counts: these values
/// are written back to storage, where order is part of byte identity.
bool jsonValueEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    final ka = a.keys.toList();
    final kb = b.keys.toList();
    for (var i = 0; i < ka.length; i++) {
      if (ka[i] != kb[i] || !jsonValueEquals(a[ka[i]], b[kb[i]])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonValueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int jsonValueHash(Object? v) {
  if (v is Map) {
    return Object.hashAll([
      for (final e in v.entries) Object.hash(e.key, jsonValueHash(e.value)),
    ]);
  }
  if (v is List) return Object.hashAll(v.map(jsonValueHash));
  return v.hashCode;
}
```

- [ ] **Step 4: Run it to see it pass**

Run: `flutter test test/features/cheatsheet/domain/card_style_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Write the failing palette (WCAG AA) test**

Create `test/features/cheatsheet/presentation/look/cheatsheet_palette_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cheatsheet_palette.dart';

void main() {
  test('contrastRatio matches the WCAG formula at its extremes', () {
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFF777777), const Color(0xFF777777)),
        closeTo(1, 0.0001));
  });

  for (final b in Brightness.values) {
    for (final t in CardThemeId.values) {
      test('${t.name} (${b.name}): title and subtitle meet AA, '
          'with and without the pattern ink', () {
        final c = CheatsheetPalette.of(t, b);
        // The pattern is drawn in foreground ink over the background, so text
        // may sit on either the bare colour or the inked one.
        final inked = Color.alphaBlend(c.patternInk, c.background);
        for (final bg in [c.background, inked]) {
          expect(contrastRatio(c.foreground, bg), greaterThanOrEqualTo(4.5),
              reason: 'title on ${bg.toARGB32().toRadixString(16)}');
          expect(contrastRatio(Color.alphaBlend(c.subtitle, bg), bg),
              greaterThanOrEqualTo(4.5),
              reason: 'subtitle on ${bg.toARGB32().toRadixString(16)}');
        }
      });

      test('${t.name} (${b.name}): the cover header bar meets AA', () {
        final c = CheatsheetPalette.forCover(t, b);
        expect(contrastRatio(c.foreground, c.background),
            greaterThanOrEqualTo(4.5));
        expect(
            contrastRatio(
                Color.alphaBlend(c.subtitle, c.background), c.background),
            greaterThanOrEqualTo(4.5));
      });
    }
  }

  test('light and dark variants differ for every theme', () {
    for (final t in CardThemeId.values) {
      expect(CheatsheetPalette.of(t, Brightness.light).background,
          isNot(CheatsheetPalette.of(t, Brightness.dark).background),
          reason: t.name);
    }
  });

  test('every theme has a distinct light background', () {
    final seen = {
      for (final t in CardThemeId.values)
        CheatsheetPalette.of(t, Brightness.light).background,
    };
    expect(seen, hasLength(CardThemeId.values.length));
  });
}
```

- [ ] **Step 6: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/presentation/look/cheatsheet_palette_test.dart`
Expected: compilation fails — `cheatsheet_palette.dart` does not exist.

- [ ] **Step 7: Implement the palette**

Create `lib/features/cheatsheet/presentation/look/cheatsheet_palette.dart`:

```dart
import 'dart:ui' show Brightness, Color;

import '../../domain/entities/card_style.dart';

/// Pattern strokes are the foreground colour at this opacity. The AA test
/// composites it over the background, so raising it needs that test green.
const double kPatternInkOpacity = 0.10;

/// Subtitle text is the foreground colour at this opacity.
const double kCardSubtitleOpacity = 0.90;

/// How much black darkens the theme colour behind white text on a card with
/// a cover (the detail app bar). 0.5 keeps amber's white text at AA.
const double kCoverScrimOpacity = 0.50;

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

/// Background plus the text colour derived from it. Text colour is never
/// user-chosen: it comes with the variant.
class CardColors {
  const CardColors({
    required this.background,
    required this.foreground,
    this.subtitleOpacity = kCardSubtitleOpacity,
  });

  final Color background;
  final Color foreground;
  final double subtitleOpacity;

  Color get subtitle => foreground.withValues(alpha: subtitleOpacity);
  Color get patternInk => foreground.withValues(alpha: kPatternInkOpacity);
}

/// The twelve themes, each with a light and a dark variant whose text meets
/// WCAG AA (pinned by `cheatsheet_palette_test.dart`).
class CheatsheetPalette {
  const CheatsheetPalette._();

  static CardColors of(CardThemeId id, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final (Color light, Color night, Color fg) = switch (id) {
      CardThemeId.blue => (const Color(0xFF1258A8), const Color(0xFF0D47A1), _white),
      CardThemeId.green => (const Color(0xFF1E6B24), const Color(0xFF1B5E20), _white),
      CardThemeId.orange => (const Color(0xFFA8380A), const Color(0xFF8A2E0E), _white),
      CardThemeId.red => (const Color(0xFFB71C1C), const Color(0xFF8E1B1B), _white),
      CardThemeId.purple => (const Color(0xFF6A1B9A), const Color(0xFF4A148C), _white),
      CardThemeId.teal => (const Color(0xFF00695C), const Color(0xFF004D40), _white),
      CardThemeId.pink => (const Color(0xFFAD1457), const Color(0xFF880E4F), _white),
      CardThemeId.amber => (const Color(0xFFFFC107), const Color(0xFFC79500), _black),
      CardThemeId.slate => (const Color(0xFF475569), const Color(0xFF334155), _white),
      CardThemeId.indigo => (const Color(0xFF3949AB), const Color(0xFF283593), _white),
      CardThemeId.brown => (const Color(0xFF6D4C41), const Color(0xFF4E342E), _white),
      CardThemeId.black => (const Color(0xFF212121), const Color(0xFF2A2A2A), _white),
    };
    return CardColors(background: dark ? night : light, foreground: fg);
  }

  /// The app bar over a card that has a cover: the theme darkened, with white
  /// text, so the bar reads the same whether or not the photo loads.
  static CardColors forCover(CardThemeId id, Brightness brightness) =>
      CardColors(
        background: Color.alphaBlend(
          _black.withValues(alpha: kCoverScrimOpacity),
          of(id, brightness).background,
        ),
        foreground: _white,
      );
}

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
```

- [ ] **Step 8: Run both tests to see them pass**

Run: `flutter test test/features/cheatsheet/domain/card_style_test.dart test/features/cheatsheet/presentation/look/cheatsheet_palette_test.dart`
Expected: `All tests passed!` (the palette values were pre-checked: minimum title ratio 5.26 (green light, inked), minimum subtitle ratio 4.62 (green light, inked); amber cover bar ≈ 5.0).

- [ ] **Step 9: Analyze and commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet test/features/cheatsheet
git add lib/features/cheatsheet/domain/entities/card_style.dart \
  lib/features/cheatsheet/presentation/look/cheatsheet_palette.dart \
  test/features/cheatsheet/domain/card_style_test.dart \
  test/features/cheatsheet/presentation/look/cheatsheet_palette_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): card style model and AA-checked theme palette

CardStyle wraps the raw style map so unknown values survive; twelve
themes with light/dark variants pass WCAG AA with the pattern ink.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

Expected: analyze reports `No issues found!` for these paths.

---

### Task 2: Codec — `style`, row `emoji`, unknown keys, byte identity

**Files:**
- Modify: `lib/features/cheatsheet/domain/entities/cheatsheet_card.dart` (whole file, 116 lines → replaced)
- Modify: `lib/features/cheatsheet/domain/entities/cheatsheet_row.dart` (whole file, 61 lines → replaced)
- Modify: `lib/features/cheatsheet/data/cheatsheet_codec.dart` (whole file, 114 lines → replaced)
- Test: `test/features/cheatsheet/data/cheatsheet_codec_look_test.dart` (new)

**Interfaces:**
- Consumes: `CardStyle`, `CardLook`, `jsonValueEquals`, `jsonValueHash` (Task 1); `VaultRef`, `NoteAttachments`, `AttachmentRef` from `lib/core/data/attachments/attachment_ref.dart`.
- Produces:
  - `CheatsheetCard({..., CardStyle style = CardStyle.empty, VaultRef? cover, Map<String, dynamic> extraFields = const {}})`; `CardLook get look`; `CheatsheetCard withCover(VaultRef? ref)`; `copyWith({..., CardStyle? style, VaultRef? cover, bool clearCover = false, Map<String, dynamic>? extraFields})`
  - `CheatsheetRow({..., String? emoji, Map<String, dynamic> extraFields = const {}})`; `copyWith({..., String? emoji, bool clearEmoji = false, Map<String, dynamic>? extraFields})`
  - `CheatsheetCodec.fromMap(Map<String, dynamic> m, {NoteAttachments? attachments})` — `cover` is the `VaultRef` in [attachments] whose path equals `style.cover`, else null.
  - `CheatsheetCodec.toMap(CheatsheetCard c)` — canonical order, `style` only when non-empty, extras last.

- [ ] **Step 1: Write the failing codec test**

Create `test/features/cheatsheet/data/cheatsheet_codec_look_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_codec.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';

/// decode -> encode -> the exact same JSON text.
String _roundTrip(String json, {NoteAttachments? attachments}) =>
    jsonEncode(CheatsheetCodec.toMap(CheatsheetCodec.fromMap(
        (jsonDecode(json) as Map).cast<String, dynamic>(),
        attachments: attachments)));

void main() {
  const cover = VaultRef(
    path: 'attachments/note-7/cover.jpg',
    contentType: 'image/jpeg',
    byteSize: 1234,
  );

  group('byte identity', () {
    test('a card written before this feature round-trips byte-identical', () {
      // Exactly what the pre-feature codec wrote: no style, no emoji.
      const before = '{"schemaVersion":1,"id":"c1","title":"Claim",'
          '"walletGroup":"Vehicle","tags":["legal"],'
          '"templateId":"accidentClaim","protected":false,"rows":['
          '{"label":"Plate","valueAction":"call","openSource":true,'
          '"source":{"noteUuid":"auto1","kind":"field",'
          '"locator":"AutomobileInfo.plate"}},'
          '{"label":"Unbound","valueAction":"none","openSource":true}]}';
      expect(_roundTrip(before), before);
    });

    test('a styled card with unknown keys everywhere round-trips byte-identical',
        () {
      const styled = '{"schemaVersion":1,"id":"c1","title":"Vim",'
          '"walletGroup":"Reference","tags":[],"templateId":"document",'
          '"protected":false,"rows":['
          '{"label":"Motions","valueAction":"none","openSource":true,'
          '"emoji":"\u{1F440}","hint":{"x":1}}],'
          '"style":{"theme":"turquoise","pattern":"dots","sparkle":[1,2]},'
          '"future":42}';
      expect(_roundTrip(styled), styled);
    });

    test('a card with a cover round-trips byte-identical and projects the ref',
        () {
      const withCover = '{"schemaVersion":1,"id":"c1","title":"T",'
          '"walletGroup":"Ungrouped","tags":[],"templateId":"blank",'
          '"protected":false,"rows":[],'
          '"style":{"cover":"attachments/note-7/cover.jpg"}}';
      final attachments = NoteAttachments(images: const [cover]);
      expect(_roundTrip(withCover, attachments: attachments), withCover);

      final card = CheatsheetCodec.fromMap(
          (jsonDecode(withCover) as Map).cast<String, dynamic>(),
          attachments: attachments);
      expect(card.cover, cover);
    });
  });

  group('style', () {
    test('an unstyled card writes no style key', () {
      const c = CheatsheetCard(
        id: 'c1',
        title: 'T',
        walletGroup: 'Ungrouped',
        tags: [],
        templateId: 'blank',
        rows: [],
      );
      expect(CheatsheetCodec.toMap(c).containsKey('style'), isFalse);
    });

    test('a style that differs from the template is written', () {
      final c = const CheatsheetCard(
        id: 'c1',
        title: 'T',
        walletGroup: 'Ungrouped',
        tags: [],
        templateId: 'blank',
        rows: [],
      ).copyWith(
          style: CardStyle.empty
              .withTheme(CardThemeId.red, templateId: 'blank')
              .withPattern(CardPattern.waves));
      expect(CheatsheetCodec.toMap(c)['style'],
          {'theme': 'red', 'pattern': 'waves'});
    });

    test('unknown theme, pattern, layout and style keys are preserved', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'templateId': 'document',
        'rows': [],
        'style': {
          'theme': 'turquoise',
          'pattern': 'hexagons',
          'layout': 'timeline',
          'icon': 'not an emoji',
          'sparkle': {'a': 1},
        },
      });
      final look = decoded.look;
      expect(look.theme, CardThemeId.orange);
      expect(look.pattern, CardPattern.none);
      expect(look.layout, CardLayout.keyPoints);
      expect(look.icon, '\u{1F4D6}');
      expect(CheatsheetCodec.toMap(decoded)['style'], {
        'theme': 'turquoise',
        'pattern': 'hexagons',
        'layout': 'timeline',
        'icon': 'not an emoji',
        'sparkle': {'a': 1},
      });
    });

    test('a non-map style is kept verbatim as an unknown key', () {
      final decoded = CheatsheetCodec.fromMap(
          {'id': 'x', 'rows': [], 'style': 'from-the-future'});
      expect(decoded.style.isEmpty, isTrue);
      expect(CheatsheetCodec.toMap(decoded)['style'], 'from-the-future');
    });

    test('setting a style replaces a preserved non-map style', () {
      final decoded = CheatsheetCodec.fromMap(
          {'id': 'x', 'rows': [], 'style': 'from-the-future'});
      final edited = decoded.copyWith(
          style: decoded.style.withPattern(CardPattern.grid));
      expect(CheatsheetCodec.toMap(edited)['style'], {'pattern': 'grid'});
    });

    test('a cover path with no matching attachment yields no cover but keeps '
        'the path', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'rows': [],
        'style': {'cover': 'attachments/note-9/gone.jpg'},
      }, attachments: NoteAttachments.empty);
      expect(decoded.cover, isNull);
      expect(CheatsheetCodec.toMap(decoded)['style'],
          {'cover': 'attachments/note-9/gone.jpg'});
    });

    test('content records the cover PATH, never the ref', () {
      final c = const CheatsheetCard(
        id: 'c1',
        title: 'T',
        walletGroup: 'Ungrouped',
        tags: [],
        templateId: 'blank',
        rows: [],
      ).withCover(cover);
      final json = jsonEncode(CheatsheetCodec.toMap(c));
      expect(json, contains('"cover":"attachments/note-7/cover.jpg"'));
      expect(json, isNot(contains('contentType')));
      expect(json, isNot(contains('byteSize')));
    });
  });

  group('top-level and row unknown keys', () {
    test('unknown top-level keys survive an edit', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'title': 'T',
        'rows': [],
        'quickAccess': {'pinned': true},
      });
      final edited = decoded.copyWith(title: 'Renamed');
      expect(CheatsheetCodec.toMap(edited)['quickAccess'], {'pinned': true});
    });

    test('row emoji round-trips and unknown row keys are kept beside it', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'rows': [
          {'label': 'A', 'emoji': '\u{1F440}', 'hint': 'keep me'},
        ],
      });
      expect(decoded.rows.single.emoji, '\u{1F440}');
      final row = (CheatsheetCodec.toMap(decoded)['rows'] as List).single;
      expect(row['emoji'], '\u{1F440}');
      expect(row['hint'], 'keep me');
    });

    test('a non-string row emoji is preserved verbatim, not dropped', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'rows': [
          {'label': 'A', 'emoji': 42},
        ],
      });
      expect(decoded.rows.single.emoji, isNull);
      final row = (CheatsheetCodec.toMap(decoded)['rows'] as List).single;
      expect(row['emoji'], 42);
    });
  });

  group('reset semantics', () {
    test('an empty style and cleared row emoji leave no trace', () {
      final decoded = CheatsheetCodec.fromMap({
        'id': 'x',
        'rows': [
          {'label': 'A', 'emoji': '\u{1F440}'},
        ],
        'style': {'theme': 'red'},
      });
      final reset = decoded.copyWith(
        style: CardStyle.empty,
        rows: [
          for (final r in decoded.rows) r.copyWith(clearEmoji: true),
        ],
      );
      final map = CheatsheetCodec.toMap(reset);
      expect(map.containsKey('style'), isFalse);
      expect((map['rows'] as List).single.containsKey('emoji'), isFalse);
    });

    test('withCover(null) clears both the ref and the stored path', () {
      final c = const CheatsheetCard(
        id: 'c1',
        title: 'T',
        walletGroup: 'Ungrouped',
        tags: [],
        templateId: 'blank',
        rows: [],
      ).withCover(cover).withCover(null);
      expect(c.cover, isNull);
      expect(c.style.isEmpty, isTrue);
    });
  });

  group('equality', () {
    const base = CheatsheetCard(
      id: 'c1',
      title: 'T',
      walletGroup: 'Ungrouped',
      tags: [],
      templateId: 'blank',
      rows: [CheatsheetRow(label: 'A', source: null)],
    );

    test('style, cover, extras and row emoji are part of the value', () {
      expect(base.copyWith(style: const CardStyle({'theme': 'red'})),
          isNot(base));
      expect(base.withCover(cover), isNot(base));
      expect(base.copyWith(extraFields: const {'x': 1}), isNot(base));
      expect(
          base.copyWith(rows: [base.rows.single.copyWith(emoji: '⭐')]),
          isNot(base));
      expect(base.copyWith(), base);
      expect(base.copyWith().hashCode, base.hashCode);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/data/cheatsheet_codec_look_test.dart`
Expected: compilation fails — `The named parameter 'attachments' isn't defined`, `The getter 'look' isn't defined for the type 'CheatsheetCard'`, `The method 'withCover' isn't defined`.

- [ ] **Step 3: Replace `cheatsheet_row.dart`**

Replace the whole of `lib/features/cheatsheet/domain/entities/cheatsheet_row.dart` with:

```dart
import 'card_style.dart';
import 'cheatsheet_source.dart';

/// One labelled line of a cheatsheet card.
///
/// A row may be **unbound** ([source] is null) — the designer allows saving a
/// partially bound card, and the detail screen renders an unbound row as a
/// muted placeholder rather than an error.
class CheatsheetRow {
  const CheatsheetRow({
    required this.label,
    required this.source,
    this.valueAction = ValueAction.none,
    this.openSource = true,
    this.emoji,
    this.extraFields = const {},
  });

  final String label;

  /// Null = unbound.
  final CheatsheetSource? source;

  /// Explicit — see [ValueAction]. Never inferred.
  final ValueAction valueAction;

  /// Whether the detail screen offers "open the source note".
  final bool openSource;

  /// Shown beside the label in the Key points layout. Stored as typed, valid
  /// or not; rendering checks it with `isSingleEmoji`.
  final String? emoji;

  /// Row keys this version does not model, written back unchanged so a save
  /// cannot destroy what a newer client stored.
  final Map<String, dynamic> extraFields;

  bool get isBound => source != null;

  /// Pass [clearSource] to unbind and [clearEmoji] to drop the emoji — a null
  /// argument can't express "remove" because null already means "leave
  /// unchanged".
  CheatsheetRow copyWith({
    String? label,
    CheatsheetSource? source,
    bool clearSource = false,
    ValueAction? valueAction,
    bool? openSource,
    String? emoji,
    bool clearEmoji = false,
    Map<String, dynamic>? extraFields,
  }) =>
      CheatsheetRow(
        label: label ?? this.label,
        source: clearSource ? null : (source ?? this.source),
        valueAction: valueAction ?? this.valueAction,
        openSource: openSource ?? this.openSource,
        emoji: clearEmoji ? null : (emoji ?? this.emoji),
        extraFields: extraFields ?? this.extraFields,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheatsheetRow &&
        other.label == label &&
        other.source == source &&
        other.valueAction == valueAction &&
        other.openSource == openSource &&
        other.emoji == emoji &&
        jsonValueEquals(other.extraFields, extraFields);
  }

  @override
  int get hashCode => Object.hash(label, source, valueAction, openSource,
      emoji, jsonValueHash(extraFields));

  @override
  String toString() => 'CheatsheetRow(label: $label, source: $source, '
      'valueAction: ${valueAction.name}, openSource: $openSource, '
      'emoji: ${emoji != null}, extraKeys: ${extraFields.keys.toList()})';
}
```

- [ ] **Step 4: Replace `cheatsheet_card.dart`**

Replace the whole of `lib/features/cheatsheet/domain/entities/cheatsheet_card.dart` with:

```dart
import '../../../../core/data/attachments/attachment_ref.dart';
import 'card_style.dart';
import 'cheatsheet_row.dart';

/// A read-only "wallet" card: a titled, grouped list of labelled rows, each
/// referencing a piece of some note.
///
/// Persisted as an `HmmNote`'s content under the `Hmm.CheatsheetMan.Cheatsheet`
/// catalog; see `LocalCheatsheetRepository`. Deliberately absent in v1:
/// `quickAccess` (the Quick Access Panel is an action-button registry, not a
/// card surface) and `sortOrder`/user reordering — the wallet orders
/// deterministically by title then id instead.
class CheatsheetCard {
  const CheatsheetCard({
    required this.id,
    required this.title,
    required this.walletGroup,
    required this.tags,
    required this.templateId,
    required this.rows,
    this.protected = false,
    this.unreadableRows = const [],
    this.style = CardStyle.empty,
    this.cover,
    this.extraFields = const {},
  });

  /// Stable v4 UUID minted once at create time and never regenerated on edit.
  /// Also the note's subject (`Cheatsheet:{id}`), so it must not track the
  /// mutable, non-unique [title].
  final String id;

  final String title;
  final String walletGroup;
  final List<String> tags;
  final String templateId;

  /// Phase-2 reserved (biometric/PIN gating). Not surfaced in any v1 UI. A
  /// protected card's cover is stored as a sensitive attachment.
  final bool protected;

  final List<CheatsheetRow> rows;

  /// Rows the codec could not decode, kept verbatim.
  ///
  /// Saving rewrites the whole card, so a row dropped at read time would be
  /// erased by the next unrelated edit. Carrying the raw maps through means a
  /// save can't destroy data this version didn't understand — a newer client,
  /// or a fixed decoder, can still read them.
  final List<Map<String, dynamic>> unreadableRows;

  /// The stored look (raw; see [CardStyle]). Empty for a card whose look was
  /// never changed — it renders its template default.
  final CardStyle style;

  /// Read-through projection of the cover attachment in the owning note's
  /// `attachments` column, matched by `style.cover`. Null when there is no
  /// cover or its ref is not in the column. The bytes are NEVER referenced
  /// from content: `VaultGc` reads only the attachments column.
  final VaultRef? cover;

  /// Card keys this version does not model, written back unchanged.
  final Map<String, dynamic> extraFields;

  /// What the card renders with: [style] where valid, template defaults
  /// everywhere else.
  CardLook get look => style.resolve(templateId);

  /// Sets or clears the cover, keeping `style.cover` and [cover] in step.
  CheatsheetCard withCover(VaultRef? ref) => copyWith(
        style: style.withCoverPath(ref?.path),
        cover: ref,
        clearCover: ref == null,
      );

  CheatsheetCard copyWith({
    String? id,
    String? title,
    String? walletGroup,
    List<String>? tags,
    String? templateId,
    bool? protected,
    List<CheatsheetRow>? rows,
    List<Map<String, dynamic>>? unreadableRows,
    CardStyle? style,
    VaultRef? cover,
    bool clearCover = false,
    Map<String, dynamic>? extraFields,
  }) =>
      CheatsheetCard(
        id: id ?? this.id,
        title: title ?? this.title,
        walletGroup: walletGroup ?? this.walletGroup,
        tags: tags ?? this.tags,
        templateId: templateId ?? this.templateId,
        protected: protected ?? this.protected,
        rows: rows ?? this.rows,
        unreadableRows: unreadableRows ?? this.unreadableRows,
        style: style ?? this.style,
        cover: clearCover ? null : (cover ?? this.cover),
        extraFields: extraFields ?? this.extraFields,
      );

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheatsheetCard &&
        other.id == id &&
        other.title == title &&
        other.walletGroup == walletGroup &&
        other.templateId == templateId &&
        other.protected == protected &&
        _sameList(other.tags, tags) &&
        _sameList(other.rows, rows) &&
        // Part of the value: two cards are not the same card if one carries
        // rows this version couldn't parse and the other doesn't.
        _sameMapList(other.unreadableRows, unreadableRows) &&
        other.style == style &&
        other.cover == cover &&
        jsonValueEquals(other.extraFields, extraFields);
  }

  static bool _sameMapList(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (final entry in a[i].entries) {
        if (!b[i].containsKey(entry.key) || b[i][entry.key] != entry.value) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        walletGroup,
        templateId,
        protected,
        Object.hashAll(tags),
        Object.hashAll(rows),
        unreadableRows.length,
        style,
        cover,
        jsonValueHash(extraFields),
      );

  @override
  String toString() => 'CheatsheetCard(id: $id, title: $title, '
      'walletGroup: $walletGroup, tags: $tags, templateId: $templateId, '
      'protected: $protected, rows: ${rows.length}, '
      'unreadableRows: ${unreadableRows.length}, style: $style, '
      'cover: ${cover != null}, extraKeys: ${extraFields.keys.toList()})';
}
```

- [ ] **Step 5: Replace `cheatsheet_codec.dart`**

Replace the whole of `lib/features/cheatsheet/data/cheatsheet_codec.dart` with:

```dart
import 'package:flutter/foundation.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../domain/entities/card_style.dart';
import '../domain/entities/cheatsheet_card.dart';
import '../domain/entities/cheatsheet_row.dart';
import '../domain/entities/cheatsheet_source.dart';

/// Card <-> JSON map. The map is what `LocalCheatsheetRepository` nests under
/// the note-content envelope, so it is **persisted data**: decode defensively.
///
/// Rules that hold the line against data loss:
/// * a malformed *row* is dropped on its own — never the whole card;
/// * every scalar read is type-checked and falls back to a default rather
///   than throwing, so a serializer change or a hand-edited note degrades to
///   a partial card instead of an invisible one;
/// * keys this version does not model — on the card, on a row, inside
///   `style` — are carried through and written back unchanged;
/// * the write order is fixed (known keys, then `style`, then unknown keys),
///   so a card read and saved without edits is byte-identical. The backend
///   serializer writes the same order.
class CheatsheetCodec {
  /// Bump when the persisted shape changes incompatibly, and branch on
  /// [schemaVersionOf] here. v1 is the only known shape today; newer versions
  /// decode best-effort through the defensive readers below. `style` and row
  /// `emoji` are optional additions to v1, not a new version: an older reader
  /// that ignores them still reads the card.
  static const currentSchemaVersion = 1;

  static const _styleKey = 'style';
  static const _emojiKey = 'emoji';
  static const _cardKeys = {
    'schemaVersion',
    'id',
    'title',
    'walletGroup',
    'tags',
    'templateId',
    'protected',
    'rows',
  };
  static const _rowKeys = {'label', 'valueAction', 'openSource', 'source'};

  static int schemaVersionOf(Map<String, dynamic> m) =>
      (m['schemaVersion'] as num?)?.toInt() ?? 1;

  static Map<String, dynamic> toMap(CheatsheetCard c) => {
        'schemaVersion': currentSchemaVersion,
        'id': c.id,
        'title': c.title,
        'walletGroup': c.walletGroup,
        'tags': c.tags,
        'templateId': c.templateId,
        'protected': c.protected,
        // Unreadable rows are written back untouched: a save must not destroy
        // rows this version couldn't parse.
        'rows': [
          ...c.rows.map(_rowToMap),
          ...c.unreadableRows,
        ],
        if (!c.style.isEmpty) _styleKey: c.style.toMap(),
        for (final e in c.extraFields.entries)
          // A preserved non-map `style` yields to a real one the user set.
          if (!_cardKeys.contains(e.key) &&
              !(e.key == _styleKey && !c.style.isEmpty))
            e.key: e.value,
      };

  /// [attachments] is the owning note's attachments column; the cover is the
  /// vault ref there whose path `style.cover` names. Without it (or without a
  /// match) the card has no cover but keeps the stored path.
  static CheatsheetCard fromMap(
    Map<String, dynamic> m, {
    NoteAttachments? attachments,
  }) {
    final rows = <CheatsheetRow>[];
    final unreadable = <Map<String, dynamic>>[];
    var index = 0;
    for (final e in _list(m['rows'])) {
      try {
        rows.add(_rowFromMap((e as Map).cast<String, dynamic>()));
      } catch (err) {
        // Keep, don't drop. One bad row must never lose the whole card — and
        // must not be silently erased by the next save either.
        final kept = e is Map;
        if (kept) unreadable.add(e.cast<String, dynamic>());
        debugPrint(
          'CheatsheetCodec: card ${_str(m['id'])} row $index is unreadable '
          '(${err.runtimeType}); ${kept ? 'preserved verbatim and re-saved untouched' : 'dropped — not a map'}.',
        );
      }
      index++;
    }

    final rawStyle = m[_styleKey];
    final style = rawStyle is Map
        ? CardStyle(Map<String, dynamic>.of(rawStyle.cast<String, dynamic>()))
        : CardStyle.empty;

    return CheatsheetCard(
      unreadableRows: unreadable,
      id: _str(m['id']) ?? '',
      title: _str(m['title']) ?? '',
      walletGroup: _str(m['walletGroup']) ?? 'Ungrouped',
      tags: _list(m['tags']).whereType<String>().toList(),
      templateId: _str(m['templateId']) ?? 'blank',
      protected: _bool(m['protected']) ?? false,
      rows: rows,
      style: style,
      cover: _coverFrom(style.coverPath, attachments),
      extraFields: {
        for (final e in m.entries)
          // A non-map `style` is not consumed: it rides along as an unknown.
          if (!_cardKeys.contains(e.key) &&
              !(e.key == _styleKey && rawStyle is Map))
            e.key: e.value,
      },
    );
  }

  static VaultRef? _coverFrom(String? path, NoteAttachments? a) {
    if (path == null || a == null) return null;
    final refs = <AttachmentRef?>[a.primaryImage, ...a.images, ...a.files];
    for (final r in refs) {
      if (r is VaultRef && r.path == path) return r;
    }
    return null;
  }

  /// `as List?` would throw on a non-list; persisted data may hold anything.
  static List<Object?> _list(Object? v) => v is List ? v : const [];

  static String? _str(Object? v) => v is String ? v : null;

  static bool? _bool(Object? v) => v is bool ? v : null;

  static Map<String, dynamic> _rowToMap(CheatsheetRow r) => {
        'label': r.label,
        'valueAction': r.valueAction.name,
        'openSource': r.openSource,
        if (r.source != null) 'source': _srcToMap(r.source!),
        if (r.emoji != null) _emojiKey: r.emoji,
        for (final e in r.extraFields.entries)
          if (!_rowKeys.contains(e.key) &&
              !(e.key == _emojiKey && r.emoji != null))
            e.key: e.value,
      };

  static CheatsheetRow _rowFromMap(Map<String, dynamic> m) {
    final rawEmoji = m[_emojiKey];
    return CheatsheetRow(
      label: _str(m['label']) ?? '',
      source: m['source'] == null
          ? null
          // A non-map source throws here, dropping just this row.
          : _srcFromMap((m['source'] as Map).cast<String, dynamic>()),
      valueAction: m['valueAction'] == null
          ? ValueAction.none
          // An unrecognised value throws, so the row is preserved verbatim
          // rather than silently normalised to a different action.
          : ValueAction.values.firstWhere((v) => v.name == m['valueAction']),
      openSource: _bool(m['openSource']) ?? true,
      emoji: rawEmoji is String ? rawEmoji : null,
      extraFields: {
        for (final e in m.entries)
          // A non-string emoji is not consumed, so it survives as an unknown.
          if (!_rowKeys.contains(e.key) &&
              !(e.key == _emojiKey && rawEmoji is String))
            e.key: e.value,
      },
    );
  }

  static Map<String, dynamic> _srcToMap(CheatsheetSource s) => {
        'noteUuid': s.noteUuid,
        'kind': s.kind.name,
        if (s.locator != null) 'locator': s.locator,
      };

  static CheatsheetSource _srcFromMap(Map<String, dynamic> m) =>
      CheatsheetSource(
        noteUuid: _str(m['noteUuid']) ?? '',
        kind: m['kind'] == null
            ? SourceGranularity.whole
            // An unrecognised kind throws, so the row is preserved verbatim.
            : SourceGranularity.values.firstWhere((k) => k.name == m['kind']),
        locator: _str(m['locator']),
      );
}
```

- [ ] **Step 6: Run the new test and the existing cheatsheet suite**

Run: `flutter test test/features/cheatsheet/data/cheatsheet_codec_look_test.dart test/features/cheatsheet/data/cheatsheet_codec_test.dart test/features/cheatsheet/domain/cheatsheet_card_test.dart`
Expected: `All tests passed!` (the existing codec tests are unchanged: unknown row keys are now kept instead of dropped, which none of them asserted against).

Run: `flutter test test/features/cheatsheet test/core/data/local/local_cheatsheet_repository_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Analyze and commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet test/features/cheatsheet
git add lib/features/cheatsheet/domain/entities/cheatsheet_card.dart \
  lib/features/cheatsheet/domain/entities/cheatsheet_row.dart \
  lib/features/cheatsheet/data/cheatsheet_codec.dart \
  test/features/cheatsheet/data/cheatsheet_codec_look_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): persist card style and row emoji, keep unknown keys

style is written only when non-default; unknown card, row and style keys
survive a save; untouched cards stay byte-identical; the cover is projected
from the note's attachments by the path in style.cover.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Cover persistence (local repository + `CheatsheetsState`)

**Files:**
- Modify: `lib/features/cheatsheet/data/i_cheatsheet_repository.dart` (add `noteIdFor`, after line 13)
- Modify: `lib/core/data/local/local_cheatsheet_repository.dart` (imports lines 1-12; `_deserialize` line 45; `saveCard` lines 105-122; `deleteCard` lines 124-128; new `_attachmentsFor`, `noteIdFor`)
- Modify: `lib/features/cheatsheet/data/repositories/cheatsheet_api_repository.dart` (add `noteIdFor` after `deleteCard`, line 60)
- Modify: `lib/features/cheatsheet/states/cheatsheets_state.dart` (whole file, 33 lines → replaced)
- Modify (test fakes only, for the new `save` signature / interface member): `test/features/cheatsheet/states/cheatsheets_state_test.dart` (`_FakeRepo`, lines 10-37), `test/features/cheatsheet/states/cheatsheet_editor_state_test.dart` (`_CapturingCheatsheets`, lines 13-21), `test/features/cheatsheet/presentation/cheatsheet_designer_screen_test.dart` (`_CapturingCheatsheets`, lines 19-33)
- Test: `test/core/data/local/local_cheatsheet_repository_cover_test.dart` (new)
- Test: `test/features/cheatsheet/states/cheatsheets_state_cover_test.dart` (new)

**Interfaces:**
- Consumes: `CheatsheetCard.cover`, `withCover`, `CheatsheetCodec.fromMap(..., attachments:)` (Task 2); `NoteAttachments`, `VaultRef` (`attachment_ref.dart`); `HmmNoteUpdate(attachments:)` patch semantics (`hmm_note_input.dart` lines 71-76: null = don't touch, `NoteAttachments.empty` = clear); `imageAttachmentPickerProvider` / `vaultStoreProvider` (`attachment_providers.dart` lines 134, 156); `IImageAttachmentPicker.persistToVault` (`image_attachment_picker.dart` line 63); `PickedImageBytes` (`image_byte_source.dart` line 11); `dataModeProvider`.
- Produces:
  - `ICheatsheetRepository.noteIdFor(String cardId) → Future<int?>`
  - `CheatsheetsState.save(CheatsheetCard card, {PickedImageBytes? newCover, List<VaultRef> released = const []}) → Future<void>`
  - `CheatsheetsState.remove(String id) → Future<void>` (now also deletes the card's cover bytes)

- [ ] **Step 1: Write the failing repository test**

Create `test/core/data/local/local_cheatsheet_repository_cover_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/vault/vault_gc.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';

// The cover's bytes stay alive only while some note's `attachments` column
// names them — that column is all VaultGc reads. These tests pin that the
// card note's column always holds exactly the current cover and nothing else.
void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository notes;
  late LocalNoteCatalogRepository catalogs;
  late LocalCheatsheetRepository repo;

  const cover = VaultRef(
    path: 'attachments/note-1/cover.jpg',
    contentType: 'image/jpeg',
    byteSize: 100,
  );
  const otherCover = VaultRef(
    path: 'attachments/note-1/other.jpg',
    contentType: 'image/jpeg',
    byteSize: 200,
  );

  const plain = CheatsheetCard(
    id: 'c1',
    title: 'Claim',
    walletGroup: 'Vehicle',
    tags: [],
    templateId: 'accidentClaim',
    rows: [],
  );

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'cover-tester'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    notes = LocalHmmNoteRepository(db, () async => author);
    catalogs = LocalNoteCatalogRepository(db);
    repo = LocalCheatsheetRepository(notes, catalogs);
  });

  tearDown(() async => db.close());

  Future<Note> row() async => (await db.select(db.notes).get()).single;

  Future<int> catalogId() async =>
      (await catalogs.getOrCreateCatalog(cheatsheetCatalogName, '{}')).id;

  String envelope(Map<String, dynamic> card) => jsonEncode({
        'note': {
          'content': {'Cheatsheet': card},
        },
      });

  test('noteIdFor is null before the first save and the note id after',
      () async {
    expect(await repo.noteIdFor('c1'), isNull);
    await repo.saveCard(plain);
    expect(await repo.noteIdFor('c1'), (await row()).id);
  });

  test('the cover ref lives in the attachments column, content holds its path',
      () async {
    await repo.saveCard(plain.withCover(cover));

    expect(await collectReferencedVaultPaths(db), {cover.path});
    final content = (await row()).content!;
    expect(content, contains('"cover":"attachments/note-1/cover.jpg"'));
    expect(content, isNot(contains('byteSize')));
  });

  test('getCard projects the cover from the attachments column', () async {
    await repo.saveCard(plain.withCover(cover));
    final card = await repo.getCard('c1');
    expect(card!.cover, cover);
    expect(card.style.coverPath, cover.path);
  });

  test('replacing the cover leaves only the new one referenced', () async {
    await repo.saveCard(plain.withCover(cover));
    await repo.saveCard(plain.withCover(otherCover));
    expect(await collectReferencedVaultPaths(db), {otherCover.path});
  });

  test('removing the cover clears the column', () async {
    await repo.saveCard(plain.withCover(cover));
    await repo.saveCard(plain.withCover(cover).withCover(null));
    expect(await collectReferencedVaultPaths(db), isEmpty);
    expect((await repo.getCard('c1'))!.cover, isNull);
  });

  test('deleteCard releases the cover so VaultGc no longer counts it',
      () async {
    await repo.saveCard(plain.withCover(cover));
    await repo.deleteCard('c1');

    // deleteNote is a soft delete and VaultGc counts soft-deleted notes, so
    // only an explicit release frees the bytes.
    expect(await collectReferencedVaultPaths(db), isEmpty);
    expect(await repo.getCard('c1'), isNull);
  });

  test('an untouched card is written back byte-identical', () async {
    final stored = envelope({
      'schemaVersion': 1,
      'id': 'c1',
      'title': 'Vim',
      'walletGroup': 'Reference',
      'tags': [],
      'templateId': 'document',
      'protected': false,
      'rows': [
        {
          'label': 'Motions',
          'valueAction': 'none',
          'openSource': true,
          'emoji': '\u{1F440}',
        },
      ],
      'style': {'theme': 'turquoise', 'sparkle': true},
      'future': 1,
    });
    await notes.createNote(HmmNoteCreate(
      subject: cheatsheetSubjectFor('c1'),
      catalogId: await catalogId(),
      content: stored,
    ));

    await repo.saveCard((await repo.getCard('c1'))!);

    expect((await row()).content, stored);
  });

  test('a card saved by an older app version shows no cover and the next '
      'save releases it', () async {
    // An older app rewrote the content without `style` (it did not know the
    // key) and never touched the attachments column, so the cover ref is
    // still there with nothing pointing at it.
    await notes.createNote(HmmNoteCreate(
      subject: cheatsheetSubjectFor('c1'),
      catalogId: await catalogId(),
      content: envelope({
        'schemaVersion': 1,
        'id': 'c1',
        'title': 'Claim',
        'walletGroup': 'Vehicle',
        'tags': [],
        'templateId': 'accidentClaim',
        'protected': false,
        'rows': [],
      }),
      attachments: NoteAttachments(images: const [cover]),
    ));

    final card = (await repo.getCard('c1'))!;
    expect(card.cover, isNull);
    expect(card.look.theme, CardThemeId.blue);

    await repo.saveCard(card.copyWith(title: 'Claim 2'));
    expect(await collectReferencedVaultPaths(db), isEmpty);
  });

  test('a cover path whose attachment is missing keeps its path', () async {
    await notes.createNote(HmmNoteCreate(
      subject: cheatsheetSubjectFor('c1'),
      catalogId: await catalogId(),
      content: envelope({
        'schemaVersion': 1,
        'id': 'c1',
        'title': 'Claim',
        'walletGroup': 'Vehicle',
        'tags': [],
        'templateId': 'accidentClaim',
        'protected': false,
        'rows': [],
        'style': {'cover': 'attachments/note-9/elsewhere.jpg'},
      }),
    ));

    final card = (await repo.getCard('c1'))!;
    expect(card.cover, isNull);
    await repo.saveCard(card);
    expect((await row()).content,
        contains('"cover":"attachments/note-9/elsewhere.jpg"'));
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/core/data/local/local_cheatsheet_repository_cover_test.dart`
Expected: compilation fails — `The method 'noteIdFor' isn't defined for the type 'LocalCheatsheetRepository'`.

- [ ] **Step 3: Add `noteIdFor` to the interface and both repositories**

In `lib/features/cheatsheet/data/i_cheatsheet_repository.dart`, after `Future<void> deleteCard(String id);` (line 13) add:

```dart

  /// The local int id of the note that stores card [cardId], or null when
  /// there is none yet — or when this store has no local notes at all
  /// (cloudApi). Vault paths are keyed by note id, so a cover can only be
  /// written once this answers non-null.
  Future<int?> noteIdFor(String cardId);
```

In `lib/features/cheatsheet/data/repositories/cheatsheet_api_repository.dart`, after the `deleteCard` method (ends line 60) add:

```dart

  /// `/v1/cheatsheets` exposes neither the backing note id nor its
  /// attachments column, so covers are not available in cloudApi mode (the
  /// designer hides them). A `style.cover` written elsewhere passes through.
  @override
  Future<int?> noteIdFor(String cardId) async => null;
```

- [ ] **Step 4: Rewrite the local repository's persistence**

In `lib/core/data/local/local_cheatsheet_repository.dart`:

Add to the imports (after `import '../../../features/notes/data/models/hmm_note.dart';`, line 9):

```dart
import '../attachments/attachment_ref.dart';
```

Replace `_deserialize`'s decode call (line 45, `return CheatsheetCodec.fromMap(data.cast<String, dynamic>());`) with:

```dart
        return CheatsheetCodec.fromMap(
          data.cast<String, dynamic>(),
          attachments: note!.effectiveAttachments,
        );
```

After `String _serialize(CheatsheetCard c) => ...;` (ends line 36) add:

```dart

  /// The cover's bytes are referenced from the note's `attachments` column —
  /// the only column `VaultGc` reads when deciding what is live — and content
  /// records just its path (`style.cover`). The column belongs to the cover
  /// alone, so writing it whole on every save also releases a replaced or
  /// removed cover.
  NoteAttachments _attachmentsFor(CheatsheetCard c) {
    final cover = c.cover;
    return cover == null
        ? NoteAttachments.empty
        : NoteAttachments(images: [cover]);
  }
```

Replace `saveCard` and `deleteCard` (lines 105-128) with:

```dart
  @override
  Future<CheatsheetCard> saveCard(CheatsheetCard card) async {
    final subject = cheatsheetSubjectFor(card.id);
    final existing = await _noteForCard(card.id);
    // `attachments` is passed on BOTH paths: omitting it on update leaves the
    // previous set in place, so a replaced or removed cover would keep its
    // bytes alive forever.
    if (existing == null) {
      await _notes.createNote(HmmNoteCreate(
        subject: subject,
        catalogId: await _catalogId(),
        content: _serialize(card),
        attachments: _attachmentsFor(card),
      ));
    } else {
      await _notes.updateNote(
        existing.id,
        HmmNoteUpdate(
          subject: subject,
          content: _serialize(card),
          attachments: _attachmentsFor(card),
        ),
      );
    }
    return card;
  }

  @override
  Future<void> deleteCard(String id) async {
    final n = await _noteForCard(id);
    if (n == null) return;
    // deleteNote is a soft delete, and VaultGc deliberately counts a
    // tombstoned note's attachments as live. Release the cover first, or
    // deleting a card would pin its photo in the vault forever.
    if (n.effectiveAttachments.isNotEmpty) {
      await _notes.updateNote(
        n.id,
        HmmNoteUpdate(attachments: NoteAttachments.empty),
      );
    }
    await _notes.deleteNote(n.id);
  }

  @override
  Future<int?> noteIdFor(String cardId) async =>
      (await _noteForCard(cardId))?.id;
```

- [ ] **Step 5: Update the existing fake repository so the suite compiles**

In `test/features/cheatsheet/states/cheatsheets_state_test.dart`, inside `_FakeRepo` after `Future<void> deleteCard(String id) async => _cards.remove(id);` (line 36) add:

```dart

  @override
  Future<int?> noteIdFor(String cardId) async => null;
```

- [ ] **Step 6: Run the repository tests to see them pass**

Run: `flutter test test/core/data/local/local_cheatsheet_repository_cover_test.dart test/core/data/local/local_cheatsheet_repository_test.dart test/features/cheatsheet/data/cheatsheet_cross_device_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Write the failing state test**

Create `test/features/cheatsheet/states/cheatsheets_state_cover_test.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/vault/vault_gc.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';

class _MemVault implements IVaultStore {
  final files = <String, Uint8List>{};

  @override
  Future<void> putBytes(String relativePath, Uint8List bytes,
      {String? contentType}) async {
    files[relativePath] = bytes;
  }

  @override
  Future<Uint8List> getBytes(String relativePath) async {
    final b = files[relativePath];
    if (b == null) throw VaultStoreException('missing', relativePath);
    return b;
  }

  @override
  Future<bool> exists(String relativePath) async =>
      files.containsKey(relativePath);

  @override
  Future<void> delete(String relativePath) async {
    files.remove(relativePath);
  }

  @override
  Future<List<VaultEntry>> list(String prefix) async => [
        for (final e in files.entries)
          if (e.key.startsWith(prefix))
            VaultEntry(relativePath: e.key, byteSize: e.value.length),
      ]..sort((a, b) => a.relativePath.compareTo(b.relativePath));
}

class _Mode extends DataModeNotifier {
  _Mode(this.mode);
  final DataMode mode;
  @override
  DataMode build() => mode;
}

/// A vault store that must never be touched.
class _NoVault implements IVaultStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('vault touched: ${invocation.memberName}');
}

void main() {
  late HmmDatabase db;
  late LocalCheatsheetRepository repo;
  late _MemVault vault;

  final png = Uint8List.fromList(List<int>.generate(64, (i) => i));
  PickedImageBytes pick() =>
      PickedImageBytes(bytes: png, originalName: 'c.png', contentType: 'image/png');

  const plain = CheatsheetCard(
    id: 'c1',
    title: 'Claim',
    walletGroup: 'Vehicle',
    tags: [],
    templateId: 'accidentClaim',
    rows: [],
  );

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'state-cover'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    final notes = LocalHmmNoteRepository(db, () async => author);
    repo = LocalCheatsheetRepository(notes, LocalNoteCatalogRepository(db));
    vault = _MemVault();
  });

  tearDown(() async => db.close());

  ProviderContainer container({
    DataMode mode = DataMode.local,
    IVaultStore? store,
  }) {
    final s = store ?? vault;
    final c = ProviderContainer(overrides: [
      cheatsheetRepositoryModeProvider.overrideWithValue(repo),
      dataModeProvider.overrideWith(() => _Mode(mode)),
      vaultStoreProvider.overrideWith((ref) async => s),
      imageAttachmentPickerProvider.overrideWith(
          (ref) async => VaultImageAttachmentPicker(vaultStore: s)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('a new card with a cover: bytes in the vault, ref in the column',
      () async {
    final c = container();
    await c.read(cheatsheetsStateProvider.notifier).save(plain, newCover: pick());

    final saved = (await repo.getCard('c1'))!;
    final ref = saved.cover!;
    expect(ref.path, startsWith('attachments/note-'));
    expect(ref.sensitive, isFalse);
    expect(vault.files.keys, [ref.path]);
    expect(await collectReferencedVaultPaths(db), {ref.path});
    expect(saved.style.coverPath, ref.path);
  });

  test('replacing a cover deletes the old bytes after the save', () async {
    final c = container();
    final state = c.read(cheatsheetsStateProvider.notifier);
    await state.save(plain, newCover: pick());
    final first = (await repo.getCard('c1'))!;

    await state.save(first.withCover(null),
        newCover: pick(), released: [first.cover!]);

    final second = (await repo.getCard('c1'))!.cover!;
    expect(second.path, isNot(first.cover!.path));
    expect(vault.files.keys, [second.path]);
    expect(await collectReferencedVaultPaths(db), {second.path});
  });

  test('removing a cover releases the attachment and deletes its bytes',
      () async {
    final c = container();
    final state = c.read(cheatsheetsStateProvider.notifier);
    await state.save(plain, newCover: pick());
    final withCover = (await repo.getCard('c1'))!;

    await state.save(withCover.withCover(null), released: [withCover.cover!]);

    expect(vault.files, isEmpty);
    expect(await collectReferencedVaultPaths(db), isEmpty);
  });

  test('removing a card deletes its cover bytes', () async {
    final c = container();
    final state = c.read(cheatsheetsStateProvider.notifier);
    await state.save(plain, newCover: pick());

    await state.remove('c1');

    expect(vault.files, isEmpty);
    expect(await collectReferencedVaultPaths(db), isEmpty);
    expect(await repo.getCard('c1'), isNull);
  });

  test('a protected card stores its cover as sensitive', () async {
    final c = container();
    await c
        .read(cheatsheetsStateProvider.notifier)
        .save(plain.copyWith(protected: true), newCover: pick());
    expect((await repo.getCard('c1'))!.cover!.sensitive, isTrue);
  });

  test('cloudApi mode never deletes vault bytes', () async {
    const stale = VaultRef(
      path: 'attachments/note-1/old.jpg',
      contentType: 'image/jpeg',
      byteSize: 3,
    );
    vault.files[stale.path] = Uint8List(3);
    final c = container(mode: DataMode.cloudApi);

    await c
        .read(cheatsheetsStateProvider.notifier)
        .save(plain, released: const [stale]);

    expect(vault.files.keys, [stale.path]);
  });

  test('a card without a cover never touches the vault', () async {
    final c = container(store: _NoVault());
    final state = c.read(cheatsheetsStateProvider.notifier);
    await state.save(plain);
    await state.remove('c1');
    expect(await repo.getCard('c1'), isNull);
  });
}
```

- [ ] **Step 8: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/states/cheatsheets_state_cover_test.dart`
Expected: compilation fails — `No named parameter with the name 'newCover'`.

- [ ] **Step 9: Replace `cheatsheets_state.dart`**

Replace the whole of `lib/features/cheatsheet/states/cheatsheets_state.dart` with:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/data_mode.dart';
import '../../../core/data/repository_providers.dart';
import '../domain/entities/cheatsheet_card.dart';

/// The wallet's card list.
///
/// Mutations write through the repository and then invalidate, so the list is
/// always re-read from storage rather than patched in memory — the repository
/// upserts by card id, and mirroring that merge logic here is how the two
/// would drift apart.
///
/// The repository is pure persistence, so the vault work for covers —
/// writing picked bytes, deleting released ones — happens here, the same
/// split `DriverLicenceState` uses.
class CheatsheetsState extends AsyncNotifier<List<CheatsheetCard>> {
  @override
  Future<List<CheatsheetCard>> build() =>
      ref.read(cheatsheetRepositoryModeProvider).getCards();

  /// Saves [card]. [newCover] is a picked image to store as the cover;
  /// [released] are covers the edit dropped, deleted only after the write
  /// lands so a failed save never leaves the card pointing at missing bytes.
  Future<void> save(
    CheatsheetCard card, {
    PickedImageBytes? newCover,
    List<VaultRef> released = const [],
  }) async {
    final repo = ref.read(cheatsheetRepositoryModeProvider);
    var next = card;
    if (newCover != null) {
      // Vault paths are keyed by note id, so a brand-new card's note has to
      // exist before its cover can be written.
      var noteId = await repo.noteIdFor(card.id);
      if (noteId == null) {
        await repo.saveCard(card);
        noteId = await repo.noteIdFor(card.id);
      }
      if (noteId == null) {
        throw StateError('card ${card.id} has no note to hold a cover');
      }
      final picker = await ref.read(imageAttachmentPickerProvider.future);
      final cover = await picker.persistToVault(
        noteId: noteId,
        bytes: newCover.bytes,
        originalName: newCover.originalName,
        contentTypeHint: newCover.contentType,
        sensitive: card.protected,
      );
      next = card.withCover(cover);
    }
    await repo.saveCard(next);
    await _release(released);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    final repo = ref.read(cheatsheetRepositoryModeProvider);
    final cover = (await repo.getCard(id))?.cover;
    await repo.deleteCard(id);
    if (cover != null) await _release([cover]);
    ref.invalidateSelf();
  }

  void refresh() => ref.invalidateSelf();

  /// Best effort: the refs are already gone from the attachments column, so
  /// a failed delete leaves unreferenced bytes that VaultGc reclaims — never
  /// a broken card. cloudApi keeps bytes server-side and is skipped.
  Future<void> _release(List<VaultRef> refs) async {
    if (refs.isEmpty) return;
    if (ref.read(dataModeProvider) == DataMode.cloudApi) return;
    try {
      final store = await ref.read(vaultStoreProvider.future);
      for (final r in refs) {
        await store.delete(r.path);
      }
    } catch (e) {
      // Type only: the error can quote the vault path.
      debugPrint('CheatsheetsState: releasing ${refs.length} cover file(s) '
          'failed (${e.runtimeType}); VaultGc will reclaim them.');
    }
  }
}

final cheatsheetsStateProvider =
    AsyncNotifierProvider<CheatsheetsState, List<CheatsheetCard>>(
  () => CheatsheetsState(),
);
```

- [ ] **Step 10: Update the two `save` overrides in existing tests**

In `test/features/cheatsheet/states/cheatsheet_editor_state_test.dart` add the imports

```dart
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
```

and replace `_CapturingCheatsheets` (lines 13-21) with:

```dart
class _CapturingCheatsheets extends CheatsheetsState {
  static final saved = <CheatsheetCard>[];
  static final covers = <PickedImageBytes?>[];
  static final releases = <List<VaultRef>>[];

  @override
  Future<List<CheatsheetCard>> build() async => const [];

  @override
  Future<void> save(
    CheatsheetCard card, {
    PickedImageBytes? newCover,
    List<VaultRef> released = const [],
  }) async {
    saved.add(card);
    covers.add(newCover);
    releases.add(released);
  }
}
```

In `test/features/cheatsheet/presentation/cheatsheet_designer_screen_test.dart` add the same two imports and replace the `save` override inside `_CapturingCheatsheets` (lines 29-33) with:

```dart
  @override
  Future<void> save(
    CheatsheetCard card, {
    PickedImageBytes? newCover,
    List<VaultRef> released = const [],
  }) async {
    if (saveError != null) throw saveError!;
    saved.add(card);
  }
```

- [ ] **Step 11: Run the new and affected tests**

Run: `flutter test test/features/cheatsheet/states test/features/cheatsheet/presentation test/features/cheatsheet/cheatsheet_acceptance_test.dart test/core/data/local test/core/navigation/cheatsheet_routes_test.dart`
Expected: `All tests passed!`

- [ ] **Step 12: Analyze and commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet lib/core/data/local test/features/cheatsheet test/core/data/local
git add lib/features/cheatsheet/data/i_cheatsheet_repository.dart \
  lib/core/data/local/local_cheatsheet_repository.dart \
  lib/features/cheatsheet/data/repositories/cheatsheet_api_repository.dart \
  lib/features/cheatsheet/states/cheatsheets_state.dart \
  test/core/data/local/local_cheatsheet_repository_cover_test.dart \
  test/features/cheatsheet/states/cheatsheets_state_cover_test.dart \
  test/features/cheatsheet/states/cheatsheets_state_test.dart \
  test/features/cheatsheet/states/cheatsheet_editor_state_test.dart \
  test/features/cheatsheet/presentation/cheatsheet_designer_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): store a card cover on the card note's attachments

The cover ref lives in the attachments column VaultGc reads; content keeps
only its path. Replace, remove and delete release it (delete explicitly,
since soft-deleted notes still pin their attachments).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Backend pass-through for `Style` and row `Emoji` (Hmm repo)

All paths in this task are under `/Users/fchy/Projects/hmm`. Before any change, create and switch to the feature branch from `main`: `git -C /Users/fchy/Projects/hmm switch -c feat/cheatsheet-style-passthrough main` (if the branch already exists, `git -C /Users/fchy/Projects/hmm switch feat/cheatsheet-style-passthrough`), then confirm `git -C /Users/fchy/Projects/hmm branch --show-current` prints `feat/cheatsheet-style-passthrough`. Every test run and the commit in this task happen on that branch — never commit on `main`. Switching branches carries the repo's unrelated uncommitted `CLAUDE.md` change along untouched — leave it unstaged and never stage it.

**Files:**
- Modify: `src/Hmm.Cheatsheet/DomainEntity/CheatsheetCard.cs` (add `Style` after `Rows`, line 42)
- Modify: `src/Hmm.Cheatsheet/DomainEntity/CheatsheetRow.cs` (add `Emoji` after `Source`, line 24)
- Modify: `src/Hmm.Cheatsheet/NoteSerialize/CheatsheetJsonNoteSerialize.cs` (keys after line 43; card write lines 160-172; `WriteRow` lines 208-235; `CopyExtras` lines 238-251; `ReadCard` lines 293-306; `ReadRow` lines 347-352; new `ReadStyle`)
- Modify: `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheet.cs` (after `Rows`, line 32)
- Modify: `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetForCreate.cs` (after `Rows`, line 28)
- Modify: `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetForUpdate.cs` (after `Rows`, line 26)
- Modify: `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetRow.cs` (after `Source`, line 23)
- Modify: `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetRowConverter.cs` (`WriteJson` after line 44; `ReadJson` initializer lines 83-88)
- Modify: `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/CheatsheetJsonInterop.cs` (two helpers after line 24)
- Modify: `src/Hmm.ServiceApi/Areas/CheatsheetService/Infrastructure/CheatsheetMappingProfile.cs` (card maps, lines 51-76)
- Test: `src/Hmm.Cheatsheet.Tests/CheatsheetStylePassThroughTests.cs` (new)
- Test: `src/Hmm.ServiceApi.Core.Tests/CheatsheetStyleMappingTests.cs` (new)

**Interfaces:**
- Consumes: `CheatsheetJsonNoteSerialize` read/write helpers (`ReadString`, `ReadExtras`, `CopyExtras`), `CheatsheetJsonInterop.ToJToken` / `ToJsonElement`, the existing AutoMapper profile.
- Produces:
  - `CheatsheetCard.Style : JsonElement?` ⇄ note content `"style"` (any JSON kind except null is consumed; written only when present, after `rows`, before extras)
  - `CheatsheetRow.Emoji : string` ⇄ row `"emoji"` (consumed only when a string; written only when non-null, after `source`, before extras)
  - `ApiCheatsheet.Style : JToken` (omitted on the wire when null), `ApiCheatsheetForCreate.Style : JToken`, `ApiCheatsheetForUpdate.Style : JToken` + `StyleSpecified : bool` (absent ⇒ keep stored, explicit null ⇒ clear)
  - `ApiCheatsheetRow.Emoji : string` ⇄ wire `"Emoji"`
  - `CheatsheetJsonInterop.ToJTokenOrNull(JsonElement?) : JToken`, `ToJsonElementOrNull(JToken) : JsonElement?`

- [ ] **Step 1: Write the failing serializer test**

Create `src/Hmm.Cheatsheet.Tests/CheatsheetStylePassThroughTests.cs`:

```csharp
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Hmm.Cheatsheet.DomainEntity;
using Hmm.Cheatsheet.NoteSerialize;
using Hmm.Core.Map.DomainEntity;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Hmm.Cheatsheet.Tests
{
    /// <summary>
    /// The card look is a client concern the server must carry without
    /// interpreting: "style" and row "emoji" in note content map to typed
    /// members so the API can expose them as Style / Emoji, and everything
    /// inside them is passed through verbatim.
    /// </summary>
    public class CheatsheetStylePassThroughTests
    {
        private const string Eyes = "👀";

        private static CheatsheetJsonNoteSerialize CreateSerializer()
        {
            var catalogProvider = new Mock<ICheatsheetCatalogProvider>();
            catalogProvider
                .Setup(p => p.GetCatalogAsync())
                .ReturnsAsync(new NoteCatalog
                {
                    Id = 7,
                    Name = CheatsheetConstant.CheatsheetCatalogName,
                    Schema = "{}"
                });

            return new CheatsheetJsonNoteSerialize(
                catalogProvider.Object,
                NullLogger<CheatsheetCard>.Instance);
        }

        private static HmmNote NoteWith(string cardJson)
            => new()
            {
                Id = 42,
                Subject = CheatsheetCard.GetNoteSubject("card-1"),
                Content = "{\"note\":{\"content\":{\"Cheatsheet\":" + cardJson + "}}}",
                Author = new Author { Id = 9 }
            };

        private static JsonElement CardElementOf(string noteJson)
        {
            using var document = JsonDocument.Parse(noteJson);
            return document.RootElement
                .GetProperty("note")
                .GetProperty("content")
                .GetProperty("Cheatsheet")
                .Clone();
        }

        private static JsonElement Raw(string json)
        {
            using var document = JsonDocument.Parse(json);
            return document.RootElement.Clone();
        }

        private static async Task<CheatsheetCard> ReadAsync(string cardJson)
        {
            var result = await CreateSerializer().GetEntity(NoteWith(cardJson));
            Assert.True(result.Success, result.ErrorMessage);
            return result.Value;
        }

        private const string StyledCard =
            "{\"schemaVersion\":1,\"id\":\"card-1\",\"title\":\"Vim\",\"walletGroup\":\"Reference\"," +
            "\"tags\":[],\"templateId\":\"document\",\"protected\":false," +
            "\"rows\":[{\"label\":\"Motions\",\"valueAction\":\"none\",\"openSource\":true,\"emoji\":\"" + Eyes + "\"}]," +
            "\"style\":{\"theme\":\"turquoise\",\"pattern\":\"dots\",\"sparkle\":{\"a\":[1,2]}}," +
            "\"future\":1}";

        [Fact]
        public async Task Read_Style_IsTypedNotAnExtra()
        {
            var card = await ReadAsync(StyledCard);

            Assert.True(card.Style.HasValue);
            Assert.Equal("turquoise", card.Style.Value.GetProperty("theme").GetString());
            Assert.False(card.ExtraFields.ContainsKey("style"));
            Assert.True(card.ExtraFields.ContainsKey("future"));
        }

        [Fact]
        public async Task Write_Style_IsEmittedVerbatim_IncludingUnknownKeys()
        {
            var serializer = CreateSerializer();
            var card = await ReadAsync(StyledCard);

            var style = CardElementOf(serializer.GetNoteSerializationText(card)).GetProperty("style");

            Assert.Equal("turquoise", style.GetProperty("theme").GetString());
            Assert.Equal("dots", style.GetProperty("pattern").GetString());
            Assert.Equal(2, style.GetProperty("sparkle").GetProperty("a")[1].GetInt32());
        }

        [Fact]
        public async Task Write_KeyOrder_IsRowsThenStyleThenExtras()
        {
            var serializer = CreateSerializer();
            var card = await ReadAsync(StyledCard);

            var names = CardElementOf(serializer.GetNoteSerializationText(card))
                .EnumerateObject().Select(p => p.Name).ToList();

            Assert.Equal(
                new[] { "schemaVersion", "id", "title", "walletGroup", "tags", "templateId", "protected", "rows", "style", "future" },
                names);
        }

        [Fact]
        public void Write_AbsentStyle_IsNotWritten()
        {
            var card = new CheatsheetCard { Id = "card-1", Title = "Plain" };

            var json = CardElementOf(CreateSerializer().GetNoteSerializationText(card));

            Assert.False(json.TryGetProperty("style", out _));
        }

        [Fact]
        public async Task ExplicitNullStyle_IsKeptVerbatimAsAnExtra()
        {
            var serializer = CreateSerializer();
            var card = await ReadAsync(
                "{\"id\":\"card-1\",\"title\":\"T\",\"rows\":[],\"style\":null}");

            Assert.False(card.Style.HasValue);
            var written = CardElementOf(serializer.GetNoteSerializationText(card));
            Assert.Equal(JsonValueKind.Null, written.GetProperty("style").ValueKind);
        }

        [Fact]
        public void ATypedStyle_BeatsAPreservedNullStyle()
        {
            var card = new CheatsheetCard
            {
                Id = "card-1",
                Style = Raw("{\"theme\":\"red\"}"),
                ExtraFields = new Dictionary<string, JsonElement> { ["style"] = Raw("null") }
            };

            var json = CardElementOf(CreateSerializer().GetNoteSerializationText(card));

            Assert.Equal("red", json.GetProperty("style").GetProperty("theme").GetString());
        }

        [Fact]
        public async Task RowEmoji_RoundTrips_AndIsNotAnExtra()
        {
            var serializer = CreateSerializer();
            var card = await ReadAsync(StyledCard);

            Assert.Equal(Eyes, card.Rows[0].Emoji);
            Assert.False(card.Rows[0].ExtraFields.ContainsKey("emoji"));
            var row = CardElementOf(serializer.GetNoteSerializationText(card)).GetProperty("rows")[0];
            Assert.Equal(Eyes, row.GetProperty("emoji").GetString());
        }

        [Fact]
        public void AbsentRowEmoji_IsNotWritten()
        {
            var card = new CheatsheetCard
            {
                Id = "card-1",
                Rows = new List<CheatsheetRow> { new() { Label = "A" } }
            };

            var row = CardElementOf(CreateSerializer().GetNoteSerializationText(card)).GetProperty("rows")[0];

            Assert.False(row.TryGetProperty("emoji", out _));
        }

        [Fact]
        public async Task NonStringRowEmoji_IsPreservedAsAnExtra()
        {
            var serializer = CreateSerializer();
            var card = await ReadAsync(
                "{\"id\":\"card-1\",\"rows\":[{\"label\":\"A\",\"emoji\":5}]}");

            Assert.Null(card.Rows[0].Emoji);
            var row = CardElementOf(serializer.GetNoteSerializationText(card)).GetProperty("rows")[0];
            Assert.Equal(5, row.GetProperty("emoji").GetInt32());
        }
    }
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `dotnet test /Users/fchy/Projects/hmm/src/Hmm.Cheatsheet.Tests/Hmm.Cheatsheet.Tests.csproj --filter "FullyQualifiedName~CheatsheetStylePassThroughTests"`
Expected: build fails — `error CS1061: 'CheatsheetCard' does not contain a definition for 'Style'` (and the same for `CheatsheetRow.Emoji`).

- [ ] **Step 3: Add the domain members**

In `src/Hmm.Cheatsheet/DomainEntity/CheatsheetCard.cs`, after `public IList<CheatsheetRow> Rows { get; set; } = new List<CheatsheetRow>();` (line 42) add:

```csharp

        /// <summary>
        /// The card's look ("style" in note content): theme, pattern, icon,
        /// layout, cover path - all client concerns. Passed through verbatim;
        /// the server never interprets it. Null = never styled (nothing written).
        /// </summary>
        public JsonElement? Style { get; set; }
```

In `src/Hmm.Cheatsheet/DomainEntity/CheatsheetRow.cs`, after `public CheatsheetSource Source { get; set; }` (line 24) add:

```csharp

        /// <summary>
        /// Optional emoji the client shows beside the row in its Key points
        /// layout. Verbatim; null = none (nothing written).
        /// </summary>
        public string Emoji { get; set; }
```

- [ ] **Step 4: Read and write them in the serializer**

In `src/Hmm.Cheatsheet/NoteSerialize/CheatsheetJsonNoteSerialize.cs`:

After `private const string KeyLocator = "locator";` (line 43) add:

```csharp
        private const string KeyStyle = "style";
        private const string KeyEmoji = "emoji";
```

Replace `CopyExtras(entity.ExtraFields, cardData);` (line 172) with:

```csharp
                // Typed style sits after rows and before extras - the order the
                // Flutter codec writes, so a card round-trips byte-identical on
                // the client. A typed style beats a preserved raw "style".
                var hasStyle = entity.Style.HasValue &&
                               entity.Style.Value.ValueKind != JsonValueKind.Undefined;
                if (hasStyle)
                {
                    cardData[KeyStyle] = entity.Style.Value;
                }

                CopyExtras(entity.ExtraFields, cardData, hasStyle ? KeyStyle : null);
```

In `WriteRow`, replace `CopyExtras(row.ExtraFields, rowData);` (line 234) with:

```csharp
            if (row.Emoji != null)
            {
                rowData[KeyEmoji] = row.Emoji;
            }

            CopyExtras(row.ExtraFields, rowData, row.Emoji != null ? KeyEmoji : null);
```

Replace the whole `CopyExtras` method (lines 238-251) with:

```csharp
        private static void CopyExtras(
            IDictionary<string, JsonElement> extras,
            IDictionary<string, object> target,
            string skipKey = null)
        {
            if (extras == null)
            {
                return;
            }

            foreach (var extra in extras)
            {
                if (skipKey != null && string.Equals(extra.Key, skipKey, StringComparison.Ordinal))
                {
                    continue;
                }

                target[extra.Key] = extra.Value;
            }
        }
```

In `ReadCard`, add `Style = ReadStyle(cardJson, consumed),` as the last initializer member (after `Rows = ReadRows(cardJson, consumed)` on line 302 — add a comma to that line):

```csharp
                Rows = ReadRows(cardJson, consumed),
                Style = ReadStyle(cardJson, consumed)
```

In `ReadRow`, change the initializer (lines 347-352) to:

```csharp
            var row = new CheatsheetRow
            {
                Label = ReadString(rowJson, KeyLabel, consumed) ?? string.Empty,
                ValueAction = ReadString(rowJson, KeyValueAction, consumed) ?? CheatsheetConstant.ValueActionNone,
                OpenSource = ReadBool(rowJson, KeyOpenSource, true, consumed),
                // Consumed only when a string, like every typed read here: a
                // mistyped emoji falls through to ExtraFields and survives.
                Emoji = ReadString(rowJson, KeyEmoji, consumed)
            };
```

After `ReadSource` (ends line 383) add:

```csharp

        /// <summary>
        /// Any JSON kind except null is consumed into the typed style and
        /// re-emitted verbatim. An explicit null stays in ExtraFields, so it is
        /// written back exactly as stored.
        /// </summary>
        private static JsonElement? ReadStyle(JsonElement cardJson, HashSet<string> consumed)
        {
            if (cardJson.TryGetProperty(KeyStyle, out var property) &&
                property.ValueKind != JsonValueKind.Null)
            {
                consumed.Add(KeyStyle);
                return property.Clone();
            }

            return null;
        }
```

- [ ] **Step 5: Run the serializer tests to see them pass**

Run: `dotnet test /Users/fchy/Projects/hmm/src/Hmm.Cheatsheet.Tests/Hmm.Cheatsheet.Tests.csproj`
Expected: `Passed!  - Failed: 0, Passed: 103` (94 existing + 9 new).

- [ ] **Step 6: Write the failing DTO / mapping test**

Create `src/Hmm.ServiceApi.Core.Tests/CheatsheetStyleMappingTests.cs`:

```csharp
using System.Collections.Generic;
using System.Text.Json;
using AutoMapper;
using Hmm.Cheatsheet.DomainEntity;
using Hmm.ServiceApi.Areas.CheatsheetService.Infrastructure;
using Hmm.ServiceApi.DtoEntity.Cheatsheets;
using Microsoft.Extensions.Logging.Abstractions;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Xunit;

namespace Hmm.ServiceApi.Core.Tests
{
    /// <summary>
    /// Style and Emoji cross the API untouched in every direction. The PUT
    /// rule is the subtle one: an older client that has never heard of Style
    /// must not wipe it, while an explicit null is a deliberate reset.
    /// </summary>
    public class CheatsheetStyleMappingTests
    {
        private const string Eyes = "👀";

        private readonly IMapper _mapper = new MapperConfiguration(
                cfg => cfg.AddProfile<CheatsheetMappingProfile>(),
                NullLoggerFactory.Instance)
            .CreateMapper();

        private static JsonElement Raw(string json)
        {
            using var document = JsonDocument.Parse(json);
            return document.RootElement.Clone();
        }

        private static CheatsheetCard StyledCard() => new()
        {
            NoteId = 42,
            AuthorId = 9,
            Id = "c-1",
            Title = "Vim",
            TemplateId = "document",
            Style = Raw("{\"theme\":\"turquoise\",\"sparkle\":{\"a\":1}}"),
            Rows = new List<CheatsheetRow> { new() { Label = "Motions", Emoji = Eyes } }
        };

        [Fact]
        public void Configuration_IsStillValid()
        {
            new MapperConfiguration(
                    cfg => cfg.AddProfile<CheatsheetMappingProfile>(),
                    NullLoggerFactory.Instance)
                .AssertConfigurationIsValid();
        }

        [Fact]
        public void Card_StyleAndEmoji_ReachTheWireVerbatim()
        {
            var api = _mapper.Map<CheatsheetCard, ApiCheatsheet>(StyledCard());

            var wire = JObject.Parse(JsonConvert.SerializeObject(api));

            Assert.Equal("turquoise", wire["Style"]!["theme"]!.Value<string>());
            Assert.Equal(1, wire["Style"]!["sparkle"]!["a"]!.Value<int>());
            Assert.Equal(Eyes, wire["Rows"]![0]!["Emoji"]!.Value<string>());
        }

        [Fact]
        public void UnstyledCard_OmitsStyleAndEmojiOnTheWire()
        {
            var card = new CheatsheetCard
            {
                Id = "c-2",
                Rows = new List<CheatsheetRow> { new() { Label = "A" } }
            };

            var wire = JObject.Parse(JsonConvert.SerializeObject(
                _mapper.Map<CheatsheetCard, ApiCheatsheet>(card)));

            Assert.Null(wire["Style"]);
            Assert.Null(wire["Rows"]![0]!["Emoji"]);
        }

        [Fact]
        public void ForCreate_FromTheWire_CarriesStyleAndEmoji()
        {
            const string body =
                "{\"Id\":\"c-3\",\"Title\":\"T\",\"Rows\":[{\"Label\":\"A\",\"Emoji\":\"\\uD83D\\uDC40\"}]," +
                "\"Style\":{\"pattern\":\"dots\",\"future\":true}}";
            var dto = JsonConvert.DeserializeObject<ApiCheatsheetForCreate>(body)!;

            var card = _mapper.Map<ApiCheatsheetForCreate, CheatsheetCard>(dto);

            Assert.Equal("dots", card.Style!.Value.GetProperty("pattern").GetString());
            Assert.True(card.Style.Value.GetProperty("future").GetBoolean());
            Assert.Equal(Eyes, card.Rows[0].Emoji);
            Assert.False(card.ExtraFields.ContainsKey("Style"));
        }

        [Fact]
        public void ForUpdate_WithoutStyleKey_KeepsTheStoredStyle()
        {
            var stored = StyledCard();
            var dto = JsonConvert.DeserializeObject<ApiCheatsheetForUpdate>("{\"Title\":\"Renamed\"}")!;

            Assert.False(dto.StyleSpecified);
            _mapper.Map(dto, stored);

            Assert.Equal("Renamed", stored.Title);
            Assert.Equal("turquoise", stored.Style!.Value.GetProperty("theme").GetString());
        }

        [Fact]
        public void ForUpdate_WithExplicitNullStyle_ClearsIt()
        {
            var stored = StyledCard();
            var dto = JsonConvert.DeserializeObject<ApiCheatsheetForUpdate>("{\"Title\":\"T\",\"Style\":null}")!;

            Assert.True(dto.StyleSpecified);
            _mapper.Map(dto, stored);

            Assert.False(stored.Style.HasValue);
        }

        [Fact]
        public void ForUpdate_WithAStyle_ReplacesIt()
        {
            var stored = StyledCard();
            var dto = JsonConvert.DeserializeObject<ApiCheatsheetForUpdate>("{\"Style\":{\"theme\":\"red\"}}")!;

            _mapper.Map(dto, stored);

            Assert.Equal("red", stored.Style!.Value.GetProperty("theme").GetString());
            Assert.False(stored.Style.Value.TryGetProperty("sparkle", out _));
        }

        [Fact]
        public void RowConverter_ReadsAndWritesEmoji()
        {
            var row = JsonConvert.DeserializeObject<ApiCheatsheetRow>("{\"Label\":\"A\",\"Emoji\":\"x\"}")!;

            Assert.Equal("x", row.Emoji);
            Assert.False(row.ExtraFields.ContainsKey("Emoji"));
            Assert.Equal("x", JObject.Parse(JsonConvert.SerializeObject(row))["Emoji"]!.Value<string>());
            Assert.Null(JObject.Parse(JsonConvert.SerializeObject(new ApiCheatsheetRow { Label = "B" }))["Emoji"]);
        }

        [Fact]
        public void RowConverter_KeepsANonStringEmojiAsAnExtra()
        {
            var row = JsonConvert.DeserializeObject<ApiCheatsheetRow>("{\"Label\":\"A\",\"Emoji\":5}")!;

            Assert.Null(row.Emoji);
            Assert.Equal(5, row.ExtraFields["Emoji"].Value<int>());
            Assert.Equal(5, JObject.Parse(JsonConvert.SerializeObject(row))["Emoji"]!.Value<int>());
        }
    }
}
```

- [ ] **Step 7: Run it to see it fail**

Run: `dotnet test /Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj --filter "FullyQualifiedName~CheatsheetStyleMappingTests"`
Expected: build fails — `error CS1061: 'ApiCheatsheetForUpdate' does not contain a definition for 'StyleSpecified'` (and `ApiCheatsheetRow.Emoji`).

- [ ] **Step 8: Add the DTO members and the converter support**

In `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheet.cs`, after `public IList<ApiCheatsheetRow> Rows { get; set; } = new List<ApiCheatsheetRow>();` (line 32) add:

```csharp

        /// <summary>
        /// The card's look ("style" in note content), passed through verbatim
        /// so no data mode drops it. Null = never styled, and then omitted.
        /// </summary>
        [JsonProperty(NullValueHandling = NullValueHandling.Ignore)]
        public JToken Style { get; set; }
```

In `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetForCreate.cs`, after `Rows` (line 28) add:

```csharp

        /// <summary>The card's look, verbatim. Null or absent = unstyled.</summary>
        public JToken Style { get; set; }
```

In `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetForUpdate.cs`, after `Rows` (line 26) add:

```csharp

        private JToken _style;

        /// <summary>
        /// The card's look, verbatim. This DTO is mapped ONTO the stored card,
        /// so presence matters: a client that predates styles sends no "Style"
        /// key and must not wipe one (<see cref="StyleSpecified"/> stays false),
        /// while "Style": null is a deliberate reset. Newtonsoft calls this
        /// setter only for a key that is present - null included.
        /// </summary>
        public JToken Style
        {
            get => _style;
            set
            {
                _style = value;
                StyleSpecified = true;
            }
        }

        /// <summary>True when the request body carried a "Style" key at all.</summary>
        [JsonIgnore]
        public bool StyleSpecified { get; private set; }
```

In `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetRow.cs`, after `public ApiCheatsheetSource Source { get; set; }` (line 23) add:

```csharp

        /// <summary>Optional emoji for the client's Key points layout. Verbatim.</summary>
        public string Emoji { get; set; }
```

In `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetRowConverter.cs`:

In `WriteJson`, after the `if (value.Source != null) { ... }` block (ends line 44) add:

```csharp

            if (value.Emoji != null)
            {
                row[nameof(ApiCheatsheetRow.Emoji)] = value.Emoji;
            }
```

In `ReadJson`, change the initializer (lines 83-88) to:

```csharp
            var row = new ApiCheatsheetRow
            {
                Label = ReadString(source, nameof(ApiCheatsheetRow.Label), consumed) ?? string.Empty,
                ValueAction = ReadString(source, nameof(ApiCheatsheetRow.ValueAction), consumed) ?? "none",
                OpenSource = ReadBool(source, nameof(ApiCheatsheetRow.OpenSource), true, consumed),
                Emoji = ReadString(source, nameof(ApiCheatsheetRow.Emoji), consumed)
            };
```

In `src/Hmm.ServiceApi.DtoEntity/Cheatsheets/CheatsheetJsonInterop.cs`, after `ToJsonElement` (ends line 24) add:

```csharp

        /// <summary>No value (or an undefined one) maps to null.</summary>
        public static JToken ToJTokenOrNull(JsonElement? element)
            => element.HasValue && element.Value.ValueKind != JsonValueKind.Undefined
                ? ToJToken(element.Value)
                : null;

        /// <summary>A C# null and a JSON null both mean "no value".</summary>
        public static JsonElement? ToJsonElementOrNull(JToken token)
            => token == null || token.Type == JTokenType.Null
                ? null
                : ToJsonElement(token);
```

- [ ] **Step 9: Map `Style` in the profile**

In `src/Hmm.ServiceApi/Areas/CheatsheetService/Infrastructure/CheatsheetMappingProfile.cs`, replace the four card maps (lines 51-76) with:

```csharp
            CreateMap<CheatsheetCard, ApiCheatsheet>()
                .ForMember(d => d.Links, opt => opt.Ignore())
                .ForMember(d => d.Style, opt => opt.MapFrom(
                    (src, dest) => CheatsheetJsonInterop.ToJTokenOrNull(src.Style)))
                .ForMember(d => d.ExtraFields, opt => opt.MapFrom(
                    (src, dest) => CheatsheetJsonInterop.ToJTokens(src.ExtraFields)));

            CreateMap<ApiCheatsheet, CheatsheetCard>()
                .ForMember(d => d.NoteId, opt => opt.Ignore())
                .ForMember(d => d.AuthorId, opt => opt.Ignore())
                .ForMember(d => d.Style, opt => opt.MapFrom(
                    (src, dest) => CheatsheetJsonInterop.ToJsonElementOrNull(src.Style)))
                .ForMember(d => d.ExtraFields, opt => opt.MapFrom(
                    (src, dest) => CheatsheetJsonInterop.ToJsonElements(src.ExtraFields)));

            CreateMap<ApiCheatsheetForCreate, CheatsheetCard>()
                .ForMember(d => d.NoteId, opt => opt.Ignore())
                .ForMember(d => d.AuthorId, opt => opt.Ignore())
                .ForMember(d => d.Style, opt => opt.MapFrom(
                    (src, dest) => CheatsheetJsonInterop.ToJsonElementOrNull(src.Style)))
                .ForMember(d => d.ExtraFields, opt => opt.MapFrom(
                    (src, dest) => CheatsheetJsonInterop.ToJsonElements(src.ExtraFields)));

            // PUT replaces content only. Id, NoteId and AuthorId are identity:
            // they come from the route and the authenticated author, never from
            // a request body that could disagree with them. Style follows the
            // MergeExtras philosophy: a body that never mentions it (an older
            // client) keeps the stored one; an explicit null clears it.
            CreateMap<ApiCheatsheetForUpdate, CheatsheetCard>()
                .ForMember(d => d.Id, opt => opt.Ignore())
                .ForMember(d => d.NoteId, opt => opt.Ignore())
                .ForMember(d => d.AuthorId, opt => opt.Ignore())
                .ForMember(d => d.Style, opt => opt.MapFrom(
                    (src, dest) => src.StyleSpecified
                        ? CheatsheetJsonInterop.ToJsonElementOrNull(src.Style)
                        : dest.Style))
                .ForMember(d => d.ExtraFields, opt => opt.MapFrom(
                    (src, dest) => MergeExtras(dest.ExtraFields, src.ExtraFields)));
```

- [ ] **Step 10: Run both backend test projects (on `feat/cheatsheet-style-passthrough`)**

Run: `dotnet test /Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj`
Expected: `Passed!  - Failed: 0, Passed: 429` (420 + 9).

Run: `dotnet test /Users/fchy/Projects/hmm/src/Hmm.Cheatsheet.Tests/Hmm.Cheatsheet.Tests.csproj`
Expected: `Passed!  - Failed: 0, Passed: 103`.

- [ ] **Step 11: Commit (hmm repo, branch `feat/cheatsheet-style-passthrough`)**

```bash
cd /Users/fchy/Projects/hmm
git branch --show-current   # expect: feat/cheatsheet-style-passthrough (stop if it prints main)
git add src/Hmm.Cheatsheet/DomainEntity/CheatsheetCard.cs \
  src/Hmm.Cheatsheet/DomainEntity/CheatsheetRow.cs \
  src/Hmm.Cheatsheet/NoteSerialize/CheatsheetJsonNoteSerialize.cs \
  src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheet.cs \
  src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetForCreate.cs \
  src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetForUpdate.cs \
  src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetRow.cs \
  src/Hmm.ServiceApi.DtoEntity/Cheatsheets/ApiCheatsheetRowConverter.cs \
  src/Hmm.ServiceApi.DtoEntity/Cheatsheets/CheatsheetJsonInterop.cs \
  src/Hmm.ServiceApi/Areas/CheatsheetService/Infrastructure/CheatsheetMappingProfile.cs \
  src/Hmm.Cheatsheet.Tests/CheatsheetStylePassThroughTests.cs \
  src/Hmm.ServiceApi.Core.Tests/CheatsheetStyleMappingTests.cs
git status --short   # expect: only ' M CLAUDE.md' left unstaged
git commit -m "$(cat <<'EOF'
feat(cheatsheet): pass card Style and row Emoji through verbatim

Note content "style"/"emoji" map to typed members exposed as Style/Emoji
on the API. A PUT without a Style key keeps the stored look (older
clients); an explicit null clears it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

Do **not** deploy. The client's Cloud API writes of `style` (Task 5) depend on this being live first; record "server pass-through must deploy before/with the client release" in the ledger.

---

### Task 5: Client API mapper — `style` ⇄ `Style`, `emoji` ⇄ `Emoji`

**Files:**
- Modify: `lib/features/cheatsheet/data/mappers/cheatsheet_api_mapper.dart` (imports lines 1-5; `toApi` lines 25-39; `fromApi` lines 61-70; `_rowToApi` lines 81-86; `_rowFromApi` lines 88-100)
- Test: `test/features/cheatsheet/data/cheatsheet_api_style_test.dart` (new)

**Interfaces:**
- Consumes: `CardStyle` (Task 1), `CheatsheetCard.style`, `CheatsheetRow.emoji` (Task 2), the Task 4 wire contract.
- Produces: `CheatsheetApiMapper.toApi` always sends `'Style'` (`null` when the style is empty, so a reset clears it server-side); `'Emoji'` per row when set. `fromApi` reads both verbatim.

- [ ] **Step 1: Write the failing test**

Create `test/features/cheatsheet/data/cheatsheet_api_style_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/data/datasources/cheatsheet_remote_datasource.dart';
import 'package:hmm_console/features/cheatsheet/data/mappers/cheatsheet_api_mapper.dart';
import 'package:hmm_console/features/cheatsheet/data/repositories/cheatsheet_api_repository.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';

class _FakeRemote implements CheatsheetRemoteDataSource {
  _FakeRemote(this.existing);

  Map<String, dynamic>? existing;
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>?> getCard(String id) async => existing;

  @override
  Future<void> updateCard(String id, Map<String, dynamic> body) async {
    lastBody = body;
  }

  @override
  Future<Map<String, dynamic>> createCard(Map<String, dynamic> body) async {
    lastBody = body;
    return body;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  const eyes = '\u{1F440}';
  final styled = const CheatsheetCard(
    id: 'c-1',
    title: 'Vim',
    walletGroup: 'Reference',
    tags: [],
    templateId: 'document',
    rows: [CheatsheetRow(label: 'Motions', source: null, emoji: eyes)],
  ).copyWith(
    style: const CardStyle({
      'theme': 'turquoise',
      'pattern': 'dots',
      'sparkle': {'a': 1},
    }),
  );

  test('toApi sends Style verbatim, unknown keys included, and row Emoji', () {
    final json = CheatsheetApiMapper.toApi(styled);
    expect(json['Style'], {
      'theme': 'turquoise',
      'pattern': 'dots',
      'sparkle': {'a': 1},
    });
    expect((json['Rows'] as List).single['Emoji'], eyes);
    expect(json.containsKey('style'), isFalse);
  });

  test('an unstyled card sends Style: null so a reset clears the server copy',
      () {
    final json = CheatsheetApiMapper.toApi(styled.copyWith(
      style: CardStyle.empty,
      rows: [styled.rows.single.copyWith(clearEmoji: true)],
    ));
    expect(json.containsKey('Style'), isTrue);
    expect(json['Style'], isNull);
    expect((json['Rows'] as List).single.containsKey('Emoji'), isFalse);
  });

  test('fromApi reads Style and Emoji back into an equal card', () {
    expect(CheatsheetApiMapper.fromApi(CheatsheetApiMapper.toApi(styled)),
        styled);
  });

  test('a null or non-map Style reads as unstyled', () {
    final base = CheatsheetApiMapper.toApi(styled);
    expect(CheatsheetApiMapper.fromApi({...base, 'Style': null}).style.isEmpty,
        isTrue);
    expect(
        CheatsheetApiMapper.fromApi({...base, 'Style': 'odd'}).style.isEmpty,
        isTrue);
  });

  test('unknown style keys survive a get-then-save through the repository',
      () async {
    final stored = CheatsheetApiMapper.toApi(styled);
    final remote = _FakeRemote(stored);
    final repo = CheatsheetApiRepository(remote);

    final card = await repo.getCard('c-1');
    await repo.saveCard(card!.copyWith(title: 'Vim 2'));

    expect(remote.lastBody!['Style'], stored['Style']);
    expect((remote.lastBody!['Rows'] as List).single['Emoji'], eyes);
  });

  test('the API repository has no note ids, so no covers', () async {
    expect(await CheatsheetApiRepository(_FakeRemote(null)).noteIdFor('c-1'),
        isNull);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/data/cheatsheet_api_style_test.dart`
Expected: FAIL — `toApi sends Style verbatim...` (`Expected: {...} Actual: <null>` for `json['Style']`), `fromApi reads Style...` (cards differ in style), and `unknown style keys survive...`.

- [ ] **Step 3: Map style and emoji**

In `lib/features/cheatsheet/data/mappers/cheatsheet_api_mapper.dart`:

Add the import after line 3 (`import '../../domain/entities/cheatsheet_card.dart';`):

```dart
import '../../domain/entities/card_style.dart';
```

In `toApi`, after the `'Rows': [...]` entry (closing `],` on line 38) add:

```dart
        // Always present: null tells the server to clear its copy (Reset
        // look). A body WITHOUT the key - an older client - keeps it.
        'Style': c.style.isEmpty ? null : c.style.toMap(),
```

In `fromApi`, add to the `CheatsheetCard(` constructor call (after `unreadableRows: unreadable,`, line 69):

```dart
      style: m['Style'] is Map
          ? CardStyle(Map<String, dynamic>.of(
              (m['Style'] as Map).cast<String, dynamic>()))
          : CardStyle.empty,
```

In `_rowToApi`, after `if (r.source != null) 'Source': _srcToApi(r.source!),` (line 85) add:

```dart
        if (r.emoji != null) 'Emoji': r.emoji,
```

In `_rowFromApi`, after `openSource: _bool(m['OpenSource']) ?? true,` (line 99) add:

```dart
        emoji: _str(m['Emoji']),
```

- [ ] **Step 4: Run the new and existing API tests**

Run: `flutter test test/features/cheatsheet/data/cheatsheet_api_style_test.dart test/features/cheatsheet/data/cheatsheet_api_mapper_test.dart test/features/cheatsheet/data/cheatsheet_api_repository_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Analyze and commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet test/features/cheatsheet
git add lib/features/cheatsheet/data/mappers/cheatsheet_api_mapper.dart \
  test/features/cheatsheet/data/cheatsheet_api_style_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): carry card Style and row Emoji over the Cloud API

Style is sent verbatim (null when unstyled, so Reset look clears the server
copy); unknown style keys survive a get-then-save. Needs the Hmm server
pass-through deployed first.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Shared rendering — `CardSurface`, `CardTile`, `CardHeader`

**Files:**
- Create: `lib/features/cheatsheet/presentation/look/card_surface.dart`
- Create: `lib/features/cheatsheet/presentation/look/card_tile.dart`
- Create: `lib/features/cheatsheet/presentation/look/card_header.dart`
- Modify: `lib/l10n/app_en.arb` (after `"cheatsheetRowSection1": "Section 1",`, line 441), `lib/l10n/app_zh.arb` (after `"cheatsheetRowSection1": "第 1 节",`, line 219), then regenerate `lib/l10n/gen/`
- Test: `test/features/cheatsheet/presentation/look/card_surface_test.dart`

**Interfaces:**
- Consumes: `CardLook`, `CardPattern`, `CheatsheetCard.look/cover/protected` (Tasks 1-2); `CheatsheetPalette`, `CardColors` (Task 1); `attachmentResolverProvider` (`attachment_providers.dart` line 147), `IAttachmentResolver.resolve` (returns null for a missing file, throws `VaultLockedException` when locked); `vaultSessionProvider` / `VaultStatus` (`vault_session.dart` lines 26, 202); `SensitiveAttachmentImage` + `sensitiveLockedPlaceholderKey` (`sensitive_attachment_image.dart` lines 36-52); `cheatsheetGroupLabel` (`cheatsheet_templates.dart` line 123).
- Produces:
  - `class CardInk { final Color foreground; final Color subtitle; final bool overCover; final bool coverLocked; }`
  - `class CardPatternPainter extends CustomPainter { CardPatternPainter({required CardPattern pattern, required Color ink}); }`
  - `class CardSurface extends ConsumerStatefulWidget { const CardSurface({Key? key, required CheatsheetCard card, required Widget Function(BuildContext, CardInk) builder, Uint8List? pendingCoverBytes, bool allowUnlock = false}); }` — keys `card-surface-themed`, `card-surface-cover`, `card-surface-scrim`
  - `class CardTile extends StatelessWidget { const CardTile({Key? key, required CheatsheetCard card, VoidCallback? onTap, Uint8List? pendingCoverBytes}); }` — keys `card-tile-icon`, `card-tile-title`, `card-tile-protected`, `card-tile-cover-locked`
  - `class CardHeader extends StatelessWidget { const CardHeader({Key? key, required CheatsheetCard card}); }` — keys `detail-header-icon`, `detail-header-title`, `detail-header-subtitle`
  - `CardColors headerBarColors(CheatsheetCard card, Brightness brightness)`
  - ARB: `cheatsheetTileSubtitle(String group, int count)`, `cheatsheetTileSemantics(String title, String group, int count)`

- [ ] **Step 1: Add the ARB strings and regenerate**

In `lib/l10n/app_en.arb`, after `"cheatsheetRowSection1": "Section 1",` (line 441) insert:

```json
  "cheatsheetTileSubtitle": "{group} · {count, plural, =1{1 row} other{{count} rows}}",
  "@cheatsheetTileSubtitle": {"placeholders": {"group": {"type": "String"}, "count": {"type": "int"}}},
  "cheatsheetTileSemantics": "{title}, {group}, {count, plural, =1{1 row} other{{count} rows}}",
  "@cheatsheetTileSemantics": {"placeholders": {"title": {"type": "String"}, "group": {"type": "String"}, "count": {"type": "int"}}},
```

In `lib/l10n/app_zh.arb`, after `"cheatsheetRowSection1": "第 1 节",` (line 219) insert:

```json
  "cheatsheetTileSubtitle": "{group} · {count} 行",
  "cheatsheetTileSemantics": "{title}，{group}，{count} 行",
```

Run: `cd /Users/fchy/Projects/hmm_console && flutter gen-l10n`
Expected: no output errors; `lib/l10n/gen/app_localizations.dart` gains `String cheatsheetTileSubtitle(String group, int count);` and `String cheatsheetTileSemantics(String title, String group, int count);`.

- [ ] **Step 2: Write the failing rendering test**

Create `test/features/cheatsheet/presentation/look/card_surface_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/sensitive_attachment_image.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/card_header.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/card_surface.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/card_tile.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cheatsheet_palette.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// A real 1x1 PNG: invalid bytes would fail decoding and fail the test.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
    'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

class _Resolver implements IAttachmentResolver {
  _Resolver(this.answer);
  final Future<Uint8List?> Function() answer;
  int calls = 0;

  @override
  Future<Uint8List?> resolve(AttachmentRef ref) {
    calls++;
    return answer();
  }
}

class _StubVault extends VaultSessionController {
  _StubVault(this._status);
  final VaultStatus _status;
  static int unlockAttempts = 0;

  @override
  VaultStatus build() => _status;

  @override
  Future<void> refresh() async {
    state = _status;
  }

  @override
  Future<bool> unlockWithBiometric() async {
    unlockAttempts++;
    return false;
  }

  @override
  Future<bool> unlockWithPassphrase(String passphrase) async {
    unlockAttempts++;
    return false;
  }
}

const _cover = VaultRef(
  path: 'attachments/note-3/cover.png',
  contentType: 'image/png',
  byteSize: 70,
);
const _secretCover = VaultRef(
  path: 'attachments/note-3/sensitive/secret.png',
  contentType: 'image/png',
  byteSize: 70,
  sensitive: true,
);

const _card = CheatsheetCard(
  id: 'c1',
  title: 'Claim',
  walletGroup: 'Vehicle',
  tags: [],
  templateId: 'accidentClaim',
  rows: [
    CheatsheetRow(label: 'Plate', source: null),
    CheatsheetRow(label: 'VIN', source: null),
  ],
);

Future<List<String>> _captureLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final saved = debugPrint;
  debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
  try {
    await body();
  } finally {
    debugPrint = saved;
  }
  return logs;
}

void main() {
  setUp(() => _StubVault.unlockAttempts = 0);

  Future<List<String>> mountTile(
    WidgetTester tester,
    CheatsheetCard card, {
    IAttachmentResolver? resolver,
    VaultStatus vault = VaultStatus.unlocked,
    Brightness brightness = Brightness.light,
    Size size = const Size(200, 160),
    Uint8List? pending,
  }) async {
    final taps = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider.overrideWith(
            (ref) async => resolver ?? _Resolver(() async => _png)),
        vaultSessionProvider.overrideWith(() => _StubVault(vault)),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CardTile(
                card: card,
                pendingCoverBytes: pending,
                onTap: () => taps.add(card.id),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return taps;
  }

  Color themedColour(WidgetTester tester) => ((tester
              .widget<DecoratedBox>(find.byKey(const Key('card-surface-themed')))
              .decoration) as BoxDecoration)
      .color!;

  CardPattern paintedPattern(WidgetTester tester) => (tester
          .widget<CustomPaint>(find.descendant(
            of: find.byKey(const Key('card-surface-themed')),
            matching: find.byType(CustomPaint),
          ))
          .painter! as CardPatternPainter)
      .pattern;

  testWidgets('a plain card paints its template theme and icon, no pattern',
      (tester) async {
    await mountTile(tester, _card);

    expect(themedColour(tester),
        CheatsheetPalette.of(CardThemeId.blue, Brightness.light).background);
    expect(paintedPattern(tester), CardPattern.none);
    expect(find.text(CardLookDefaults.car), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget);
    expect(find.text('Vehicle · 2 rows'), findsOneWidget);
  });

  testWidgets('a styled card paints its chosen theme and pattern',
      (tester) async {
    await mountTile(
        tester,
        _card.copyWith(
            style: CardStyle.empty
                .withTheme(CardThemeId.red, templateId: 'accidentClaim')
                .withPattern(CardPattern.dots)));

    expect(themedColour(tester),
        CheatsheetPalette.of(CardThemeId.red, Brightness.light).background);
    expect(paintedPattern(tester), CardPattern.dots);
  });

  testWidgets('dark mode uses the dark variant', (tester) async {
    await mountTile(tester, _card, brightness: Brightness.dark);
    expect(themedColour(tester),
        CheatsheetPalette.of(CardThemeId.blue, Brightness.dark).background);
  });

  testWidgets('a cover is drawn under a darkening scrim with white text',
      (tester) async {
    await mountTile(tester, _card.withCover(_cover));

    expect(find.byKey(const Key('card-surface-cover')), findsOneWidget);
    expect(find.byKey(const Key('card-surface-scrim')), findsOneWidget);
    expect(find.byKey(const Key('card-surface-themed')), findsNothing);
    expect(tester.widget<Text>(find.text('Claim')).style!.color,
        const Color(0xFFFFFFFF));
  });

  testWidgets('a cover whose vault file is gone falls back to the theme',
      (tester) async {
    final logs = await _captureLogs(() => mountTile(
        tester, _card.withCover(_cover),
        resolver: _Resolver(() async => null)));

    expect(find.byKey(const Key('card-surface-themed')), findsOneWidget);
    expect(find.byKey(const Key('card-surface-cover')), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(logs.join('\n'), contains('missing'));
    expect(logs.join('\n'), isNot(contains('cover.png')));
  });

  testWidgets('a cover that fails to decrypt falls back and logs the type only',
      (tester) async {
    final logs = await _captureLogs(() => mountTile(
          tester,
          _card.withCover(_cover),
          resolver: _Resolver(
              () async => throw StateError('attachments/note-3/cover.png')),
        ));

    expect(find.byKey(const Key('card-surface-themed')), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(logs.join('\n'), contains('StateError'));
    expect(logs.join('\n'), isNot(contains('cover.png')));
  });

  testWidgets('a locked sensitive cover shows the theme with a lock badge and '
      'never prompts', (tester) async {
    final resolver = _Resolver(() async => _png);
    final taps = await mountTile(tester, _card.withCover(_secretCover),
        resolver: resolver, vault: VaultStatus.locked);

    expect(find.byKey(const Key('card-surface-themed')), findsOneWidget);
    expect(find.byKey(const Key('card-tile-cover-locked')), findsOneWidget);
    expect(find.byKey(sensitiveLockedPlaceholderKey), findsNothing);
    expect(resolver.calls, 0, reason: 'nothing is decrypted while locked');

    await tester.tap(find.byType(CardTile));
    await tester.pumpAndSettle();

    expect(taps, ['c1'], reason: 'the tap opens the card');
    expect(_StubVault.unlockAttempts, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('pending cover bytes preview without touching the resolver',
      (tester) async {
    final resolver =
        _Resolver(() async => throw StateError('must not be called'));
    await mountTile(tester, _card, resolver: resolver, pending: _png);

    expect(find.byKey(const Key('card-surface-cover')), findsOneWidget);
    expect(resolver.calls, 0);
  });

  testWidgets('a long title and a ZWJ skin-tone icon render on a tile without '
      'overflow', (tester) async {
    const technologist = '\u{1F469}\u{1F3FD}‍\u{1F4BB}';
    final card = _card.copyWith(
      title: 'A very long cheatsheet title ' * 8,
      style: CardStyle.empty
          .withIcon(technologist, templateId: 'accidentClaim'),
    );
    await mountTile(tester, card, size: const Size(160, 150));

    expect(tester.takeException(), isNull);
    expect(find.text(technologist), findsOneWidget);
    final title = tester.widget<Text>(find.byKey(const Key('card-tile-title')));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('an invalid stored icon renders the template icon',
      (tester) async {
    await mountTile(
        tester, _card.copyWith(style: const CardStyle({'icon': 'car'})));
    expect(find.text(CardLookDefaults.car), findsOneWidget);
    expect(find.text('car'), findsNothing);
  });

  testWidgets('semantics read title, group and rows as one button',
      (tester) async {
    final handle = tester.ensureSemantics();
    await mountTile(tester, _card);

    final node = find.bySemanticsLabel('Claim, Vehicle, 2 rows');
    expect(node, findsOneWidget);
    expect(tester.getSemantics(node),
        containsSemantics(isButton: true, hasTapAction: true));
    handle.dispose();
  });

  testWidgets('a protected card shows a lock badge', (tester) async {
    await mountTile(tester, _card.copyWith(protected: true));
    expect(find.byKey(const Key('card-tile-protected')), findsOneWidget);
  });

  testWidgets('the header offers the shared tap-to-unlock tile for a locked '
      'sensitive cover', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider
            .overrideWith((ref) async => _Resolver(() async => _png)),
        vaultSessionProvider
            .overrideWith(() => _StubVault(VaultStatus.locked)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CardHeader(card: _card.withCover(_secretCover))),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(sensitiveLockedPlaceholderKey), findsOneWidget);
    expect(find.byKey(const Key('detail-header-title')), findsOneWidget);
    expect(find.text('Vehicle · 2 rows'), findsOneWidget);
  });

  test('the app bar over a cover card uses the darkened theme with white', () {
    final plain = headerBarColors(_card, Brightness.light);
    expect(plain.background,
        CheatsheetPalette.of(CardThemeId.blue, Brightness.light).background);

    final covered = headerBarColors(_card.withCover(_cover), Brightness.light);
    expect(covered.foreground, const Color(0xFFFFFFFF));
    expect(covered.background,
        CheatsheetPalette.forCover(CardThemeId.blue, Brightness.light)
            .background);
  });
}
```

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/presentation/look/card_surface_test.dart`
Expected: compilation fails — `card_surface.dart`, `card_tile.dart`, `card_header.dart` do not exist.

- [ ] **Step 4: Implement `CardSurface`**

Create `lib/features/cheatsheet/presentation/look/card_surface.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/sensitive_attachment_image.dart';
import '../../../../core/data/vault/encrypted_vault_store.dart'
    show VaultLockedException;
import '../../../../core/data/vault/vault_session.dart';
import '../../domain/entities/card_style.dart';
import '../../domain/entities/cheatsheet_card.dart';
import 'cheatsheet_palette.dart';

const Color _coverText = Color(0xFFFFFFFF);
const Color _coverSubtitle = Color(0xE6FFFFFF);

/// Text colours for whatever is drawn on a [CardSurface], and whether a
/// sensitive cover is being withheld because the vault is locked.
class CardInk {
  const CardInk({
    required this.foreground,
    required this.subtitle,
    required this.overCover,
    required this.coverLocked,
  });

  final Color foreground;
  final Color subtitle;
  final bool overCover;
  final bool coverLocked;
}

/// Draws a [CardPattern] in [ink] (the foreground at [kPatternInkOpacity]).
class CardPatternPainter extends CustomPainter {
  CardPatternPainter({required this.pattern, required this.ink});

  final CardPattern pattern;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    switch (pattern) {
      case CardPattern.none:
        return;
      case CardPattern.dots:
        final fill = Paint()..color = ink;
        for (var y = 6.0; y < size.height; y += 12) {
          for (var x = 6.0; x < size.width; x += 12) {
            canvas.drawCircle(Offset(x, y), 1.6, fill);
          }
        }
      case CardPattern.stripes:
        for (var x = -size.height; x < size.width; x += 10) {
          canvas.drawLine(
              Offset(x, size.height), Offset(x + size.height, 0), stroke);
        }
      case CardPattern.grid:
        stroke.strokeWidth = 1;
        for (var x = 0.0; x <= size.width; x += 14) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
        }
        for (var y = 0.0; y <= size.height; y += 14) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
        }
      case CardPattern.waves:
        for (var y = 8.0; y < size.height + 8; y += 14) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 4) {
            path.lineTo(x, y + 3 * math.sin(x / 24 * 2 * math.pi));
          }
          canvas.drawPath(path, stroke);
        }
    }
  }

  @override
  bool shouldRepaint(CardPatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern || oldDelegate.ink != ink;
}

/// The card's background — theme colour + pattern, or the cover photo under
/// a darkening scrim — with [builder]'s content on top in matching ink.
///
/// Failure is always the theme: a missing or undecryptable cover falls back
/// silently (logging the card id and error type only), and a sensitive cover
/// on a locked vault shows the theme with `ink.coverLocked`. Only when
/// [allowUnlock] is true (the detail header) does a locked cover offer the
/// shared tap-to-unlock tile; a wallet tile must never prompt.
class CardSurface extends ConsumerStatefulWidget {
  const CardSurface({
    super.key,
    required this.card,
    required this.builder,
    this.pendingCoverBytes,
    this.allowUnlock = false,
  });

  final CheatsheetCard card;
  final Widget Function(BuildContext context, CardInk ink) builder;

  /// A just-picked cover not yet in the vault (the designer preview).
  final Uint8List? pendingCoverBytes;

  final bool allowUnlock;

  @override
  ConsumerState<CardSurface> createState() => _CardSurfaceState();
}

class _CoverResult {
  const _CoverResult(this.bytes, {this.locked = false});
  final Uint8List? bytes;
  final bool locked;
}

class _CardSurfaceState extends ConsumerState<CardSurface> {
  Future<_CoverResult>? _cover;
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    // The session status can be stale on first build; without a refresh the
    // surface would show the lock over a cover it could already decrypt.
    if (widget.card.cover?.sensitive ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(vaultSessionProvider.notifier).refresh();
      });
    }
  }

  Future<_CoverResult> _load(VaultRef cover) async {
    final cardId = widget.card.id;
    try {
      final resolver = await ref.read(attachmentResolverProvider.future);
      final bytes = await resolver.resolve(cover);
      if (bytes == null) {
        debugPrint('CardSurface: card $cardId cover is missing; '
            'showing its theme.');
      }
      return _CoverResult(bytes);
    } on VaultLockedException {
      // Relocked between the status check and the read.
      return const _CoverResult(null, locked: true);
    } catch (e) {
      // Type only: the error can quote the vault path.
      debugPrint('CardSurface: card $cardId cover could not load '
          '(${e.runtimeType}); showing its theme.');
      return const _CoverResult(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final look = card.look;
    final colors =
        CheatsheetPalette.of(look.theme, Theme.of(context).brightness);

    final pending = widget.pendingCoverBytes;
    if (pending != null) return _overCover(context, pending);

    final cover = card.cover;
    if (cover == null) return _themed(context, colors, look.pattern);

    final unlockResolver = widget.allowUnlock && cover.sensitive
        ? ref.watch(attachmentResolverProvider).value
        : null;

    if (cover.sensitive &&
        ref.watch(vaultSessionProvider) != VaultStatus.unlocked) {
      return _themed(context, colors, look.pattern,
          lockedCover: cover, unlockResolver: unlockResolver);
    }

    // Memoised per cover path so a rebuild never re-reads the vault.
    if (_cover == null || _coverPath != cover.path) {
      _coverPath = cover.path;
      _cover = _load(cover);
    }
    return FutureBuilder<_CoverResult>(
      future: _cover,
      builder: (context, snap) {
        final result = snap.data;
        final bytes = result?.bytes;
        if (bytes != null) return _overCover(context, bytes);
        final locked = result?.locked ?? false;
        return _themed(context, colors, look.pattern,
            lockedCover: locked ? cover : null,
            unlockResolver: unlockResolver);
      },
    );
  }

  Widget _themed(
    BuildContext context,
    CardColors colors,
    CardPattern pattern, {
    VaultRef? lockedCover,
    IAttachmentResolver? unlockResolver,
  }) {
    final locked = lockedCover != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          key: const Key('card-surface-themed'),
          decoration: BoxDecoration(color: colors.background),
          child: CustomPaint(
            painter:
                CardPatternPainter(pattern: pattern, ink: colors.patternInk),
          ),
        ),
        widget.builder(
          context,
          CardInk(
            foreground: colors.foreground,
            subtitle: colors.subtitle,
            overCover: false,
            coverLocked: locked,
          ),
        ),
        // Null checks on the parameters themselves, so both promote.
        if (lockedCover != null && widget.allowUnlock && unlockResolver != null)
          Positioned(
            top: 12,
            right: 12,
            width: 72,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SensitiveAttachmentImage(
                ref: lockedCover,
                resolver: unlockResolver,
              ),
            ),
          ),
      ],
    );
  }

  Widget _overCover(BuildContext context, Uint8List bytes) => Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            bytes,
            key: const Key('card-surface-cover'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
          const DecoratedBox(
            key: Key('card-surface-scrim'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.4, 1],
                colors: [
                  Color(0x59000000),
                  Color(0x00000000),
                  Color(0xA6000000),
                ],
              ),
            ),
          ),
          widget.builder(
            context,
            const CardInk(
              foreground: _coverText,
              subtitle: _coverSubtitle,
              overCover: true,
              coverLocked: false,
            ),
          ),
        ],
      );
}
```

- [ ] **Step 5: Implement `CardTile`**

Create `lib/features/cheatsheet/presentation/look/card_tile.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../data/cheatsheet_templates.dart';
import '../../domain/entities/cheatsheet_card.dart';
import 'card_surface.dart';

/// A wallet tile: the card's look as background, its icon, a two-line title
/// and "group · N rows". Read by screen readers as one button whose label
/// never relies on colour.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    this.onTap,
    this.pendingCoverBytes,
  });

  final CheatsheetCard card;
  final VoidCallback? onTap;
  final Uint8List? pendingCoverBytes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final group = cheatsheetGroupLabel(card.walletGroup, l);
    final count = card.rows.length;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: l.cheatsheetTileSemantics(card.title, group, count),
      onTap: onTap,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CardSurface(
          card: card,
          pendingCoverBytes: pendingCoverBytes,
          builder: (context, ink) => Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          card.look.icon,
                          key: const Key('card-tile-icon'),
                          style: const TextStyle(fontSize: 28),
                        ),
                        const Spacer(),
                        if (card.protected)
                          Icon(
                            Icons.lock_outline,
                            key: const Key('card-tile-protected'),
                            size: 18,
                            color: ink.foreground,
                          ),
                        if (ink.coverLocked)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text(
                              '\u{1F512}',
                              key: Key('card-tile-cover-locked'),
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      card.title,
                      key: const Key('card-tile-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        color: ink.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.cheatsheetTileSubtitle(group, count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: ink.subtitle),
                    ),
                  ],
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

- [ ] **Step 6: Implement `CardHeader`**

Create `lib/features/cheatsheet/presentation/look/card_header.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../data/cheatsheet_templates.dart';
import '../../domain/entities/cheatsheet_card.dart';
import 'card_surface.dart';
import 'cheatsheet_palette.dart';

/// App-bar colours for a card's detail screen. A card with a cover uses the
/// darkened theme with white text, so the bar reads the same whether or not
/// the photo loads (AA-tested in `cheatsheet_palette_test.dart`).
CardColors headerBarColors(CheatsheetCard card, Brightness brightness) =>
    card.cover != null
        ? CheatsheetPalette.forCover(card.look.theme, brightness)
        : CheatsheetPalette.of(card.look.theme, brightness);

/// The detail screen's banner: cover or theme + pattern, icon, title and
/// "group · N rows". A locked sensitive cover offers the shared
/// tap-to-unlock tile here (and only here).
class CardHeader extends StatelessWidget {
  const CardHeader({super.key, required this.card});

  final CheatsheetCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final group = cheatsheetGroupLabel(card.walletGroup, l);
    return SizedBox(
      height: 168,
      child: CardSurface(
        card: card,
        allowUnlock: true,
        builder: (context, ink) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                card.look.icon,
                key: const Key('detail-header-icon'),
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 8),
              Text(
                card.title,
                key: const Key('detail-header-title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.headlineSmall?.copyWith(color: ink.foreground),
              ),
              Text(
                l.cheatsheetTileSubtitle(group, card.rows.length),
                key: const Key('detail-header-subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: ink.subtitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run it to see it pass**

Run: `flutter test test/features/cheatsheet/presentation/look/card_surface_test.dart`
Expected: `All tests passed!`

- [ ] **Step 8: Analyze and commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet test/features/cheatsheet
git add lib/features/cheatsheet/presentation/look/card_surface.dart \
  lib/features/cheatsheet/presentation/look/card_tile.dart \
  lib/features/cheatsheet/presentation/look/card_header.dart \
  lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/ \
  test/features/cheatsheet/presentation/look/card_surface_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): card surface, wallet tile and detail header

One surface draws theme + pattern or cover + scrim; a missing or locked
cover falls back to the theme, and only the header offers an unlock.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Wallet — tile grid, group chips, search

**Files:**
- Modify: `lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart` (whole file, 208 lines → replaced)
- Modify: `test/core/help/icon_button_guard_test.dart` (remove the `cheatsheet_wallet_screen.dart: 1` entry, line 22 — the add button becomes an `HmmIconButton`)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (one chip key after the Task 6 keys; ten wallet help keys after `"helpContactEditSelfBody": ...,` — en line 1235, zh line 697 before this plan's edits), regenerate `lib/l10n/gen/`
- Modify: `lib/core/help/help_registry.dart` (enum line 10; new case after the `HelpId.contactEdit` case, before the closing `};`, line 135)
- Test: `test/features/cheatsheet/presentation/cheatsheet_wallet_screen_test.dart` (whole file, 210 lines → replaced)
- Test: `test/core/help/help_registry_test.dart` (append two tests)

**Interfaces:**
- Consumes: `CardTile` (Task 6), `cheatsheetGroupLabel`, `HmmIconButton` (`lib/core/widgets/hmm_icon_button.dart`), `cheatsheetsStateProvider`, `HelpButton`, `helpFor`, `HelpEntry` (`lib/core/help/`).
- Produces:
  - `int walletColumnsFor(double width)` — 2 below 600, 3 from 600, 4 from 900
  - Keys: `wallet-add`, `wallet-search`, `wallet-group-all`, `wallet-group-<storedGroup>` (ChoiceChip), `wallet-tag-<tag>` (FilterChip, unchanged), `wallet-grid`, `wallet-card-<id>` (the `CardTile`), `wallet-empty`, `wallet-error`, `wallet-no-matches`
  - ARB: `cheatsheetChipAll`; `helpCheatsheetWalletTitle`, `helpCheatsheetWalletSummary`, `helpCheatsheetWallet{Tiles,Groups,Tags,Lock}{Title,Body}`
  - `HelpId.cheatsheetWallet` (entries in this order: tiles `Icons.touch_app_outlined`, group chips `Icons.filter_list`, tag chips `Icons.label_outline`, lock badge `Icons.lock_outline`)

- [ ] **Step 1: Add the ARB strings and regenerate**

In `lib/l10n/app_en.arb`, after the `"@cheatsheetTileSemantics": {...},` line added in Task 6, insert:

```json
  "cheatsheetChipAll": "All",
```

In `lib/l10n/app_zh.arb`, after `"cheatsheetTileSemantics": "{title}，{group}，{count} 行",` insert:

```json
  "cheatsheetChipAll": "全部",
```

In `lib/l10n/app_en.arb`, after `"helpContactEditSelfBody": "Marks this contact as yourself. Only one contact can be marked.",` insert:

```json
  "helpCheatsheetWalletTitle": "Cheatsheets",
  "helpCheatsheetWalletSummary": "Your cards at a glance. Tap a card to open it; use search and the chips to narrow the wallet.",
  "helpCheatsheetWalletTilesTitle": "Cards",
  "helpCheatsheetWalletTilesBody": "Each card shows its colour or cover photo, its icon, its title, and its group with the number of rows. Tap a card to open it.",
  "helpCheatsheetWalletGroupsTitle": "Group chips",
  "helpCheatsheetWalletGroupsBody": "The first row of chips shows one wallet group at a time; All shows every card again. Search works within the chosen group.",
  "helpCheatsheetWalletTagsTitle": "Tag chips",
  "helpCheatsheetWalletTagsBody": "Tag chips narrow the wallet to cards that carry every tag you select. Tap a tag again to drop it.",
  "helpCheatsheetWalletLockTitle": "Lock badge",
  "helpCheatsheetWalletLockBody": "A lock marks a protected card. A 🔒 means its cover photo is locked in the vault: the card shows its colour instead, and opening the card lets you unlock the photo.",
```

In `lib/l10n/app_zh.arb`, after `"helpContactEditSelfBody": "将此联系人标记为你本人。只能标记一个联系人。",` insert:

```json
  "helpCheatsheetWalletTitle": "速查卡",
  "helpCheatsheetWalletSummary": "一目了然地查看所有卡片。点按卡片即可打开；用搜索和筛选标签缩小范围。",
  "helpCheatsheetWalletTilesTitle": "卡片",
  "helpCheatsheetWalletTilesBody": "每张卡片显示其颜色或封面照片、图标、标题，以及所属分组和行数。点按卡片即可打开。",
  "helpCheatsheetWalletGroupsTitle": "分组标签",
  "helpCheatsheetWalletGroupsBody": "第一排标签一次只显示一个卡包分组；点“全部”可重新显示所有卡片。搜索只在所选分组内进行。",
  "helpCheatsheetWalletTagsTitle": "标签筛选",
  "helpCheatsheetWalletTagsBody": "标签筛选只显示带有全部已选标签的卡片。再次点按标签即可取消。",
  "helpCheatsheetWalletLockTitle": "锁定标记",
  "helpCheatsheetWalletLockBody": "锁形图标表示受保护的卡片。🔒 表示其封面照片已在保险库中锁定：卡片会改为显示颜色，打开卡片后可解锁照片。",
```

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 2: Replace the wallet test with the tile-grid version**

Replace the whole of `test/features/cheatsheet/presentation/cheatsheet_wallet_screen_test.dart` with:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/sensitive_attachment_image.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/card_tile.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';

class _SeededCheatsheets extends CheatsheetsState {
  static List<CheatsheetCard> seed = const [];

  @override
  Future<List<CheatsheetCard>> build() async => seed;
}

class _FailingCheatsheets extends CheatsheetsState {
  @override
  Future<List<CheatsheetCard>> build() async => throw Exception('boom');
}

class _Resolver implements IAttachmentResolver {
  int calls = 0;
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async {
    calls++;
    return base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
        'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
  }
}

class _LockedVault extends VaultSessionController {
  static int unlockAttempts = 0;
  @override
  VaultStatus build() => VaultStatus.locked;
  @override
  Future<void> refresh() async {
    state = VaultStatus.locked;
  }

  @override
  Future<bool> unlockWithBiometric() async {
    unlockAttempts++;
    return false;
  }
}

CheatsheetCard card(
  String id, {
  required String title,
  String group = 'Vehicle',
  List<String> tags = const [],
}) =>
    CheatsheetCard(
      id: id,
      title: title,
      walletGroup: group,
      tags: tags,
      templateId: 'blank',
      rows: const [],
    );

void main() {
  setUp(() {
    _SeededCheatsheets.seed = const [];
    _LockedVault.unlockAttempts = 0;
  });

  Future<List<String>> mount(
    WidgetTester tester, {
    bool failing = false,
    List<Override> extra = const [],
  }) async {
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cheatsheetsStateProvider.overrideWith(
            failing ? _FailingCheatsheets.new : _SeededCheatsheets.new,
          ),
          cheatsheetOpenCardProvider
              .overrideWithValue((_, id) => opened.add(id)),
          cheatsheetCreateCardProvider
              .overrideWithValue((_) => opened.add('#create')),
          ...extra,
        ],
        child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CheatsheetWalletScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  /// Reading order in the grid: top to bottom, then left to right.
  bool before(WidgetTester tester, String a, String b) {
    final pa = tester.getTopLeft(find.byKey(Key('wallet-card-$a')));
    final pb = tester.getTopLeft(find.byKey(Key('wallet-card-$b')));
    return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
  }

  int columns(WidgetTester tester) => (tester
          .widget<GridView>(find.byKey(const Key('wallet-grid')))
          .gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;

  testWidgets('every card is a tile', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    expect(find.byType(CardTile), findsNWidgets(2));
    expect(find.text('Claim'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
  });

  testWidgets('offers All plus one translated chip per wallet group in use',
      (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    expect(find.byKey(const Key('wallet-group-all')), findsOneWidget);
    expect(find.byKey(const Key('wallet-group-Vehicle')), findsOneWidget);
    expect(find.byKey(const Key('wallet-group-Health')), findsOneWidget);
    expect(find.byKey(const Key('wallet-group-Reference')), findsNothing);
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('wallet-group-all')))
            .selected,
        isTrue);
  });

  testWidgets('a group chip filters the grid and All restores it',
      (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-group-Health')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-card-a')), findsNothing);
    expect(find.byKey(const Key('wallet-card-b')), findsOneWidget);

    await tester.tap(find.byKey(const Key('wallet-group-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-card-a')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-b')), findsOneWidget);
  });

  testWidgets('tapping a card opens its detail', (tester) async {
    _SeededCheatsheets.seed = [card('a', title: 'Claim')];
    final opened = await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-card-a')));
    await tester.pumpAndSettle();

    expect(opened, ['a']);
  });

  testWidgets('the add action opens the designer', (tester) async {
    final opened = await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-add')));
    await tester.pumpAndSettle();

    expect(opened, ['#create']);
  });

  testWidgets('cards with the same title order by id, stably', (tester) async {
    _SeededCheatsheets.seed = [
      card('b', title: 'Claim'),
      card('a', title: 'Claim'),
    ];
    await mount(tester);

    expect(before(tester, 'a', 'b'), isTrue);
    await tester.pump(); // rebuild
    expect(before(tester, 'a', 'b'), isTrue,
        reason: 'order is stable across builds');
  });

  testWidgets('titles sort case-insensitively across groups', (tester) async {
    _SeededCheatsheets.seed = [
      card('1', title: 'zebra', group: 'vehicle'),
      card('2', title: 'Apple', group: 'Health'),
    ];
    await mount(tester);

    expect(before(tester, '2', '1'), isTrue, reason: 'Apple before zebra');
  });

  testWidgets('columns: 2 on phones, 3 from 600 dp, 4 from 900 dp',
      (tester) async {
    expect(walletColumnsFor(320), 2);
    expect(walletColumnsFor(599), 2);
    expect(walletColumnsFor(600), 3);
    expect(walletColumnsFor(899), 3);
    expect(walletColumnsFor(900), 4);

    _SeededCheatsheets.seed = [card('a', title: 'Claim')];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (width, expected) in [(400.0, 2), (700.0, 3), (1000.0, 4)]) {
      tester.view.physicalSize = Size(width, 900);
      await mount(tester);
      expect(columns(tester), expected, reason: '$width wide');
    }
  });

  testWidgets('a locked sensitive cover shows a badge and triggers no unlock',
      (tester) async {
    const secret = VaultRef(
      path: 'attachments/note-1/sensitive/c.png',
      contentType: 'image/png',
      byteSize: 70,
      sensitive: true,
    );
    _SeededCheatsheets.seed = [card('a', title: 'Claim').withCover(secret)];
    final resolver = _Resolver();
    final opened = await mount(tester, extra: [
      attachmentResolverProvider.overrideWith((ref) async => resolver),
      vaultSessionProvider.overrideWith(_LockedVault.new),
    ]);

    expect(find.byKey(const Key('card-tile-cover-locked')), findsOneWidget);
    expect(find.byKey(sensitiveLockedPlaceholderKey), findsNothing);
    expect(resolver.calls, 0);

    await tester.tap(find.byKey(const Key('wallet-card-a')));
    await tester.pumpAndSettle();
    expect(opened, ['a']);
    expect(_LockedVault.unlockAttempts, 0);
  });

  testWidgets('search matches titles case-insensitively', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Doctor', group: 'Health'),
    ];
    await mount(tester);

    await tester.enterText(find.byKey(const Key('wallet-search')), 'cla');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-card-a')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-b')), findsNothing);
  });

  testWidgets('search and the group chip intersect', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim'),
      card('b', title: 'Claim health', group: 'Health'),
    ];
    await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-group-Health')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wallet-search')), 'claim');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-card-a')), findsNothing);
    expect(find.byKey(const Key('wallet-card-b')), findsOneWidget);
  });

  testWidgets('a search with no matches shows the empty-result state',
      (tester) async {
    _SeededCheatsheets.seed = [card('a', title: 'Claim')];
    await mount(tester);

    await tester.enterText(find.byKey(const Key('wallet-search')), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-no-matches')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-a')), findsNothing);
  });

  testWidgets('a tag filter shows only cards carrying that tag',
      (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim', tags: const ['legal']),
      card('b', title: 'Doctor', group: 'Health', tags: const ['medical']),
    ];
    await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-tag-legal')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-card-a')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-b')), findsNothing);
  });

  testWidgets('title and tag filters intersect', (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim', tags: const ['legal']),
      card('b', title: 'Claim backup', tags: const ['medical']),
    ];
    await mount(tester);

    await tester.tap(find.byKey(const Key('wallet-tag-legal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wallet-search')), 'claim');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-card-a')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-b')), findsNothing);
  });

  testWidgets('tag chips are trimmed and de-duplicated case-insensitively',
      (tester) async {
    _SeededCheatsheets.seed = [
      card('a', title: 'Claim', tags: const ['Legal', 'legal ']),
      card('b', title: 'Doctor', tags: const ['health']),
    ];
    await mount(tester);

    expect(find.byKey(const Key('wallet-tag-legal')), findsOneWidget);
    expect(find.byKey(const Key('wallet-tag-health')), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(2));
  });

  testWidgets('an empty wallet shows an empty state', (tester) async {
    await mount(tester);
    expect(find.byKey(const Key('wallet-empty')), findsOneWidget);
  });

  testWidgets('a load failure shows an error state, not a blank screen',
      (tester) async {
    await mount(tester, failing: true);
    expect(find.byKey(const Key('wallet-error')), findsOneWidget);
  });

  testWidgets('a load failure never shows the exception text', (tester) async {
    await mount(tester, failing: true);
    expect(find.text('Could not load your cheatsheets.'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('the wallet has a help button that explains tiles, chips and '
      'the lock badge', (tester) async {
    // An empty wallet: the only lock icon on screen is the help sheet's.
    await mount(tester);

    await tester.tap(find.byType(HelpButton));
    await tester.pumpAndSettle();

    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Group chips'), findsOneWidget);
    expect(find.text('Tag chips'), findsOneWidget);
    expect(find.text('Lock badge'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
```

In `test/core/help/help_registry_test.dart`, append inside `main()`:

```dart
  test('wallet help explains tiles, both chip rows and the lock badge', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entries = helpFor(HelpId.cheatsheetWallet, l).entries;
    // card_tile.dart draws Icons.lock_outline on a protected card. Tiles and
    // chips draw no Material icon, so they use the closest stand-in (the
    // vehicleNotes "Open" entry's precedent).
    expect(entries.map((e) => e.icon), [
      Icons.touch_app_outlined,
      Icons.filter_list,
      Icons.label_outline,
      Icons.lock_outline,
    ]);
    expect(entries.map((e) => e.title), [
      l.helpCheatsheetWalletTilesTitle,
      l.helpCheatsheetWalletGroupsTitle,
      l.helpCheatsheetWalletTagsTitle,
      l.helpCheatsheetWalletLockTitle,
    ]);
  });

  test('wallet help is translated entry by entry in zh', () {
    final en =
        helpFor(HelpId.cheatsheetWallet, lookupAppLocalizations(const Locale('en')));
    final zh =
        helpFor(HelpId.cheatsheetWallet, lookupAppLocalizations(const Locale('zh')));
    expect(zh.entries.length, en.entries.length);
    for (var i = 0; i < en.entries.length; i++) {
      expect(zh.entries[i].title, isNot(en.entries[i].title), reason: '$i');
      expect(zh.entries[i].body, isNot(en.entries[i].body), reason: '$i');
    }
  });
```

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/cheatsheet/presentation/cheatsheet_wallet_screen_test.dart test/core/help/help_registry_test.dart`
Expected: compilation fails — `The function 'walletColumnsFor' isn't defined`; `There's no constant named 'cheatsheetWallet' in 'HelpId'`.

- [ ] **Step 4: Register the wallet help**

In `lib/core/help/help_registry.dart`, change the enum (line 10) to:

```dart
enum HelpId {
  automobileHub,
  vehicleNotes,
  contacts,
  contactDetail,
  contactEdit,
  cheatsheetWallet,
}
```

and add this case after the `HelpId.contactEdit => ScreenHelp(...)` case (before the closing `};`, line 135):

```dart
      HelpId.cheatsheetWallet => ScreenHelp(
          title: l.helpCheatsheetWalletTitle,
          summary: l.helpCheatsheetWalletSummary,
          entries: [
            HelpEntry(
                icon: Icons.touch_app_outlined,
                title: l.helpCheatsheetWalletTilesTitle,
                body: l.helpCheatsheetWalletTilesBody),
            HelpEntry(
                icon: Icons.filter_list,
                title: l.helpCheatsheetWalletGroupsTitle,
                body: l.helpCheatsheetWalletGroupsBody),
            HelpEntry(
                icon: Icons.label_outline,
                title: l.helpCheatsheetWalletTagsTitle,
                body: l.helpCheatsheetWalletTagsBody),
            HelpEntry(
                icon: Icons.lock_outline,
                title: l.helpCheatsheetWalletLockTitle,
                body: l.helpCheatsheetWalletLockBody),
          ],
        ),
```

- [ ] **Step 5: Replace the wallet screen**

Replace the whole of `lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/cheatsheet_templates.dart';
import '../../domain/entities/cheatsheet_card.dart';
import '../../states/cheatsheets_state.dart';
import '../look/card_tile.dart';

/// Navigation seams. Widget tests override these instead of standing up a
/// router; T15 wires the real routes behind them.
final cheatsheetOpenCardProvider = Provider<void Function(BuildContext, String)>(
  (ref) => (context, id) => context.pushNamed(
        RouterNames.cheatsheetDetail.name,
        pathParameters: {'id': id},
      ),
);

final cheatsheetCreateCardProvider = Provider<void Function(BuildContext)>(
  (ref) => (context) => context.pushNamed(RouterNames.cheatsheetCreate.name),
);

/// Normalized tag form: trimmed and lower-cased.
///
/// Tags are free text typed by hand, so `Legal`, `legal ` and `legal` are the
/// same tag. Normalizing at both the chip list and the match keeps the filter
/// from silently missing cards over a stray capital or space.
String normalizeTag(String tag) => tag.trim().toLowerCase();

/// Tile columns for a wallet [width] in logical pixels: 2 on phones, 3 from
/// 600 dp, 4 from 900 dp.
int walletColumnsFor(double width) =>
    width >= 900 ? 4 : (width >= 600 ? 3 : 2);

/// The card wallet: a searchable grid of tiles, filtered by wallet group
/// (single-select chips) and by tags.
class CheatsheetWalletScreen extends ConsumerStatefulWidget {
  const CheatsheetWalletScreen({super.key});

  @override
  ConsumerState<CheatsheetWalletScreen> createState() =>
      _CheatsheetWalletScreenState();
}

class _CheatsheetWalletScreenState
    extends ConsumerState<CheatsheetWalletScreen> {
  String _query = '';

  /// The stored (English-key) wallet group, or null for All.
  String? _group;
  final _selectedTags = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cards = ref.watch(cheatsheetsStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.cheatsheetWalletTitle),
        actions: [
          const HelpButton(helpId: HelpId.cheatsheetWallet),
          HmmIconButton(
            key: const Key('wallet-add'),
            icon: Icons.add,
            tooltip: l.cheatsheetNew,
            onPressed: () => ref.read(cheatsheetCreateCardProvider)(context),
          ),
        ],
      ),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Never the exception text on screen: it can quote stored values.
        error: (_, _) => Center(
          key: const Key('wallet-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.cheatsheetLoadFailed),
          ),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(List<CheatsheetCard> all) {
    final l = AppLocalizations.of(context);
    if (all.isEmpty) {
      return Center(
        key: const Key('wallet-empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.cheatsheetEmpty),
        ),
      );
    }

    final groups = _groupsInUse(all);
    // A chosen group whose last card was deleted falls back to All.
    final group = groups.contains(_group) ? _group : null;
    final tags = _allTags(all);
    final matches = _filter(all, group);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const Key('wallet-search'),
            decoration: InputDecoration(
              hintText: l.cheatsheetSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: const Key('wallet-group-all'),
                  label: Text(l.cheatsheetChipAll),
                  selected: group == null,
                  onSelected: (_) => setState(() => _group = null),
                ),
              ),
              for (final name in groups)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // The KEY stays `name` (the stored English group) so it is
                  // language-independent; only the label is translated.
                  child: ChoiceChip(
                    key: Key('wallet-group-$name'),
                    label: Text(cheatsheetGroupLabel(name, l)),
                    selected: group == name,
                    onSelected: (_) => setState(() => _group = name),
                  ),
                ),
            ],
          ),
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final tag in tags)
                  FilterChip(
                    key: Key('wallet-tag-$tag'),
                    label: Text(tag),
                    selected: _selectedTags.contains(tag),
                    onSelected: (on) => setState(
                      () => on
                          ? _selectedTags.add(tag)
                          : _selectedTags.remove(tag),
                    ),
                  ),
              ],
            ),
          ),
        if (matches.isEmpty)
          Expanded(
            child: Center(
              key: const Key('wallet-no-matches'),
              child: Text(l.cheatsheetNoMatches),
            ),
          )
        else
          Expanded(child: _grid(matches)),
      ],
    );
  }

  /// Every wallet group in use, sorted case-insensitively.
  List<String> _groupsInUse(List<CheatsheetCard> cards) {
    final seen = {for (final c in cards) c.walletGroup};
    return seen.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Every tag in use, normalized and de-duplicated, in a stable order.
  List<String> _allTags(List<CheatsheetCard> cards) {
    final seen = <String>{};
    for (final c in cards) {
      for (final t in c.tags) {
        final n = normalizeTag(t);
        if (n.isNotEmpty) seen.add(n);
      }
    }
    return seen.toList()..sort();
  }

  List<CheatsheetCard> _filter(List<CheatsheetCard> cards, String? group) {
    final q = _query.trim().toLowerCase();
    return cards.where((c) {
      if (group != null && c.walletGroup != group) return false;
      if (q.isNotEmpty && !c.title.toLowerCase().contains(q)) return false;
      if (_selectedTags.isEmpty) return true;
      final cardTags = c.tags.map(normalizeTag).toSet();
      return _selectedTags.every(cardTags.contains);
    }).toList();
  }

  Widget _grid(List<CheatsheetCard> cards) {
    // Deterministic: title case-insensitively, then id as the tie-breaker.
    // Without the id, two same-titled cards could swap places between builds.
    final sorted = [...cards]
      ..sort((a, b) {
        final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      });

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        key: const Key('wallet-grid'),
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: walletColumnsFor(constraints.maxWidth),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: sorted.length,
        itemBuilder: (context, i) {
          final c = sorted[i];
          return CardTile(
            key: Key('wallet-card-${c.id}'),
            card: c,
            onTap: () => ref.read(cheatsheetOpenCardProvider)(context, c.id),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: Lower the icon-button allow-list**

In `test/core/help/icon_button_guard_test.dart`, delete the line (line 22):

```dart
  'lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart': 1,
```

- [ ] **Step 7: Run the wallet, help, guard and route tests**

Run: `flutter test test/features/cheatsheet/presentation/cheatsheet_wallet_screen_test.dart test/core/help test/core/navigation/cheatsheet_routes_test.dart test/features/dashboard`
Expected: `All tests passed!` (the existing `every HelpId has complete help in en/zh` and `zh help is translated` tests now cover `cheatsheetWallet` too).

- [ ] **Step 8: Analyze and commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet lib/core/help test/features/cheatsheet test/core/help
git add lib/features/cheatsheet/presentation/screens/cheatsheet_wallet_screen.dart \
  lib/core/help/help_registry.dart \
  test/features/cheatsheet/presentation/cheatsheet_wallet_screen_test.dart \
  test/core/help/help_registry_test.dart \
  test/core/help/icon_button_guard_test.dart \
  lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/
git commit -m "$(cat <<'EOF'
feat(cheatsheet): wallet as a tile grid with group chips, and its help

2/3/4 columns by width; wallet groups become single-select chips beside
the existing search and tag filters; the add button is an HmmIconButton.
A help sheet explains tiles, group and tag chips and the lock badge.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Detail — header and Facts / Key points layouts

**Files:**
- Modify: `lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart` (imports lines 1-21; `CheatsheetDetailScreen.build` through the end of `_RowTile`, lines 136-279)
- Modify: `test/core/help/icon_button_guard_test.dart` (remove the `cheatsheet_detail_screen.dart: 3` entry, line 21 — all three become `HmmIconButton`s)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (ten detail help keys after the Task 7 `"helpCheatsheetWalletLockBody": ...,` line), regenerate `lib/l10n/gen/`
- Modify: `lib/core/help/help_registry.dart` (enum; new case after the Task 7 `HelpId.cheatsheetWallet` case)
- Test: `test/features/cheatsheet/presentation/cheatsheet_detail_screen_test.dart` (imports; append a `look` group inside `main()`, before its closing brace on line 422)
- Test: `test/core/help/help_registry_test.dart` (append two tests)

**Interfaces:**
- Consumes: `CardHeader`, `headerBarColors` (Task 6), `CheatsheetPalette.of` (Task 1), `CardLayout`, `isSingleEmoji` (Task 1), `CheatsheetRow.emoji` (Task 2), existing `ResolvedValue`, `launchActionProvider`, `_ImageValue` (unchanged, lines 281-362), `HelpButton`, `helpFor`, `HelpEntry` (`lib/core/help/`), `HelpId.cheatsheetWallet` (Task 7).
- Produces: keys `detail-header` (the `CardHeader`), `keypoint-<i>`, `keypoint-<i>-number`, `keypoint-<i>-emoji`; the existing `row-<i>-unbound|missing|image|value|open-source` and `detail-edit|delete` keys work in both layouts.
  - ARB: `helpCheatsheetDetailTitle`, `helpCheatsheetDetailSummary`, `helpCheatsheetDetail{Facts,KeyPoints,Header,Lock}{Title,Body}`
  - `HelpId.cheatsheetDetail` (entries in this order: Facts layout `Icons.list_alt`, Key points layout `Icons.format_list_numbered` — the icons the Task 9 layout control draws — cover header `Icons.image_outlined`, lock tile `Icons.lock_outline` as drawn by `sensitive_attachment_image.dart` line 213)

- [ ] **Step 1: Add the detail help strings and regenerate**

In `lib/l10n/app_en.arb`, after the `"helpCheatsheetWalletLockBody": ...,` line added in Task 7, insert:

```json
  "helpCheatsheetDetailTitle": "Cheatsheet",
  "helpCheatsheetDetailSummary": "One card, its rows filled from your notes. Edit or delete it from the top bar.",
  "helpCheatsheetDetailFactsTitle": "Facts layout",
  "helpCheatsheetDetailFactsBody": "Each row shows its label with the value from your note underneath. A dash means the row is not linked yet; \"source removed\" means its note was deleted. Tap a phone number or an address to call or map it.",
  "helpCheatsheetDetailKeyPointsTitle": "Key points layout",
  "helpCheatsheetDetailKeyPointsBody": "Rows are numbered on the card's colour, each with its emoji if one was chosen, the label in bold and the value below. Values, actions and photos work as in Facts.",
  "helpCheatsheetDetailHeaderTitle": "Cover header",
  "helpCheatsheetDetailHeaderBody": "The top of the card shows its colour and pattern or its cover photo, its icon, its title, and its group with the number of rows. Change the look in the designer.",
  "helpCheatsheetDetailLockTitle": "Locked cover",
  "helpCheatsheetDetailLockBody": "When the cover photo is protected and the vault is locked, the header shows a lock tile instead. Tap it to unlock and see the photo.",
```

In `lib/l10n/app_zh.arb`, after the `"helpCheatsheetWalletLockBody": ...,` line added in Task 7, insert:

```json
  "helpCheatsheetDetailTitle": "速查卡详情",
  "helpCheatsheetDetailSummary": "一张卡片，各行内容取自你的笔记。可在顶部栏编辑或删除。",
  "helpCheatsheetDetailFactsTitle": "“信息”布局",
  "helpCheatsheetDetailFactsBody": "每一行显示标签，下方是取自笔记的值。短横线表示该行尚未关联；“source removed”表示其笔记已被删除。点按电话号码或地址可拨打或在地图中查看。",
  "helpCheatsheetDetailKeyPointsTitle": "“要点”布局",
  "helpCheatsheetDetailKeyPointsBody": "各行在卡片颜色上编号，若已选择表情符号则一并显示，标签加粗，值显示在下方。值、操作和照片与“信息”布局相同。",
  "helpCheatsheetDetailHeaderTitle": "封面标题区",
  "helpCheatsheetDetailHeaderBody": "卡片顶部显示其颜色和图案或封面照片、图标、标题，以及所属分组和行数。可在设计器中更改外观。",
  "helpCheatsheetDetailLockTitle": "已锁定的封面",
  "helpCheatsheetDetailLockBody": "封面照片受保护且保险库已锁定时，标题区会改为显示锁定图块。点按即可解锁并查看照片。",
```

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 2: Write the failing detail and help tests**

In `test/features/cheatsheet/presentation/cheatsheet_detail_screen_test.dart`, add to the imports:

```dart
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cheatsheet_palette.dart';
```

and add this group as the last statement inside `main()` (just before the `}` that closes `main`, line 422):

```dart
  group('look', () {
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
        'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

    final keyPointsCard = card.copyWith(
      style: const CardStyle({'layout': 'keyPoints'}),
      rows: [
        card.rows[0].copyWith(emoji: '\u{1F440}'),
        card.rows[1],
        card.rows[2].copyWith(emoji: 'not an emoji'),
        ...card.rows.sublist(3),
      ],
    );

    Future<List<(ValueAction, String)>> mountLook(
      WidgetTester tester,
      CheatsheetCard c, {
      VaultStatus vault = VaultStatus.unlocked,
      Map<String, HmmNote>? notes,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final launched = <(ValueAction, String)>[];
      _SeededCheatsheets.seed = [c];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          hmmNoteRepositoryProvider.overrideWithValue(
              _FakeNotes(notes ?? {'auto1': autoNote, 'doc1': docNote})),
          cheatsheetsStateProvider.overrideWith(_SeededCheatsheets.new),
          launchActionProvider.overrideWithValue((action, value) async {
            launched.add((action, value));
          }),
          attachmentResolverProvider
              .overrideWith((ref) async => _BytesResolver(png)),
          vaultSessionProvider.overrideWith(() => _StubVault(vault)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CheatsheetDetailScreen(cardId: 'c1'),
        ),
      ));
      await tester.pumpAndSettle();
      return launched;
    }

    String textOf(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('the header shows the icon, title and group · rows',
        (tester) async {
      await mountLook(tester, card);

      expect(find.byKey(const Key('detail-header')), findsOneWidget);
      expect(textOf(tester, 'detail-header-icon'), CardLookDefaults.dividers);
      expect(textOf(tester, 'detail-header-title'), 'Claim');
      expect(textOf(tester, 'detail-header-subtitle'), 'Vehicle · 6 rows');
    });

    testWidgets('Facts stays the default and renders rows as before',
        (tester) async {
      await mountLook(tester, card);

      expect(find.byKey(const Key('keypoint-0')), findsNothing);
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.byKey(const Key('row-2-unbound')), findsOneWidget);
      expect(find.byKey(const Key('row-1-missing')), findsOneWidget);
    });

    testWidgets('Key points numbers rows, shows valid row emoji and a theme '
        'border', (tester) async {
      await mountLook(tester, keyPointsCard);

      String number(int i) => tester
          .widget<Text>(find.descendant(
            of: find.byKey(Key('keypoint-$i-number')),
            matching: find.byType(Text),
          ))
          .data!;
      expect(number(0), '1');
      expect(number(3), '4');
      expect(find.byKey(const Key('keypoint-0-emoji')), findsOneWidget);
      expect(find.byKey(const Key('keypoint-2-emoji')), findsNothing,
          reason: 'an invalid stored emoji is not shown');

      final slate = CheatsheetPalette.of(CardThemeId.slate, Brightness.light);
      final box = tester
          .widget<Container>(find.byKey(const Key('keypoint-0')))
          .decoration! as BoxDecoration;
      expect((box.border! as Border).left.color, slate.background);
    });

    testWidgets('Key points keeps unbound, missing, section text and actions',
        (tester) async {
      final launched = await mountLook(tester, keyPointsCard);

      expect(find.byKey(const Key('row-2-unbound')), findsOneWidget);
      expect(find.byKey(const Key('row-1-missing')), findsOneWidget);
      expect(find.textContaining('dd delete line'), findsOneWidget);

      await tester.tap(find.byKey(const Key('row-3-value')));
      await tester.pumpAndSettle();
      expect(launched, [(ValueAction.call, '(555) 123-4567')]);
    });

    testWidgets('an image row renders in Key points', (tester) async {
      const front = VaultRef(
        path: 'images/front.png',
        contentType: 'image/png',
        byteSize: 70,
      );
      final licence = HmmNote(
        id: 3,
        uuid: 'lic1',
        subject: 'Licence',
        authorId: 1,
        createDate: DateTime(2026),
        content: '{"note":{"content":{"DriverLicence":'
            '{"frontImagePath":"images/front.png"}}}}',
        attachments: NoteAttachments(images: const [front]),
      );
      final imageCard = card.copyWith(
        style: const CardStyle({'layout': 'keyPoints'}),
        rows: const [
          CheatsheetRow(
            label: 'Licence (front)',
            source: CheatsheetSource(
              noteUuid: 'lic1',
              kind: SourceGranularity.image,
              locator: 'images/front.png',
            ),
          ),
        ],
      );
      await mountLook(tester, imageCard, notes: {'lic1': licence});

      expect(find.byKey(const Key('keypoint-0')), findsOneWidget);
      expect(find.byKey(const Key('row-0-image')), findsOneWidget);
    });

    testWidgets('a locked sensitive cover shows the tap-to-unlock tile in the '
        'header', (tester) async {
      const secret = VaultRef(
        path: 'attachments/note-9/sensitive/c.png',
        contentType: 'image/png',
        byteSize: 70,
        sensitive: true,
      );
      await mountLook(tester, card.withCover(secret),
          vault: VaultStatus.locked);

      expect(
          find.descendant(
            of: find.byKey(const Key('detail-header')),
            matching: find.byKey(sensitiveLockedPlaceholderKey),
          ),
          findsOneWidget);
    });

    testWidgets('a cover card colours the app bar dark with white actions',
        (tester) async {
      const cover = VaultRef(
        path: 'attachments/note-9/c.png',
        contentType: 'image/png',
        byteSize: 70,
      );
      await mountLook(tester, card.withCover(cover));

      final bar = tester.widget<AppBar>(find.byType(AppBar));
      final expected =
          CheatsheetPalette.forCover(CardThemeId.slate, Brightness.light);
      expect(bar.backgroundColor, expected.background);
      expect(bar.foregroundColor, expected.foreground);
      expect(find.byKey(const Key('card-surface-cover')), findsOneWidget);
    });

    testWidgets('the detail has a help button that explains both layouts, '
        'the header and the lock tile', (tester) async {
      await mountLook(tester, card);

      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();

      expect(find.text('Facts layout'), findsOneWidget);
      expect(find.text('Key points layout'), findsOneWidget);
      expect(find.text('Cover header'), findsOneWidget);
      expect(find.text('Locked cover'), findsOneWidget);
    });
  });
```

In `test/core/help/help_registry_test.dart`, append inside `main()`:

```dart
  test('detail help covers both layouts, the header and the lock tile', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final entries = helpFor(HelpId.cheatsheetDetail, l).entries;
    // The designer's layout control draws list_alt / format_list_numbered;
    // sensitive_attachment_image.dart's lock tile draws lock_outline.
    expect(entries.map((e) => e.icon), [
      Icons.list_alt,
      Icons.format_list_numbered,
      Icons.image_outlined,
      Icons.lock_outline,
    ]);
    expect(entries.map((e) => e.title), [
      l.helpCheatsheetDetailFactsTitle,
      l.helpCheatsheetDetailKeyPointsTitle,
      l.helpCheatsheetDetailHeaderTitle,
      l.helpCheatsheetDetailLockTitle,
    ]);
  });

  test('detail help is translated entry by entry in zh', () {
    final en =
        helpFor(HelpId.cheatsheetDetail, lookupAppLocalizations(const Locale('en')));
    final zh =
        helpFor(HelpId.cheatsheetDetail, lookupAppLocalizations(const Locale('zh')));
    expect(zh.entries.length, en.entries.length);
    for (var i = 0; i < en.entries.length; i++) {
      expect(zh.entries[i].title, isNot(en.entries[i].title), reason: '$i');
      expect(zh.entries[i].body, isNot(en.entries[i].body), reason: '$i');
    }
  });
```

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/cheatsheet/presentation/cheatsheet_detail_screen_test.dart test/core/help/help_registry_test.dart`
Expected: in the detail file the existing tests pass and every test in `look` fails — e.g. `Expected: exactly one matching candidate, Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'detail-header'>]>` (the help test: `Found 0 widgets with type "HelpButton"`); `help_registry_test.dart` fails to compile — `There's no constant named 'cheatsheetDetail' in 'HelpId'`.

- [ ] **Step 4: Register the detail help**

In `lib/core/help/help_registry.dart`, change the enum (as left by Task 7) to:

```dart
enum HelpId {
  automobileHub,
  vehicleNotes,
  contacts,
  contactDetail,
  contactEdit,
  cheatsheetWallet,
  cheatsheetDetail,
}
```

and add this case after the `HelpId.cheatsheetWallet => ScreenHelp(...)` case (before the closing `};`):

```dart
      HelpId.cheatsheetDetail => ScreenHelp(
          title: l.helpCheatsheetDetailTitle,
          summary: l.helpCheatsheetDetailSummary,
          entries: [
            HelpEntry(
                icon: Icons.list_alt,
                title: l.helpCheatsheetDetailFactsTitle,
                body: l.helpCheatsheetDetailFactsBody),
            HelpEntry(
                icon: Icons.format_list_numbered,
                title: l.helpCheatsheetDetailKeyPointsTitle,
                body: l.helpCheatsheetDetailKeyPointsBody),
            HelpEntry(
                icon: Icons.image_outlined,
                title: l.helpCheatsheetDetailHeaderTitle,
                body: l.helpCheatsheetDetailHeaderBody),
            HelpEntry(
                icon: Icons.lock_outline,
                title: l.helpCheatsheetDetailLockTitle,
                body: l.helpCheatsheetDetailLockBody),
          ],
        ),
```

- [ ] **Step 5: Update the detail screen imports**

In `lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart`, add before `import '../../../../core/navigation/route_names.dart';` (line 14):

```dart
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
```

and after it:

```dart
import '../../../../core/widgets/hmm_icon_button.dart';
```

and after `import '../../data/cheatsheet_resolver.dart';` (line 16):

```dart
import '../../domain/entities/card_style.dart';
```

and after `import '../../states/derived_field_registry_provider.dart';` (line 21):

```dart
import '../look/card_header.dart';
import '../look/cheatsheet_palette.dart';
```

- [ ] **Step 6: Replace the screen's `build` and `_RowTile`**

Replace everything from `  @override\n  Widget build(BuildContext context, WidgetRef ref) {\n    final l = AppLocalizations.of(context);\n    final cards = ref.watch(cheatsheetsStateProvider);` (line 136) through the `}` that closes `class _RowTile` (line 279, the line before `/// An image row: a photo ID or insurance card, ...`) with:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cards = ref.watch(cheatsheetsStateProvider);
    final card = _findCard(cards.value ?? const [], cardId);

    if (cards.isLoading && card == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (card == null) {
      return Scaffold(
        body: Center(
          key: const Key('detail-not-found'),
          child: Text(l.cheatsheetGone),
        ),
      );
    }

    final resolved = ref.watch(cheatsheetResolvedRowsProvider(cardId));
    final brightness = Theme.of(context).brightness;
    final bar = headerBarColors(card, brightness);
    final look = card.look;
    final palette = CheatsheetPalette.of(look.theme, brightness);

    return Scaffold(
      appBar: AppBar(
        // The bar carries the card's colour so edit/delete stay legible
        // against it; a cover card gets the darkened theme with white.
        backgroundColor: bar.background,
        foregroundColor: bar.foreground,
        title: Text(card.title),
        actions: [
          const HelpButton(helpId: HelpId.cheatsheetDetail),
          HmmIconButton(
            key: const Key('detail-edit'),
            icon: Icons.edit_outlined,
            tooltip: l.cheatsheetEditTooltip,
            onPressed: () =>
                ref.read(cheatsheetEditCardProvider)(context, cardId),
          ),
          HmmIconButton(
            key: const Key('detail-delete'),
            icon: Icons.delete_outline,
            tooltip: l.cheatsheetDeleteTooltip,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        children: [
          CardHeader(key: const Key('detail-header'), card: card),
          ...resolved.when<List<Widget>>(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [Center(child: Text('$e'))],
            data: (values) => [
              for (var i = 0; i < card.rows.length; i++)
                _RowTile(
                  index: i,
                  row: card.rows[i],
                  value: i < values.length ? values[i] : const ResolvedValue(),
                  layout: look.layout,
                  colors: palette,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row in either layout. The value widget — and with it every state
/// (unbound "—", "source removed", an image, a tappable call/map value) — is
/// built once and placed by [layout], so both layouts behave identically.
class _RowTile extends ConsumerWidget {
  const _RowTile({
    required this.index,
    required this.row,
    required this.value,
    required this.layout,
    required this.colors,
  });

  final int index;
  final CheatsheetRow row;
  final ResolvedValue value;
  final CardLayout layout;
  final CardColors colors;

  Future<void> _launch(BuildContext context, WidgetRef ref, String text) async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(launchActionProvider)(row.valueAction, text);
    } on Exception catch (e) {
      // Exceptions only. A missing handler app is an expected, recoverable
      // outcome worth reporting; an Error is a defect, and showing it as
      // "could not open that" would disguise a bug as a normal failure.
      // Type only: the error can quote the value (a number or address).
      debugPrint('CheatsheetDetail: launching ${row.valueAction.name} failed '
          '(${e.runtimeType}); showed the user a message.');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.cheatsheetOpenFailed)),
      );
    }
  }

  Widget _valueWidget(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).disabledColor,
          fontStyle: FontStyle.italic,
        );
    if (value.unbound) {
      return Text('—', key: Key('row-$index-unbound'), style: muted);
    }
    if (value.missing) {
      return Text(
        'source removed',
        key: Key('row-$index-missing'),
        style: muted,
      );
    }
    if (value.image != null) {
      return _ImageValue(
        key: Key('row-$index-image'),
        image: value.image!,
        label: row.label,
      );
    }
    final text = value.text ?? '';
    final action = row.valueAction;
    return InkWell(
      key: Key('row-$index-value'),
      onTap: action == ValueAction.none
          ? null
          : () => _launch(context, ref, text),
      child: Text(
        text,
        style: action == ValueAction.none
            ? null
            : TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget? _openSourceButton(BuildContext context, WidgetRef ref) {
    final CheatsheetSource? source = row.source;
    if (!row.openSource || source == null) return null;
    final l = AppLocalizations.of(context);
    return HmmIconButton(
      key: Key('row-$index-open-source'),
      icon: Icons.open_in_new,
      tooltip: l.cheatsheetOpenSourceTooltip,
      onPressed: () =>
          ref.read(cheatsheetOpenSourceProvider)(context, source.noteUuid),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valueWidget = _valueWidget(context, ref);
    final trailing = _openSourceButton(context, ref);

    if (layout == CardLayout.facts) {
      return ListTile(
        title: Text(row.label),
        subtitle: valueWidget,
        trailing: trailing,
      );
    }

    final emoji = row.emoji;
    return Container(
      key: Key('keypoint-$index'),
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.background, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number on the theme colour in its own text colour, so the pair
          // is covered by the palette's AA test.
          Container(
            key: Key('keypoint-$index-number'),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.background,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (emoji != null && isSingleEmoji(emoji))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(emoji, key: Key('keypoint-$index-emoji')),
                      ),
                    Expanded(
                      child: Text(
                        row.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                valueWidget,
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Lower the icon-button allow-list**

In `test/core/help/icon_button_guard_test.dart`, delete the line (line 21):

```dart
  'lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart': 3,
```

- [ ] **Step 8: Run the detail, help, guard, acceptance and route tests**

Run: `flutter test test/features/cheatsheet/presentation/cheatsheet_detail_screen_test.dart test/core/help test/features/cheatsheet/cheatsheet_acceptance_test.dart test/core/navigation/cheatsheet_routes_test.dart`
Expected: `All tests passed!`

- [ ] **Step 9: Analyze and commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet lib/core/help test/features/cheatsheet test/core/help
git add lib/features/cheatsheet/presentation/screens/cheatsheet_detail_screen.dart \
  lib/core/help/help_registry.dart \
  test/features/cheatsheet/presentation/cheatsheet_detail_screen_test.dart \
  test/core/help/help_registry_test.dart \
  test/core/help/icon_button_guard_test.dart \
  lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/
git commit -m "$(cat <<'EOF'
feat(cheatsheet): detail header, Key points layout, and its help

A themed header leads the card; Key points numbers rows on the theme
colour with optional row emoji. Both layouts share one value widget, so
unbound, missing, image and call/map rows behave as before. A help sheet
explains both layouts, the cover header and the locked-cover tile.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Designer "Look" section, emoji picker, cover, row emoji, help

This task has four TDD cycles (editor state → emoji catalog → sheets → designer). Commit after each.

**Files:**
- Modify: `lib/l10n/app_en.arb` (after `"cheatsheetChipAll": "All",` from Task 7; help keys after the Task 8 `"helpCheatsheetDetailLockBody": ...,` line), `lib/l10n/app_zh.arb` (after `"cheatsheetChipAll": "全部",`; help keys after the Task 8 `"helpCheatsheetDetailLockBody": ...,` line), regenerate `lib/l10n/gen/`
- Create: `lib/features/cheatsheet/states/cheatsheet_cover_draft.dart`
- Modify: `lib/features/cheatsheet/states/cheatsheet_editor_state.dart` (imports lines 1-10; `startFromTemplate` lines 47-57; `load` line 60; `commit` lines 90-91; new look methods)
- Create: `lib/features/cheatsheet/presentation/look/emoji_catalog.dart`
- Create: `lib/features/cheatsheet/presentation/look/look_labels.dart`
- Create: `lib/features/cheatsheet/presentation/look/emoji_picker.dart`
- Create: `lib/features/cheatsheet/presentation/look/cover_action_sheet.dart`
- Create: `lib/features/cheatsheet/presentation/widgets/look_section.dart`
- Modify: `lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart` (imports after line 6; app-bar actions lines 201-207; form children after line 217; `_rowTile` row header lines 266-276; new `_emojiSlot` / `_chooseRowEmoji` before `_actionLabel`, line 312)
- Modify: `lib/core/help/help_registry.dart` (enum; new case after the Task 8 `HelpId.cheatsheetDetail` case)
- Modify: `test/features/cheatsheet/presentation/cheatsheet_designer_screen_test.dart` (`mount` and the two-cards container: tall view + `cheatsheetCoversSupportedProvider` override — Look now opens expanded on create)
- Modify: `test/features/cheatsheet/cheatsheet_acceptance_test.dart` (same tall view + override, for its create step)
- Test: `test/features/cheatsheet/states/cheatsheet_editor_state_test.dart` (append a `look` group inside `main()`)
- Test: `test/features/cheatsheet/presentation/look/emoji_catalog_test.dart` (new)
- Test: `test/features/cheatsheet/presentation/look/look_sheets_test.dart` (new)
- Test: `test/features/cheatsheet/presentation/cheatsheet_designer_look_test.dart` (new)
- Test: `test/core/help/help_registry_test.dart` (append one test)

**Interfaces:**
- Consumes: `CardStyle.with*`, `CardLook`, `isSingleEmoji` (Task 1); `CheatsheetCard.withCover`, `CheatsheetRow.copyWith(emoji/clearEmoji)` (Task 2); `CheatsheetsState.save(card, newCover:, released:)` (Task 3); `CardTile`, `CardSurface`, `CardPatternPainter`, `CheatsheetPalette` (Tasks 1, 6); `imageByteSourceProvider` / `ImageByteSource.pick(AttachmentPickSource)` (`image_byte_source.dart` lines 37-64); `documentScannerProvider` / `DocumentScanner.isAvailable()` / `scan()` (`document_scanner.dart` lines 13-45); `dataModeProvider`; `HelpButton`, `helpFor`, `HelpEntry` (`lib/core/help/`).
- Produces:
  - `class CoverDraft { final PickedImageBytes? pending; final List<VaultRef> released; }`, `cheatsheetCoverDraftProvider : NotifierProvider<CheatsheetCoverDraft, CoverDraft>` with `clear()`, `stage(PickedImageBytes)`, `dropPending()`, `release(VaultRef)`
  - `CheatsheetEditor.setTheme(CardThemeId)`, `setPattern(CardPattern)`, `setIcon(String?)`, `setLayout(CardLayout)`, `setRowEmoji(int, String?)`, `pickCover(PickedImageBytes)`, `removeCover()`, `resetLook()`; `commit()` now passes the draft
  - `enum EmojiGroup { vehicle, health, home, books, work, travel, money, misc }`, `class EmojiEntry`, `EmojiCatalog.entries / inGroup(EmojiGroup) / search(String)`
  - `cheatsheetThemeLabel(CardThemeId, AppLocalizations)`, `cheatsheetPatternLabel(CardPattern, …)`, `cheatsheetLayoutLabel(CardLayout, …)`, `emojiGroupLabel(EmojiGroup, …)`
  - `Future<String?> showEmojiPicker(BuildContext, {bool allowClear = false})` (`''` = "No emoji"), `class EmojiPickerSheet`, `cheatsheetEmojiPickerProvider`
  - `enum CoverAction { camera, library, scan, remove }`, `Future<CoverAction?> showCoverActionSheet(BuildContext, {required bool hasCover, required bool canScan})`, `cheatsheetCoverActionProvider`
  - `cheatsheetCoversSupportedProvider : Provider<bool>` (false in cloudApi), `class LookSection({Key? key, required bool initiallyExpanded})` — the designer passes `widget.cardId == null`: expanded when creating, collapsed (mini-tile preview in its header) when editing
  - `HelpId.cheatsheetDesigner` (Tasks 7 and 8 already added `HelpId.cheatsheetWallet` and `HelpId.cheatsheetDetail`)

#### 9a — strings

- [ ] **Step 1: Add every remaining ARB string and regenerate**

In `lib/l10n/app_en.arb`, after `"cheatsheetChipAll": "All",` insert:

```json
  "cheatsheetLookTitle": "Look",
  "cheatsheetLookTheme": "Colour",
  "cheatsheetLookPattern": "Pattern",
  "cheatsheetLookIcon": "Icon",
  "cheatsheetLookCover": "Cover photo",
  "cheatsheetLookLayout": "Layout",
  "cheatsheetLookReset": "Reset look",
  "cheatsheetLayoutFacts": "Facts",
  "cheatsheetLayoutKeyPoints": "Key points",
  "cheatsheetThemeBlue": "Blue",
  "cheatsheetThemeGreen": "Green",
  "cheatsheetThemeOrange": "Orange",
  "cheatsheetThemeRed": "Red",
  "cheatsheetThemePurple": "Purple",
  "cheatsheetThemeTeal": "Teal",
  "cheatsheetThemePink": "Pink",
  "cheatsheetThemeAmber": "Amber",
  "cheatsheetThemeSlate": "Slate",
  "cheatsheetThemeIndigo": "Indigo",
  "cheatsheetThemeBrown": "Brown",
  "cheatsheetThemeBlack": "Black",
  "cheatsheetPatternNone": "Plain",
  "cheatsheetPatternDots": "Dots",
  "cheatsheetPatternStripes": "Stripes",
  "cheatsheetPatternGrid": "Grid",
  "cheatsheetPatternWaves": "Waves",
  "cheatsheetIconChoose": "Choose icon",
  "cheatsheetCoverAdd": "Add cover",
  "cheatsheetCoverChange": "Change cover",
  "cheatsheetCoverRemove": "Remove cover",
  "cheatsheetCoverCamera": "Take a photo",
  "cheatsheetCoverLibrary": "Choose from photos",
  "cheatsheetCoverScan": "Scan a document",
  "cheatsheetCoverFailed": "Could not add that photo.",
  "cheatsheetEmojiPickerTitle": "Choose an emoji",
  "cheatsheetEmojiSearchHint": "Search in English or Chinese",
  "cheatsheetEmojiCustomLabel": "Or type any emoji",
  "cheatsheetEmojiUse": "Use",
  "cheatsheetEmojiInvalid": "Enter one emoji.",
  "cheatsheetEmojiClear": "No emoji",
  "cheatsheetEmojiNoMatches": "No emoji match that search.",
  "cheatsheetEmojiGroupVehicle": "Vehicle",
  "cheatsheetEmojiGroupHealth": "Health",
  "cheatsheetEmojiGroupHome": "Home",
  "cheatsheetEmojiGroupBooks": "Books & learning",
  "cheatsheetEmojiGroupWork": "Work",
  "cheatsheetEmojiGroupTravel": "Travel",
  "cheatsheetEmojiGroupMoney": "Money",
  "cheatsheetEmojiGroupMisc": "Misc",
  "cheatsheetRowEmojiTooltip": "Row emoji",
```

and after the `"helpCheatsheetDetailLockBody": ...,` line added in Task 8 insert:

```json
  "helpCheatsheetDesignerTitle": "Designing a cheatsheet",
  "helpCheatsheetDesignerSummary": "Name the card, choose how it looks, then point each row at a piece of a note.",
  "helpCheatsheetDesignerLookTitle": "Look",
  "helpCheatsheetDesignerLookBody": "Look holds the colour, pattern, icon, cover and layout. It starts open on a new card and folded on an existing one; tap its header to open or fold it. The small tile in the header previews the card as it will appear in the wallet.",
  "helpCheatsheetDesignerIconTitle": "Icon",
  "helpCheatsheetDesignerIconBody": "Choose an emoji for the card. Search in English or Chinese, or type any emoji yourself.",
  "helpCheatsheetDesignerCoverTitle": "Cover photo",
  "helpCheatsheetDesignerCoverBody": "Take a photo, choose one from your photos or scan a document to use as the card's background; the text gets a dark gradient so it stays readable. Remove it any time and the colour comes back. Covers are available in Local and Cloud Storage modes.",
  "helpCheatsheetDesignerLayoutTitle": "Layout",
  "helpCheatsheetDesignerLayoutBody": "Facts shows each label beside its value. Key points numbers the rows and colours them with the card's theme, which suits books and documents.",
  "helpCheatsheetDesignerRowEmojiTitle": "Row emoji",
  "helpCheatsheetDesignerRowEmojiBody": "In Key points, each row can carry its own emoji. Switching to Facts hides them without deleting them.",
  "helpCheatsheetDesignerResetTitle": "Reset look",
  "helpCheatsheetDesignerResetBody": "Returns the colour, pattern, icon and layout to the template's defaults, removes the cover photo and clears every row emoji.",
```

In `lib/l10n/app_zh.arb`, after `"cheatsheetChipAll": "全部",` insert:

```json
  "cheatsheetLookTitle": "外观",
  "cheatsheetLookTheme": "颜色",
  "cheatsheetLookPattern": "图案",
  "cheatsheetLookIcon": "图标",
  "cheatsheetLookCover": "封面照片",
  "cheatsheetLookLayout": "布局",
  "cheatsheetLookReset": "重置外观",
  "cheatsheetLayoutFacts": "信息",
  "cheatsheetLayoutKeyPoints": "要点",
  "cheatsheetThemeBlue": "蓝色",
  "cheatsheetThemeGreen": "绿色",
  "cheatsheetThemeOrange": "橙色",
  "cheatsheetThemeRed": "红色",
  "cheatsheetThemePurple": "紫色",
  "cheatsheetThemeTeal": "青色",
  "cheatsheetThemePink": "粉色",
  "cheatsheetThemeAmber": "琥珀色",
  "cheatsheetThemeSlate": "石板灰",
  "cheatsheetThemeIndigo": "靛蓝",
  "cheatsheetThemeBrown": "棕色",
  "cheatsheetThemeBlack": "黑色",
  "cheatsheetPatternNone": "纯色",
  "cheatsheetPatternDots": "圆点",
  "cheatsheetPatternStripes": "条纹",
  "cheatsheetPatternGrid": "网格",
  "cheatsheetPatternWaves": "波浪",
  "cheatsheetIconChoose": "选择图标",
  "cheatsheetCoverAdd": "添加封面",
  "cheatsheetCoverChange": "更换封面",
  "cheatsheetCoverRemove": "移除封面",
  "cheatsheetCoverCamera": "拍照",
  "cheatsheetCoverLibrary": "从相册选择",
  "cheatsheetCoverScan": "扫描文档",
  "cheatsheetCoverFailed": "无法添加该照片。",
  "cheatsheetEmojiPickerTitle": "选择表情符号",
  "cheatsheetEmojiSearchHint": "用中文或英文搜索",
  "cheatsheetEmojiCustomLabel": "或输入任意表情符号",
  "cheatsheetEmojiUse": "使用",
  "cheatsheetEmojiInvalid": "请输入一个表情符号。",
  "cheatsheetEmojiClear": "不使用表情符号",
  "cheatsheetEmojiNoMatches": "没有匹配的表情符号。",
  "cheatsheetEmojiGroupVehicle": "车辆",
  "cheatsheetEmojiGroupHealth": "健康",
  "cheatsheetEmojiGroupHome": "家居",
  "cheatsheetEmojiGroupBooks": "书籍与学习",
  "cheatsheetEmojiGroupWork": "工作",
  "cheatsheetEmojiGroupTravel": "旅行",
  "cheatsheetEmojiGroupMoney": "财务",
  "cheatsheetEmojiGroupMisc": "其他",
  "cheatsheetRowEmojiTooltip": "行表情符号",
```

and after the `"helpCheatsheetDetailLockBody": ...,` line added in Task 8 insert:

```json
  "helpCheatsheetDesignerTitle": "设计速查卡",
  "helpCheatsheetDesignerSummary": "为卡片命名、选择外观，然后将每一行指向笔记中的某一部分。",
  "helpCheatsheetDesignerLookTitle": "外观",
  "helpCheatsheetDesignerLookBody": "“外观”包含颜色、图案、图标、封面和布局。新建卡片时默认展开，编辑已有卡片时默认收起；点按其标题栏即可展开或收起。标题栏中的小卡片会预览卡片在卡包中的样子。",
  "helpCheatsheetDesignerIconTitle": "图标",
  "helpCheatsheetDesignerIconBody": "为卡片选择一个表情符号。可用中文或英文搜索，也可以自己输入任意表情符号。",
  "helpCheatsheetDesignerCoverTitle": "封面照片",
  "helpCheatsheetDesignerCoverBody": "拍照、从相册选择或扫描文档作为卡片背景；文字下方会加深色渐变以保持清晰。随时可以移除，颜色会恢复。封面仅在本地和云存储模式下可用。",
  "helpCheatsheetDesignerLayoutTitle": "布局",
  "helpCheatsheetDesignerLayoutBody": "“信息”在每个标签旁显示其值。“要点”为各行编号并使用卡片主题颜色，适合书籍和文档。",
  "helpCheatsheetDesignerRowEmojiTitle": "行表情符号",
  "helpCheatsheetDesignerRowEmojiBody": "在“要点”布局中，每一行都可以有自己的表情符号。切换到“信息”会隐藏它们，但不会删除。",
  "helpCheatsheetDesignerResetTitle": "重置外观",
  "helpCheatsheetDesignerResetBody": "将颜色、图案、图标和布局恢复为模板默认值，移除封面照片并清除所有行表情符号。",
```

Run: `flutter gen-l10n`
Expected: no errors.

#### 9b — editor state and cover draft

- [ ] **Step 2: Write the failing editor tests**

In `test/features/cheatsheet/states/cheatsheet_editor_state_test.dart` add to the imports:

```dart
import 'dart:typed_data';

import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_cover_draft.dart';
```

(`attachment_ref.dart` and `image_byte_source.dart` were added in Task 3.) Then append this group as the last statement inside `main()`:

```dart
  group('look', () {
    setUp(() {
      _CapturingCheatsheets.covers.clear();
      _CapturingCheatsheets.releases.clear();
    });

    const eyes = '\u{1F440}';
    const star = '⭐';
    const cover = VaultRef(
      path: 'attachments/note-1/c.jpg',
      contentType: 'image/jpeg',
      byteSize: 3,
    );
    const existing = CheatsheetCard(
      id: 'e1',
      title: 'Vim',
      walletGroup: 'Reference',
      tags: [],
      templateId: 'document',
      rows: [CheatsheetRow(label: 'Motions', source: null)],
    );
    PickedImageBytes pick() => PickedImageBytes(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          originalName: 'c.png',
          contentType: 'image/png',
        );

    test('the template theme stores nothing; another theme is stored', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.startFromTemplate('accidentClaim', en);

      editor.setTheme(CardThemeId.red);
      expect(c.read(cheatsheetEditorProvider).style.toMap(), {'theme': 'red'});

      editor.setTheme(CardThemeId.blue);
      expect(c.read(cheatsheetEditorProvider).style.isEmpty, isTrue);
    });

    test('pattern, icon and layout edits store only non-defaults', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.startFromTemplate('document', en);

      editor.setPattern(CardPattern.grid);
      editor.setIcon('\u{1F984}');
      editor.setLayout(CardLayout.facts);
      expect(c.read(cheatsheetEditorProvider).style.toMap(),
          {'pattern': 'grid', 'icon': '\u{1F984}', 'layout': 'facts'});

      editor.setIcon(null);
      editor.setLayout(CardLayout.keyPoints);
      expect(c.read(cheatsheetEditorProvider).style.toMap(),
          {'pattern': 'grid'});
    });

    test('a layout round trip keeps every row emoji', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.startFromTemplate('document', en);
      editor.addRow('Second');
      editor.setRowEmoji(0, eyes);
      editor.setRowEmoji(1, star);

      editor.setLayout(CardLayout.facts);
      editor.setLayout(CardLayout.keyPoints);

      final card = c.read(cheatsheetEditorProvider);
      expect(card.rows.map((r) => r.emoji), [eyes, star]);
      expect(card.style.isEmpty, isTrue,
          reason: 'Key points is the document default');
    });

    test('setRowEmoji with null or empty clears it; a stale index is a no-op',
        () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(existing);
      editor.setRowEmoji(0, eyes);
      editor.setRowEmoji(0, '');
      expect(c.read(cheatsheetEditorProvider).rows.single.emoji, isNull);
      editor.setRowEmoji(0, eyes);
      editor.setRowEmoji(0, null);
      expect(c.read(cheatsheetEditorProvider).rows.single.emoji, isNull);
      editor.setRowEmoji(9, eyes);
      expect(c.read(cheatsheetEditorProvider).rows, hasLength(1));
    });

    test('picking a cover stages it and commit hands it to save', () async {
      final c = containerWith();
      final editor = editorOf(c);
      editor.startFromTemplate('blank', en);

      editor.pickCover(pick());
      expect(c.read(cheatsheetCoverDraftProvider).pending, isNotNull);

      await editor.commit();
      expect(_CapturingCheatsheets.covers.single, isNotNull);
      expect(_CapturingCheatsheets.releases.single, isEmpty);
    });

    test('replacing a stored cover releases the old one on commit', () async {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(existing.withCover(cover));

      editor.pickCover(pick());
      expect(c.read(cheatsheetEditorProvider).cover, isNull);

      await editor.commit();
      expect(_CapturingCheatsheets.releases.single, [cover]);
      expect(_CapturingCheatsheets.covers.single, isNotNull);
    });

    test('removing drops a pending pick and releases the stored cover',
        () async {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(existing.withCover(cover));
      editor.pickCover(pick());

      editor.removeCover();
      await editor.commit();

      expect(_CapturingCheatsheets.covers.single, isNull);
      expect(_CapturingCheatsheets.releases.single, [cover]);
      expect(_CapturingCheatsheets.saved.last.cover, isNull);
      expect(_CapturingCheatsheets.saved.last.style.coverPath, isNull);
    });

    test('reset look clears style, row emoji and preserved raw look keys, and '
        'releases the cover', () async {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(existing
          .copyWith(
            style: const CardStyle({'theme': 'red', 'sparkle': true}),
            rows: const [
              CheatsheetRow(
                label: 'Motions',
                source: null,
                emoji: eyes,
                extraFields: {'hint': 1},
              ),
            ],
            extraFields: const {'future': 2},
          )
          .withCover(cover));

      editor.resetLook();
      final card = c.read(cheatsheetEditorProvider);
      expect(card.style.isEmpty, isTrue);
      expect(card.cover, isNull);
      expect(card.rows.single.emoji, isNull);
      expect(card.rows.single.extraFields, {'hint': 1});
      expect(card.extraFields, {'future': 2});

      await editor.commit();
      expect(_CapturingCheatsheets.releases.single, [cover]);
    });

    test('reset look also drops a preserved non-map style and a non-string '
        'row emoji', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(existing.copyWith(
        extraFields: const {'style': 'odd'},
        rows: const [
          CheatsheetRow(
            label: 'Motions',
            source: null,
            extraFields: {'emoji': 42},
          ),
        ],
      ));

      editor.resetLook();
      final card = c.read(cheatsheetEditorProvider);
      expect(card.extraFields.containsKey('style'), isFalse);
      expect(card.rows.single.extraFields.containsKey('emoji'), isFalse);
    });

    test('loading a card discards a pending cover from an earlier visit', () {
      final c = containerWith();
      final editor = editorOf(c);
      editor.load(existing.withCover(cover));
      editor.pickCover(pick());

      editor.load(existing);

      final draft = c.read(cheatsheetCoverDraftProvider);
      expect(draft.pending, isNull);
      expect(draft.released, isEmpty);
    });
  });
```

- [ ] **Step 3: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/states/cheatsheet_editor_state_test.dart`
Expected: compilation fails — `cheatsheet_cover_draft.dart` does not exist; `The method 'setTheme' isn't defined for the type 'CheatsheetEditor'`.

- [ ] **Step 4: Create the cover draft**

Create `lib/features/cheatsheet/states/cheatsheet_cover_draft.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';

/// The designer's unsaved cover changes, kept beside the card being edited
/// because neither belongs in the card: [pending] has no vault path until the
/// save writes it, and [released] are covers this edit dropped — deleted only
/// after the save lands (see `CheatsheetsState.save`).
class CoverDraft {
  const CoverDraft({this.pending, this.released = const []});

  final PickedImageBytes? pending;
  final List<VaultRef> released;
}

class CheatsheetCoverDraft extends Notifier<CoverDraft> {
  @override
  CoverDraft build() => const CoverDraft();

  void clear() => state = const CoverDraft();

  void stage(PickedImageBytes pick) =>
      state = CoverDraft(pending: pick, released: state.released);

  void dropPending() => state = CoverDraft(released: state.released);

  void release(VaultRef cover) => state = CoverDraft(
        pending: state.pending,
        released: [...state.released, cover],
      );
}

final cheatsheetCoverDraftProvider =
    NotifierProvider<CheatsheetCoverDraft, CoverDraft>(
        CheatsheetCoverDraft.new);
```

- [ ] **Step 5: Add the look methods to the editor**

In `lib/features/cheatsheet/states/cheatsheet_editor_state.dart`:

Add to the imports (after `import '../../../core/util/uuid.dart';`, line 5):

```dart
import '../../../core/data/attachments/picker/image_byte_source.dart';
```

and after `import '../domain/entities/cheatsheet_source.dart';` (line 9):

```dart
import '../domain/entities/card_style.dart';
import 'cheatsheet_cover_draft.dart';
```

In `startFromTemplate`, insert as its first statement (before `final templates = ...`, line 48):

```dart
    ref.read(cheatsheetCoverDraftProvider.notifier).clear();
```

Replace `void load(CheatsheetCard existing) => state = existing;` (line 60) with:

```dart
  void load(CheatsheetCard existing) {
    // A cover picked on an earlier, abandoned visit must not ride along.
    ref.read(cheatsheetCoverDraftProvider.notifier).clear();
    state = existing;
  }
```

Replace `commit()` (lines 90-91) with the look methods and the new commit:

```dart
  void setTheme(CardThemeId theme) => state = state.copyWith(
      style: state.style.withTheme(theme, templateId: state.templateId));

  void setPattern(CardPattern pattern) =>
      state = state.copyWith(style: state.style.withPattern(pattern));

  /// Null or empty returns the card to its template icon.
  void setIcon(String? icon) => state = state.copyWith(
      style: state.style.withIcon(icon, templateId: state.templateId));

  /// Row emoji are untouched: Facts hides them, it never deletes them.
  void setLayout(CardLayout layout) => state = state.copyWith(
      style: state.style.withLayout(layout, templateId: state.templateId));

  /// Null or empty clears the row's emoji.
  void setRowEmoji(int index, String? emoji) => _updateRow(
        index,
        (r) => emoji == null || emoji.isEmpty
            ? r.copyWith(clearEmoji: true)
            : r.copyWith(emoji: emoji),
      );

  /// Stages [pick] as the new cover; a stored cover is released on save.
  void pickCover(PickedImageBytes pick) {
    final draft = ref.read(cheatsheetCoverDraftProvider.notifier);
    final old = state.cover;
    if (old != null) draft.release(old);
    state = state.withCover(null);
    draft.stage(pick);
  }

  void removeCover() {
    final draft = ref.read(cheatsheetCoverDraftProvider.notifier);
    draft.dropPending();
    final old = state.cover;
    if (old != null) draft.release(old);
    state = state.withCover(null);
  }

  /// Back to the template look: no style (including a preserved raw one), no
  /// row emoji (including preserved raw ones), no cover.
  void resetLook() {
    removeCover();
    state = state.copyWith(
      style: CardStyle.empty,
      extraFields: {
        for (final e in state.extraFields.entries)
          if (e.key != 'style') e.key: e.value,
      },
      rows: [
        for (final r in state.rows)
          r.copyWith(
            clearEmoji: true,
            extraFields: {
              for (final e in r.extraFields.entries)
                if (e.key != 'emoji') e.key: e.value,
            },
          ),
      ],
    );
  }

  Future<void> commit() {
    final draft = ref.read(cheatsheetCoverDraftProvider);
    return ref.read(cheatsheetsStateProvider.notifier).save(
          state,
          newCover: draft.pending,
          released: draft.released,
        );
  }
```

- [ ] **Step 6: Run the editor tests to see them pass**

Run: `flutter test test/features/cheatsheet/states/cheatsheet_editor_state_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet test/features/cheatsheet
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen/ \
  lib/features/cheatsheet/states/cheatsheet_cover_draft.dart \
  lib/features/cheatsheet/states/cheatsheet_editor_state.dart \
  test/features/cheatsheet/states/cheatsheet_editor_state_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): editor look actions and cover draft

Theme, pattern, icon, layout and row emoji edits store only non-defaults;
covers are staged and released through a draft the save consumes; Reset
look clears every look trace and releases the cover.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

#### 9c — emoji catalog and labels

- [ ] **Step 8: Write the failing catalog test**

Create `test/features/cheatsheet/presentation/look/emoji_catalog_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/emoji_catalog.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/look_labels.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  test('every entry is one emoji, unique, with English and Chinese keywords',
      () {
    final seen = <String>{};
    for (final e in EmojiCatalog.entries) {
      expect(isSingleEmoji(e.emoji), isTrue, reason: e.en.first);
      expect(seen.add(e.emoji), isTrue, reason: 'duplicate ${e.en.first}');
      expect(e.en, isNotEmpty);
      expect(e.zh, isNotEmpty);
      expect(e.en.every((k) => k == k.toLowerCase()), isTrue,
          reason: 'English keywords are stored lower-case');
    }
  });

  test('every group has at least six entries', () {
    for (final g in EmojiGroup.values) {
      expect(EmojiCatalog.inGroup(g).length, greaterThanOrEqualTo(6),
          reason: g.name);
    }
  });

  test('search matches English keywords case-insensitively', () {
    expect(EmojiCatalog.search('BOOK').map((e) => e.emoji),
        containsAll(['\u{1F4D6}', '\u{1F4DA}']));
    expect(EmojiCatalog.search('car').map((e) => e.emoji),
        contains('\u{1F697}'));
  });

  test('search matches Chinese keywords', () {
    expect(EmojiCatalog.search('护照').map((e) => e.emoji), ['\u{1F6C2}']);
    expect(EmojiCatalog.search('汽车').map((e) => e.emoji),
        contains('\u{1F697}'));
  });

  test('an empty query returns everything; nonsense returns nothing', () {
    expect(EmojiCatalog.search('  '), EmojiCatalog.entries);
    expect(EmojiCatalog.search('zzzz'), isEmpty);
  });

  for (final code in ['en', 'zh']) {
    test('every theme, pattern, layout and group has a distinct $code label',
        () {
      final l = lookupAppLocalizations(Locale(code));
      Set<String> labels(Iterable<String> all) {
        final s = all.toSet();
        expect(s.every((x) => x.trim().isNotEmpty), isTrue);
        return s;
      }

      expect(labels(CardThemeId.values.map((t) => cheatsheetThemeLabel(t, l))),
          hasLength(CardThemeId.values.length));
      expect(
          labels(CardPattern.values.map((p) => cheatsheetPatternLabel(p, l))),
          hasLength(CardPattern.values.length));
      expect(labels(CardLayout.values.map((x) => cheatsheetLayoutLabel(x, l))),
          hasLength(CardLayout.values.length));
      expect(labels(EmojiGroup.values.map((g) => emojiGroupLabel(g, l))),
          hasLength(EmojiGroup.values.length));
    });
  }
}
```

- [ ] **Step 9: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/presentation/look/emoji_catalog_test.dart`
Expected: compilation fails — `emoji_catalog.dart` and `look_labels.dart` do not exist.

- [ ] **Step 10: Create the catalog**

Create `lib/features/cheatsheet/presentation/look/emoji_catalog.dart`:

```dart
/// The emoji picker's curated grid. Keywords are SEARCH vocabulary, not copy:
/// both languages are always searched, whatever the UI locale, so a bilingual
/// user can type either. Code points are escaped so a variation selector
/// (U+FE0F) can never be lost by an editor.
enum EmojiGroup { vehicle, health, home, books, work, travel, money, misc }

class EmojiEntry {
  const EmojiEntry(this.emoji, this.group, this.en, this.zh);

  final String emoji;
  final EmojiGroup group;

  /// Lower-case English keywords; the first is the accessible name.
  final List<String> en;

  /// Chinese keywords; the first is the accessible name in zh.
  final List<String> zh;
}

class EmojiCatalog {
  const EmojiCatalog._();

  static const List<EmojiEntry> entries = [
    // Vehicle
    EmojiEntry('\u{1F697}', EmojiGroup.vehicle, ['car', 'vehicle', 'auto'], ['汽车', '车']),
    EmojiEntry('\u{1F699}', EmojiGroup.vehicle, ['suv', 'jeep'], ['越野车', '车']),
    EmojiEntry('\u{1F3CD}️', EmojiGroup.vehicle, ['motorcycle', 'motorbike'], ['摩托车']),
    EmojiEntry('\u{1F6B2}', EmojiGroup.vehicle, ['bicycle', 'bike'], ['自行车']),
    EmojiEntry('⛽', EmojiGroup.vehicle, ['fuel', 'gas', 'petrol'], ['加油', '汽油']),
    EmojiEntry('\u{1F527}', EmojiGroup.vehicle, ['wrench', 'repair', 'service'], ['维修', '扳手']),
    EmojiEntry('\u{1F6DE}', EmojiGroup.vehicle, ['tire', 'tyre', 'wheel'], ['轮胎', '车轮']),
    EmojiEntry('\u{1F6A6}', EmojiGroup.vehicle, ['traffic light', 'road'], ['红绿灯', '交通']),
    // Health
    EmojiEntry('⚕️', EmojiGroup.health, ['medical', 'health'], ['医疗', '健康']),
    EmojiEntry('\u{1F48A}', EmojiGroup.health, ['pill', 'medicine', 'drug'], ['药', '药丸']),
    EmojiEntry('\u{1FA7A}', EmojiGroup.health, ['stethoscope', 'doctor'], ['医生', '听诊器']),
    EmojiEntry('\u{1F3E5}', EmojiGroup.health, ['hospital', 'clinic'], ['医院', '诊所']),
    EmojiEntry('\u{1F9B7}', EmojiGroup.health, ['tooth', 'dentist', 'dental'], ['牙齿', '牙医']),
    EmojiEntry('\u{1FA79}', EmojiGroup.health, ['bandage', 'first aid'], ['创可贴', '急救']),
    EmojiEntry('❤️', EmojiGroup.health, ['heart', 'love'], ['心', '爱']),
    EmojiEntry('\u{1F9EC}', EmojiGroup.health, ['dna', 'gene'], ['基因']),
    // Home
    EmojiEntry('\u{1F3E0}', EmojiGroup.home, ['home', 'house'], ['家', '房子']),
    EmojiEntry('\u{1F511}', EmojiGroup.home, ['key', 'lock'], ['钥匙']),
    EmojiEntry('\u{1F6CB}️', EmojiGroup.home, ['couch', 'sofa', 'furniture'], ['沙发', '家具']),
    EmojiEntry('\u{1F9F9}', EmojiGroup.home, ['broom', 'cleaning'], ['扫帚', '清洁']),
    EmojiEntry('\u{1F4A1}', EmojiGroup.home, ['light bulb', 'idea'], ['灯泡', '想法']),
    EmojiEntry('\u{1F50C}', EmojiGroup.home, ['plug', 'electric', 'power'], ['插头', '电']),
    EmojiEntry('\u{1F6BF}', EmojiGroup.home, ['shower', 'bathroom'], ['淋浴', '浴室']),
    EmojiEntry('\u{1F331}', EmojiGroup.home, ['plant', 'garden'], ['植物', '花园']),
    // Books & learning
    EmojiEntry('\u{1F4D6}', EmojiGroup.books, ['book', 'read', 'reading'], ['书', '阅读']),
    EmojiEntry('\u{1F4DA}', EmojiGroup.books, ['books', 'library'], ['书籍', '图书馆']),
    EmojiEntry('\u{1F4DD}', EmojiGroup.books, ['memo', 'note', 'notes'], ['笔记', '备忘']),
    EmojiEntry('\u{1F393}', EmojiGroup.books, ['graduation', 'school', 'study'], ['毕业', '学校', '学习']),
    EmojiEntry('✏️', EmojiGroup.books, ['pencil', 'write'], ['铅笔', '写']),
    EmojiEntry('\u{1F9E0}', EmojiGroup.books, ['brain', 'learn', 'memory'], ['大脑', '记忆']),
    EmojiEntry('\u{1F52C}', EmojiGroup.books, ['microscope', 'science'], ['显微镜', '科学']),
    EmojiEntry('\u{1F5E3}️', EmojiGroup.books, ['language', 'speak'], ['语言', '说话']),
    // Work
    EmojiEntry('\u{1F4BC}', EmojiGroup.work, ['work', 'briefcase', 'job'], ['工作', '公文包']),
    EmojiEntry('\u{1F4BB}', EmojiGroup.work, ['laptop', 'computer'], ['电脑', '笔记本电脑']),
    EmojiEntry('\u{1F4C5}', EmojiGroup.work, ['calendar', 'date'], ['日历', '日期']),
    EmojiEntry('\u{1F4CA}', EmojiGroup.work, ['bar chart', 'report'], ['图表', '报告']),
    EmojiEntry('\u{1F4CE}', EmojiGroup.work, ['paperclip', 'attachment'], ['回形针', '附件']),
    EmojiEntry('☎️', EmojiGroup.work, ['telephone', 'call'], ['电话']),
    EmojiEntry('\u{1F4E7}', EmojiGroup.work, ['email', 'mail'], ['邮件', '电子邮件']),
    EmojiEntry('\u{1F5C2}️', EmojiGroup.work, ['folder', 'dividers', 'files'], ['文件夹', '文件']),
    // Travel
    EmojiEntry('✈️', EmojiGroup.travel, ['plane', 'flight'], ['飞机', '航班']),
    EmojiEntry('\u{1F9F3}', EmojiGroup.travel, ['luggage', 'suitcase'], ['行李', '行李箱']),
    EmojiEntry('\u{1F5FA}️', EmojiGroup.travel, ['map', 'world'], ['地图']),
    EmojiEntry('\u{1F3E8}', EmojiGroup.travel, ['hotel'], ['酒店', '旅馆']),
    EmojiEntry('\u{1F6C2}', EmojiGroup.travel, ['passport', 'customs', 'border'], ['护照', '海关', '边境']),
    EmojiEntry('\u{1F686}', EmojiGroup.travel, ['train', 'rail'], ['火车', '铁路']),
    EmojiEntry('\u{1F3D6}️', EmojiGroup.travel, ['beach', 'vacation', 'holiday'], ['海滩', '度假']),
    EmojiEntry('\u{1F3AB}', EmojiGroup.travel, ['ticket'], ['票', '门票']),
    // Money
    EmojiEntry('\u{1F4B0}', EmojiGroup.money, ['money', 'savings'], ['钱', '存款']),
    EmojiEntry('\u{1F4B3}', EmojiGroup.money, ['credit card', 'bank card'], ['信用卡', '银行卡']),
    EmojiEntry('\u{1F3E6}', EmojiGroup.money, ['bank'], ['银行']),
    EmojiEntry('\u{1F9FE}', EmojiGroup.money, ['receipt', 'invoice'], ['收据', '发票']),
    EmojiEntry('\u{1F4B5}', EmojiGroup.money, ['cash', 'dollar'], ['现金', '美元']),
    EmojiEntry('\u{1F4C8}', EmojiGroup.money, ['invest', 'growth', 'stocks'], ['投资', '增长', '股票']),
    EmojiEntry('\u{1FA99}', EmojiGroup.money, ['coin'], ['硬币']),
    EmojiEntry('\u{1F6E1}️', EmojiGroup.money, ['insurance', 'shield'], ['保险', '保护']),
    // Misc
    EmojiEntry('⭐', EmojiGroup.misc, ['star', 'favourite', 'favorite'], ['星', '收藏']),
    EmojiEntry('\u{1F4CC}', EmojiGroup.misc, ['pin', 'pushpin'], ['图钉', '置顶']),
    EmojiEntry('✅', EmojiGroup.misc, ['done', 'check'], ['完成', '勾']),
    EmojiEntry('⚠️', EmojiGroup.misc, ['warning', 'caution'], ['警告', '注意']),
    EmojiEntry('\u{1F512}', EmojiGroup.misc, ['lock', 'private', 'secret'], ['锁', '私密']),
    EmojiEntry('\u{1F381}', EmojiGroup.misc, ['gift', 'present'], ['礼物']),
    EmojiEntry('\u{1F436}', EmojiGroup.misc, ['dog', 'pet'], ['狗', '宠物']),
    EmojiEntry('\u{1F37D}️', EmojiGroup.misc, ['food', 'restaurant', 'dinner'], ['食物', '餐厅']),
  ];

  static List<EmojiEntry> inGroup(EmojiGroup group) => [
        for (final e in entries)
          if (e.group == group) e,
      ];

  /// Case-insensitive substring match on either language's keywords, or the
  /// emoji itself. An empty query returns everything.
  static List<EmojiEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return [
      for (final e in entries)
        if (e.emoji == q ||
            e.en.any((k) => k.contains(q)) ||
            e.zh.any((k) => k.contains(q)))
          e,
    ];
  }
}
```

- [ ] **Step 11: Create the labels**

Create `lib/features/cheatsheet/presentation/look/look_labels.dart`:

```dart
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/card_style.dart';
import 'emoji_catalog.dart';

/// Display names. The stored values stay the enum names; only these are
/// translated, so a language change never re-groups or re-styles a card.
String cheatsheetThemeLabel(CardThemeId theme, AppLocalizations l) =>
    switch (theme) {
      CardThemeId.blue => l.cheatsheetThemeBlue,
      CardThemeId.green => l.cheatsheetThemeGreen,
      CardThemeId.orange => l.cheatsheetThemeOrange,
      CardThemeId.red => l.cheatsheetThemeRed,
      CardThemeId.purple => l.cheatsheetThemePurple,
      CardThemeId.teal => l.cheatsheetThemeTeal,
      CardThemeId.pink => l.cheatsheetThemePink,
      CardThemeId.amber => l.cheatsheetThemeAmber,
      CardThemeId.slate => l.cheatsheetThemeSlate,
      CardThemeId.indigo => l.cheatsheetThemeIndigo,
      CardThemeId.brown => l.cheatsheetThemeBrown,
      CardThemeId.black => l.cheatsheetThemeBlack,
    };

String cheatsheetPatternLabel(CardPattern pattern, AppLocalizations l) =>
    switch (pattern) {
      CardPattern.none => l.cheatsheetPatternNone,
      CardPattern.dots => l.cheatsheetPatternDots,
      CardPattern.stripes => l.cheatsheetPatternStripes,
      CardPattern.grid => l.cheatsheetPatternGrid,
      CardPattern.waves => l.cheatsheetPatternWaves,
    };

String cheatsheetLayoutLabel(CardLayout layout, AppLocalizations l) =>
    switch (layout) {
      CardLayout.facts => l.cheatsheetLayoutFacts,
      CardLayout.keyPoints => l.cheatsheetLayoutKeyPoints,
    };

String emojiGroupLabel(EmojiGroup group, AppLocalizations l) =>
    switch (group) {
      EmojiGroup.vehicle => l.cheatsheetEmojiGroupVehicle,
      EmojiGroup.health => l.cheatsheetEmojiGroupHealth,
      EmojiGroup.home => l.cheatsheetEmojiGroupHome,
      EmojiGroup.books => l.cheatsheetEmojiGroupBooks,
      EmojiGroup.work => l.cheatsheetEmojiGroupWork,
      EmojiGroup.travel => l.cheatsheetEmojiGroupTravel,
      EmojiGroup.money => l.cheatsheetEmojiGroupMoney,
      EmojiGroup.misc => l.cheatsheetEmojiGroupMisc,
    };
```

- [ ] **Step 12: Run it to see it pass, then commit**

Run: `flutter test test/features/cheatsheet/presentation/look/emoji_catalog_test.dart`
Expected: `All tests passed!`

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet test/features/cheatsheet
git add lib/features/cheatsheet/presentation/look/emoji_catalog.dart \
  lib/features/cheatsheet/presentation/look/look_labels.dart \
  test/features/cheatsheet/presentation/look/emoji_catalog_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): curated emoji catalog with English and Chinese search

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

#### 9d — emoji picker and cover action sheet

- [ ] **Step 13: Write the failing sheet tests**

Create `test/features/cheatsheet/presentation/look/look_sheets_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cover_action_sheet.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/emoji_picker.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  Future<List<T?>> open<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext) show, {
    TargetPlatform platform = TargetPlatform.android,
    Locale? locale,
  }) async {
    final results = <T?>[];
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: platform),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () async => results.add(await show(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    return results;
  }

  group('emoji picker', () {
    testWidgets('groups the curated emoji and returns the tapped one',
        (tester) async {
      final results =
          await open<String>(tester, (c) => showEmojiPicker(c));

      expect(find.byKey(const Key('emoji-group-vehicle')), findsOneWidget);
      expect(find.text('Vehicle'), findsOneWidget);
      await tester.tap(find.byKey(const Key('emoji-\u{1F697}')));
      await tester.pumpAndSettle();

      expect(results, ['\u{1F697}']);
    });

    testWidgets('searches English and Chinese keywords', (tester) async {
      await open<String>(tester, (c) => showEmojiPicker(c));

      await tester.enterText(find.byKey(const Key('emoji-search')), 'passport');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-\u{1F6C2}')), findsOneWidget);
      expect(find.byKey(const Key('emoji-\u{1F697}')), findsNothing);

      await tester.enterText(find.byKey(const Key('emoji-search')), '护照');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-\u{1F6C2}')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('emoji-search')), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji-no-matches')), findsOneWidget);
    });

    testWidgets('free typing accepts one emoji and rejects anything else',
        (tester) async {
      final results =
          await open<String>(tester, (c) => showEmojiPicker(c));

      await tester.enterText(find.byKey(const Key('emoji-custom')), 'abc');
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextButton>(find.byKey(const Key('emoji-custom-use')))
              .onPressed,
          isNull);
      expect(find.byKey(const Key('emoji-custom-error')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('emoji-custom')), '\u{1F984}');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('emoji-custom-use')));
      await tester.pumpAndSettle();

      expect(results, ['\u{1F984}']);
    });

    testWidgets('allowClear offers No emoji, which returns an empty string',
        (tester) async {
      final results = await open<String>(
          tester, (c) => showEmojiPicker(c, allowClear: true));

      await tester.tap(find.byKey(const Key('emoji-clear')));
      await tester.pumpAndSettle();

      expect(results, ['']);
    });

    testWidgets('without allowClear there is no No emoji option',
        (tester) async {
      await open<String>(tester, (c) => showEmojiPicker(c));
      expect(find.byKey(const Key('emoji-clear')), findsNothing);
    });

    testWidgets('iOS opens a Cupertino popup with a Cupertino search field',
        (tester) async {
      await open<String>(tester, (c) => showEmojiPicker(c),
          platform: TargetPlatform.iOS);

      expect(find.byType(CupertinoPopupSurface), findsOneWidget);
      expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    });

    testWidgets('group headings are translated', (tester) async {
      await open<String>(tester, (c) => showEmojiPicker(c),
          locale: const Locale('zh'));
      expect(find.text('车辆'), findsOneWidget);
    });
  });

  group('cover action sheet', () {
    testWidgets('Android offers camera and library; scan and remove only when '
        'available', (tester) async {
      final results = await open<CoverAction>(tester,
          (c) => showCoverActionSheet(c, hasCover: false, canScan: false));

      expect(find.byKey(const Key('cover-camera')), findsOneWidget);
      expect(find.byKey(const Key('cover-library')), findsOneWidget);
      expect(find.byKey(const Key('cover-scan')), findsNothing);
      expect(find.byKey(const Key('cover-remove')), findsNothing);

      await tester.tap(find.byKey(const Key('cover-library')));
      await tester.pumpAndSettle();
      expect(results, [CoverAction.library]);
    });

    testWidgets('scan and remove appear when offered', (tester) async {
      final results = await open<CoverAction>(tester,
          (c) => showCoverActionSheet(c, hasCover: true, canScan: true));

      expect(find.byKey(const Key('cover-scan')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cover-remove')));
      await tester.pumpAndSettle();
      expect(results, [CoverAction.remove]);
    });

    testWidgets('iOS uses a Cupertino action sheet', (tester) async {
      final results = await open<CoverAction>(
        tester,
        (c) => showCoverActionSheet(c, hasCover: false, canScan: true),
        platform: TargetPlatform.iOS,
      );

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('cover-camera')));
      await tester.pumpAndSettle();
      expect(results, [CoverAction.camera]);
    });
  });
}
```

- [ ] **Step 14: Run it to see it fail**

Run: `flutter test test/features/cheatsheet/presentation/look/look_sheets_test.dart`
Expected: compilation fails — `cover_action_sheet.dart` and `emoji_picker.dart` do not exist.

- [ ] **Step 15: Create the emoji picker**

Create `lib/features/cheatsheet/presentation/look/emoji_picker.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/card_style.dart';
import 'emoji_catalog.dart';
import 'look_labels.dart';

/// Opens the picker as a Cupertino popup on iOS and a bottom sheet elsewhere.
/// Returns the chosen emoji, `''` for "No emoji" (offered only when
/// [allowClear]), or null when dismissed.
Future<String?> showEmojiPicker(
  BuildContext context, {
  bool allowClear = false,
}) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (_) => CupertinoPopupSurface(
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: EmojiPickerSheet(allowClear: allowClear),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EmojiPickerSheet(allowClear: allowClear),
  );
}

/// Seam so designer widget tests never open a real sheet.
final cheatsheetEmojiPickerProvider = Provider<
    Future<String?> Function(BuildContext, {bool allowClear})>(
  (ref) => showEmojiPicker,
);

/// The picker's content: curated groups, bilingual search, and free typing
/// of any single emoji.
class EmojiPickerSheet extends StatefulWidget {
  const EmojiPickerSheet({super.key, this.allowClear = false});

  final bool allowClear;

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  String _query = '';
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _choose(String emoji) => Navigator.of(context).pop(emoji);

  Widget _button(EmojiEntry e, bool zh) => Semantics(
        button: true,
        label: zh ? e.zh.first : e.en.first,
        onTap: () => _choose(e.emoji),
        excludeSemantics: true,
        child: InkWell(
          key: Key('emoji-${e.emoji}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _choose(e.emoji),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(e.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final custom = _custom.text.trim();
    final valid = isSingleEmoji(custom);
    final results = EmojiCatalog.search(_query);

    final List<Widget> grid;
    if (_query.trim().isEmpty) {
      grid = [
        for (final g in EmojiGroup.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              emojiGroupLabel(g, l),
              key: Key('emoji-group-${g.name}'),
              style: theme.textTheme.labelLarge,
            ),
          ),
          Wrap(children: [
            for (final e in EmojiCatalog.inGroup(g)) _button(e, zh),
          ]),
        ],
      ];
    } else if (results.isEmpty) {
      grid = [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l.cheatsheetEmojiNoMatches,
            key: const Key('emoji-no-matches'),
          ),
        ),
      ];
    } else {
      grid = [
        Wrap(children: [for (final e in results) _button(e, zh)]),
      ];
    }

    final search = ios
        ? CupertinoSearchTextField(
            key: const Key('emoji-search'),
            placeholder: l.cheatsheetEmojiSearchHint,
            onChanged: (v) => setState(() => _query = v),
          )
        : TextField(
            key: const Key('emoji-search'),
            decoration: InputDecoration(
              hintText: l.cheatsheetEmojiSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          );

    final customField = ios
        ? CupertinoTextField(
            key: const Key('emoji-custom'),
            controller: _custom,
            placeholder: l.cheatsheetEmojiCustomLabel,
            onChanged: (_) => setState(() {}),
          )
        : TextField(
            key: const Key('emoji-custom'),
            controller: _custom,
            decoration:
                InputDecoration(labelText: l.cheatsheetEmojiCustomLabel),
            onChanged: (_) => setState(() {}),
          );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.cheatsheetEmojiPickerTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (widget.allowClear)
                  TextButton(
                    key: const Key('emoji-clear'),
                    onPressed: () => _choose(''),
                    child: Text(l.cheatsheetEmojiClear),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            search,
            Expanded(child: ListView(children: grid)),
            Row(
              children: [
                Expanded(child: customField),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('emoji-custom-use'),
                  onPressed: valid ? () => _choose(custom) : null,
                  child: Text(l.cheatsheetEmojiUse),
                ),
              ],
            ),
            if (custom.isNotEmpty && !valid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.cheatsheetEmojiInvalid,
                  key: const Key('emoji-custom-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            SizedBox(height: 12 + MediaQuery.viewInsetsOf(context).bottom),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 16: Create the cover action sheet**

Create `lib/features/cheatsheet/presentation/look/cover_action_sheet.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';

enum CoverAction { camera, library, scan, remove }

/// Where the cover comes from: the existing camera / photo-library pickers and
/// the document scanner (only when [canScan]), plus Remove when [hasCover].
/// A Cupertino action sheet on iOS, a bottom sheet elsewhere.
Future<CoverAction?> showCoverActionSheet(
  BuildContext context, {
  required bool hasCover,
  required bool canScan,
}) {
  final l = AppLocalizations.of(context);
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<CoverAction>(
      context: context,
      builder: (ctx) {
        CupertinoActionSheetAction action(
          CoverAction a,
          String label, {
          bool destructive = false,
        }) =>
            CupertinoActionSheetAction(
              key: Key('cover-${a.name}'),
              isDestructiveAction: destructive,
              onPressed: () => Navigator.of(ctx).pop(a),
              child: Text(label),
            );
        return CupertinoActionSheet(
          title: Text(l.cheatsheetLookCover),
          actions: [
            action(CoverAction.camera, l.cheatsheetCoverCamera),
            action(CoverAction.library, l.cheatsheetCoverLibrary),
            if (canScan) action(CoverAction.scan, l.cheatsheetCoverScan),
            if (hasCover)
              action(CoverAction.remove, l.cheatsheetCoverRemove,
                  destructive: true),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.commonCancel),
          ),
        );
      },
    );
  }
  return showModalBottomSheet<CoverAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      Widget tile(CoverAction a, IconData icon, String label) => ListTile(
            key: Key('cover-${a.name}'),
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.of(ctx).pop(a),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(CoverAction.camera, Icons.photo_camera_outlined,
                l.cheatsheetCoverCamera),
            tile(CoverAction.library, Icons.photo_library_outlined,
                l.cheatsheetCoverLibrary),
            if (canScan)
              tile(CoverAction.scan, Icons.document_scanner_outlined,
                  l.cheatsheetCoverScan),
            if (hasCover)
              tile(CoverAction.remove, Icons.delete_outline,
                  l.cheatsheetCoverRemove),
          ],
        ),
      );
    },
  );
}

/// Seam so designer widget tests never open a real sheet.
final cheatsheetCoverActionProvider = Provider<
    Future<CoverAction?> Function(
  BuildContext, {
  required bool hasCover,
  required bool canScan,
})>(
  (ref) => showCoverActionSheet,
);
```

- [ ] **Step 17: Run the sheet tests to see them pass, then commit**

Run: `flutter test test/features/cheatsheet/presentation/look/look_sheets_test.dart`
Expected: `All tests passed!`

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet test/features/cheatsheet
git add lib/features/cheatsheet/presentation/look/emoji_picker.dart \
  lib/features/cheatsheet/presentation/look/cover_action_sheet.dart \
  test/features/cheatsheet/presentation/look/look_sheets_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): emoji picker and cover source sheet, per platform

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

#### 9e — the Look section in the designer, row emoji, help

- [ ] **Step 18: Write the failing designer and help tests**

Create `test/features/cheatsheet/presentation/cheatsheet_designer_look_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/scanner/document_scanner.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cheatsheet_palette.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cover_action_sheet.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/emoji_picker.dart';
import 'package:hmm_console/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart';
import 'package:hmm_console/features/cheatsheet/presentation/widgets/look_section.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheet_editor_state.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

/// A real 1x1 PNG: the preview and thumbnail decode it.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
    'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

const _eyes = '\u{1F440}';

class _Capturing extends CheatsheetsState {
  static List<CheatsheetCard> seed = const [];
  static final saved = <CheatsheetCard>[];
  static final covers = <PickedImageBytes?>[];
  static final releases = <List<VaultRef>>[];

  @override
  Future<List<CheatsheetCard>> build() async => seed;

  @override
  Future<void> save(
    CheatsheetCard card, {
    PickedImageBytes? newCover,
    List<VaultRef> released = const [],
  }) async {
    saved.add(card);
    covers.add(newCover);
    releases.add(released);
  }
}

class _Bytes implements ImageByteSource {
  final sources = <AttachmentPickSource>[];

  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async {
    sources.add(source);
    return PickedImageBytes(
        bytes: _png, originalName: 'cover.png', contentType: 'image/png');
  }
}

class _Scanner implements DocumentScanner {
  _Scanner(this.available);
  final bool available;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<PickedImageBytes>> scan() async => [
        PickedImageBytes(
            bytes: _png, originalName: 'scan.png', contentType: 'image/png'),
      ];
}

class _Resolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => _png;
}

const _cover = VaultRef(
  path: 'attachments/note-4/cover.png',
  contentType: 'image/png',
  byteSize: 70,
);

const _existing = CheatsheetCard(
  id: 'e1',
  title: 'Vim',
  walletGroup: 'Reference',
  tags: [],
  templateId: 'document',
  rows: [CheatsheetRow(label: 'Motions', source: null)],
);

void main() {
  late List<String?> emojiAnswers;
  late List<CoverAction?> coverAnswers;
  late List<(bool, bool)> coverCalls;
  late _Bytes bytes;

  setUp(() {
    _Capturing.seed = const [];
    _Capturing.saved.clear();
    _Capturing.covers.clear();
    _Capturing.releases.clear();
    emojiAnswers = [];
    coverAnswers = [];
    coverCalls = [];
    bytes = _Bytes();
  });

  Future<void> mount(
    WidgetTester tester, {
    String? cardId,
    bool coversSupported = true,
    bool canScan = false,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cheatsheetIdGenProvider.overrideWithValue(() => 'new-id'),
        cheatsheetsStateProvider.overrideWith(_Capturing.new),
        cheatsheetSourcePickerProvider
            .overrideWithValue((_, {required templateId}) async => null),
        cheatsheetEmojiPickerProvider.overrideWithValue(
            (_, {bool allowClear = false}) async => emojiAnswers.removeAt(0)),
        cheatsheetCoverActionProvider.overrideWithValue(
            (_, {required bool hasCover, required bool canScan}) async {
          coverCalls.add((hasCover, canScan));
          return coverAnswers.removeAt(0);
        }),
        cheatsheetCoversSupportedProvider.overrideWithValue(coversSupported),
        imageByteSourceProvider.overrideWithValue(bytes),
        documentScannerProvider.overrideWithValue(_Scanner(canScan)),
        attachmentResolverProvider.overrideWith((ref) async => _Resolver()),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CheatsheetDesignerScreen(cardId: cardId),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// Creating a card: picking a template opens the form with Look already
  /// expanded, so no tap on `designer-look` (that would fold it).
  Future<void> start(WidgetTester tester, String templateId) =>
      tapKey(tester, 'template-$templateId');

  Color previewColour(WidgetTester tester) => ((tester
              .widget<DecoratedBox>(find.descendant(
                of: find.byKey(const Key('look-preview')),
                matching: find.byKey(const Key('card-surface-themed')),
              ))
              .decoration) as BoxDecoration)
      .color!;

  testWidgets('creating a card opens Look expanded', (tester) async {
    await mount(tester);
    await start(tester, 'blank');

    expect(find.byKey(const Key('look-preview')), findsOneWidget);
    expect(find.byKey(const Key('look-theme-red')), findsOneWidget);
    expect(find.byKey(const Key('look-layout')), findsOneWidget);
    expect(find.byKey(const Key('look-reset')), findsOneWidget);
  });

  testWidgets('editing a card starts with Look collapsed, the preview in its '
      'header, and a tap expands it', (tester) async {
    _Capturing.seed = [
      _existing.copyWith(style: const CardStyle({'theme': 'red'})),
    ];
    await mount(tester, cardId: 'e1');

    expect(find.byKey(const Key('look-preview')), findsOneWidget);
    expect(previewColour(tester),
        CheatsheetPalette.of(CardThemeId.red, Brightness.light).background);
    expect(find.byKey(const Key('look-theme-red')), findsNothing,
        reason: 'collapsed: the body is not built');
    expect(find.byKey(const Key('look-reset')), findsNothing);

    await tapKey(tester, 'designer-look');

    expect(find.byKey(const Key('look-theme-red')), findsOneWidget);
    expect(find.byKey(const Key('look-theme-red-selected')), findsOneWidget);
  });

  testWidgets('the mini-tile preview follows the chosen theme', (tester) async {
    await mount(tester);
    await start(tester, 'accidentClaim');

    expect(previewColour(tester),
        CheatsheetPalette.of(CardThemeId.blue, Brightness.light).background);
    expect(find.byKey(const Key('look-theme-blue-selected')), findsOneWidget);

    await tapKey(tester, 'look-theme-red');

    expect(previewColour(tester),
        CheatsheetPalette.of(CardThemeId.red, Brightness.light).background);
    expect(find.byKey(const Key('look-theme-red-selected')), findsOneWidget);
    expect(find.byKey(const Key('look-theme-blue-selected')), findsNothing);
  });

  testWidgets('swatches have accessible names and report selection',
      (tester) async {
    final handle = tester.ensureSemantics();
    await mount(tester);
    await start(tester, 'accidentClaim');

    expect(find.bySemanticsLabel('Red'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Blue')),
        containsSemantics(isButton: true, isSelected: true));
    expect(find.bySemanticsLabel('Waves'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('saving writes only what differs from the template',
      (tester) async {
    await mount(tester);
    await start(tester, 'accidentClaim');

    await tapKey(tester, 'look-theme-blue'); // the template default
    await tapKey(tester, 'look-pattern-dots');
    await tapKey(tester, 'designer-save');

    expect(_Capturing.saved.single.style.toMap(), {'pattern': 'dots'});
  });

  testWidgets('the icon picker sets the card icon', (tester) async {
    await mount(tester);
    await start(tester, 'blank');
    emojiAnswers = ['\u{1F984}'];

    await tapKey(tester, 'look-icon-choose');

    expect(tester.widget<Text>(find.byKey(const Key('look-icon'))).data,
        '\u{1F984}');
    await tapKey(tester, 'designer-save');
    expect(_Capturing.saved.single.style.icon, '\u{1F984}');
  });

  testWidgets('adding a cover from the library stages it and previews it',
      (tester) async {
    await mount(tester);
    await start(tester, 'blank');
    coverAnswers = [CoverAction.library];

    await tapKey(tester, 'look-cover-add');

    expect(bytes.sources, [AttachmentPickSource.gallery]);
    expect(find.byKey(const Key('look-cover-thumb')), findsOneWidget);
    expect(
        find.descendant(
          of: find.byKey(const Key('look-preview')),
          matching: find.byKey(const Key('card-surface-cover')),
        ),
        findsOneWidget);

    await tapKey(tester, 'designer-save');
    expect(_Capturing.covers.single!.bytes, _png);
  });

  testWidgets('the scanner is offered only when available, and scans a cover',
      (tester) async {
    await mount(tester, canScan: true);
    await start(tester, 'blank');
    coverAnswers = [CoverAction.scan];

    await tapKey(tester, 'look-cover-add');

    expect(coverCalls.single, (false, true));
    expect(find.byKey(const Key('look-cover-thumb')), findsOneWidget);
  });

  testWidgets('without a scanner the sheet is told so', (tester) async {
    await mount(tester);
    await start(tester, 'blank');
    coverAnswers = [null];

    await tapKey(tester, 'look-cover-add');

    expect(coverCalls.single, (false, false));
    expect(find.byKey(const Key('look-cover-thumb')), findsNothing);
  });

  testWidgets('removing an existing cover releases it on save',
      (tester) async {
    _Capturing.seed = [_existing.withCover(_cover)];
    await mount(tester, cardId: 'e1');
    await tapKey(tester, 'designer-look');
    expect(find.byKey(const Key('look-cover-thumb')), findsOneWidget);

    await tapKey(tester, 'look-cover-remove');
    await tapKey(tester, 'designer-save');

    expect(_Capturing.releases.single, [_cover]);
    expect(_Capturing.saved.single.cover, isNull);
  });

  testWidgets('covers are hidden in cloudApi mode', (tester) async {
    await mount(tester, coversSupported: false);
    await start(tester, 'blank');

    expect(find.byKey(const Key('look-cover-add')), findsNothing);
    expect(find.byKey(const Key('look-theme-red')), findsOneWidget);
  });

  testWidgets('Android picks the layout with a SegmentedButton',
      (tester) async {
    await mount(tester);
    await start(tester, 'accidentClaim');
    expect(find.byType(SegmentedButton<CardLayout>), findsOneWidget);
  });

  testWidgets('iOS picks the layout with a CupertinoSlidingSegmentedControl',
      (tester) async {
    await mount(tester, platform: TargetPlatform.iOS);
    await start(tester, 'accidentClaim');

    expect(find.byType(CupertinoSlidingSegmentedControl<CardLayout>),
        findsOneWidget);
    await tester.tap(find.text('Key points'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('row-0-emoji')), findsOneWidget);
  });

  testWidgets('row emoji slots appear only in Key points', (tester) async {
    await mount(tester);
    await start(tester, 'accidentClaim');
    expect(find.byKey(const Key('row-0-emoji')), findsNothing);

    await tester.tap(find.text('Key points'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('row-0-emoji')), findsOneWidget);
  });

  testWidgets('row emoji survive Key points -> Facts -> Key points and are '
      'saved', (tester) async {
    await mount(tester);
    await start(tester, 'document');
    emojiAnswers = [_eyes];

    await tapKey(tester, 'row-0-emoji');
    await tester.tap(find.text('Facts'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('row-0-emoji')), findsNothing);
    await tester.tap(find.text('Key points'));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
          of: find.byKey(const Key('row-0-emoji')),
          matching: find.text(_eyes),
        ),
        findsOneWidget);
    await tapKey(tester, 'designer-save');
    expect(_Capturing.saved.single.rows.single.emoji, _eyes);
    expect(_Capturing.saved.single.style.isEmpty, isTrue);
  });

  testWidgets('Reset look clears style and row emoji and releases the cover',
      (tester) async {
    _Capturing.seed = [
      _existing
          .copyWith(
            style: const CardStyle({'theme': 'red', 'pattern': 'dots'}),
            rows: [_existing.rows.single.copyWith(emoji: _eyes)],
          )
          .withCover(_cover),
    ];
    await mount(tester, cardId: 'e1');
    await tapKey(tester, 'designer-look');

    await tapKey(tester, 'look-reset');
    await tapKey(tester, 'designer-save');

    final saved = _Capturing.saved.single;
    expect(saved.style.isEmpty, isTrue);
    expect(saved.cover, isNull);
    expect(saved.rows.single.emoji, isNull);
    expect(_Capturing.releases.single, [_cover]);
  });

  testWidgets('the designer has a help button that explains Look',
      (tester) async {
    await mount(tester);
    await tapKey(tester, 'template-blank');

    await tester.tap(find.byType(HelpButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('starts open on a new card'), findsOneWidget);
  });
}
```

In `test/core/help/help_registry_test.dart`, append inside `main()`:

```dart
  test('designer help explains the Look controls with their own icons', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final icons =
        helpFor(HelpId.cheatsheetDesigner, l).entries.map((e) => e.icon);
    // look_section.dart and the designer's row slot draw these.
    expect(
        icons,
        containsAll(<IconData>[
          Icons.palette_outlined,
          Icons.emoji_emotions_outlined,
          Icons.add_photo_alternate_outlined,
          Icons.format_list_numbered,
          Icons.add_reaction_outlined,
          Icons.format_color_reset_outlined,
        ]));
  });
```

- [ ] **Step 19: Run them to see them fail**

Run: `flutter test test/features/cheatsheet/presentation/cheatsheet_designer_look_test.dart test/core/help/help_registry_test.dart`
Expected: compilation fails — `look_section.dart` does not exist; `There's no constant named 'cheatsheetDesigner' in 'HelpId'`.

- [ ] **Step 20: Register the designer help**

In `lib/core/help/help_registry.dart`, change the enum (as left by Task 8) to:

```dart
enum HelpId {
  automobileHub,
  vehicleNotes,
  contacts,
  contactDetail,
  contactEdit,
  cheatsheetWallet,
  cheatsheetDetail,
  cheatsheetDesigner,
}
```

and add this case after the `HelpId.cheatsheetDetail => ScreenHelp(...)` case (before the closing `};`):

```dart
      HelpId.cheatsheetDesigner => ScreenHelp(
          title: l.helpCheatsheetDesignerTitle,
          summary: l.helpCheatsheetDesignerSummary,
          entries: [
            HelpEntry(
                icon: Icons.palette_outlined,
                title: l.helpCheatsheetDesignerLookTitle,
                body: l.helpCheatsheetDesignerLookBody),
            HelpEntry(
                icon: Icons.emoji_emotions_outlined,
                title: l.helpCheatsheetDesignerIconTitle,
                body: l.helpCheatsheetDesignerIconBody),
            HelpEntry(
                icon: Icons.add_photo_alternate_outlined,
                title: l.helpCheatsheetDesignerCoverTitle,
                body: l.helpCheatsheetDesignerCoverBody),
            HelpEntry(
                icon: Icons.format_list_numbered,
                title: l.helpCheatsheetDesignerLayoutTitle,
                body: l.helpCheatsheetDesignerLayoutBody),
            HelpEntry(
                icon: Icons.add_reaction_outlined,
                title: l.helpCheatsheetDesignerRowEmojiTitle,
                body: l.helpCheatsheetDesignerRowEmojiBody),
            HelpEntry(
                icon: Icons.format_color_reset_outlined,
                title: l.helpCheatsheetDesignerResetTitle,
                body: l.helpCheatsheetDesignerResetBody),
          ],
        ),
```

- [ ] **Step 21: Create the Look section**

Create `lib/features/cheatsheet/presentation/widgets/look_section.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/scanner/document_scanner.dart';
import '../../../../core/data/data_mode.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/entities/card_style.dart';
import '../../states/cheatsheet_cover_draft.dart';
import '../../states/cheatsheet_editor_state.dart';
import '../look/card_surface.dart';
import '../look/card_tile.dart';
import '../look/cheatsheet_palette.dart';
import '../look/cover_action_sheet.dart';
import '../look/emoji_picker.dart';
import '../look/look_labels.dart';

/// A cover needs the card note's local id and attachments column, which
/// `/v1/cheatsheets` does not expose, so cloudApi offers no cover. Overridden
/// in tests.
final cheatsheetCoversSupportedProvider = Provider<bool>(
  (ref) => ref.watch(dataModeProvider) != DataMode.cloudApi,
);

/// The designer's "Look" section, with the real wallet tile scaled down as a
/// live preview in its header. Expanded when creating a card (choosing the
/// look is part of making it); collapsed when editing one, where the preview
/// alone shows the current look and the rows stay in the first viewport.
class LookSection extends ConsumerWidget {
  const LookSection({super.key, required this.initiallyExpanded});

  /// The designer passes `cardId == null`: true on create, false on edit.
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final card = ref.watch(cheatsheetEditorProvider);
    final draft = ref.watch(cheatsheetCoverDraftProvider);
    return ExpansionTile(
      key: const Key('designer-look'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: SizedBox(
        key: const Key('look-preview'),
        width: 75,
        height: 56,
        child: FittedBox(
          child: SizedBox(
            width: 200,
            height: 150,
            child: CardTile(
              card: card,
              pendingCoverBytes: draft.pending?.bytes,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          const Icon(Icons.palette_outlined, size: 20),
          const SizedBox(width: 8),
          Text(l.cheatsheetLookTitle),
        ],
      ),
      // Built only when expanded (maintainState is false), so a collapsed
      // section reads no providers beyond the editor and the cover draft.
      children: const [_LookBody()],
    );
  }
}

class _LookBody extends ConsumerWidget {
  const _LookBody();

  static IconData _layoutIcon(CardLayout layout) => switch (layout) {
        CardLayout.facts => Icons.list_alt,
        CardLayout.keyPoints => Icons.format_list_numbered,
      };

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );

  Future<void> _chooseIcon(BuildContext context, WidgetRef ref) async {
    final editor = ref.read(cheatsheetEditorProvider.notifier);
    final pick = ref.read(cheatsheetEmojiPickerProvider);
    final chosen = await pick(context, allowClear: true);
    if (chosen == null) return;
    editor.setIcon(chosen.isEmpty ? null : chosen);
  }

  /// Reuses the app's pickers: camera / library through [ImageByteSource]
  /// and the OS document scanner. Bytes are downsized when the save writes
  /// them to the vault (`persistToVault`), as for every other photo.
  Future<void> _chooseCover(
    BuildContext context,
    WidgetRef ref, {
    required bool hasCover,
  }) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final editor = ref.read(cheatsheetEditorProvider.notifier);
    final scanner = ref.read(documentScannerProvider);
    final source = ref.read(imageByteSourceProvider);
    final chooseAction = ref.read(cheatsheetCoverActionProvider);
    try {
      final canScan = await scanner.isAvailable();
      if (!context.mounted) return;
      final action = await chooseAction(
        context,
        hasCover: hasCover,
        canScan: canScan,
      );
      switch (action) {
        case null:
          return;
        case CoverAction.remove:
          editor.removeCover();
        case CoverAction.camera:
          {
            final pick = await source.pick(AttachmentPickSource.camera);
            if (pick != null) editor.pickCover(pick);
          }
        case CoverAction.library:
          {
            final pick = await source.pick(AttachmentPickSource.gallery);
            if (pick != null) editor.pickCover(pick);
          }
        case CoverAction.scan:
          {
            final pages = await scanner.scan();
            if (pages.isNotEmpty) editor.pickCover(pages.first);
          }
      }
    } on Exception catch (e) {
      // Type only: platform errors can quote file paths.
      debugPrint('LookSection: choosing a cover failed (${e.runtimeType}); '
          'nothing changed.');
      messenger.showSnackBar(SnackBar(content: Text(l.cheatsheetCoverFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final card = ref.watch(cheatsheetEditorProvider);
    final draft = ref.watch(cheatsheetCoverDraftProvider);
    final coversSupported = ref.watch(cheatsheetCoversSupportedProvider);
    final editor = ref.read(cheatsheetEditorProvider.notifier);
    final look = card.look;
    final brightness = Theme.of(context).brightness;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final pending = draft.pending;
    final hasCover = pending != null || card.cover != null;

    final Widget layoutControl = ios
        ? CupertinoSlidingSegmentedControl<CardLayout>(
            key: const Key('look-layout'),
            groupValue: look.layout,
            children: {
              for (final x in CardLayout.values)
                x: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_layoutIcon(x), size: 18),
                      const SizedBox(width: 6),
                      Text(cheatsheetLayoutLabel(x, l)),
                    ],
                  ),
                ),
            },
            onValueChanged: (v) {
              if (v != null) editor.setLayout(v);
            },
          )
        : SegmentedButton<CardLayout>(
            key: const Key('look-layout'),
            segments: [
              for (final x in CardLayout.values)
                ButtonSegment(
                  value: x,
                  icon: Icon(_layoutIcon(x)),
                  label: Text(cheatsheetLayoutLabel(x, l)),
                ),
            ],
            selected: {look.layout},
            onSelectionChanged: (s) => editor.setLayout(s.first),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, l.cheatsheetLookTheme),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in CardThemeId.values)
              _ThemeSwatch(
                theme: t,
                colors: CheatsheetPalette.of(t, brightness),
                label: cheatsheetThemeLabel(t, l),
                selected: look.theme == t,
                onTap: () => editor.setTheme(t),
              ),
          ],
        ),
        _label(context, l.cheatsheetLookPattern),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in CardPattern.values)
              _PatternSwatch(
                pattern: p,
                colors: CheatsheetPalette.of(look.theme, brightness),
                label: cheatsheetPatternLabel(p, l),
                selected: look.pattern == p,
                onTap: () => editor.setPattern(p),
              ),
          ],
        ),
        _label(context, l.cheatsheetLookIcon),
        Row(
          children: [
            Text(
              look.icon,
              key: const Key('look-icon'),
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              key: const Key('look-icon-choose'),
              onPressed: () => _chooseIcon(context, ref),
              icon: const Icon(Icons.emoji_emotions_outlined),
              label: Text(l.cheatsheetIconChoose),
            ),
          ],
        ),
        if (coversSupported) ...[
          _label(context, l.cheatsheetLookCover),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasCover)
                SizedBox(
                  key: const Key('look-cover-thumb'),
                  width: 56,
                  height: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: pending != null
                        ? Image.memory(pending.bytes, fit: BoxFit.cover)
                        : CardSurface(
                            card: card,
                            builder: (_, _) => const SizedBox.shrink(),
                          ),
                  ),
                ),
              TextButton.icon(
                key: const Key('look-cover-add'),
                onPressed: () =>
                    _chooseCover(context, ref, hasCover: hasCover),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                    hasCover ? l.cheatsheetCoverChange : l.cheatsheetCoverAdd),
              ),
              if (hasCover)
                TextButton(
                  key: const Key('look-cover-remove'),
                  onPressed: editor.removeCover,
                  child: Text(l.cheatsheetCoverRemove),
                ),
            ],
          ),
        ],
        _label(context, l.cheatsheetLookLayout),
        layoutControl,
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('look-reset'),
          onPressed: editor.resetLook,
          icon: const Icon(Icons.format_color_reset_outlined),
          label: Text(l.cheatsheetLookReset),
        ),
      ],
    );
  }
}

/// One colour choice. Named for screen readers; a check mark (not only the
/// colour) shows the selection.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CardThemeId theme;
  final CardColors colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          key: Key('look-theme-${theme.name}'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    key: Key('look-theme-${theme.name}-selected'),
                    size: 20,
                    color: colors.foreground,
                  )
                : null,
          ),
        ),
      );
}

class _PatternSwatch extends StatelessWidget {
  const _PatternSwatch({
    required this.pattern,
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CardPattern pattern;
  final CardColors colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          key: Key('look-pattern-${pattern.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2,
              ),
            ),
            // Stronger ink than on a card, so the swatch reads at this size.
            child: CustomPaint(
              painter: CardPatternPainter(
                pattern: pattern,
                ink: colors.foreground.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      );
}
```

- [ ] **Step 22: Wire the section, row emoji slots and help into the designer**

In `lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart`:

After `import '../../data/cheatsheet_templates.dart';` (line 6) add:

```dart
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../domain/entities/card_style.dart';
import '../../domain/entities/cheatsheet_row.dart';
import '../look/emoji_picker.dart';
import '../widgets/look_section.dart';
```

Replace the app-bar `actions: [ TextButton(key: const Key('designer-save'), ...), ],` (lines 201-207) with:

```dart
          actions: [
            const HelpButton(helpId: HelpId.cheatsheetDesigner),
            TextButton(
              key: const Key('designer-save'),
              onPressed: _saving ? null : _save,
              child: Text(l.commonSave),
            ),
          ],
```

In `_form`, directly after the title field (the `TextField(key: const Key('designer-title'), ... onChanged: _editor.setTitle,\n            ),` that ends on line 217) insert:

```dart
            const SizedBox(height: 12),
            // Q4: expanded when creating, collapsed (preview only) when editing.
            LookSection(initiallyExpanded: widget.cardId == null),
```

In `_rowTile`, change the header `Row(children: [ Expanded(child: Text(row.label)), IconButton(...remove...) ])` (lines 266-276) so its `children` start with the emoji slot:

```dart
            Row(
              children: [
                if (card.look.layout == CardLayout.keyPoints)
                  _emojiSlot(row, i),
                Expanded(child: Text(row.label)),
                IconButton(
                  key: Key('row-$i-remove'),
                  icon: const Icon(Icons.close),
                  tooltip: l.cheatsheetRemoveRow,
                  onPressed: () => _editor.removeRow(i),
                ),
              ],
            ),
```

Add these two methods directly before `static String _actionLabel(ValueAction a)` (line 312):

```dart
  /// Shown only in Key points. An unset (or invalid stored) emoji shows the
  /// add-reaction button; a set one shows itself, tappable to change.
  Widget _emojiSlot(CheatsheetRow row, int i) {
    final l = AppLocalizations.of(context);
    final emoji = row.emoji;
    if (emoji == null || !isSingleEmoji(emoji)) {
      return HmmIconButton(
        key: Key('row-$i-emoji'),
        icon: Icons.add_reaction_outlined,
        tooltip: l.cheatsheetRowEmojiTooltip,
        onPressed: () => _chooseRowEmoji(i),
      );
    }
    return Tooltip(
      message: l.cheatsheetRowEmojiTooltip,
      child: TextButton(
        key: Key('row-$i-emoji'),
        onPressed: () => _chooseRowEmoji(i),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  Future<void> _chooseRowEmoji(int i) async {
    final editor = _editor;
    final pick = ref.read(cheatsheetEmojiPickerProvider);
    final chosen = await pick(context, allowClear: true);
    if (chosen == null) return;
    editor.setRowEmoji(i, chosen.isEmpty ? null : chosen);
  }
```

(The two raw `IconButton`s in this file — add-row and remove-row — are unchanged, so its allow-list count of 2 still holds.)

- [ ] **Step 23: Keep the existing create-path tests working with Look expanded**

On create, the expanded Look section (about 600 dp) pushes the rows below the default 800×600 test view, past the `ListView`'s build extent, so taps on `row-0-bind` / `row-0-action-call` would find nothing; and the expanded body reads `cheatsheetCoversSupportedProvider`, whose real value watches `dataModeProvider` → `settingsProvider` (SharedPreferences). Both create-path suites get a tall view and a fixed override; the edit-path tests are unaffected (collapsed).

In `test/features/cheatsheet/presentation/cheatsheet_designer_screen_test.dart`, add to the imports:

```dart
import 'package:hmm_console/features/cheatsheet/presentation/widgets/look_section.dart';
```

In `mount`, replace

```dart
    lastPickerTemplateId = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cheatsheetIdGenProvider.overrideWithValue(() => 'new-id'),
```

with

```dart
    lastPickerTemplateId = null;
    // Tall enough that the rows stay built below the expanded Look section.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cheatsheetCoversSupportedProvider.overrideWithValue(true),
          cheatsheetIdGenProvider.overrideWithValue(() => 'new-id'),
```

and in `starting a second new card does not reuse the first`, replace

```dart
      final container = ProviderContainer(
        overrides: [
          cheatsheetIdGenProvider.overrideWithValue(() => 'id-${++nextId}'),
```

with

```dart
      final container = ProviderContainer(
        overrides: [
          cheatsheetCoversSupportedProvider.overrideWithValue(true),
          cheatsheetIdGenProvider.overrideWithValue(() => 'id-${++nextId}'),
```

In `test/features/cheatsheet/cheatsheet_acceptance_test.dart`, add to the imports:

```dart
import 'package:hmm_console/features/cheatsheet/presentation/widgets/look_section.dart';
```

and replace

```dart
    final container = ProviderContainer(
      overrides: [
        hmmNoteRepositoryProvider.overrideWithValue(noteRepo),
```

with

```dart
    // The designer opens Look expanded on create; keep its rows built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        cheatsheetCoversSupportedProvider.overrideWithValue(true),
        hmmNoteRepositoryProvider.overrideWithValue(noteRepo),
```

- [ ] **Step 24: Run the designer, help and existing cheatsheet tests**

Run: `flutter test test/features/cheatsheet test/core/help test/core/navigation/cheatsheet_routes_test.dart`
Expected: `All tests passed!` — the create-path tests (`binds a row through the picker…`, `value actions are chosen explicitly`, `rows can be added and removed`, the acceptance flow) find `row-0-*` below the expanded Look section in the tall view; the edit-path tests (`renaming and saving keeps the id`, `the loaded card's template reaches the picker`, the acceptance edit step) see Look collapsed and never read `cheatsheetCoversSupportedProvider`.

- [ ] **Step 25: Analyze and commit**

```bash
cd /Users/fchy/Projects/hmm_console
flutter analyze lib/features/cheatsheet lib/core/help test/features/cheatsheet test/core/help
git add lib/features/cheatsheet/presentation/widgets/look_section.dart \
  lib/features/cheatsheet/presentation/screens/cheatsheet_designer_screen.dart \
  lib/core/help/help_registry.dart \
  test/features/cheatsheet/presentation/cheatsheet_designer_look_test.dart \
  test/features/cheatsheet/presentation/cheatsheet_designer_screen_test.dart \
  test/features/cheatsheet/cheatsheet_acceptance_test.dart \
  test/core/help/help_registry_test.dart
git commit -m "$(cat <<'EOF'
feat(cheatsheet): designer Look section with live tile preview

Theme and pattern swatches, emoji icon, cover from camera/library/scanner
(local modes), Facts/Key points control per platform, row emoji slots in
Key points, Reset look, and a designer help sheet. Look opens expanded
when creating a card and collapsed, preview only, when editing one.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Full verification

**Files:**
- No code changes. Fix anything found here in the task that owns it, then re-run this task.

**Interfaces:**
- Consumes: everything above.
- Produces: a green client branch (`feat/contacts-client`) and a green backend commit on hmm branch `feat/cheatsheet-style-passthrough` (not merged to `main`), the manual results recorded in the ledger, and the deploy-order note.

- [ ] **Step 1: Analyze**

Run: `cd /Users/fchy/Projects/hmm_console && flutter analyze`
Expected: exactly 2 issues — the pre-existing infos in `onboarding_screen.dart` and `main.dart`.

- [ ] **Step 2: Full client test suite**

Run: `cd /Users/fchy/Projects/hmm_console && flutter test 2>&1 | tail -3`
Expected: `All tests passed!` with a count above 2060 (2060 plus every test added in Tasks 1-9).

- [ ] **Step 3: ARB parity and generated files**

```bash
cd /Users/fchy/Projects/hmm_console && python3 - <<'EOF'
import json
en = {k for k in json.load(open('lib/l10n/app_en.arb')) if not k.startswith('@')}
zh = {k for k in json.load(open('lib/l10n/app_zh.arb')) if not k.startswith('@')}
print('missing in zh:', sorted(en - zh))
print('missing in en:', sorted(zh - en))
EOF
flutter gen-l10n && git status --short lib/l10n/gen
```

Expected: both lists empty, and no uncommitted changes in `lib/l10n/gen`.

- [ ] **Step 4: Backend tests**

```bash
git -C /Users/fchy/Projects/hmm branch --show-current   # expect: feat/cheatsheet-style-passthrough
dotnet test /Users/fchy/Projects/hmm/src/Hmm.Cheatsheet.Tests/Hmm.Cheatsheet.Tests.csproj 2>&1 | tail -2
dotnet test /Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj 2>&1 | tail -2
dotnet test /Users/fchy/Projects/hmm/Hmm.sln 2>&1 | grep -E "^(Passed|Failed)!"
```

Expected: `Passed! - Failed: 0, Passed: 103` and `Passed! - Failed: 0, Passed: 429`; every project line in the solution run is `Passed!`.

- [ ] **Step 5: Guard checks**

```bash
cd /Users/fchy/Projects/hmm_console
grep -rn "IconButton(" lib/features/cheatsheet | grep -v HmmIconButton   # expect: only designer add-row/remove-row and source_picker (allow-listed)
grep -rn "debugPrint" lib/features/cheatsheet/presentation/look lib/features/cheatsheet/presentation/widgets/look_section.dart lib/features/cheatsheet/states/cheatsheets_state.dart   # every line prints ids / runtimeType only
grep -rn "html\|Html\|WebView" lib/features/cheatsheet   # expect: nothing (never stored HTML)
grep -n "cheatsheet_wallet_screen\|cheatsheet_detail_screen" test/core/help/icon_button_guard_test.dart   # expect: nothing
git status --short   # expect: clean
git -C /Users/fchy/Projects/hmm status --short   # expect: only ' M CLAUDE.md' (not ours)
```

- [ ] **Step 6: Manual checks (record each result in the ledger)**

Run on the iOS simulator (macOS dev host, per CLAUDE.md) with `flutter run`, then on an Android emulator, in Local mode unless stated:

1. Open an existing pre-feature card and save it without edits: the wallet tile shows its template look; in cloudStorage mode no sync push is triggered by a content change (sync status card), because the content is byte-identical.
2. Wallet: 2 columns on an iPhone, 3 on an iPad portrait (≥ 600 pt), 4 on an iPad landscape (≥ 900 pt). The group chips filter; search still works; VoiceOver/TalkBack reads "<title>, <group>, <N> rows, button".
3. Designer → Look: on a new card the section opens expanded; on an existing card it opens collapsed with the mini-tile in its header and a tap expands it. Each swatch updates the mini-tile live; the selected swatch shows a check; VoiceOver reads the colour name. iOS shows the Cupertino sliding control, Android the Material segmented button; labels fit at 320 pt (iPhone SE) in en and zh.
4. Emoji picker: search `book` and `书` both find 📖; type 🦄 in the free field and use it; type `abc` and see the error.
5. Cover: add from camera, from photos, and (iOS device only) via the document scanner; the tile shows the photo under a dark gradient with readable text; replace it and remove it. In Settings → Vault GC dry run, the replaced photo is reclaimable and the current one is not.
6. Mark a card protected (dev build / data edit) and add a cover: it is stored sensitive. Lock the vault: the wallet tile shows the theme with a 🔒 badge and opening the wallet prompts for nothing; the detail header shows the tap-to-unlock tile, and unlocking reveals the cover.
7. Detail: Key points numbers rows on the theme colour, shows row emoji, and the call/map/open-source actions and image rows work exactly as in Facts. Switch Key points → Facts → Key points in the designer: the row emoji are still there.
8. Dark mode: every theme with every pattern is legible on tiles and the header (spot-check amber, slate and black).
9. Reset look: the card returns to its template look, the cover disappears and its bytes become reclaimable.
10. Delete a card with a cover: the Vault GC dry run no longer counts its photo.
11. Help: the wallet, the detail and the designer each show a "?" in the top bar; each sheet lists its entries (wallet: cards, group chips, tag chips, lock badge; detail: Facts layout, Key points layout, cover header, locked cover; designer: Look … Reset look) in en and in zh, and on iOS it opens as the Cupertino popup.
12. Cloud API mode against the local backend (`../hmm/docker/test-env.sh` with the Task 4 build): change theme/pattern/icon/layout and row emoji, reload — they persist; Cover is not offered; Reset look clears the server copy.

- [ ] **Step 7: Stop**

Do not push, merge, deploy or open a PR. Report the client commit range (`git log --oneline main..HEAD` in hmm_console), the backend branch and commit (`git -C /Users/fchy/Projects/hmm branch --show-current` — expect `feat/cheatsheet-style-passthrough` — and `git -C /Users/fchy/Projects/hmm log --oneline main..feat/cheatsheet-style-passthrough`), the manual results, and the deploy-order rule: **the Hmm server pass-through (Task 4) must be deployed before or together with the client release; until then a Cloud API save stores `Style` as an unknown PascalCase extra and the next server-side read will not see it as `style`.**

---

## Self-review

- **Spec coverage.** D1 presets + cover → Tasks 1, 3, 9. D2 wallet tiles 2/3/4 + chips → Tasks 6, 7. D3 cover header + Facts / Key points → Tasks 6, 8. D4 `style` in the card JSON, written only when non-default, byte-identical, unknown values raw, top-level and row unknown keys, reset → Tasks 1, 2, 9. D5 server pass-through + client mapper → Tasks 4, 5. Themes AA light+dark (with pattern ink) → Task 1. Template defaults table → Task 1. Cover in the attachments column, released on replace/remove/delete/reset → Tasks 3, 9. Sensitive cover: badge on tile without prompt, tap-to-unlock in header → Task 6 (and Task 7 wallet test). Wallet help (tiles, group chips, tag chips, lock badge) → Task 7; detail help (Facts, Key points, cover header, lock tile) → Task 8. Error handling: silent fallback, type-only logs, invalid icon → Tasks 1, 6. Designer: swatches with names, patterns, emoji picker (curated groups, en/zh search, free typing), cover add/replace/remove via camera/library/scanner with thumbnail, platform layout control, row emoji only in Key points, reset, live preview, Look expanded on create / collapsed on edit, help en+zh, `HmmIconButton` → Task 9. Cloud API tests (server round trip, client mapper, unknown style keys end to end) → Tasks 4, 5. Large photos → the existing downsizer in `persistToVault` (Task 3). Deploy ordering → Global Constraints, Task 4 Step 11, Task 10 Step 7.
- **Not mapped (deliberately, see Deviations and the spec's "Decisions from plan review"):** covers in Cloud API mode.
- **Placeholders:** none — every code step carries full code; every run step names the command and the expected result.
- **Type consistency:** `CardStyle`/`CardLook`/`CardThemeId`/`CardPattern`/`CardLayout` (Task 1) are used unchanged in Tasks 2, 5, 6, 8, 9; `CheatsheetsState.save(card, {newCover, released})` (Task 3) matches the editor's `commit` (Task 9) and every test fake (Tasks 3, 9); `noteIdFor` exists on the interface, both repositories and `_FakeRepo`; `CardColors`/`CheatsheetPalette` (Task 1) are what `CardSurface`, `headerBarColors`, `_RowTile` and the swatches consume; the generated l10n signatures `cheatsheetTileSubtitle(String group, int count)` and `cheatsheetTileSemantics(String title, String group, int count)` match their placeholder order; `HelpId.cheatsheetWallet` (Task 7) → `cheatsheetDetail` (Task 8) → `cheatsheetDesigner` (Task 9) are added in that order, each task's enum listing includes the earlier ones, each registry case goes after the previous task's case, and each task's help ARB keys go after the previous task's last help key (`helpContactEditSelfBody` → `helpCheatsheetWalletLockBody` → `helpCheatsheetDetailLockBody`); `LookSection(initiallyExpanded:)` (Task 9 Step 21) matches its only call site (Step 22).
- **Review Focus owners:** 1 → Task 6 tests; 2 → Task 3 and Task 4 tests; 3 → Task 9 editor and designer tests; 4 → Task 3 repository and state tests; 5 → Task 1 and Task 6 tests.
