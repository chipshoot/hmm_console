# Cheatsheet Cards — Design Spec

**Date:** 2026-07-23 (revised 2026-07-25 after the 2026-07-24 design-defect review)
**Status:** Approved (brainstorming) — **blocked on a Contacts feature** (see Prerequisites)
**Scope:** a new **Cheatsheet domain module on both backend (`Hmm`) and client (`hmm_console`)**, modeled by **composition** like the Automobile module — the definition is stored as `HmmNote` content (`Cheatsheet:{id}` subject convention + fixed `Hmm.Cheatsheet` catalog), so **no backend schema change**. Clients own live resolution + platform-adaptive rendering.

## Goal

A **cheatsheet** is a read-only card that surfaces the handful of facts you want at a glance — a health-info card, an accident-claim card — assembled from **live links** to information that already lives in other Hmm notes/entities. Cards are organized into wallet-style stacks, stay current when their sources change, and are synced across devices like any other note.

Two motivating examples:
- **Accident Claim card:** plate number, VIN, insurance provider + policy number, plus the driver's own name / phone / home address.
- **Health Info card:** family doctor name + phone, pharmacy name + phone, a person's own name / phone / address; extendable to a family member.

## Prerequisites & sequencing (from the 2026-07-24 defect review)

The person-centric parts of both example cards depend on a **Contacts** entity (name, phones, address, relationship, `isSelf`) that **does not exist in the client today** (verified: no Contacts module). Decision: **Contacts ships as its own separate feature first** (own spec → plan → implementation); cheatsheet v1 follows.

Build order:
1. **Contacts feature** (separate spec) — the person entity cheatsheets bind to.
2. **Cheatsheet v1 — field cards** (this spec).
3. **Cheatsheet Phase 2** — image/ID cards + sensitive protection.

Until Contacts exists, only the non-person sources below are bindable, and the person rows of the starter templates render unbound ("—").

## Locked decisions (from brainstorming)

| Area | Decision |
|------|----------|
| Data source | **Live references** — each row points at a source field and is re-resolved every open, so it changes the moment the source changes. No snapshots. |
| Bindable sources | **Structured entity fields** (Contacts *(pending its feature)*, Automobile, Insurance policy) **+ general-note whole-text**. One field of one entity instance per row, or a general note rendered as plain text. |
| People / self | **Contacts** (self + family, `isSelf` flag) — delivered by the prerequisite Contacts feature. |
| Authoring | **Template-first designer** — start from a template, bind each slot, add/remove/reorder rows. |
| Binding granularity | **One field per row**. |
| Interactions | **Actionable values** — a primary value action (call / map / none) **plus** a universal "open source" affordance on every row. |
| Grouping | **Wallet group** (a user string) + **tags**, both authoritative in the card JSON (see Storage). |
| Storage | **Synced, note-backed entity** — one fixed `Hmm.Cheatsheet` note catalog; definition in JSON content. |
| v1 card type | **Field cards**. Image/ID cards + flashcards are later phases. |

## Non-goals (v1)

- No flashcards / computed-aggregated rows / sharing-export / rich layout editor.
- Image/ID cards and the sensitive-protection **gating** are Phase 2 (planned next), not permanent non-goals.
- Daily activity summary is a **separate feature** (see end).

---

## Architecture — composition, both stacks, platform rendering

**Domain model = composition (like `GasLog`/`Automobile`), never inheritance.** A typed `CheatsheetCard` entity is **serialized into** an `HmmNote`; it is **not** a subclass of `HmmNote`. Rationale: a cheatsheet *is-a view over many notes*, not *an* note — inheritance would model the wrong ("is-a") relationship, drag `HmmNote`'s persistence machinery (`Version[]`, `IsDeleted`, `Author`, repository) into the domain model, and has no precedent (GasLog/AutomobileInfo all compose). The note is classified by a fixed `Hmm.Cheatsheet` catalog + `Cheatsheet:{id}` subject convention.

**Three separate layers (the "viewer" model — cheatsheet : HmmNotes ≈ HTML/CSS : web content):**
- **Definition** — the `CheatsheetCard` JSON in the note (rows, references, layout *semantics*, quick-access props). Stored, portable, platform-agnostic.
- **Content** — the live values, pulled from the *other* HmmNotes each row references; resolved fresh on every open.
- **Rendering** — per platform. The definition is a **semantic model, never pre-rendered HTML**, so each client renders it natively (Flutter widgets today; HTML/CSS on a future web client). `NoteCatalog.Render`(HTML) is deliberately NOT used, so rendering stays platform-adaptive and content stays live.

**Stack placement (both, like Automobile):**
- **Backend (`Hmm`)** — a new Cheatsheet domain module (entity + `CheatsheetJsonNoteSerialize` + `Validator` + `Manager` over `EntityManagerBase`/`EntityValidatorBase`/`EntityJsonNoteSerializeBase`, plus `/v1/cheatsheets` endpoints). It owns the **definition entity's** lifecycle: CRUD and **shape validation** (well-formed rows, known field keys) — **not** reference resolution (references may point at not-yet-synced/device-local notes, so resolution is a client render-time concern that degrades gracefully). Stored as note content → **no schema change**.
- **Client (`hmm_console`)** — the `cheatsheet` feature module: entity + serializer + live **resolver** + **platform-adaptive renderer** + designer/wallet UI + quick-access surfacing:

```
lib/features/cheatsheet/
  domain/entities/   cheatsheet_card.dart, cheatsheet_row.dart, cheatsheet_source.dart
  data/              cheatsheet_note_serializer.dart, cheatsheet_repository.dart, cheatsheet_resolver.dart
  states/            cheatsheet_list_state.dart, cheatsheet_designer_state.dart
  presentation/      screens/{wallet,designer,detail}, widgets/{card_view,row_view,source_picker}
```

Only the card **definition** is stored; displayed **values** are resolved live per platform.

## Data model (defects 1, 4, 5 resolved)

```dart
class CheatsheetCard {
  final String id;            // uuid
  final String title;
  final String walletGroup;   // authoritative here (NOT the note catalog) — defect 2/5a
  final List<String> tags;    // authoritative here
  final String templateId;    // 'accidentClaim' | 'healthInfo' | 'blank'
  final bool protected;       // reserved in v1 (default false); gated in Phase 2
  final bool quickAccess;     // surfaces the card in the app's Quick Access Panel (feature #23) for fast reach
  final int sortOrder;        // user ordering within its wallet group
  final List<CheatsheetRow> rows;
}

class CheatsheetRow {
  final String label;
  final CheatsheetSource? source;  // NULL = unbound (defect 1) -> renders "-"
  final ValueAction valueAction;   // call | map | none  (primary value action) — defect 5b
  final bool openSource;           // universal "jump to source" affordance — defect 5b
}

// Reference by CROSS-DEVICE-STABLE identity, never a device-local int PK — defect 4.
class CheatsheetSource {
  final SourceKind kind;      // entityField | noteText
  final String entityType;    // 'contact' | 'automobile' | 'insurance'  ('' for noteText)
  final String noteUuid;      // stable owning-note UUID (or the note itself for noteText)
  final String? childKey;     // stable sub-record key when the note owns several children
  final String fieldKey;      // e.g. 'phone', 'plateNumber'; '*' = noteText whole-content
}

enum SourceKind { entityField, noteText }
enum ValueAction { call, map, none }
```

- **Defect 1:** `source` is nullable; templates instantiate rows with `source: null`. Partially-bound cards **can be saved**; unbound rows render a muted "-".
- **Defect 5b:** the primary value action (`call`/`map`/`none`, inferred by field or set explicitly) is separate from the always-available `openSource` affordance.
- **Defect 4:** a reference is a **stable, cross-device identifier** — the owning note's UUID plus an optional stable `childKey` — never a device-local autoincrement id. The exact stable key per source type is audited and finalized in the plan (each of Automobile/Insurance is checked for whether its id is a server-canonical stable value or must be addressed via its owning note UUID). A **fresh-device resolve test** (below) is mandatory.

## Reference resolution

`CheatsheetResolver.resolve(row)` -> current display value:
1. `entityField` -> resolve the entity via `(entityType, noteUuid, childKey)`, read `fieldKey`.
2. `noteText` -> load note `noteUuid`, return full content as plain text.
3. Recomputed every card open.

**Edge cases (never crash):** unbound row -> "-"; source note/entity missing or reference unresolvable -> muted "source removed"; absent field -> "-"; a sensitive/encrypted `noteText` source -> the Phase 4b locked placeholder.

## Storage (defect 2/5a resolved)

- Every cheatsheet is an `HmmNote` under **one fixed note catalog `Hmm.Cheatsheet`** (never changed per-edit — the note-catalog is immutable after creation, so it is not used to carry the mutable wallet group).
- **Wallet group and tags are authoritative in the card JSON content**, the single source of truth. Changing the wallet group is a JSON edit — no note-catalog move, no dependence on `HmmNoteUpdate` exposing a catalog id.
- Flows through existing note storage + sync as note content — **no schema change**. A new backend Cheatsheet domain module (manager/validator/serializer + `/v1/cheatsheets`, mirroring the Automobile module) owns CRUD + shape-validation of the definition.
- **Quick-access props** (`quickAccess`, `sortOrder`) live in the JSON too; a `quickAccess` card is surfaced in the existing Quick Access Panel (feature #23).

## Bindable sources (v1) — corrected to the real domain model (defect 3)

- **Contact** *(from the prerequisite Contacts feature)* — name, phone(s), email, address, relationship, `isSelf`.
- **AutomobileInfo** — the fields the entity actually exposes (plate, VIN, make/model/year, …); enumerated in the plan.
- **AutoInsurancePolicy** — **real fields only:** `provider`, `policyNumber`, `coverage` (`List<CoverageItem>`), `effectiveDate`, `expiryDate`, `premium`, `deductible`. **There is no `providerPhone` and no `coverageSummary`** (the earlier spec invented these). A provider phone would come from a linked **Contact** for the insurer, not the policy.
- **General HmmNote** — whole-content plain text (`fieldKey = '*'`).

## Starter templates (v1)

- **Accident Claim** — vehicle rows bind now (Automobile -> plate, VIN; Insurance -> provider, policyNumber); the driver's person rows (name / phone / address) and an insurer-contact phone are **unbound until Contacts exists**.
- **Health Info** — entirely person-based -> **ships with the Contacts feature**; before that it exists as an all-unbound template.
- **Blank** — no rows.

Templates instantiate pre-labeled rows with `source: null`; the designer prompts binding.

## The designer (template-first)

Create -> pick a template -> bind each row via `source_picker` (entity type -> instance -> field, or general note -> whole-text) -> relabel, add/remove/reorder, set wallet group + tags, optionally set a per-row value action -> save (partial binding allowed).

## Browse & render (wallet)

Wallet screen: stacks grouped by `walletGroup`, tag filter/search; tap a card -> read-only detail with live label->value rows, actionable values (call / map) + open-source; editing routes back to the designer. Entry point decided in the plan.

## Sync & data-mode

Syncs as a normal note. References use cross-device-stable ids; a card resolves against the active data mode's dataset — unresolvable references degrade to "source removed" (documented, not an error).

## Testing

- **Serializer:** card <-> HmmNote JSON round-trips, **including an unbound row** (`source: null`); unknown/absent fields tolerated.
- **Resolver:** entityField hit, missing entity, missing field, unbound row, noteText whole-text; value-action inference.
- **Cross-device (defect 4, mandatory):** author a card, sync it to a **fresh database/device**, assert every reference resolves to the intended record (and does not resolve an unintended one).
- **Storage (defect 2):** changing the wallet group mutates JSON only and never touches the note catalog.
- **Designer / wallet (widget):** template -> unbound rows; binding sets the reference; partial save; grouping/filter; tap-to-call / tap-to-map with the resolved value; open-source affordance present on every row.

## Card types & roadmap

- **v1 — Field cards** (this spec).
- **Phase 2 — Image / ID cards + sensitive protection:** stored images (driver's-licence front+back, health card) + optional fields, composed with **Phase 4b** (images through the encrypted, biometric-gated vault) and the `protected`-flag gating.
- **Later —** flashcards; computed/derived rows; sharing/export; richer layouts.

## Sensitive protection (flag reserved in v1, gated in Phase 2)

`CheatsheetCard.protected` (default false) marks a card as needing the Phase 4b unlock before its contents show. **Image/ID cards (Phase 2):** *real* protection — images stored as encrypted sensitive attachments. **Field cards:** only a **view-gate** — display hidden until unlock, but the values live in plaintext source entities that remain independently viewable (access-friction, not encryption; the UI must not imply otherwise).

## Explicitly a separate feature (not a cheatsheet)

A **daily activity summary** (Apple Health/Fitness style) is a computed dashboard — it aggregates metrics/trends rather than linking to one existing field, and real fitness/health metrics need HealthKit / Google Fit. Tracked as its own future feature, outside the cheatsheet line.

## Appendix — 2026-07-24 defect review resolutions

| Defect | Resolution |
|--------|-----------|
| 1 Unbound template rows | `CheatsheetRow.source` nullable; partial save allowed; unbound -> "-". |
| 2 Wallet group vs immutable catalog | Fixed `Hmm.Cheatsheet` catalog; wallet group + tags authoritative in JSON. |
| 3 Missing fields/entities | Contacts built first as a separate feature; insurance fields corrected to `provider`/`policyNumber`/`coverage`; no `providerPhone`/`coverageSummary`. |
| 4 Unstable cross-device ids | Reference = stable note UUID + optional child key, never device-local int; mandatory fresh-device resolve test. |
| 5 Metadata/action ambiguity | Wallet group + tags authoritative in JSON (5a); `ValueAction` (call/map/none) separate from the universal `openSource` flag (5b). |
