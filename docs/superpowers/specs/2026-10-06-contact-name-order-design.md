# Contact Name Order, Pinyin Sort and Search — Design Spec

**Date:** 2026-10-06
**Status:** Approved in conversation (grilling Q1–Q13 + three design sections) — awaiting written-spec review
**Branch:** `feat/contacts-client`
**Builds on:** `2026-07-25-contacts-design.md` (Contacts), `2026-07-23-cheatsheet-cards-design.md` (Cheatsheet)

## Goal

Show each contact's name the way that name is written: Chinese names family-name first (张伟), Latin and pinyin names given-name first (John Smith, Wei Zhang). Sorting and search must still work by family or given name, and Chinese names must sort and search alongside Latin ones through pinyin (张伟 sorts next to "Zhang", and `zw` / `zhangwei` find it).

## Decisions (from grilling)

| # | Decision |
|---|----------|
| Q1 | Order is **auto-detected** from script, with a **per-contact override**: Auto / Given name first / Family name first. |
| Q2 | Family-first names: **no space** when both parts are Chinese (张伟); **a space** when mixed (张 David). Any Chinese character in either part ⇒ family-first under Auto. |
| Q3 | Settings: **"Sort contacts by: Family name (default) / Given name"**. Sorting is independent of display order. |
| Q4 | Pinyin is computed **automatically** for sort and search, with **optional phonetic fields** (family / given) that override it. |
| Q5 | The persisted `displayName` follows the display order. |
| Q6 | Scope: **contacts only** — list, detail, "Me", cheatsheet cards, search. A–Z index bar and other features are out of scope. |
| Q7 | The override lives under a **"More name options"** expander. |
| Q8 | The phonetic fields live in the same expander, which **opens automatically for Chinese names** and shows the automatic pinyin as **greyed hint text**. |
| Q9 | **No global display-order setting** for Latin names; they are always given-first unless overridden per contact. |
| Q10 | Search matches display name, phones/emails, family/given **in either order**, **full pinyin** (with/without spaces) and **pinyin initials**. |
| Q11 | Within the Family / Providers / Other groups: **"Me" first**, then the sort key; **organizations sort by their name among people**; Chinese names sort by pinyin. |
| Q12 | **No bulk rewrite.** New fields are written only when a contact is edited. Cheatsheet cards resolve the order at read time so they are correct immediately. |
| Q13 | Library: **`pinyin_pro_flutter`**, adopted only after a scratch spike passes; fallback **`pinyin` 3.3.0 + a polyphonic-surname table**. Pinyin is **computed at read time, never persisted**. |

## Non-goals

- A–Z / pinyin index bar on the list.
- Applying name order outside Contacts (author profile, note authors).
- Global display-order preference for Latin names.
- Auto-parsing a single free-text name into family/given.
- Japanese/Korean-specific handling beyond the per-contact override (kanji/hanja names are detected as Han characters and default to family-first, which is correct for both).

## Architecture

All name logic lives in one pure-Dart module; pinyin sits behind an interface. No unit outside these files re-implements ordering.

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `lib/features/contacts/domain/contact_name.dart` (pure) | `hasChinese(String)` (Han ideographs: U+3400–U+4DBF, U+4E00–U+9FFF, U+F900–U+FAFF, U+20000–U+2FA1F); `effectiveOrder(Contact)` → `givenFirst` / `familyFirst` (override wins, else Auto rule); `displayName(Contact)` applying the spacing rule; organizations → `organizationName`. | nothing |
| `lib/features/contacts/domain/pinyin_transcriber.dart` | Interface: `List<String> family(String)` (surname mode) and `List<String> given(String)` — toneless lowercase syllables; non-Han characters pass through unchanged. | nothing |
| `lib/features/contacts/data/pinyin_pro_transcriber.dart` | Real implementation on the chosen library (per spike); the fallback implementation applies the surname override table to the leading family characters. | library |
| `lib/features/contacts/domain/contact_sort.dart` (pure) | `sortKey(Contact, ContactSortBy, PinyinTranscriber)` and `searchTerms(Contact, PinyinTranscriber)`. | `contact_name`, transcriber |
| `Contact` entity + `ContactCodec` | New optional fields `nameOrder`, `phoneticFamily`, `phoneticGiven`; derived `displayName` via `contact_name`. | `contact_name` |
| `lib/features/contacts/states/` | A provider pairing each contact with its precomputed sort key and search terms; the list sorts/filters on those. | `contact_sort`, transcriber provider, sort setting |
| Settings | `SyncableSettings.contactSortBy` (`family` / `given`), one Settings row. | — |
| Cheatsheet `DerivedFieldRegistry` | Resolver asks the registry before reading stored JSON for `field` rows; Contacts registers `Contact.displayName`. | Contacts registers at startup |

Display order needs no pinyin, so `Contact.displayName` stays synchronous and cheap. The transcriber (and its dictionary) loads only when the contacts list or search is used — never on the dashboard.

## Data model

New optional `Contact` fields:

| Field | Type | Stored when |
|-------|------|-------------|
| `nameOrder` | enum `auto` / `givenFirst` / `familyFirst` | only when not `auto` |
| `phoneticFamily` | String | only when non-empty |
| `phoneticGiven` | String | only when non-empty |

Codec rules (all existing preservation rules apply):

- The three keys are **known keys**. An unknown `nameOrder` value reads as `auto` and its raw string is preserved via `rawKnownValues`.
- A contact opened and saved **without edits** is written back **byte-identical** — no new keys, stored `displayName` untouched.
- An edited contact's `displayName` is derived from `ContactName.displayName` at save time.
- No migration, no bulk rewrite.

Phonetic validation: Latin letters (including tone-marked vowels ā á ǎ à ē é ě è ī í ǐ ì ō ó ǒ ò ū ú ǔ ù ü ǖ ǘ ǚ ǜ), spaces, apostrophes; trimmed; stored as typed. Invalid input refuses Save with an inline error plus a SnackBar (same pattern as postal codes).

## Display rules

| Family | Given | Override | Shown |
|--------|-------|----------|-------|
| 张 | 伟 | Auto | 张伟 |
| 欧阳 | 娜娜 | Auto | 欧阳娜娜 |
| 张 | David | Auto | 张 David |
| Smith | John | Auto | John Smith |
| Zhang | Wei | Auto | Wei Zhang |
| Zhang | Wei | Family first | Zhang Wei |
| 张 | 伟 | Given first | 伟 张 |
| 张 | — | Auto | 张 |
| — | John | Auto | John |
| (organization) | | | organizationName |

A space typed inside a Chinese part is kept as typed. Family-first output joins the two parts with **no space only when both parts contain Chinese**; otherwise a single space. Given-first output always uses a single space.

## Edit form (persons only)

- Name fields keep their place. For Chinese names the field order flips to Family (姓) above Given (名); the stored data is the same.
- A preview line under the name fields: *Shown as: 张伟*.
- **"More name options"** expander directly below:
  - **Name order:** Auto / Given name first / Family name first — `CupertinoSlidingSegmentedControl` on iOS, `SegmentedButton` on Android (same pattern as the person/organization toggle).
  - **Family name phonetic**, **Given name phonetic** — empty fields show the automatic pinyin as hint text, recomputed (debounced) as the name changes, from the same transcriber.
  - Starts **expanded** when the name contains Chinese or any option is set; otherwise collapsed.
- Help: a new `contactEdit` entry for "More name options" (en + zh), following the `helpContactEdit<Control>Title/Body` pattern.

## Sorting

- Groups unchanged (Family / Providers / Other). Within a group: **"Me" first**, then ascending sort key. Organizations use `organizationName` as their key among people.
- **Family-name sort:** key = family + `|` + given. **Given-name sort:** given + `|` + family.
- Each part's sortable text: phonetic field if set; else, for a part containing Chinese, the transcriber's syllables joined by spaces; else the part as typed. Lowercased and accent-folded (é→e, ü→u).
- Mixed scripts therefore interleave alphabetically (张伟 → `zhang|wei` sits beside `zhang|li`).
- Tie-break: display name, then contact id — stable across devices.
- A contact with no name parts and no organization sorts last in its group.

## Search

Query normalized like sort keys (lowercase, accent-folded, whitespace collapsed). A contact matches if any term contains the query:

- display name;
- `given family` and `family given`;
- full pinyin with and without spaces (`zhang wei`, `zhangwei`) — phonetic fields win when set;
- pinyin initials (`zw`), matched as a prefix only;
- phones (digits-only comparison, existing behaviour) and emails.

Chinese queries (张) match through the display-name term. Terms are built once per list load in the provider and rebuilt when contacts change.

## Cheatsheet

- New `DerivedFieldRegistry` in the cheatsheet domain: `resolve(rootKey, path, entityMap)` returns a value or null.
- `CheatsheetResolver` consults it for `field` rows before reading stored JSON; a non-null answer wins.
- Contacts registers root `Contact`, path `displayName`: decode with `ContactCodec`, return `ContactName.displayName`. On any decode failure return null so the row falls back to the stored value.
- The field picker's offered paths are unchanged.

## Settings

- `SyncableSettings.contactSortBy`: `family` | `given`. Absent in older bundles ⇒ `family`. Synced with the bundle (last-writer-wins, as today).
- One Settings row "Sort contacts by" using the screen's existing platform picker pattern; en + zh label and help entry.

## Error handling

- Transcriber failure (throw, dictionary load failure): sort falls back to Latin parts and then raw code-unit order; pinyin search terms are omitted; log the error **type only** (no names); the list still renders.
- Phonetic validation failure: Save refused with inline error + SnackBar.
- Cheatsheet derived field failure: fall back to the stored value.

## Pinyin library spike (plan task 1, throwaway)

In a scratch Flutter project outside the repo:

1. Add `pinyin_pro_flutter`; transcribe surnames 曾 单 解 区 仇 朴 查 盖 in surname mode. Expected: zeng, shan, xie, ou, qiu, piao, zha, ge.
2. Confirm it builds under Dart `^3.11` and record the release iOS app-size delta.
3. Decision: all eight correct and it builds ⇒ adopt. Otherwise adopt `pinyin` 3.3.0 + a polyphonic-surname override table covering at least the eight above plus 尉迟→yu chi, 万俟→mo qi, 长孙→zhang sun, 乐→yue, 缪→miao, 覃→qin, 翟→zhai, 召→shao, 隗→wei, 句→gou, 秘→bi.

The plan records the outcome before any app code depends on the library.

## Testing

- `contact_name`: table test covering every row of the Display rules table plus organizations.
- `contact_sort`: keys and search terms with a fake transcriber — mixed-script ordering, both sort modes, "Me" first, organizations interleaved, tie-break, phonetic override, initials prefix-only.
- Real transcriber: integration test pinning the eight surnames, so a dependency bump that breaks them fails CI.
- Codec: untouched contact byte-identical; new keys only when non-default; unknown `nameOrder` preserved; edited contact's `displayName` follows the order.
- Widgets: expander auto-opens for Chinese names; hint pinyin shown; preview updates; override changes list order; search finds 张伟 by `zw` and `zhangwei`; iOS and Android controls.
- Cheatsheet: `Contact.displayName` row shows 张伟 for an unsaved legacy contact whose stored `displayName` is "伟 张".
- Settings: `contactSortBy` round-trips through the synced bundle; old bundles read as `family`.

## Risks

- **Polyphonic surnames** beyond the tested set may still be wrong — mitigated by the phonetic fields.
- **Dictionary size / load time** of the pinyin library — measured in the spike; lazy-loaded only on the contacts surfaces.
- **New dependency** maintenance (`pinyin_pro_flutter` is new, publisher unverified) — the transcriber interface keeps it swappable; the surname integration test catches regressions.
