# Cheatsheet Cards — Design Spec

**Date:** 2026-07-23
**Status:** Approved (brainstorming) — ready for planning
**Scope:** hmm_console (Flutter client). No backend schema change (rides existing note sync).

## Goal

A **cheatsheet** is a read-only card that surfaces the handful of facts you want at a glance — a health-info card, an accident-claim card — assembled from **live links** to information that already lives in other Hmm notes/entities. Cards are organized into wallet-style stacks, stay current when their sources change, and are synced across devices like any other note.

Two motivating examples:
- **Accident Claim card:** plate number, VIN, insurance provider name + phone, policy number, plus the driver's own name / phone / home address — everything an insurer asks for at the scene.
- **Health Info card:** family doctor name + phone, pharmacy name + phone, the person's own name / phone / address; extendable to a family member's details.

## Locked decisions (from brainstorming)

| Area | Decision |
|------|----------|
| Data source | **Live references** — each row points at a specific source field and is re-resolved every time the card opens, so it changes the moment the source changes. No copied/snapshot values. |
| Bindable sources | **Structured entity fields** (Contacts incl. self + family, Automobile, Insurance policy, and other typed entities) **+ general-note whole-text**. A row links to one field of one entity instance, or to a general note (renders that note's full content as plain text). |
| Person / self identity | **Contacts.** Your own details and each family member (wife, dad, …) are ordinary Contacts; a row binds to any contact's field. An optional `isSelf` convenience flag marks the default "me" contact. No new profile-with-address entity. |
| Authoring | **Template-first designer.** Start from a starter template with labeled slots, bind each slot, then add/remove/reorder rows. |
| Binding granularity | **One field per row** — you choose the exact field (e.g. `Contact → phone`, `Insurance → providerName`). |
| Interactions | **Actionable values** — tap a phone → call, an address → Maps, optional "open source note". Otherwise fully read-only. |
| Grouping | **Catalog = wallet stack** (user-facing group a card lives in); **tags = cross-cutting filter/search**. |
| Storage | **Synced, note-backed entity** — a cheatsheet is an `HmmNote` (subject-convention + JSON content), synced by the existing note pipeline. |
| v1 card type | **Field cards** (key→value rows). Flashcards / book key-points are a later phase. |

## Non-goals (v1)

- **No flashcards / study cards** (book key-points) — separate phase.
- **No computed/aggregated values** — rows are direct field links only, no math or joins across notes.
- **No sharing / export** of a cheatsheet.
- **No rich layout editor** — v1 ships 1–2 clean layouts, not a freeform canvas.
- **No cloudApi-tier special handling** beyond the general "sources must exist in the active dataset" rule (see Data-mode note).

---

## Architecture

A new client feature module `cheatsheet` following the existing note-backed domain pattern (mirrors `automobile` / `gas_log`):

```
lib/features/cheatsheet/
  domain/entities/        cheatsheet_card.dart, cheatsheet_row.dart, cheatsheet_source_ref.dart
  data/                   cheatsheet_note_serializer.dart (card <-> HmmNote JSON),
                          cheatsheet_repository.dart (CRUD over the note store),
                          cheatsheet_resolver.dart (live value lookup)
  states/                 cheatsheet_list_state.dart, cheatsheet_designer_state.dart (Riverpod)
  presentation/
    screens/              cheatsheet_wallet_screen.dart, cheatsheet_designer_screen.dart,
                          cheatsheet_detail_screen.dart
    widgets/              cheatsheet_card_view.dart, cheatsheet_row_view.dart, source_picker.dart
```

A cheatsheet's **definition** (rows + references) is authored data; its **displayed values** are resolved live from the sources. The two never merge on disk — only the definition is stored.

## Data model

```dart
class CheatsheetCard {
  final String id;            // stable card id (uuid)
  final String title;         // e.g. "Accident Claim"
  final String catalog;       // wallet stack, e.g. "Vehicle" / "Health"
  final List<String> tags;
  final String templateId;    // which starter template it came from ('accidentClaim', 'healthInfo', 'blank')
  final List<CheatsheetRow> rows;
}

class CheatsheetRow {
  final String label;         // display label, e.g. "Insurance phone"
  final CheatsheetSource source;
  final RowAction action;     // auto | call | map | openSource | none
}

class CheatsheetSource {
  final SourceKind kind;      // entityField | noteText
  final String entityType;    // 'contact' | 'automobile' | 'insurance' | ... ('' for noteText)
  final String sourceId;      // the source entity/note id
  final String fieldKey;      // e.g. 'phone', 'plateNumber' ; '*' for a noteText whole-content dump
}

enum SourceKind { entityField, noteText }
enum RowAction { auto, call, map, openSource, none }
```

**Storage:** serialized to JSON and saved as an `HmmNote` using the subject-convention pattern already used by the automobile module (e.g. subject `Cheatsheet:{id}`), so it flows through the existing note CRUD + sync with **no backend change**. Catalog + tags reuse the note's existing catalog/tag surfaces where practical.

## Live resolution

`CheatsheetResolver.resolve(row)` returns the current display value:
1. `entityField` → look up the entity of `entityType` by `sourceId` in the local DB, read `fieldKey`.
2. `noteText` → load note `sourceId`, return its full content as plain text.
3. Recomputed on every card open (and on the source's change stream where cheap), so edits to a source reflect immediately.

**Value → action inference (`action == auto`):** phone-shaped fields → `call`; address fields → `map`; everything else → `none`. Explicit `action` overrides. `openSource` (jump to the underlying note/entity) is offered on any row.

**Edge cases (never crash):**
- Source entity/note deleted, or `sourceId` no longer resolves → row shows a muted placeholder ("source removed").
- `fieldKey` absent/empty on the source → "—".
- A `noteText` source that is itself a sensitive/encrypted note → shows the locked placeholder, consistent with Phase 4b (out of v1 scope to unlock inline; renders the lock state).

## Bindable sources (v1)

- **Contact** — name, phone(s), email, address, role/relationship, plus `isSelf`. Covers self + family members.
- **Automobile (AutomobileInfo)** — plate number, VIN, make/model/year, etc.
- **Auto Insurance policy (AutoInsurancePolicy)** — provider name, provider phone, policy number, coverage summary.
- **General HmmNote** — whole-content plain-text (`fieldKey = '*'`).

(Additional entities — ServiceRecord, GasLog — are bindable later without model changes; the source picker lists whatever entity types are registered. Exact per-entity field lists are finalized in the plan.)

## Starter templates (v1)

- **Accident Claim** — rows: Plate (Automobile→plate), VIN (Automobile→vin), Insurer (Insurance→providerName), Insurer phone (Insurance→providerPhone), Policy # (Insurance→policyNumber), Driver name (Contact[self]→name), Driver phone (Contact[self]→phone), Home address (Contact[self]→address).
- **Health Info** — rows: Person (Contact→name), Family doctor (Contact→name), Doctor phone (Contact→phone), Pharmacy (Contact→name), Pharmacy phone (Contact→phone), Address (Contact→address).
- **Blank** — no rows; freeform add.

A template ships as a set of pre-labeled rows with **unbound** sources; the designer prompts the user to bind each.

## The designer (template-first)

1. **Create** → choose a template (Accident Claim / Health Info / Blank).
2. Card opens with labeled rows whose sources are empty.
3. **Bind a row** → `source_picker`: choose an entity type → choose the specific instance (e.g. which Contact) → choose the field; or choose "General note" → pick the note (whole-text). Relabel if desired.
4. **Add / remove / reorder** rows; set the **wallet group** (catalog) + **tags**; set per-row action override if needed.
5. **Save** → writes the cheatsheet note.

Editing an existing card reopens the same designer.

## Browse & render (wallet)

- **Cheatsheet wallet screen:** stacked cards grouped by catalog (the "wallet"), with a tag filter/search. Tapping a stack fans it; tapping a card opens its read-only detail.
- **Detail:** live label→value rows; actionable values (call / map / open source); no inline editing (edit routes to the designer).
- Reachable from the app's primary navigation / quick-access surface (exact entry point decided in the plan).

## Sync & data-mode

- Syncs as a normal note through the existing pipeline; no new sync code.
- References are by **stable entity id**. A card only resolves against the **active data mode's** dataset — its source entities must exist there. Cross-mode references that can't resolve degrade to the "source removed" placeholder (documented behavior, not an error).

## Testing

- **Serializer:** card ↔ HmmNote JSON round-trips; unknown/absent fields tolerated (forward-compat).
- **Resolver:** entityField hit, missing entity, missing field, noteText whole-text, deleted source → correct value/placeholder; action inference (phone→call, address→map).
- **Designer:** template instantiates labeled unbound rows; binding sets `(kind, entityType, sourceId, fieldKey)`; add/remove/reorder; save produces the expected note.
- **Wallet/detail (widget):** grouping by catalog, tag filter, live value render, tap-to-call / tap-to-map invoked with the resolved value, edit routes to designer.

## Future phases (out of v1)

- Flashcard / book key-points cheatsheets (the second card shape).
- Computed/derived rows (e.g. totals, "days until"), multi-source rows.
- Sharing / export (PDF, share sheet).
- Richer layouts and per-card theming.
