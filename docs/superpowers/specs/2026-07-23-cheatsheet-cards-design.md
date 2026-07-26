# Cheatsheet Cards — Design Spec

**Date:** 2026-07-23 (revised 2026-07-26: generalized source model, decoupled from Contacts)
**Status:** Approved (brainstorming) — **not blocked** (Contacts is now an optional source, not a prerequisite)
**Scope:** a new **Cheatsheet domain module on both backend (`Hmm`) and client (`hmm_console`)**, modeled by **composition** like the Automobile module — the definition is stored as `HmmNote` content (`Cheatsheet:{id}` subject + fixed `Hmm.Cheatsheet` catalog), so **no backend schema change**. Clients own live resolution + platform-adaptive rendering.

## Goal

A **cheatsheet** is a read-only card that surfaces chosen **pieces of other HmmNotes** at a glance, kept live and browsed wallet-style. Its one job is: *reference a piece of a note, at whatever granularity fits, and render it.* It is a **viewer over notes** (like HTML/CSS over web content) — not a typed entity.

Motivating examples (deliberately varied to pin the model):
- **Accident Claim** — plate + VIN (fields of the Automobile note), insurer + policy # (fields of the Insurance note), driver name/phone/address (fields of a person source).
- **Health Info** — a doctor's name/phone, a pharmacy's name/phone (fields of person/org sources).
- **Vim cheatsheet** — the "Shortcuts" *section* of a big Vim note (which also holds VimScript, config, …).
- **Game of Thrones** — the "Characters" / "Houses" *sections* (or the whole) of a GoT note.

The health/vehicle cases reference **fields**; the vim/GoT cases reference **sections/whole** — both are just "a piece of an HmmNote."

## Sources & independence from Contacts (the key model)

A row's source is **a reference to a piece of an HmmNote at one of three granularities**:

- **`field`** — for a **structured note** (one whose catalog/schema exposes named fields: Automobile, Insurance, or a contact-shaped note). `locator` = the field key. Renders just that value (e.g. "phone"). Enables the clean key->value cards.
- **`section`** — a heading/block within a markdown note. `locator` = a stable section anchor (heading text). Renders that section (e.g. Vim "Shortcuts", GoT "Houses").
- **`whole`** — the note's entire content as text.

**Cheatsheets therefore do NOT require a Contact entity.** Person data is simply *a structured source* — a Contact (if that feature exists) **or** any contact-shaped note. Contacts is an **independent, optional** feature (valuable for an address book, reuse across cards, tap-to-call, and future sharing, and it gives the cleanest person-field binding), but it **does not gate** this feature. v1 can ship over the sources that already exist (Automobile, Insurance — note-content with fields) plus section/whole references to any note.

**Build order (revised):** Cheatsheet v1 can proceed now. Contacts ships in parallel/whenever, and its contacts light up automatically as an extra `field` source. Cheatsheet Phase 2 (image/ID cards + protection) follows.

## Non-goals (v1)

- No computed/aggregated rows / sharing-export / rich layout editor.
- Image/ID cards + sensitive-protection **gating** are Phase 2.
- Daily activity summary is a **separate feature** (computed dashboard / HealthKit).

---

## Architecture — composition, both stacks, platform rendering

**Domain model = composition (like `GasLog`/`Automobile`), never inheritance.** A typed `CheatsheetCard` entity is **serialized into** an `HmmNote`; it is **not** a subclass of `HmmNote` (a cheatsheet *is-a view over* notes, not *an* note — inheritance would model the wrong relationship and drag `HmmNote`'s persistence machinery into the domain). Classified by a fixed `Hmm.Cheatsheet` catalog + `Cheatsheet:{id}` subject.

**Three layers (the "viewer" model — cheatsheet : HmmNotes ~ HTML/CSS : web content):**
- **Definition** — the `CheatsheetCard` JSON (rows, references, layout *semantics*, quick-access props). Stored, portable, platform-agnostic.
- **Content** — live values, resolved fresh from the *referenced* notes on every open.
- **Rendering** — per platform; the definition is a **semantic model, never pre-rendered HTML**, so each client renders natively (Flutter today; HTML/CSS on a future web client). `NoteCatalog.Render`(HTML) is deliberately unused.

**Stack placement (both, like Automobile):**
- **Backend (`Hmm`)** — Cheatsheet module (entity + `CheatsheetJsonNoteSerialize` + `Validator` + `Manager` over the `Entity*Base` classes + `/v1/cheatsheets`). Owns CRUD + **shape validation** (well-formed rows) — not reference resolution (references may point at not-yet-synced notes -> resolution is a client concern that degrades gracefully). Note-content storage -> **no schema change**.
- **Client (`hmm_console`)** — the `cheatsheet` feature module: entity + serializer + live **resolver** + platform-adaptive renderer + designer/wallet UI + quick-access surfacing:

```
lib/features/cheatsheet/
  domain/entities/   cheatsheet_card.dart, cheatsheet_row.dart, cheatsheet_source.dart
  data/              cheatsheet_note_serializer.dart, cheatsheet_repository.dart, cheatsheet_resolver.dart
  states/            cheatsheet_list_state.dart, cheatsheet_designer_state.dart
  presentation/      screens/{wallet,designer,detail}, widgets/{card_view,row_view,source_picker}
```

## Data model (defects 1, 4, 5 resolved; source generalized)

```dart
class CheatsheetCard {
  final String id;            // uuid
  final String title;
  final String walletGroup;   // authoritative here (NOT the note catalog)
  final List<String> tags;    // authoritative here
  final String templateId;    // 'accidentClaim' | 'healthInfo' | 'document' | 'blank'
  final bool protected;       // reserved in v1 (default false); gated in Phase 2
  final bool quickAccess;     // surfaces the card in the Quick Access Panel (feature #23)
  final int sortOrder;        // user ordering within its wallet group
  final List<CheatsheetRow> rows;
}

class CheatsheetRow {
  final String label;
  final CheatsheetSource? source;  // NULL = unbound (defect 1) -> renders "-"
  final ValueAction valueAction;   // call | map | none  (primary value action) — defect 5b
  final bool openSource;           // universal "jump to source note" affordance — defect 5b
}

// A reference to a PIECE of a note, by cross-device-stable note UUID (defect 4).
class CheatsheetSource {
  final String noteUuid;          // stable owning-note UUID
  final SourceGranularity kind;   // field | section | whole
  final String? locator;          // field -> field key; section -> heading anchor; whole -> null
}

enum SourceGranularity { field, section, whole }
enum ValueAction { call, map, none }
```

- **field** granularity requires the source note to be **structured** (its catalog/schema declares field keys — Automobile, Insurance, contact-shaped notes). The source picker reads the note's schema to list bindable keys.
- **section** anchors by heading text; if the heading later disappears, the row degrades to "source removed".
- No `entityType` — "structured entities" are just structured notes addressed by `noteUuid + fieldKey`.

## Reference resolution

`CheatsheetResolver.resolve(row)` -> current value:
1. `field` -> load note `noteUuid`, read `locator` from its structured content.
2. `section` -> load note `noteUuid`, extract the block under heading `locator`.
3. `whole` -> load note `noteUuid`, return full content as text.
Recomputed every open.

**Edge cases (never crash):** unbound -> "-"; note/field/section missing or reference unresolvable -> muted "source removed"; a sensitive/encrypted source note -> the Phase 4b locked placeholder.

## Storage (defects 2/5a resolved)

- Each cheatsheet is an `HmmNote` under one fixed `Hmm.Cheatsheet` catalog (immutable after creation -> not used to carry the mutable wallet group).
- **Wallet group + tags + quick-access props are authoritative in the card JSON.** Changing the wallet group is a JSON edit — no catalog move.
- Note-content storage + existing sync; **no schema change.** Backend Cheatsheet module owns CRUD + shape validation via `/v1/cheatsheets`.
- A `quickAccess` card is surfaced in the Quick Access Panel (feature #23).

## Starter templates (v1)

- **Accident Claim** — Automobile fields (plate, VIN) + Insurance fields (provider, policyNumber) bind now; driver person rows bind to a person source (a contact-shaped note or a Contact) when available, else stay unbound.
- **Health Info** — person/org rows; bind to contact-shaped notes / Contacts when present.
- **Document** — section/whole rows for a chosen note (the Vim / GoT extract shape).
- **Blank** — no rows.

Templates instantiate pre-labeled rows with `source: null`; the designer prompts binding. Partial binding is allowed.

## The designer (template-first)

Create -> pick a template -> bind each row via `source_picker`: pick a note, then a **granularity** — if the note is structured, pick a **field**; else pick a **section** or **whole**. Relabel, add/remove/reorder, set wallet group + tags + quick-access, optional per-row value action -> save (partial binding allowed).

## Browse & render (wallet)

Wallet screen: stacks grouped by `walletGroup`, tag filter/search; tap a card -> read-only detail with live label->value rows, actionable values (call / map) + open-source; editing routes back to the designer.

## Sync & data-mode

Syncs as a normal note. References use cross-device-stable note UUIDs; a card resolves against the active data mode's dataset — unresolvable references degrade to "source removed".

## Testing

- **Serializer:** card <-> HmmNote JSON round-trips incl. an unbound row (`source: null`) and each granularity; unknown/absent fields tolerated.
- **Resolver:** field hit, missing field, section hit, missing section, whole, unbound, deleted note; value-action inference.
- **Cross-device (mandatory):** author a card, sync to a fresh DB/device, assert every reference resolves the intended piece.
- **Storage:** changing the wallet group mutates JSON only, never the note catalog.
- **Designer / wallet (widget):** template -> unbound rows; the source picker binds field vs section vs whole; partial save; grouping/filter; tap-to-call / tap-to-map; open-source on every row.

## Card types & roadmap

- **v1 — Field/section/whole reference cards** (this spec) — covers key->value cards AND document extracts (vim/GoT).
- **Phase 2 — Image / ID cards + sensitive protection** — stored images (driver's-licence front+back, health card) + the `protected`-flag gating, composed with **Phase 4b** (images through the encrypted, biometric-gated vault).
- **Later —** computed/derived rows; sharing/export; richer layouts.

## Sensitive protection (flag reserved in v1, gated in Phase 2)

`CheatsheetCard.protected` (default false) marks a card as needing the Phase 4b unlock before its contents show. **Image/ID cards (Phase 2):** *real* protection — images stored as encrypted sensitive attachments. **Reference cards:** only a **view-gate** — display hidden until unlock, but the referenced notes remain independently viewable (access-friction, not encryption; the UI must not imply otherwise).

## Explicitly a separate feature (not a cheatsheet)

A **daily activity summary** (Apple Health/Fitness style) is a computed dashboard (aggregates metrics/trends; real fitness data needs HealthKit / Google Fit). Tracked as its own future feature.

## Appendix — resolutions

**2026-07-26 (decoupling):** cheatsheet source generalized to a note-piece reference (`field` | `section` | `whole`); **Contacts is no longer a prerequisite** — it's an optional `field` source. Covers document-extract cards (vim/GoT).

**2026-07-24 defect review:**

| Defect | Resolution |
|--------|-----------|
| 1 Unbound template rows | `CheatsheetRow.source` nullable; partial save; unbound -> "-". |
| 2 Wallet group vs immutable catalog | Fixed `Hmm.Cheatsheet` catalog; wallet group + tags authoritative in JSON. |
| 3 Missing fields/entities | Source generalized to note-piece references; no dependence on a Contact entity (formerly the blocker); structured sources are addressed by note UUID + field key. |
| 4 Unstable cross-device ids | Reference = stable note UUID (+ granularity locator), never device-local int; mandatory fresh-device resolve test. |
| 5 Metadata/action ambiguity | Wallet group + tags authoritative in JSON (5a); `ValueAction` split from the universal `openSource` flag (5b). |
