# Multi-line-item Service Records — Design

**Date:** 2026-06-26
**Status:** Approved (brainstorm) — pending implementation plan
**Repos touched:** `hmm_console` (Flutter client) **and** `hmm` (`Hmm.Automobile` + `Hmm.ServiceApi` backend).
**Reference:** `~/projects/hmm/docs/Automobile_service.pdf` — a real Subaru service order (SO #952333) bundling a service request, a labour line, and many part/fee lines, with parts/labour/supplies totals + HST + grand total.

## Goal

Let one service record capture a real service event's **multiple line items** (labour, parts, fees) with computed totals + tax — modeled on the structured `gas_log` feature. Today the service-record *data layer already supports* a `parts: List<PartItem>` (client + backend serialize and round-trip it), but the form UI exposes only a single description + cost, so a user cannot itemise a service. This adds the line-items editor and refines the item model to be typed with tax/totals.

## What already exists (no rework)

- `ServiceRecord` carries `parts: List<PartItem>` on both client (`domain/entities/service_record.dart`) and backend (`Hmm.Automobile/DomainEntity/ServiceRecord.cs`).
- It serializes to the note `content` JSON `parts` array — client `local_service_record_repository.dart` (`_serialize`/`_deserialize`), backend `NoteSerialize/ServiceRecordJsonNoteSerialize.cs`.
- API DTOs exist: `ApiServiceRecord`, `ApiPartItem`, `ApiServiceRecordForCreate/Update`; the client `AutomobileRecordsApiMapper` routes parts through.
- Stored under catalog `Hmm.AutomobileMan.ServiceRecord`, parented to the automobile note. Syncs via the same note-content path as everything else.

So the changes are **additive** (a `type` on each item, a `tax` on the record) plus the **form UI** and **display**.

## Decisions (locked during brainstorm)

1. **Typed line items.** Each item gains a `type` ∈ {labour, part, fee} (default part). Item = `{type, name, quantity, unitCost, currency}`, `lineTotal = unitCost × quantity`.
2. **Manual tax, computed totals.** A manual `tax` amount on the record. `subtotal = Σ lineTotal`; `grandTotal = subtotal + tax`. Plus `partsTotal`/`labourTotal`/`feesTotal` (sums per type).
3. **Legacy fallback.** The existing record-level `cost` stays only as a fallback: `effectiveTotal = items.isNotEmpty ? grandTotal : cost`. Existing records (no items) still show their flat cost. Old item payloads with no `type` decode as `part`; no `tax` decodes as 0.
4. **Out of scope:** the walk-around inspection checklist (PDF page 3), PDF import/parsing, and labour *hours×rate* (labour is a typed line item with a flat amount).

---

## Part A — Backend (`hmm`)

### Domain model (`Hmm.Automobile/DomainEntity/`)

- New `LineItemType.cs`: `enum LineItemType { Labour, Part, Fee }`.
- `PartItem.cs`: add `public LineItemType Type { get; set; } = LineItemType.Part;`. Keep `Name`, `Quantity`, `UnitCost`.
- `ServiceRecord.cs`: add `public Money Tax { get; set; }`. Add computed helpers (methods or get-only properties): `Subtotal` (Σ item line totals), `PartsTotal`/`LabourTotal`/`FeesTotal` (sums filtered by type), `GrandTotal` (`Subtotal + Tax`). Keep `Cost` as the legacy fallback (do not remove). `Description`/`Type`/`ShopName`/`Mileage`/`Date`/`Notes` unchanged.

### Serializer (`NoteSerialize/ServiceRecordJsonNoteSerialize.cs`)

- **Write:** each part object gains `["type"] = p.Type.ToString()`; the record object gains `["tax"] = entity.Tax`.
- **Read:** parse `type` per item (`Enum.TryParse<LineItemType>`, default `Part` when absent/unknown); parse record `tax` (default `Money.Zero`/0 when absent). Everything else unchanged — old payloads decode cleanly.

### DTOs (`Hmm.ServiceApi.DtoEntity/GasLogNotes/`)

- `ApiPartItem.cs`: add `public string Type { get; set; }` (wire as the enum name; default "Part").
- `ApiServiceRecord.cs`, `ApiServiceRecordForCreate.cs`, `ApiServiceRecordForUpdate.cs`: add a `Tax` field (`decimal?` + currency, matching how `Cost` is represented in those DTOs).
- AutoMapper profile (`AutomobileMappingProfile` if it maps these) / manager mapping: carry `Type` and `Tax` through. If items map by convention, confirm; else add explicit member maps.

### Validator (`Validator/ServiceRecordValidator.cs`)

- Reject a negative `UnitCost` on any item and a negative `Tax`. An item with an empty `Name` is invalid (mirror existing required-field validation). Tax defaulting to 0 is valid.

### Backend tests

- Serializer round-trips items with `Type` + record `Tax`; an old payload (no `type`/`tax`) decodes with defaults (`Part`, 0).
- `ServiceRecord` total helpers: `Subtotal`/`PartsTotal`/`LabourTotal`/`GrandTotal` compute correctly for a mixed item list.
- Manager create/update persists typed items + tax; validator rejects negative unit cost / tax.

---

## Part B — Client (`hmm_console`)

### Domain model (`lib/features/automobile_records/domain/entities/`)

- New `line_item_type.dart`: `enum LineItemType { labour, part, fee }` with a `wireName`/`fromWire` (PascalCase to match the backend enum names: Labour/Part/Fee) and a display label.
- `part_item.dart`: add `final LineItemType type;` (default `LineItemType.part`). Keep `name`/`quantity`/`unitCost`/`currency`; keep `lineTotal`. Add `copyWith`.
- `service_record.dart`: add `final double? tax;`. Add computed getters: `double get subtotal` (Σ `lineTotal`), `double get partsTotal`/`labourTotal`/`feesTotal` (filtered sums), `double get grandTotal => subtotal + (tax ?? 0)`, and `double get effectiveTotal => parts.isNotEmpty ? grandTotal : (cost ?? 0)`. Add/extend `copyWith` for `parts` + `tax`.

### Persistence (`lib/core/data/local/local_service_record_repository.dart`)

- `_serialize`: write `type` per part (`p.type.wireName`) and `tax` on the record (as a `{amount, currency}` money object like `cost`, or a bare number — match the existing `cost` shape).
- `_deserialize`: read item `type` (default `part`); read record `tax` (default null/0). Old notes decode cleanly.

### API model + mapper

- `data/models/api_part_item.dart`: add `type` (string). `data/models/api_service_record*.dart`: add `tax`.
- `data/mappers/automobile_records_api_mapper.dart`: map `type` on items both directions; map `tax` on the record both directions.

### Form UI (`presentation/screens/service_record_form_screen.dart`)

The core deliverable. Keep the existing header fields (date, mileage, service type, shop name, notes). Replace the single record-level "cost" input with a **line-items editor + totals**:

- New widget `presentation/widgets/service_line_items_editor.dart` — owns `List<PartItem>` (seeded from `_existing?.parts`) and the `tax` value; renders the rows, an **"+ Add item"** button (appends a blank `Part`, qty 1), and the totals summary. Calls back on every change so the screen holds the current items + tax for save.
- New widget `presentation/widgets/service_line_item_row.dart` — one row: a **type** dropdown/segmented control (Labour/Part/Fee), **name** field, **qty** field, **unit cost** field, a read-only **line total**, and a ✕ remove button. Emits the updated `PartItem` on change.
- **Totals summary** (in the editor): live `Parts`, `Labour`, `Fees`, `Subtotal`, an editable **Tax** field, and a bold **Grand total` = subtotal + tax`. All recompute on any row/tax change.
- `_save`: drop empty trailing rows (no name), build the `ServiceRecord` with `parts: _items, tax: _tax`, and pass it through the existing `MutateServiceRecordState.create/edit` → repo path (already persists `parts`). Validation: each kept row needs a non-empty name and a non-negative unit cost; tax ≥ 0.

### List + detail display

- `presentation/screens/service_records_screen.dart` tile: show `effectiveTotal` as the amount and an item-count badge (e.g. "6 items") when `parts.isNotEmpty`.
- **Itemised breakdown:** show the per-type grouped lines (Labour / Parts / Fees, each `qty × unit = total`) + the totals block (subtotal · tax · grand) in the record's view. If a dedicated service-record detail/renderer exists, extend it; otherwise render the breakdown as a read-only section in the form when opened on an existing record.

### Client tests

- Model: `lineTotal`; `subtotal`/`partsTotal`/`labourTotal`/`grandTotal`; `effectiveTotal` fallback (items present → grandTotal; empty → cost).
- Serialization round-trip via the local repo: typed items + tax survive create→read; a legacy note (no `type`/`tax`) decodes with defaults.
- Mapper/DTO round-trip: `type` + `tax` both directions.
- Widget: the editor adds/edits/removes rows and totals recompute; changing an item's type moves its amount between Parts/Labour/Fees totals; editing tax updates the grand total; `_save` passes the items + tax to a fake `MutateServiceRecordState`.
- List tile renders `effectiveTotal` + item count.

## Sequencing

Backend first (model + serializer + DTOs + validator), then client. The client `local`/`cloudStorage` work ships independently; `cloudApi` lights up once the backend fields land. All changes are additive with defaults, so old data and old clients interoperate.

## Out of scope

- Walk-around inspection checklist (PDF page 3) — a separate feature.
- PDF/receipt import or OCR.
- Labour hours × rate (labour captured as a flat-amount line item).
- A dedicated Drift table for service records (they remain note-content JSON, unchanged).
