# Service-Log Header Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the automobile service log a real header — a service `name`, a shop `referenceNumber`, markdown `notes`, and multi-select category `types` — matching real service reports without new domain entities.

**Architecture:** Phase 1 adds two optional string fields (`name`, `referenceNumber`) and renders `notes` as markdown — purely additive across client entity → Drift + API mapper → backend domain/serializer/DTO. Phase 2 replaces the single `type: ServiceType` with `types: List<ServiceType>` via a read-legacy / write-array migration on both repos.

**Tech Stack:** Flutter/Dart (Riverpod, Drift, `flutter_markdown`, flutter_test); .NET 10 backend (System.Text.Json serializer, AutoMapper, xUnit).

**Repos:** `hmm_console` (client) and `hmm` (backend). Spec: `docs/superpowers/specs/2026-07-09-service-log-header-enrichment-design.md`.

## Global Constraints

- **Additive-or-migrated; nothing throws.** Missing `name`/`referenceNumber` → null; missing `types` → `[legacy type]` or `[ServiceType.other]`.
- **No new domain entity.** Do not add Garage/Shop/Inspection entities or duplicate vehicle / next-due data.
- **Line items (`parts` + `LineItemType`) are unchanged.**
- Wire JSON stays **camelCase** on both the API DTOs (`ApiServiceRecord*`, the receipt precedent uses `[JsonProperty]` where needed) and the note-content serializer keys (`name`, `referenceNumber`, `types`).
- Phase ordering is strict: **all Phase 1 tasks before any Phase 2 task.** Phase 1 must be shippable on its own.
- Backend enum: `ServiceType { OilChange, TireRotation, Brake, Inspection, Repair, Other }` (matches the client `ServiceType`).
- Commit footer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## PHASE 1 — additive header fields

### Task 1: Client entity — `name` + `referenceNumber`

**Files:**
- Modify: `lib/features/automobile_records/domain/entities/service_record.dart`
- Test: `test/features/automobile_records/domain/service_record_header_test.dart`

**Interfaces:**
- Produces: `ServiceRecord` gains `final String? name;` and `final String? referenceNumber;` (constructor params + `copyWith`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

void main() {
  ServiceRecord base() => ServiceRecord(
      id: 1, automobileId: 2, date: DateTime(2026), mileage: 50,
      type: ServiceType.oilChange);

  test('carries name and referenceNumber (null by default)', () {
    expect(base().name, isNull);
    expect(base().referenceNumber, isNull);
    final r = ServiceRecord(
        id: 1, automobileId: 2, date: DateTime(2026), mileage: 50,
        type: ServiceType.oilChange, name: 'Service A', referenceNumber: 'SO#952333');
    expect(r.name, 'Service A');
    expect(r.referenceNumber, 'SO#952333');
  });

  test('copyWith updates name/referenceNumber', () {
    final r = base().copyWith(name: 'Service B', referenceNumber: 'X1');
    expect(r.name, 'Service B');
    expect(r.referenceNumber, 'X1');
    expect(r.type, ServiceType.oilChange);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/domain/service_record_header_test.dart`
Expected: FAIL — no `name`/`referenceNumber` params (compile error).

- [ ] **Step 3: Add the fields**

In `service_record.dart`, add to the constructor (after `required this.type,`):

```dart
    this.name,
    this.referenceNumber,
```

Add the field declarations (after `final ServiceType type;`):

```dart
  final String? name;
  final String? referenceNumber;
```

Add to `copyWith` params (after `ServiceType? type,`):

```dart
    String? name,
    String? referenceNumber,
```

And to the `copyWith` body's `return ServiceRecord(` (after `type: type ?? this.type,`):

```dart
      name: name ?? this.name,
      referenceNumber: referenceNumber ?? this.referenceNumber,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/domain/service_record_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/domain/entities/service_record.dart test/features/automobile_records/domain/service_record_header_test.dart
git commit -m "feat(automobile): add name + referenceNumber to ServiceRecord

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Client local Drift persistence of `name`/`referenceNumber`

**Files:**
- Modify: `lib/core/data/local/local_service_record_repository.dart` (`_serialize` ~127-157, `_deserialize` ~159-203)
- Test: `test/core/data/local/local_service_record_header_test.dart`

**Interfaces:**
- Consumes: `ServiceRecord.name`/`referenceNumber` (Task 1).
- Produces: local Drift round-trips both fields (content keys `name`, `referenceNumber`).

- [ ] **Step 1: Write the failing test**

Reuse the existing local-repo harness pattern (in-memory Drift + `LocalHmmNoteRepository` + `LocalNoteCatalogRepository` + `LocalServiceRecordRepository`; see `test/core/data/local/local_service_record_line_items_test.dart` for setup). New test:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_service_record_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

void main() {
  test('round-trips name + referenceNumber through Drift', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final aid = await db.into(db.authors).insert(
        AuthorsCompanion.insert(accountName: 'tester'));
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid))).getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final repo = LocalServiceRecordRepository(
        noteRepo, LocalNoteCatalogRepository(db));

    final created = await repo.createRecord(
      7,
      ServiceRecord(
          id: 0, automobileId: 7, date: DateTime(2026), mileage: 50,
          type: ServiceType.oilChange,
          name: 'Service A', referenceNumber: 'SO#952333'),
    );
    final reloaded = await repo.getRecordById(7, created.id);
    expect(reloaded.name, 'Service A');
    expect(reloaded.referenceNumber, 'SO#952333');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/data/local/local_service_record_header_test.dart`
Expected: FAIL — `reloaded.name` is null (not serialized).

- [ ] **Step 3: Serialize + deserialize the fields**

In `_serialize`'s `data` map (after `'type': r.type.wireValue,`):

```dart
      if (r.name != null) 'name': r.name,
      if (r.referenceNumber != null) 'referenceNumber': r.referenceNumber,
```

In `_deserialize`'s `return ServiceRecord(` (after `type: ServiceType.fromWire(body['type'] as String?),`):

```dart
        name: body['name'] as String?,
        referenceNumber: body['referenceNumber'] as String?,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/core/data/local/local_service_record_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/core/data/local/local_service_record_repository.dart test/core/data/local/local_service_record_header_test.dart
git commit -m "feat(automobile): persist name/referenceNumber in local Drift store

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Client API models + mapper for `name`/`referenceNumber`

**Files:**
- Modify: `lib/features/automobile_records/data/models/api_service_record.dart`
- Modify: `lib/features/automobile_records/data/models/api_service_record_for_create.dart`
- Modify: `lib/features/automobile_records/data/models/api_service_record_for_update.dart`
- Modify: `lib/features/automobile_records/data/mappers/automobile_records_api_mapper.dart`
- Test: `test/features/automobile_records/service_record_mapper_test.dart` (extend)

**Interfaces:**
- Consumes: `ServiceRecord.name`/`referenceNumber` (Task 1).
- Produces: API models carry `name`/`referenceNumber` (camelCase); mapper maps both directions.

- [ ] **Step 1: Write the failing test**

Add to `test/features/automobile_records/service_record_mapper_test.dart`:

```dart
  test('maps name + referenceNumber to create and back from api', () {
    final r = ServiceRecord(
        id: 1, automobileId: 2, date: DateTime(2026), mileage: 50,
        type: ServiceType.oilChange, name: 'Service A', referenceNumber: 'SO#1');
    final create = AutomobileRecordsApiMapper.serviceToCreate(r);
    expect(create.toJson()['name'], 'Service A');
    expect(create.toJson()['referenceNumber'], 'SO#1');

    final api = ApiServiceRecord(
        id: 1, automobileId: 2, date: DateTime(2026), mileage: 50,
        type: 'OilChange', name: 'Service A', referenceNumber: 'SO#1');
    final back = AutomobileRecordsApiMapper.serviceFromApi(api);
    expect(back.name, 'Service A');
    expect(back.referenceNumber, 'SO#1');
  });
```

(Match the existing import names/aliases used in that test file.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/service_record_mapper_test.dart`
Expected: FAIL — `ApiServiceRecord`/`ApiServiceRecordForCreate` have no `name`/`referenceNumber`.

- [ ] **Step 3: Add fields to the three API models**

`api_service_record.dart`: add constructor params `this.name,` `this.referenceNumber,`; fields `final String? name;` `final String? referenceNumber;`; and in `fromJson` (after `type: ...`): `name: json['name'] as String?,` `referenceNumber: json['referenceNumber'] as String?,`.

`api_service_record_for_create.dart`: add constructor params `this.name,` `this.referenceNumber,`; fields `final String? name;` `final String? referenceNumber;`; and in `toJson()` (after the `'type': type,` entry): `if (name != null) 'name': name,` `if (referenceNumber != null) 'referenceNumber': referenceNumber,`.

`api_service_record_for_update.dart`: same three additions as the create model (params, fields, `toJson` conditional entries).

- [ ] **Step 4: Map both directions**

In `automobile_records_api_mapper.dart`:
- `serviceFromApi(ApiServiceRecord api)` `return ServiceRecord(`: add `name: api.name,` `referenceNumber: api.referenceNumber,`.
- `serviceToCreate(ServiceRecord r)` `return ApiServiceRecordForCreate(`: add `name: r.name,` `referenceNumber: r.referenceNumber,`.
- `serviceToUpdate(ServiceRecord r)` `return ApiServiceRecordForUpdate(`: add `name: r.name,` `referenceNumber: r.referenceNumber,`.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/service_record_mapper_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/data/models/api_service_record.dart lib/features/automobile_records/data/models/api_service_record_for_create.dart lib/features/automobile_records/data/models/api_service_record_for_update.dart lib/features/automobile_records/data/mappers/automobile_records_api_mapper.dart test/features/automobile_records/service_record_mapper_test.dart
git commit -m "feat(automobile): map name/referenceNumber across the API layer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Client UI — form fields, list headline, notes markdown preview

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart`
- Modify: `lib/features/automobile_records/presentation/screens/service_records_screen.dart`
- Test: extend `test/features/automobile_records/service_record_form_edit_test.dart`

**Interfaces:**
- Consumes: `ServiceRecord.name`/`referenceNumber` (Task 1); `flutter_markdown` (already a dependency — verify in `pubspec.yaml`).

- [ ] **Step 1: Add form controllers + fields**

In `_ServiceRecordFormScreenState`: add `final _nameCtrl = TextEditingController();` and `final _refCtrl = TextEditingController();` (dispose both in `dispose`). In `_loadExisting`, set `_nameCtrl.text = record.name ?? '';` and `_refCtrl.text = record.referenceNumber ?? '';`. Add two `AppTextFormField`s near the top of the form (above the date): label `'Service name'` (controller `_nameCtrl`, validator `(_) => null`) and label `'Reference # (optional)'` (controller `_refCtrl`, validator `(_) => null`).

- [ ] **Step 2: Thread into save**

In `_submit`'s `ServiceRecord(` construction, add:

```dart
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      referenceNumber:
          _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
```

- [ ] **Step 3: Notes markdown preview**

Below the existing notes `AppTextFormField`, add a read-only markdown preview shown only when notes is non-empty (rebuild on change):

```dart
if (_notesCtrl.text.trim().isNotEmpty) ...[
  const SizedBox(height: 8),
  Align(
    alignment: Alignment.centerLeft,
    child: Text('Preview', style: Theme.of(context).textTheme.labelSmall),
  ),
  MarkdownBody(data: _notesCtrl.text),
],
```

Add `import 'package:flutter_markdown/flutter_markdown.dart';` and make the notes field's `onChanged` call `setState(() {})` so the preview updates. Add a `helperText: 'Supports markdown'` to the notes field's decoration if `AppTextFormField` forwards it; otherwise add a one-line caption under the field.

- [ ] **Step 4: List tile headline**

In `service_records_screen.dart` `_ServiceTile.build`, change the `ListTile` `title` from `record.type.displayName` to:

```dart
        title: Text(
          (record.name != null && record.name!.isNotEmpty)
              ? record.name!
              : record.type.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
```

- [ ] **Step 5: Test the headline fallback + preview**

Add to `service_record_form_edit_test.dart` (reusing its `_SyncRepo` harness) a record with `name: 'Service A'` and assert the form's name field shows it; and a widget test on `service_records_screen` is optional — at minimum assert the entity-level fallback via a small unit check that `record.name ?? type.displayName` resolves to `'Service A'` when set and to `'Oil change'` when null. Run: `flutter test test/features/automobile_records/service_record_form_edit_test.dart` and `flutter analyze lib/features/automobile_records/presentation`.
Expected: PASS; `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/presentation/screens/service_record_form_screen.dart lib/features/automobile_records/presentation/screens/service_records_screen.dart test/features/automobile_records/service_record_form_edit_test.dart
git commit -m "feat(automobile): surface name/reference# in the form + list; markdown notes preview

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Backend — `Name`/`ReferenceNumber` (domain, serializer, DTO, mapper)

**Repo:** `~/projects/hmm`

**Files:**
- Modify: `src/Hmm.Automobile/DomainEntity/ServiceRecord.cs`
- Modify: `src/Hmm.Automobile/NoteSerialize/ServiceRecordJsonNoteSerialize.cs`
- Modify: `src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiServiceRecord.cs`, `ApiServiceRecordForCreate.cs`, `ApiServiceRecordForUpdate.cs`
- Modify: `src/Hmm.ServiceApi/Areas/AutomobileInfoService/Infrastructure/AutomobileMappingProfile.cs`
- Test: `src/Hmm.Automobile.Tests/` (serializer round-trip)

**Interfaces:**
- Produces (wire): each service record carries camelCase `name`, `referenceNumber` in both the note content and the API DTO.

- [ ] **Step 1: Write the failing serializer test**

In the automobile tests project, add a round-trip test: build a `ServiceRecord` with `Name = "Service A"`, `ReferenceNumber = "SO#1"`, serialize to note content via `ServiceRecordJsonNoteSerialize`, deserialize back, assert both fields survive. (Follow the existing serializer test's construction of the serializer with its catalog/note dependencies; mirror `ServiceRecordTotalsTests` for entity setup.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm && dotnet test src/Hmm.Automobile.Tests/`
Expected: FAIL — `ServiceRecord` has no `Name`/`ReferenceNumber`.

- [ ] **Step 3: Domain + serializer**

`ServiceRecord.cs`: add `public string Name { get; set; }` and `public string ReferenceNumber { get; set; }`.

`ServiceRecordJsonNoteSerialize.cs` — read (in the object built around line 95, after `Type = type,`): `Name = GetStringProperty(recordJson, "name", string.Empty),` `ReferenceNumber = GetStringProperty(recordJson, "referenceNumber", string.Empty),`. Write (in the dictionary around line 145, after `["type"] = entity.Type.ToString(),`): `["name"] = entity.Name ?? string.Empty,` `["referenceNumber"] = entity.ReferenceNumber ?? string.Empty,`.

- [ ] **Step 4: DTOs + mapper**

Add `public string Name { get; set; }` and `public string ReferenceNumber { get; set; }` to `ApiServiceRecord.cs`, `ApiServiceRecordForCreate.cs`, `ApiServiceRecordForUpdate.cs` (plain PascalCase; the automobile area's result filters emit these camelCase like the rest). In `AutomobileMappingProfile.cs`, the `CreateMap<ApiServiceRecordForCreate, ServiceRecord>()`, `...ForUpdate...`, and `CreateMap<ServiceRecord, ApiServiceRecord>()` map `Name`/`ReferenceNumber` by convention (same property names) — no explicit `ForMember` needed; verify no `Ignore()` covers them.

- [ ] **Step 5: Run to verify it passes**

Run: `cd ~/projects/hmm && dotnet test src/Hmm.Automobile.Tests/ && dotnet test src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm
git add src/Hmm.Automobile/DomainEntity/ServiceRecord.cs src/Hmm.Automobile/NoteSerialize/ServiceRecordJsonNoteSerialize.cs src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiServiceRecord.cs src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiServiceRecordForCreate.cs src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ApiServiceRecordForUpdate.cs src/Hmm.ServiceApi/Areas/AutomobileInfoService/Infrastructure/AutomobileMappingProfile.cs src/Hmm.Automobile.Tests/
git commit -m "feat(automobile): persist name/referenceNumber on the backend service record

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 7: Ship Phase 1** — deploy backend (`./scripts/deploy-api.sh --deploy`), confirm `active`; build the client to a device. Phase 1 is now a usable, non-breaking feature.

---

## PHASE 2 — multi-category tags (breaking, migrated)

### Task 6: Client entity — `type` → `types: List<ServiceType>`

**Files:**
- Modify: `lib/features/automobile_records/domain/entities/service_record.dart`
- Test: `test/features/automobile_records/domain/service_record_header_test.dart` (extend)

**Interfaces:**
- Produces: `final List<ServiceType> types;` (replaces `final ServiceType type;`); `ServiceType get primaryType => types.first;`. Constructor takes `required this.types`. `copyWith` takes `List<ServiceType>? types`.

- [ ] **Step 1: Write the failing test**

```dart
  test('types list with primaryType', () {
    final r = ServiceRecord(
        id: 1, automobileId: 2, date: DateTime(2026), mileage: 50,
        types: const [ServiceType.oilChange, ServiceType.inspection]);
    expect(r.types, [ServiceType.oilChange, ServiceType.inspection]);
    expect(r.primaryType, ServiceType.oilChange);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/domain/service_record_header_test.dart`
Expected: FAIL — no `types`/`primaryType`.

- [ ] **Step 3: Replace `type` with `types`**

In `service_record.dart`: change constructor `required this.type,` → `required this.types,`; field `final ServiceType type;` → `final List<ServiceType> types;`; add `ServiceType get primaryType => types.first;`. Update `copyWith`: param `ServiceType? type,` → `List<ServiceType>? types,`; body `type: type ?? this.type,` → `types: types ?? this.types,`. Update Task 1's test file constructions from `type: ServiceType.x` to `types: const [ServiceType.x]` and any `.type` to `.primaryType`.

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/domain/service_record_header_test.dart`
Expected: PASS. (Other files won't compile yet — fixed in Tasks 7-9.)

- [ ] **Step 5: Commit** (compile of dependents deferred to next tasks; commit the entity + its test together)

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/domain/entities/service_record.dart test/features/automobile_records/domain/service_record_header_test.dart
git commit -m "feat(automobile): ServiceRecord types list + primaryType

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Client local Drift — write `types`, read legacy `type`

**Files:**
- Modify: `lib/core/data/local/local_service_record_repository.dart`
- Test: `test/core/data/local/local_service_record_header_test.dart` (extend)

**Interfaces:**
- Consumes: `ServiceRecord.types` (Task 6).

- [ ] **Step 1: Write the failing tests**

```dart
  test('writes types array and reads it back', () async {
    // ... same harness as Task 2 ...
    final created = await repo.createRecord(7, ServiceRecord(
        id: 0, automobileId: 7, date: DateTime(2026), mileage: 50,
        types: const [ServiceType.oilChange, ServiceType.inspection]));
    final reloaded = await repo.getRecordById(7, created.id);
    expect(reloaded.types, [ServiceType.oilChange, ServiceType.inspection]);
  });
```

Also a legacy-read test: build a note whose content JSON has a single `type` and no `types`, deserialize, expect `types == [thatType]`. (Construct the content string via `_serialize` of an old-shaped map, or write a note directly with content containing `"type":"OilChange"` and no `types`.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/data/local/local_service_record_header_test.dart`
Expected: FAIL — serializer still writes single `type`.

- [ ] **Step 3: Serialize `types`, deserialize with legacy fallback**

In `_serialize`, replace `'type': r.type.wireValue,` with:

```dart
      'types': r.types.map((t) => t.wireValue).toList(),
```

In `_deserialize`, replace `type: ServiceType.fromWire(body['type'] as String?),` with:

```dart
        types: () {
          final raw = body['types'] as List<dynamic>?;
          if (raw != null) {
            return raw
                .map((e) => ServiceType.fromWire(e as String?))
                .toList();
          }
          final legacy = body['type'] as String?;
          return [ServiceType.fromWire(legacy)]; // fromWire(null) -> other
        }(),
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/core/data/local/local_service_record_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/core/data/local/local_service_record_repository.dart test/core/data/local/local_service_record_header_test.dart
git commit -m "feat(automobile): local store writes types array, reads legacy type

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Client API models + mapper — `types`

**Files:**
- Modify: `api_service_record.dart`, `api_service_record_for_create.dart`, `api_service_record_for_update.dart`, `automobile_records_api_mapper.dart`
- Test: `test/features/automobile_records/service_record_mapper_test.dart` (extend)

**Interfaces:**
- API models carry `List<String> types`; mapper converts `List<ServiceType>` ↔ `List<String>` (via `wireValue`/`fromWire`), reading legacy single `type` when `types` absent.

- [ ] **Step 1: Write the failing test**

```dart
  test('maps types list to create and back (legacy type fallback)', () {
    final r = ServiceRecord(
        id: 1, automobileId: 2, date: DateTime(2026), mileage: 50,
        types: const [ServiceType.oilChange, ServiceType.inspection]);
    final create = AutomobileRecordsApiMapper.serviceToCreate(r);
    expect(create.toJson()['types'], ['OilChange', 'Inspection']);

    // legacy single-type API payload still maps
    final legacy = ApiServiceRecord(
        id: 1, automobileId: 2, date: DateTime(2026), mileage: 50,
        type: 'Brake');
    expect(AutomobileRecordsApiMapper.serviceFromApi(legacy).types,
        [ServiceType.brake]);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/service_record_mapper_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add `types` to models + mapper**

Models: add `List<String> types` (default `const []`) to all three API models. In `ApiServiceRecord.fromJson`, read `types: (json['types'] as List?)?.map((e) => e as String).toList() ?? const [],` and keep reading the legacy `type` string. In the create/update `toJson`, add `'types': types,`.

Mapper:
- `serviceFromApi`: `types:` = if `api.types` non-empty → `api.types.map(ServiceType.fromWire).toList()`; else `[ServiceType.fromWire(api.type)]`.
- `serviceToCreate`/`serviceToUpdate`: `types: r.types.map((t) => t.wireValue).toList(),`. Keep passing legacy `type: r.primaryType.wireValue` on create/update only if the API still requires the scalar; otherwise drop it once the backend (Task 9) reads `types`. Coordinate with Task 9: backend reads `types` when present, so the client sends `types`; keep `type: r.primaryType.wireValue` too for one release for older-backend compatibility.

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/service_record_mapper_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/data/models/ lib/features/automobile_records/data/mappers/automobile_records_api_mapper.dart test/features/automobile_records/service_record_mapper_test.dart
git commit -m "feat(automobile): API layer carries types list (legacy type fallback)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Client consumers — list tile, form multi-select, fallbacks

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_records_screen.dart`
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart`
- Grep + fix any other `.type` reader in `lib/features/automobile_records/`
- Test: extend the form edit test

**Interfaces:**
- Consumes: `ServiceRecord.types`/`primaryType`.

- [ ] **Step 1: Fix the headline + all `.type` readers**

Grep: `grep -rn "\.type\b" lib/features/automobile_records | grep -v LineItemType`. For each `ServiceRecord.type` reader:
- List headline fallback → `record.primaryType.displayName`.
- Any category chip / filter / stat → iterate `record.types` ("any tag matches").
- The form's single-select `ServiceTypeDropdown` → a multi-select control: hold `List<ServiceType> _types` (seed from `record.types`, default `[ServiceType.other]`), render a wrap of `FilterChip`s over `ServiceType.values` toggling membership (min 1 enforced on save), and pass `types: _types` into the saved `ServiceRecord`.

- [ ] **Step 2: Run tests + analyze**

Run: `cd ~/projects/hmm_console && flutter analyze lib/features/automobile_records && flutter test`
Expected: `No issues found!`; `All tests passed!` (fix any remaining call sites the analyzer flags).

- [ ] **Step 3: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/ test/features/automobile_records/
git commit -m "feat(automobile): multi-select service types in form + list

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 10: Backend — `Type` → `Types` (read legacy, write array)

**Repo:** `~/projects/hmm`

**Files:**
- Modify: `src/Hmm.Automobile/DomainEntity/ServiceRecord.cs`
- Modify: `src/Hmm.Automobile/NoteSerialize/ServiceRecordJsonNoteSerialize.cs`
- Modify: the three `ApiServiceRecord*` DTOs + `AutomobileMappingProfile.cs`
- Test: `src/Hmm.Automobile.Tests/`

**Interfaces:**
- `ServiceRecord.Types` = `List<ServiceType>` (with `Type => Types[0]` kept for any C# consumer needing a scalar). Serializer writes `types` array, reads legacy `type`. DTOs carry `List<string> Types`.

- [ ] **Step 1: Write the failing tests**

Serializer round-trip of a two-element `Types`; and a legacy-content test (content has `"type":"Brake"`, no `types`) → `Types == [Brake]`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm && dotnet test src/Hmm.Automobile.Tests/`
Expected: FAIL.

- [ ] **Step 3: Domain + serializer**

`ServiceRecord.cs`: replace `public ServiceType Type { get; set; }` with `public List<ServiceType> Types { get; set; } = new();` and add `public ServiceType Type => Types.Count > 0 ? Types[0] : ServiceType.Other;` (read-only primary for existing consumers). Update `ServiceRecordManager`/validators if any set `.Type` — set `.Types` instead.

Serializer read (replace the single `Enum.TryParse<ServiceType>(GetStringProperty(recordJson, "type"), ...)` block): if `types` array present, parse each; else parse legacy `type` into a one-element list; else `[Other]`. Assign `Types = parsed`. Serializer write (replace `["type"] = entity.Type.ToString(),`): `["types"] = entity.Types.Select(t => t.ToString()).ToList(),`.

- [ ] **Step 4: DTOs + mapper**

Replace `Type` (string) with `List<string> Types` on the three DTOs (keep reading a legacy `Type` in the ForCreate/ForUpdate binding is unnecessary — the client sends `types`). In `AutomobileMappingProfile.cs`, map `Types` explicitly: `ServiceRecord → ApiServiceRecord` `.ForMember(d => d.Types, o => o.MapFrom(s => s.Types.Select(t => t.ToString())))`; `ApiServiceRecordForCreate/Update → ServiceRecord` `.ForMember(d => d.Types, o => o.MapFrom(s => (s.Types ?? new List<string>()).Select(x => Enum.Parse<ServiceType>(x, true)).ToList()))` with a fallback to `[Other]` when empty.

- [ ] **Step 5: Run to verify it passes**

Run: `cd ~/projects/hmm && dotnet test src/Hmm.Automobile.Tests/ && dotnet test src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm
git add src/Hmm.Automobile/ src/Hmm.ServiceApi.DtoEntity/GasLogNotes/ src/Hmm.ServiceApi/Areas/AutomobileInfoService/Infrastructure/AutomobileMappingProfile.cs src/Hmm.Automobile.Tests/
git commit -m "feat(automobile): backend service Types list (read legacy type, write array)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 11: Whole-branch review, merge, deploy, verify

- [ ] **Step 1:** Dispatch a final code-reviewer over each repo's branch diff, rubric = the Global Constraints (focus: additive-or-migrated correctness, legacy `type` read on both repos, no roaming/entity scope creep, camelCase, "any tag matches" semantics).
- [ ] **Step 2:** Fix Critical/Important findings (one fix pass).
- [ ] **Step 3:** Merge both repos to `main` via `superpowers:finishing-a-development-branch` (verify tests on merged result). **Phase 2 ships both repos together** (client sends `types`, backend reads them; both still read legacy `type`).
- [ ] **Step 4:** Deploy backend (`./scripts/deploy-api.sh --deploy`), build client to devices. Verify with the sample Subaru order: create a record named "Service A", reference `SO#952333`, tag it Oil change + Inspection, markdown notes render; save + reopen; confirm existing (pre-migration) records still show their category and read fine.

---

## Self-Review

**Spec coverage:** name+referenceNumber (Tasks 1-3,5), notes markdown (Task 4), list headline fallback (Task 4/9), multi-tag types + migration (Tasks 6-10), backend parity (5,10), reuse/no-new-entity honored (no Garage/Inspection tasks), rollout phased (Task 5 step 7, Task 11). ✓

**Placeholder scan:** each code step gives the exact snippet to add; UI tasks name the exact widget/field and insertion point; the two "grep the remaining `.type` readers" steps are concrete instructions with the grep command, not vague requirements. ✓

**Type consistency:** `name`/`referenceNumber` (`String?`) and `types` (`List<ServiceType>`) / `primaryType` are used identically across entity → Drift → mapper → DTO in both phases; backend `Types` (`List<ServiceType>`) with read-only `Type` primary matches the client `types`/`primaryType`; camelCase wire keys (`name`, `referenceNumber`, `types`) consistent client↔backend. Phase 2 correctly updates Phase 1's test constructions from `type:` to `types:`. ✓
