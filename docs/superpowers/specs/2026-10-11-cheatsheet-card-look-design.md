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
| D5 | Cloud API: **server pass-through** for `Style` and per-row `Emoji`, so no data mode drops the look (covers excepted for now — see Decisions from plan review). |

## Decisions from plan review (2026-10-12)

- **Q1 a — no covers in Cloud API mode for now.** `/v1/cheatsheets` exposes neither the backing note id nor its attachments, so the client cannot attach a cover there. In Cloud API mode the designer hides the Cover control; a `style.cover` reference set on another device (Local / Cloud Storage) is passed through untouched and the card renders its theme. Everything else in the look works in all three modes.
- **Q2 a — sensitive covers follow `protected`.** A cover is stored sensitive (vault-locked) only when the card's existing `protected` flag is set; otherwise it is an ordinary attachment. Any sensitive cover follows the lock rules in Wallet, Detail and Error handling.
- **Q3 a — server PUT rule for `Style`.** A PUT whose body has no `Style` key keeps the stored look (older clients); an explicit `"Style": null` clears it (Reset look). The current client always sends the key.
- **Q4 b — designer Look section** is expanded by default when creating a card and collapsed, with the mini-tile preview visible in its header, when editing an existing card.
- **Q6 b — help on all three screens:** wallet, detail and designer each get a help button and help entries (en + zh).

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

**Themes** are hand-picked, each with a light and a dark variant whose title/subtitle text meets **WCAG AA** contrast. Text colour is derived from the variant, never user-chosen. Covers always get a darkening gradient (35% black at the top, clear at 40%, 65% black at the bottom) **plus a 60% black band** (`#99000000`) directly behind the title and subtitle, so white text stays readable even on a pure-white photo (title 5.7:1, 90%-white subtitle 5.0:1). Signed off by the user 2026-10-18 over gradient-only, a softer 35% band with text shadow, and a frosted-glass band.

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
- Tile: theme colour + pattern, or the cover photo with the darkening gradient and the 60% black text band (see Themes above); the emoji icon; title (max 2 lines); subtitle "group · N rows".
- Protected cards show a lock badge (existing `protected` flag).
- Help (Q6 b): a "?" in the top bar opens the wallet help — entries for the tiles, the group chips, the tag chips and the lock badge (en + zh).
- A sensitive cover while the vault is locked: the tile shows the theme colour with a 🔒 badge — **never** an unlock prompt from merely rendering.
- Semantics: "<title>, <group>, <N> rows, button". Colour is never the only cue.

## Detail

- Header: cover or theme colour + pattern, icon, title, "group · N rows"; existing edit/delete/help actions remain, legible on the header.
- **Facts:** today's rows below the header, unchanged.
- **Key points:** each row shows its number, its emoji (if set), the row label in bold and the resolved value as body text, with a theme-coloured leading border. Unbound ("—") and missing ("source removed") states, image rows and value actions (call / map) behave as today.
- Help (Q6 b): a "?" in the top bar opens the detail help — entries for the Facts layout, the Key points layout, the cover header and the locked-cover tile (en + zh).

## Designer — "Look" section

- Placed under the card title with a live mini-tile preview in the section header.
- **Expanded by default when creating a card; collapsed when editing an existing one** (Q4 b), with the preview still visible in the collapsed header; tapping the header expands it.
- **Theme:** 12 swatches (check mark on the selected one; accessible names e.g. "Blue").
- **Pattern:** 5 swatches.
- **Icon:** opens an emoji picker — curated grid grouped Vehicle / Health / Home / Books & learning / Work / Travel / Money / Misc, searchable by English and Chinese keywords, plus free typing of any emoji.
- **Cover:** Add (camera / photo library / document scanner — reuse the existing pickers, downsizer and scanner) or Remove; thumbnail when set. Hidden in Cloud API mode (Q1 a). Stored sensitive only when the card is `protected` (Q2 a).
- **Layout:** Facts / Key points — `CupertinoSlidingSegmentedControl` on iOS, `SegmentedButton` on Android.
- **Row emoji:** an emoji slot on each row in the designer's row list, shown only for Key points.
- **Reset look** action.
- Help: a designer help entry for "Look" (en + zh); every icon button is `HmmIconButton` with a localized tooltip. The wallet and detail screens get their own help too (Q6 b).

## Cloud API (server pass-through)

- `Hmm` repo: `ApiCheatsheet` / `ApiCheatsheetForCreate` / `ApiCheatsheetForUpdate` gain an optional `Style` (JSON object, passed through verbatim) and `ApiCheatsheetRow` gains an optional `Emoji` (string); `CheatsheetJsonNoteSerialize` reads and writes them verbatim. Absent ⇒ not written.
- PUT: absent `Style` keeps the stored look; explicit `null` clears it (Reset look) (Q3 a).
- `hmm_console`: `CheatsheetApiMapper` maps `style` ↔ `Style` and row `emoji` ↔ `Emoji` verbatim, preserving unknown content.
- Covers are not available in Cloud API mode for now (Q1 a): the `/v1/cheatsheets` API exposes no note id or attachments, so the Cover control is hidden in that mode and a cover reference set on another device is passed through untouched (the card renders its theme).
- Server tests: round-trip with and without `Style`/`Emoji`; unknown keys inside `Style` preserved.

## Error handling

- Cover cannot load (missing file, decrypt failure): fall back to the theme background silently; log the error **type only**.
- Vault locked: lock badge on the tile; the detail header shows the existing tap-to-unlock lock tile.
- Invalid icon/emoji text: render the template icon; keep the raw value.

## Testing

- Codec: untouched card byte-identical; `style` written only when non-default; unknown theme/pattern/layout/top-level keys preserved; row emoji round-trip; reset removes `style` and row emoji.
- Themes: every preset's title/subtitle colours meet WCAG AA against its light and dark background.
- Wallet: tile shows colour/pattern/icon/cover; chips filter; locked sensitive cover shows a badge and triggers no unlock; 2/3/4 columns by width; help button and entries present (en + zh).
- Detail: header; Facts unchanged; Key points numbering/emoji/border; unbound/missing/image rows in both layouts; help button and entries present (en + zh).
- Designer: Look expanded on create, collapsed on edit with the preview visible and a tap expanding it; live preview updates; reset; cover add/replace/remove releases the attachment; Cover hidden in Cloud API mode; row emoji slot only in Key points; iOS and Android controls; help entry present.
- Cloud API: server round-trip of `Style`/`Emoji`; client mapper round-trip; unknown style keys preserved end to end.

## Risks

- **Emoji rendering differs by platform** (Apple vs Google glyphs) — acceptable; the model stores the character, not an image.
- **Backend deploy ordering** — until the server pass-through is deployed (backend work lives on hmm branch `feat/cheatsheet-style-passthrough`, not `main`), saving a card through the Cloud API drops its `style`. The server change must be deployed before (or with) the client release that writes `style` in Cloud API mode.
- **Large cover photos** — reuse the existing image downsizer on pick.
