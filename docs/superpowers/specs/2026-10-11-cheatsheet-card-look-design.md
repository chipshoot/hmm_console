# Cheatsheet Card Look — Design Spec

**Date:** 2026-10-11
**Status:** Approved in conversation (freedom level, wallet layout, detail layout, three design sections) — awaiting written-spec review
**Branch:** `feat/contacts-client`
**Builds on:** `2026-07-23-cheatsheet-cards-design.md` (cards are a semantic definition rendered natively per platform — **never stored HTML**)

## Goal

Give every cheatsheet card its own look — colour, pattern, icon, optional cover photo and a layout — so cards are recognisable at a glance in the wallet, and book/document cards are easier to remember.

## Decisions

| # | Decision |
|---|----------|
| D1 | Freedom: **curated presets plus an optional cover photo** (no free colour picker, no fonts, no HTML). |
| D2 | Wallet: **two-column tiles** (3–4 on tablets) with the card's colour/pattern or cover as background; wallet groups become **filter chips**. |
| D3 | Detail: **cover header + a per-card layout** — **Facts** (label → value, today's rows) or **Key points** (numbered, theme-coloured, optional emoji per row). |
| D4 | Storage: a **`style` block inside the card's existing JSON**. Rejected: shared style notes (extra record type, dangling references), stored HTML/CSS (violates the cheatsheet spec, security, needs a web view). |
| D5 | Cloud API: **server pass-through** for `Style` and per-row `Emoji`, so no data mode drops the look. |

## Non-goals

- Free colour picker, custom fonts, arbitrary images other than one cover, animated backgrounds.
- Shared/reusable themes across cards.
- Changing how row values resolve.
- Web client rendering (the model is designed so one can be built later).

## Style model

Stored only when the look differs from the template default:

```json
"style": {
  "theme": "orange",
  "pattern": "dots",
  "icon": "📖",
  "layout": "keyPoints",
  "cover": "<vault path>"
}
```

Per row (Key points layout): `"emoji": "👀"` on the row map.

| Field | Values | Default |
|-------|--------|---------|
| `theme` | `blue` `green` `orange` `red` `purple` `teal` `pink` `amber` `slate` `indigo` `brown` `black` | template default |
| `pattern` | `none` `dots` `stripes` `grid` `waves` | `none` |
| `icon` | one emoji (a single grapheme cluster) | template default |
| `layout` | `facts` `keyPoints` | template default |
| `cover` | vault path of an image attachment on the card's own note | none |
| row `emoji` | one emoji | none |

**Themes** are hand-picked, each with a light and a dark variant whose title/subtitle text meets **WCAG AA** contrast. Text colour is derived from the variant, never user-chosen. Covers always get a darkening gradient behind text.

**Template defaults:**

| Template | Theme | Icon | Layout |
|----------|-------|------|--------|
| `accidentClaim` | blue | 🚗 | facts |
| `healthInfo` | green | ⚕️ | facts |
| `document` | orange | 📖 | keyPoints |
| `blank` | slate | 🗂️ | facts |
| unknown template | slate | 🗂️ | facts |

## Persistence rules

- A card whose look was never changed has **no `style` key** and renders its template default. Existing cards need no migration.
- A card opened and saved without edits is written back **byte-identical**.
- Unknown values (a newer theme/pattern/layout, a non-emoji icon) render as the default; their **raw value is preserved** and written back unchanged unless the user changes that field.
- The card codec gains **top-level unknown-key preservation** (today it preserves unknown *rows* only), and rows preserve unknown keys alongside the new `emoji`.
- **Reset look** removes the `style` block and every row `emoji`, and releases the cover.
- The cover image is an attachment in the card note's `attachments` column (the column `VaultGc` reads), so it is never garbage-collected while referenced. Removing the cover, replacing it, or deleting the card releases it.

## Wallet (tiles)

- Grid: 2 columns on phones, 3 at ≥ 600 dp, 4 at ≥ 900 dp. Search stays above the grid; a chip row (All + each wallet group in use, translated via `cheatsheetGroupLabel`) filters below it.
- Tile: theme colour + pattern, or the cover photo with a darkening gradient; the emoji icon; title (max 2 lines); subtitle "group · N rows".
- Protected cards show a lock badge (existing `protected` flag).
- A sensitive cover while the vault is locked: the tile shows the theme colour with a 🔒 badge — **never** an unlock prompt from merely rendering.
- Semantics: "<title>, <group>, <N> rows, button". Colour is never the only cue.

## Detail

- Header: cover or theme colour + pattern, icon, title, "group · N rows"; existing edit/delete/help actions remain, legible on the header.
- **Facts:** today's rows below the header, unchanged.
- **Key points:** each row shows its number, its emoji (if set), the row label in bold and the resolved value as body text, with a theme-coloured leading border. Unbound ("—") and missing ("source removed") states, image rows and value actions (call / map) behave as today.

## Designer — "Look" section

- Placed under the card title with a live mini-tile preview.
- **Theme:** 12 swatches (check mark on the selected one; accessible names e.g. "Blue").
- **Pattern:** 5 swatches.
- **Icon:** opens an emoji picker — curated grid grouped Vehicle / Health / Home / Books & learning / Work / Travel / Money / Misc, searchable by English and Chinese keywords, plus free typing of any emoji.
- **Cover:** Add (camera / photo library / document scanner — reuse the existing pickers, downsizer and scanner) or Remove; thumbnail when set.
- **Layout:** Facts / Key points — `CupertinoSlidingSegmentedControl` on iOS, `SegmentedButton` on Android.
- **Row emoji:** an emoji slot on each row in the designer's row list, shown only for Key points.
- **Reset look** action.
- Help: a designer help entry for "Look" (en + zh); every icon button is `HmmIconButton` with a localized tooltip.

## Cloud API (server pass-through)

- `Hmm` repo: `ApiCheatsheet` / `ApiCheatsheetForCreate` / `ApiCheatsheetForUpdate` gain an optional `Style` (JSON object, passed through verbatim) and `ApiCheatsheetRow` gains an optional `Emoji` (string); `CheatsheetJsonNoteSerialize` reads and writes them verbatim. Absent ⇒ not written.
- `hmm_console`: `CheatsheetApiMapper` maps `style` ↔ `Style` and row `emoji` ↔ `Emoji` verbatim, preserving unknown content.
- Covers are vault attachments; in Cloud API mode they use the existing API vault store like other attachments.
- Server tests: round-trip with and without `Style`/`Emoji`; unknown keys inside `Style` preserved.

## Error handling

- Cover cannot load (missing file, decrypt failure): fall back to the theme background silently; log the error **type only**.
- Vault locked: lock badge on the tile; the detail header shows the existing tap-to-unlock lock tile.
- Invalid icon/emoji text: render the template icon; keep the raw value.

## Testing

- Codec: untouched card byte-identical; `style` written only when non-default; unknown theme/pattern/layout/top-level keys preserved; row emoji round-trip; reset removes `style` and row emoji.
- Themes: every preset's title/subtitle colours meet WCAG AA against its light and dark background.
- Wallet: tile shows colour/pattern/icon/cover; chips filter; locked sensitive cover shows a badge and triggers no unlock; 2/3/4 columns by width.
- Detail: header; Facts unchanged; Key points numbering/emoji/border; unbound/missing/image rows in both layouts.
- Designer: live preview updates; reset; cover add/replace/remove releases the attachment; row emoji slot only in Key points; iOS and Android controls; help entry present.
- Cloud API: server round-trip of `Style`/`Emoji`; client mapper round-trip; unknown style keys preserved end to end.

## Risks

- **Emoji rendering differs by platform** (Apple vs Google glyphs) — acceptable; the model stores the character, not an image.
- **Backend deploy ordering** — until the server pass-through is deployed, saving a card through the Cloud API drops its `style`. The server change must be deployed before (or with) the client release that writes `style` in Cloud API mode.
- **Large cover photos** — reuse the existing image downsizer on pick.
