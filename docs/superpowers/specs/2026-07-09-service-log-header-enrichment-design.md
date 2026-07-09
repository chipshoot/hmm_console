# Service-Log Header Enrichment — Design

**Date:** 2026-07-09
**Status:** Approved (pending implementation plan)
**Repos:** `hmm_console` (client) + `hmm` (backend) — additive, then one breaking-but-migrated change.

## Problem

Real service reports (e.g. the sample Subaru service order `SO# 952333`) have a
**header** the current `ServiceRecord` can't represent:
- a human **name** for the service ("Service 'A' H4 2012+") — nowhere to store
  it; today it collapses into the coarse `type` enum or free-text description;
- the shop's **reference / invoice number** (`SO# 952333`) — no field;
- rich **garage / advisor / inspection** detail — only a plain `notes` string;
- a visit is usually a **package** doing several categories at once (oil +
  inspection + tire check), but `type` is a single `ServiceType`.

The line-item body (`parts` with `LineItemType {labour, part, fee}`) already
matches the report and is **not** changed. The gap is entirely the header.

## Goal & principle

Enrich the header without new domain entities: add a **name** and a **reference
number**, treat **notes as markdown**, and evolve the single category `type`
into **multi-select tags**. Reuse existing systems for everything else — vehicle
specs live on the **Automobile** entity, next-service-due on the
**ScheduledService** feature, and the source invoice as an **attachment**.

## Scope

Two phases in one design:

**Phase 1 — additive, non-breaking (ships first, usable immediately)**
- `name` (`String?`) on `ServiceRecord`.
- `referenceNumber` (`String?`) on `ServiceRecord`.
- Render `notes` as **markdown** (no schema change to `notes`).

**Phase 2 — breaking-but-migrated**
- Replace single `type: ServiceType` with `types: List<ServiceType>`
  (multi-select, ≥1), migrated from the old single value.

**Out of scope (reuse / defer)**
- No new domain entity (no Garage/Shop entity, no Inspection entity).
- Vehicle specs (VIN, plate, colour, engine) — already on `Automobile`.
- Next-service-due — already the `ScheduledService` feature.
- Odometer in/out (keep single `mileage`), labour-hours as a distinct field,
  and item-derived tag suggestions — not now.
- A dedicated read-only detail screen — see §Phase 1 markdown note.

## Phase 1 — additive header fields

### `name` and `referenceNumber`
Two optional strings threaded through every layer:

- **Client entity** `lib/features/automobile_records/domain/entities/service_record.dart`:
  add `final String? name;` and `final String? referenceNumber;` (+ `copyWith`).
- **Local Drift** `lib/core/data/local/local_service_record_repository.dart`:
  `_serialize` writes `name`/`referenceNumber` when non-null; `_deserialize`
  reads them (absent → null).
- **API models + mapper**
  `data/models/api_service_record*.dart` + `data/mappers/automobile_records_api_mapper.dart`:
  add the fields to `ApiServiceRecord`, `ApiServiceRecordForCreate/Update`
  (camelCase `name`, `referenceNumber`), and the to/from mappers.
- **Backend** `hmm`: add `Name` / `ReferenceNumber` to
  `Hmm.Automobile/DomainEntity/ServiceRecord.cs`;
  `ServiceRecordJsonNoteSerialize` reads/writes `name`/`referenceNumber`;
  `Hmm.ServiceApi.DtoEntity/.../ApiServiceRecord*.cs` gain the fields; the
  `AutomobileMappingProfile` maps them (AutoMapper convention by name).
- **UI** `presentation/screens/service_record_form_screen.dart`: a "Service
  name" text field (top of the form) and a "Reference # (optional)" field.
  `presentation/screens/service_records_screen.dart`: the list tile headline
  uses `name` when present, else `type.displayName` (existing records read
  well). Save builds `name`/`referenceNumber` into the `ServiceRecord`.

### `notes` as markdown
No schema change. Where the record's `notes` is shown **read-only**, render it
with `flutter_markdown`; the form's notes field gets a "supports markdown" hint.
Today the app has no read-only service-record detail screen (tapping a record
opens the edit form), so Phase 1 renders a **read-only markdown preview beneath
the editable notes field** in the form (collapsed when notes is empty). A
dedicated detail screen is a natural later follow-up that would reuse the same
rendering; it is out of scope here.

## Phase 2 — multi-category tags

Replace `type: ServiceType` with `types: List<ServiceType>` (min 1).

- **Client entity:** `final List<ServiceType> types;` (drop single `type`;
  provide `ServiceType get primaryType => types.first` for any code that needs
  one). `copyWith` updated.
- **Migration / back-compat (read):** local `_deserialize` and backend
  `ServiceRecordJsonNoteSerialize` read `types` (array of enum names) when
  present; else fall back to the legacy single `type` key as `[type]`; else
  `[ServiceType.other]`. **Write** emits `types` (array). The legacy `type` key
  is not written going forward.
- **API:** `ApiServiceRecord*` carry `types` (`List<String>`); mapper converts
  enum ↔ string list. Backend DTO + AutoMapper updated; C# reads legacy `Type`
  when `Types` absent.
- **Consumers:** every `.type` reader (the list tile category chip, any
  filter/stat by service type, mappers) moves to `types` with
  "matches if any tag equals X" semantics. The name-empty headline fallback
  (§Phase 1, `type.displayName`) becomes `primaryType.displayName`
  (= `types.first`).
- **Form UI:** the single-select dropdown becomes a multi-select chip/checkbox
  control seeded from the migrated list.

## Error handling & compatibility

Additive-or-migrated throughout, nothing throws:
- missing `name`/`referenceNumber` → null; UI falls back to `type.displayName`.
- missing `types` → `[legacy type]`, or `[other]` if neither present.
- Older app versions ignore unknown keys; new versions read legacy keys — so
  mixed-version and existing records keep working across `local`,
  `cloudStorage`, and `cloudApi`.
- No new entity; no duplication of vehicle / next-due data.

## Testing

**Phase 1**
- Local Drift round-trip of `name`/`referenceNumber` (set → serialize →
  deserialize); absent → null.
- API mapper round-trip (`serviceToCreate`/`serviceFromApi`) of the two fields.
- Backend: `ServiceRecordJsonNoteSerialize` and the `ApiServiceRecord` DTO
  round-trip `name`/`referenceNumber`; camelCase on the wire.
- Widget: list tile headline uses `name`, falls back to `type.displayName`;
  the notes markdown preview renders (and hides when empty).

**Phase 2**
- Migration: content with legacy `type` and no `types` → `[type]`; neither →
  `[other]`; `types` present → used verbatim.
- Round-trip of `types` (client local + API, backend serializer + DTO).
- Consumer: "any tag matches" filter/stat; multi-select form seeds from and
  writes back the list.

## Rollout

- **Phase 1** first: additive on both repos; deploy backend, ship client.
  Existing records gain empty `name`/`referenceNumber` (headline falls back to
  type); no migration needed.
- **Phase 2** second: ships the read-legacy/write-`types` migration on both
  repos together (backend deploy + client build), so no record loses its
  category regardless of which side reads it first.
