# Multi-line-item Service Records Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let one service record capture multiple typed line items (labour / part / fee) with computed totals + a manual tax, editable through a line-items form modeled on gas_log — turning the single-cost service record into a real itemized service order.

**Architecture:** The `parts: List<PartItem>` already exists and round-trips on both repos; this is additive. Each item gains a `type`; the record gains a `tax`. Totals are computed (`subtotal = Σ lineTotal`, `grandTotal = subtotal + tax`); the old flat `cost` stays as a legacy fallback (`effectiveTotal = items.isNotEmpty ? grandTotal : cost`). The form gets a line-items editor + live totals. Stored as note-content JSON (no schema/migration change); old payloads decode with defaults (type→part, tax→0).

**Tech Stack:** Backend — .NET 10, `Hmm.Automobile` (System.Text.Json note serializer, FluentValidation), AutoMapper, xUnit. Client — Flutter, Drift (note-JSON), Riverpod.

**Two repos:**
- Backend: `/Users/fchy/projects/hmm`, branch off `main` (e.g. `feat/service-line-items`)
- Client: `/Users/fchy/projects/hmm_console`, branch off `main` (e.g. `feat/service-line-items`)

---

## File Structure

### Backend (`/Users/fchy/projects/hmm`)
- Create: `src/Hmm.Automobile/DomainEntity/LineItemType.cs`
- Modify: `src/Hmm.Automobile/DomainEntity/PartItem.cs` (Type), `ServiceRecord.cs` (Tax + total helpers)
- Modify: `src/Hmm.Automobile/NoteSerialize/ServiceRecordJsonNoteSerialize.cs` (type + tax)
- Modify: `src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiPartItem.cs` (Type), `ApiServiceRecord.cs` / `ApiServiceRecordForCreate.cs` / `ApiServiceRecordForUpdate.cs` (Tax)
- Modify: `src/Hmm.Automobile/Validator/ServiceRecordValidator.cs`
- Test: `src/Hmm.Automobile.Tests/` (serializer + total helpers)

### Client (`/Users/fchy/projects/hmm_console`)
- Create: `lib/features/automobile_records/domain/entities/line_item_type.dart`
- Modify: `domain/entities/part_item.dart` (type), `domain/entities/service_record.dart` (tax + getters)
- Modify: `lib/core/data/local/local_service_record_repository.dart` (serialize/deserialize)
- Modify: `data/models/api_part_item.dart` (type), `data/models/api_service_record*.dart` (tax), `data/mappers/automobile_records_api_mapper.dart`
- Create: `presentation/widgets/service_line_item_row.dart`, `presentation/widgets/service_line_items_editor.dart`
- Modify: `presentation/screens/service_record_form_screen.dart`, `presentation/screens/service_records_screen.dart`

---

# PART A — Backend (`/Users/fchy/projects/hmm`)

## Task A1: `LineItemType` enum + `PartItem.Type` + `ServiceRecord.Tax` + total helpers

**Files:**
- Create: `src/Hmm.Automobile/DomainEntity/LineItemType.cs`
- Modify: `src/Hmm.Automobile/DomainEntity/PartItem.cs`, `src/Hmm.Automobile/DomainEntity/ServiceRecord.cs`
- Test: `src/Hmm.Automobile.Tests/ServiceRecordTotalsTests.cs` (new)

- [ ] **Step 1: Write the failing test** — create `src/Hmm.Automobile.Tests/ServiceRecordTotalsTests.cs`:

```csharp
using Hmm.Automobile.DomainEntity;
using Hmm.Utility.Currency;
using System.Collections.Generic;
using Xunit;

namespace Hmm.Automobile.Tests
{
    public class ServiceRecordTotalsTests
    {
        private static Money Cad(decimal a) => new() { Amount = a, CurrencyCode = "CAD" };

        [Fact]
        public void Totals_split_by_type_and_add_tax()
        {
            var r = new ServiceRecord
            {
                Tax = Cad(28.90m),
                Parts = new List<PartItem>
                {
                    new() { Type = LineItemType.Labour, Name = "Service A", Quantity = 1, UnitCost = Cad(61.50m) },
                    new() { Type = LineItemType.Part, Name = "Oil", Quantity = 2, UnitCost = Cad(17.95m) },
                    new() { Type = LineItemType.Fee, Name = "Env fee", Quantity = 1, UnitCost = Cad(1.54m) },
                },
            };

            Assert.Equal(61.50m, r.LabourTotal);
            Assert.Equal(35.90m, r.PartsTotal);   // 2 × 17.95
            Assert.Equal(1.54m, r.FeesTotal);
            Assert.Equal(98.94m, r.Subtotal);     // 61.50 + 35.90 + 1.54
            Assert.Equal(127.84m, r.GrandTotal);  // 98.94 + 28.90
        }

        [Fact]
        public void New_PartItem_defaults_to_Part_type()
        {
            Assert.Equal(LineItemType.Part, new PartItem().Type);
        }
    }
}
```

NOTE: match `Money`'s real property names — if it's `Amount`/`CurrencyCode` differs, copy the construction from an existing `Hmm.Automobile.Tests` test that builds a `Money`. Adjust the literal property names only; keep the assertions.

- [ ] **Step 2: Run it to verify it fails** — Run: `dotnet test src/Hmm.Automobile.Tests/Hmm.Automobile.Tests.csproj --filter "FullyQualifiedName~ServiceRecordTotals"`
Expected: FAIL — `LineItemType` / `PartItem.Type` / total properties don't exist.

- [ ] **Step 3: Create the enum** — `src/Hmm.Automobile/DomainEntity/LineItemType.cs`:

```csharp
namespace Hmm.Automobile.DomainEntity
{
    /// <summary>Category of a service-record line item.</summary>
    public enum LineItemType
    {
        Labour,
        Part,
        Fee
    }
}
```

- [ ] **Step 4: Add `Type` to PartItem** — in `src/Hmm.Automobile/DomainEntity/PartItem.cs`, add inside the class:

```csharp
        public LineItemType Type { get; set; } = LineItemType.Part;
```

- [ ] **Step 5: Add `Tax` + total helpers to ServiceRecord** — in `src/Hmm.Automobile/DomainEntity/ServiceRecord.cs`, add a `using System.Linq;`, then inside the class:

```csharp
        public Money Tax { get; set; }

        private decimal TotalFor(LineItemType t) => Parts
            .Where(p => p.Type == t)
            .Sum(p => (p.UnitCost?.Amount ?? 0m) * p.Quantity);

        public decimal LabourTotal => TotalFor(LineItemType.Labour);
        public decimal PartsTotal => TotalFor(LineItemType.Part);
        public decimal FeesTotal => TotalFor(LineItemType.Fee);
        public decimal Subtotal => LabourTotal + PartsTotal + FeesTotal;
        public decimal GrandTotal => Subtotal + (Tax?.Amount ?? 0m);
```

NOTE: `Money`'s amount accessor here is assumed `Amount` — use the real property name (whatever `Cost.Amount` would be); confirm from `Hmm.Utility.Currency.Money`.

- [ ] **Step 6: Run it to verify it passes** — Run: `dotnet test src/Hmm.Automobile.Tests/Hmm.Automobile.Tests.csproj --filter "FullyQualifiedName~ServiceRecordTotals"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Automobile/DomainEntity/LineItemType.cs src/Hmm.Automobile/DomainEntity/PartItem.cs src/Hmm.Automobile/DomainEntity/ServiceRecord.cs src/Hmm.Automobile.Tests/ServiceRecordTotalsTests.cs
git commit -m "feat(service): typed line items (LineItemType) + tax + total helpers"
```

## Task A2: Serializer writes/reads `type` + `tax`

**Files:**
- Modify: `src/Hmm.Automobile/NoteSerialize/ServiceRecordJsonNoteSerialize.cs`
- Test: `src/Hmm.Automobile.Tests/` — extend the existing serializer test (find it via `grep -rl "ServiceRecordJsonNoteSerialize" src/Hmm.Automobile.Tests`), or add `ServiceRecordSerializeTypeTaxTests.cs`.

- [ ] **Step 1: Write the failing test** — add a round-trip test (mirror the existing serializer test's setup for building the serializer + a `ServiceRecord`):

```csharp
        [Fact]
        public void Type_and_tax_round_trip_and_legacy_defaults_apply()
        {
            var entity = new ServiceRecord
            {
                AutomobileId = 1,
                Date = System.DateTime.UtcNow,
                Mileage = 100,
                Type = ServiceType.OilChange,
                Tax = new Money { Amount = 5m, CurrencyCode = "CAD" },
                Parts = new System.Collections.Generic.List<PartItem>
                {
                    new() { Type = LineItemType.Labour, Name = "L", Quantity = 1,
                            UnitCost = new Money { Amount = 10m, CurrencyCode = "CAD" } },
                },
            };

            var json = _serializer.GetNoteSerializationText(entity);
            var note = new HmmNote { Content = json }; // build the note the existing test uses
            var back = _serializer.GetEntity(note);    // use the real deserialize entry point

            Assert.Equal(LineItemType.Labour, back.Parts[0].Type);
            Assert.Equal(5m, back.Tax.Amount);
        }
```

NOTE: use the exact serializer construction + deserialize method name from the existing serializer test (`GetEntity` / `ParseNote` — match what's already used). If `Money.Amount`/`CurrencyCode` names differ, fix the literals.

- [ ] **Step 2: Run it to verify it fails** — Run: `dotnet test src/Hmm.Automobile.Tests/Hmm.Automobile.Tests.csproj --filter "FullyQualifiedName~Type_and_tax_round_trip"`
Expected: FAIL — `type` not serialized; `Tax` lost.

- [ ] **Step 3: Write `type` + `tax`** — in `GetNoteSerializationText`, in the per-part anonymous object, add `type`:

```csharp
                        partsList.Add(new
                        {
                            type = p.Type.ToString(),
                            name = p.Name ?? string.Empty,
                            quantity = p.Quantity,
                            unitCost = p.UnitCost
                        });
```

and in `recordData`, after `["cost"] = entity.Cost,` add:

```csharp
                    ["tax"] = entity.Tax,
```

- [ ] **Step 4: Read `type` + `tax`** — in the deserialize method (where parts are parsed, the `part.TryGetProperty("unitCost"...)` block), parse `type` per item and set it on the new `PartItem`:

```csharp
                        LineItemType itemType = LineItemType.Part;
                        if (part.TryGetProperty("type", out var typeEl))
                            System.Enum.TryParse(typeEl.GetString(), true, out itemType);
                        parts.Add(new PartItem
                        {
                            Type = itemType,
                            // ... existing Name / Quantity / UnitCost ...
                        });
```

and where the record is built (after `Cost = cost,`), parse `tax` the same way `cost` is parsed (it's a `Money`): add a `tax` Money parsed from `recordJson.TryGetProperty("tax", ...)` defaulting to null, and set `Tax = tax,` on the constructed `ServiceRecord`. Mirror the exact `cost` parsing lines for `tax`.

- [ ] **Step 5: Run it to verify it passes** — Run: `dotnet test src/Hmm.Automobile.Tests/Hmm.Automobile.Tests.csproj --filter "FullyQualifiedName~ServiceRecord"`
Expected: PASS (new + existing serializer tests; an old payload with no `type`/`tax` still decodes — defaults Part/null).

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Automobile/NoteSerialize/ServiceRecordJsonNoteSerialize.cs src/Hmm.Automobile.Tests/
git commit -m "feat(service): serialize line-item type + record tax (legacy-safe)"
```

## Task A3: DTOs + validator

**Files:**
- Modify: `src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiPartItem.cs`, `ApiServiceRecord.cs`, `ApiServiceRecordForCreate.cs`, `ApiServiceRecordForUpdate.cs`
- Modify: `src/Hmm.Automobile/Validator/ServiceRecordValidator.cs`

- [ ] **Step 1: DTOs** — in `ApiPartItem.cs` add `public string Type { get; set; } = "Part";`. In `ApiServiceRecord.cs`, `ApiServiceRecordForCreate.cs`, `ApiServiceRecordForUpdate.cs` add `public decimal? Tax { get; set; }` (the records already carry `Currency` for the money pair, mirroring `Cost`).

- [ ] **Step 2: Mapping** — find where these DTOs map to/from the domain `ServiceRecord`/`PartItem` (`grep -rn "ApiPartItem\|ApiServiceRecord" src/Hmm.ServiceApi.DtoEntity/Profiles src/Hmm.ServiceApi`). `Type` (string) ↔ `PartItem.Type` (enum) and `Tax` (decimal) ↔ `ServiceRecord.Tax` (Money) need member maps if not by convention — add `.ForMember` entries mirroring how `Cost`↔`decimal? Cost` + `Currency` is already mapped. If the manager/controller maps manually, extend that.

- [ ] **Step 3: Validator** — in `ServiceRecordValidator.cs`, inside the `RuleForEach(r => r.Parts)` block add:

```csharp
                    item.RuleFor(p => p.UnitCost)
                        .Must(c => c == null || HasValidMoney(c))
                        .WithMessage("Unit cost must be a non-negative money amount");
```

and add a record-level rule near the `Cost` rule:

```csharp
            RuleFor(r => r.Tax).Must(c => c == null || HasValidMoney(c))
                .WithMessage("Tax must be a non-negative money amount");
```

- [ ] **Step 4: Build + backend test suites** — Run: `dotnet build Hmm.sln` then `dotnet test src/Hmm.Automobile.Tests/Hmm.Automobile.Tests.csproj` and `dotnet test src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj`
Expected: Build succeeded; tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ src/Hmm.Automobile/Validator/ServiceRecordValidator.cs src/Hmm.ServiceApi.DtoEntity/Profiles/ 2>/dev/null; git add -A
git commit -m "feat(service): line-item Type + record Tax on DTOs + validation"
```

---

# PART B — Client (`/Users/fchy/projects/hmm_console`)

## Task B1: `LineItemType` enum (client)

**Files:**
- Create: `lib/features/automobile_records/domain/entities/line_item_type.dart`
- Test: `test/features/automobile_records/line_item_type_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/automobile_records/line_item_type_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';

void main() {
  test('wire round-trip + default', () {
    expect(LineItemType.labour.wireName, 'Labour');
    expect(LineItemType.fromWire('Fee'), LineItemType.fee);
    expect(LineItemType.fromWire(null), LineItemType.part);
    expect(LineItemType.fromWire('nonsense'), LineItemType.part);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/automobile_records/line_item_type_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement** — create `lib/features/automobile_records/domain/entities/line_item_type.dart`:

```dart
/// Category of a service-record line item. Mirrors the backend
/// `LineItemType` enum (PascalCase wire names).
enum LineItemType {
  labour,
  part,
  fee;

  String get wireName => switch (this) {
        LineItemType.labour => 'Labour',
        LineItemType.part => 'Part',
        LineItemType.fee => 'Fee',
      };

  String get displayName => switch (this) {
        LineItemType.labour => 'Labour',
        LineItemType.part => 'Part',
        LineItemType.fee => 'Fee',
      };

  static LineItemType fromWire(String? value) => switch (value) {
        'Labour' => LineItemType.labour,
        'Fee' => LineItemType.fee,
        _ => LineItemType.part,
      };
}
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/automobile_records/line_item_type_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/automobile_records/domain/entities/line_item_type.dart test/features/automobile_records/line_item_type_test.dart
git commit -m "feat(service): client LineItemType enum"
```

## Task B2: `PartItem.type` + `ServiceRecord` tax + computed totals

**Files:**
- Modify: `lib/features/automobile_records/domain/entities/part_item.dart`, `service_record.dart`
- Test: `test/features/automobile_records/service_record_totals_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/automobile_records/service_record_totals_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

ServiceRecord _rec(List<PartItem> parts, {double? tax, double? cost}) =>
    ServiceRecord(
      id: 1, automobileId: 1, date: DateTime(2026), mileage: 1,
      type: ServiceType.oilChange, parts: parts, tax: tax, cost: cost);

void main() {
  test('totals split by type + grand total adds tax', () {
    final r = _rec([
      const PartItem(type: LineItemType.labour, name: 'L', quantity: 1, unitCost: 61.50),
      const PartItem(type: LineItemType.part, name: 'Oil', quantity: 2, unitCost: 17.95),
      const PartItem(type: LineItemType.fee, name: 'Env', quantity: 1, unitCost: 1.54),
    ], tax: 28.90);
    expect(r.labourTotal, 61.50);
    expect(r.partsTotal, 35.90);
    expect(r.feesTotal, 1.54);
    expect(r.subtotal, closeTo(98.94, 1e-9));
    expect(r.grandTotal, closeTo(127.84, 1e-9));
    expect(r.effectiveTotal, closeTo(127.84, 1e-9));
  });

  test('effectiveTotal falls back to flat cost when no items', () {
    final r = _rec(const [], cost: 85.0);
    expect(r.effectiveTotal, 85.0);
  });

  test('PartItem defaults to part type', () {
    expect(const PartItem(name: 'x').type, LineItemType.part);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/automobile_records/service_record_totals_test.dart`
Expected: FAIL — `type`/`tax`/getters don't exist.

- [ ] **Step 3: Add `type` to PartItem** — in `part_item.dart`, add the import `import 'line_item_type.dart';`, add `this.type = LineItemType.part,` to the constructor, the field `final LineItemType type;`, and `type` to `copyWith` (param `LineItemType? type` and `type: type ?? this.type`).

- [ ] **Step 4: Add `tax` + getters to ServiceRecord** — in `service_record.dart`, add `import 'line_item_type.dart';`, add `this.tax,` to the constructor, the field `final double? tax;`, and the getters:

```dart
  double _totalFor(LineItemType t) => parts
      .where((p) => p.type == t)
      .fold(0.0, (s, p) => s + p.lineTotal);

  double get labourTotal => _totalFor(LineItemType.labour);
  double get partsTotal => _totalFor(LineItemType.part);
  double get feesTotal => _totalFor(LineItemType.fee);
  double get subtotal => labourTotal + partsTotal + feesTotal;
  double get grandTotal => subtotal + (tax ?? 0);
  double get effectiveTotal => parts.isNotEmpty ? grandTotal : (cost ?? 0);
```

- [ ] **Step 5: Run it to verify it passes** — Run: `flutter test test/features/automobile_records/service_record_totals_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/automobile_records/domain/entities/part_item.dart lib/features/automobile_records/domain/entities/service_record.dart test/features/automobile_records/service_record_totals_test.dart
git commit -m "feat(service): PartItem.type + ServiceRecord tax/totals/effectiveTotal"
```

## Task B3: Local repo serialize/deserialize `type` + `tax`

**Files:**
- Modify: `lib/core/data/local/local_service_record_repository.dart`
- Test: `test/core/data/local/local_service_record_line_items_test.dart` (new) — model on `test/core/data/local/local_hmm_note_repository_*` patterns (in-memory Drift). If a service-record repo test already exists, extend it.

- [ ] **Step 1: Write the failing test** — create `test/core/data/local/local_service_record_line_items_test.dart`. Seed an automobile parent note, create a `ServiceRecord` with typed items + tax, read it back, assert type + tax survive; and assert a hand-written legacy JSON (no `type`/`tax`) decodes with defaults. (Mirror the existing local-repo test harness: in-memory `HmmDatabase`, author + catalog setup. Use `LocalServiceRecordRepository`.)

```dart
    final created = await repo.createRecord(autoId, ServiceRecord(
      id: 0, automobileId: autoId, date: DateTime(2026), mileage: 100,
      type: ServiceType.oilChange, tax: 5.0,
      parts: const [PartItem(type: LineItemType.labour, name: 'L', quantity: 1, unitCost: 10.0)],
    ));
    final back = await repo.getRecordById(autoId, created.id);
    expect(back.parts.single.type, LineItemType.labour);
    expect(back.tax, 5.0);
```

NOTE: copy the exact author/catalog/parent-note seeding from an existing `test/core/data/local/local_*_repository*` test so the harness compiles. If unsure how `createRecord` resolves the parent automobile, replicate the setup another service/gas-log local test uses.

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/local/local_service_record_line_items_test.dart`
Expected: FAIL — type/tax not persisted.

- [ ] **Step 3: Serialize** — in `local_service_record_repository.dart` `_serialize`, add `'type': p.type.wireName,` to each part map, and after the `cost` line add:

```dart
      if (r.tax != null) 'tax': {'amount': r.tax, 'currency': r.currency},
```

- [ ] **Step 4: Deserialize** — in `_deserialize`, parse item `type` and record `tax`:

```dart
        // record tax (mirror cost parsing)
        final tax = body['tax'] as Map<String, dynamic>?;
        // ... inside the parts map():
        //   type: LineItemType.fromWire(m['type'] as String?),
```

Add `type: LineItemType.fromWire(m['type'] as String?),` to the `PartItem(...)` construction, and pass `tax: (tax?['amount'] as num?)?.toDouble(),` to the `ServiceRecord(...)`. Add `import '../../../features/automobile_records/domain/entities/line_item_type.dart';` at the top.

- [ ] **Step 5: Run it to verify it passes** — Run: `flutter test test/core/data/local/local_service_record_line_items_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/local/local_service_record_repository.dart test/core/data/local/local_service_record_line_items_test.dart
git commit -m "feat(service): local repo persists line-item type + tax"
```

## Task B4: API model `type` + `tax` + mapper

**Files:**
- Modify: `data/models/api_part_item.dart`, `data/models/api_service_record.dart`, `api_service_record_for_create.dart`, `api_service_record_for_update.dart`, `data/mappers/automobile_records_api_mapper.dart`
- Test: `test/features/automobile_records/service_record_mapper_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/automobile_records/service_record_mapper_test.dart` asserting `type`+`tax` survive `serviceToCreate`/`serviceFromApi` and the part mappers. (Use `AutomobileRecordsApiMapper`; build a `ServiceRecord` with a typed item + tax, map to the create DTO, assert `dto.parts.first.type == 'Labour'` and `dto.tax == 5.0`; build an `ApiServiceRecord` with a typed part + tax, map `serviceFromApi`, assert domain `type`/`tax`.)

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/automobile_records/service_record_mapper_test.dart`
Expected: FAIL — `type`/`tax` not on the DTOs/mapper.

- [ ] **Step 3: `ApiPartItem.type`** — in `api_part_item.dart`, add `this.type = 'Part',` to the ctor, `final String type;` field, `type: json['type'] as String? ?? 'Part'` in `fromJson`, and `'type': type` in `toJson`.

- [ ] **Step 4: `tax` on the three service DTOs** — add `this.tax,` + `final double? tax;` to each, parse in `fromJson` (`tax: (json['tax'] as num?)?.toDouble()`) where present, and emit in `toJson` (`if (tax != null) 'tax': tax`).

- [ ] **Step 5: Mapper** — in `automobile_records_api_mapper.dart`: `_partFromApi` sets `type: LineItemType.fromWire(p.type)`; `_partToApi` sets `type: p.type.wireName`; `serviceFromApi` sets `tax: api.tax`; `serviceToCreate`/`serviceToUpdate` set `tax: r.tax`. Add the `line_item_type.dart` import.

- [ ] **Step 6: Run it to verify it passes** — Run: `flutter test test/features/automobile_records/service_record_mapper_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/automobile_records/data/ test/features/automobile_records/service_record_mapper_test.dart
git commit -m "feat(service): API DTOs + mapper carry line-item type + tax"
```

## Task B5: `ServiceLineItemRow` widget

**Files:**
- Create: `lib/features/automobile_records/presentation/widgets/service_line_item_row.dart`
- Test: `test/features/automobile_records/widgets/service_line_item_row_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create the test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/presentation/widgets/service_line_item_row.dart';

void main() {
  testWidgets('edits name + shows line total + removes', (t) async {
    PartItem? changed;
    var removed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ServiceLineItemRow(
          item: const PartItem(type: LineItemType.part, name: 'Oil', quantity: 2, unitCost: 17.95),
          onChanged: (p) => changed = p,
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.textContaining('35.90'), findsOneWidget); // 2 × 17.95 line total
    await t.enterText(find.byKey(const Key('li-name')), 'Oil 5W30');
    expect(changed?.name, 'Oil 5W30');
    await t.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/automobile_records/widgets/service_line_item_row_test.dart`
Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement** — create `lib/features/automobile_records/presentation/widgets/service_line_item_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/line_item_type.dart';
import '../../domain/entities/part_item.dart';

/// One editable service line item: type, name, qty, unit cost, live line total,
/// and a remove button. Emits the updated [PartItem] on every change.
class ServiceLineItemRow extends StatefulWidget {
  const ServiceLineItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final PartItem item;
  final ValueChanged<PartItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<ServiceLineItemRow> createState() => _ServiceLineItemRowState();
}

class _ServiceLineItemRowState extends State<ServiceLineItemRow> {
  late final TextEditingController _name =
      TextEditingController(text: widget.item.name);
  late final TextEditingController _qty =
      TextEditingController(text: widget.item.quantity.toString());
  late final TextEditingController _unit = TextEditingController(
      text: widget.item.unitCost?.toStringAsFixed(2) ?? '');

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(widget.item.copyWith(
      name: _name.text,
      quantity: int.tryParse(_qty.text) ?? 1,
      unitCost: _unit.text.trim().isEmpty ? null : double.tryParse(_unit.text),
    ));
  }

  double get _lineTotal =>
      (double.tryParse(_unit.text) ?? 0) * (int.tryParse(_qty.text) ?? 1);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DropdownButton<LineItemType>(
            value: widget.item.type,
            onChanged: (v) =>
                v == null ? null : widget.onChanged(widget.item.copyWith(type: v)),
            items: [
              for (final t in LineItemType.values)
                DropdownMenuItem(value: t, child: Text(t.displayName)),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              key: const Key('li-name'),
              controller: _name,
              decoration: const InputDecoration(hintText: 'Item'),
              onChanged: (_) => _emit(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: TextField(
              key: const Key('li-qty'),
              controller: _qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'Qty'),
              onChanged: (_) => setState(_emit),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              key: const Key('li-unit'),
              controller: _unit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(hintText: 'Unit'),
              onChanged: (_) => setState(_emit),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(_lineTotal.toStringAsFixed(2),
                textAlign: TextAlign.right),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/automobile_records/widgets/service_line_item_row_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/automobile_records/presentation/widgets/service_line_item_row.dart test/features/automobile_records/widgets/service_line_item_row_test.dart
git commit -m "feat(service): ServiceLineItemRow editor widget"
```

## Task B6: `ServiceLineItemsEditor` (list + add/remove + totals + tax)

**Files:**
- Create: `lib/features/automobile_records/presentation/widgets/service_line_items_editor.dart`
- Test: `test/features/automobile_records/widgets/service_line_items_editor_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create the test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/presentation/widgets/service_line_items_editor.dart';

void main() {
  testWidgets('add item, edit tax, totals recompute', (t) async {
    List<PartItem> items = const [
      PartItem(type: LineItemType.part, name: 'Oil', quantity: 2, unitCost: 10.0),
    ];
    double? tax;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ServiceLineItemsEditor(
          initialItems: items,
          initialTax: 5.0,
          onChanged: (i, x) { items = i; tax = x; },
        ),
      ),
    ));
    // subtotal 20.00, tax 5.00, grand 25.00
    expect(find.textContaining('25.00'), findsWidgets);
    await t.tap(find.text('Add item'));
    await t.pump();
    expect(find.byKey(const Key('li-name')), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/automobile_records/widgets/service_line_items_editor_test.dart`
Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement** — create `lib/features/automobile_records/presentation/widgets/service_line_items_editor.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/line_item_type.dart';
import '../../domain/entities/part_item.dart';
import 'service_line_item_row.dart';

/// Editable list of service line items + a manual tax field + a live totals
/// summary. Calls [onChanged] with the current items + tax on every change.
class ServiceLineItemsEditor extends StatefulWidget {
  const ServiceLineItemsEditor({
    super.key,
    required this.initialItems,
    required this.initialTax,
    required this.onChanged,
  });

  final List<PartItem> initialItems;
  final double? initialTax;
  final void Function(List<PartItem> items, double? tax) onChanged;

  @override
  State<ServiceLineItemsEditor> createState() => _ServiceLineItemsEditorState();
}

class _ServiceLineItemsEditorState extends State<ServiceLineItemsEditor> {
  late final List<PartItem> _items = [...widget.initialItems];
  late final List<int> _keys =
      List.generate(widget.initialItems.length, (i) => i);
  int _nextKey = 1 << 20;
  late final TextEditingController _tax = TextEditingController(
      text: widget.initialTax?.toStringAsFixed(2) ?? '');

  @override
  void dispose() {
    _tax.dispose();
    super.dispose();
  }

  double? get _taxValue =>
      _tax.text.trim().isEmpty ? null : double.tryParse(_tax.text);

  void _emit() => widget.onChanged(List.unmodifiable(_items), _taxValue);

  double _totalFor(LineItemType t) => _items
      .where((p) => p.type == t)
      .fold(0.0, (s, p) => s + p.lineTotal);

  void _add() {
    setState(() {
      _items.add(const PartItem(name: ''));
      _keys.add(_nextKey++);
    });
    _emit();
  }

  void _removeAt(int i) {
    setState(() {
      _items.removeAt(i);
      _keys.removeAt(i);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal =
        _totalFor(LineItemType.labour) + _totalFor(LineItemType.part) + _totalFor(LineItemType.fee);
    final grand = subtotal + (_taxValue ?? 0);

    Widget totalLine(String label, double v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium),
              Text(v.toStringAsFixed(2),
                  style: bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Line items', style: theme.textTheme.titleSmall),
        for (var i = 0; i < _items.length; i++)
          ServiceLineItemRow(
            key: ValueKey(_keys[i]),
            item: _items[i],
            onChanged: (p) {
              _items[i] = p;
              setState(() {});
              _emit();
            },
            onRemove: () => _removeAt(i),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ),
        const Divider(),
        totalLine('Parts', _totalFor(LineItemType.part)),
        totalLine('Labour', _totalFor(LineItemType.labour)),
        totalLine('Fees', _totalFor(LineItemType.fee)),
        totalLine('Subtotal', subtotal),
        Row(
          children: [
            const Expanded(child: Text('Tax')),
            SizedBox(
              width: 90,
              child: TextField(
                key: const Key('li-tax'),
                controller: _tax,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(hintText: '0.00'),
                onChanged: (_) {
                  setState(() {});
                  _emit();
                },
              ),
            ),
          ],
        ),
        totalLine('Grand total', grand, bold: true),
      ],
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/automobile_records/widgets/service_line_items_editor_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/automobile_records/presentation/widgets/service_line_items_editor.dart test/features/automobile_records/widgets/service_line_items_editor_test.dart
git commit -m "feat(service): ServiceLineItemsEditor with live totals + tax"
```

## Task B7: Wire the editor into the form screen

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart`

- [ ] **Step 1: Add imports + state** — in `service_record_form_screen.dart`, add:

```dart
import '../../domain/entities/part_item.dart';
import '../widgets/service_line_items_editor.dart';
```

Add state fields near the controllers:

```dart
  List<PartItem> _items = const [];
  double? _tax;
```

- [ ] **Step 2: Seed from existing** — in `_loadExisting`, after `_currency = record.currency;` add:

```dart
      _items = [...record.parts];
      _tax = record.tax;
```

- [ ] **Step 3: Replace the cost Row with the editor** — remove the cost+CCY `Row(...)` block (the `Expanded`-pair around `_costCtrl`, roughly lines 151-176) and in its place insert:

```dart
                    ServiceLineItemsEditor(
                      initialItems: _items,
                      initialTax: _tax,
                      onChanged: (items, tax) {
                        _items = items;
                        _tax = tax;
                      },
                    ),
```

Delete the now-unused `_costCtrl` field + its `dispose()` line + the `_currency` CCY field usage (keep `_currency` as a value, default 'CAD').

- [ ] **Step 4: Update `_submit`** — change the `ServiceRecord(...)` construction: drop the `cost:` line that read `_costCtrl`, and set:

```dart
      cost: _items.where((p) => p.name.trim().isNotEmpty).isEmpty
          ? _existing?.cost
          : null,
      parts: _items.where((p) => p.name.trim().isNotEmpty).toList(),
      tax: _tax,
```

(Empty-name rows are dropped; a record with no items keeps its legacy flat cost.)

- [ ] **Step 5: Analyze** — Run: `flutter analyze lib/features/automobile_records/presentation/screens/service_record_form_screen.dart`
Expected: No issues. (If `_validateAmount`/`_decimalFormatter` are now unused, remove them.)

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/automobile_records/presentation/screens/service_record_form_screen.dart
git commit -m "feat(service): form uses the line-items editor + tax (cost is legacy fallback)"
```

## Task B8: List tile shows grand total + item count

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_records_screen.dart`

- [ ] **Step 1: Update the tile** — change the cost display (around line 166-168) to show `effectiveTotal` and an item count:

```dart
                  Text('${record.currency} ${record.effectiveTotal.toStringAsFixed(2)}'),
                  if (record.parts.isNotEmpty)
                    Text('${record.parts.length} items',
                        style: Theme.of(context).textTheme.bodySmall),
```

(Replace the `if (record.cost != null)` guard — `effectiveTotal` already falls back to the flat cost, and is 0 when neither exists.)

- [ ] **Step 2: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/features/automobile_records/presentation/screens/service_records_screen.dart
git add lib/features/automobile_records/presentation/screens/service_records_screen.dart
git commit -m "feat(service): list tile shows grand total + item count"
```

Expected analyze: No issues.

## Task B9: Full client verification

- [ ] **Step 1: Analyze** — Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Full test suite** — Run: `flutter test`
Expected: All pass.

- [ ] **Step 3: Manual smoke (optional, iOS)** — Open a vehicle → Service records → Add. Add several items (e.g. Labour "Service A" $61.50; Part "Oil" qty 7 @ $17.95; Fee "Env" $1.54), watch Parts/Labour/Fees/Subtotal update; type a tax (28.90) → Grand total updates; Save. The list shows the grand total + "N items". Reopen → items + tax are present and editable. Open a legacy record (no items) → it still shows its flat cost.

---

## Notes on scope / sequencing

- **Additive + back-compat:** every field defaults (item type → Part, tax → 0/null) so old notes, old clients, and the legacy flat `cost` keep working. No Drift schema/migration change — service records remain note-content JSON.
- **Sync:** unchanged — service records ride the existing note-content path.
- **Backend first** so `cloudApi` accepts the new fields; `local`/`cloudStorage` client work ships independently.
- **Out of scope:** walk-around inspection checklist (PDF page 3), PDF/receipt import, labour hours×rate.
```
