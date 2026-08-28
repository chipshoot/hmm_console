# Vehicle Documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand vehicle registration on the `Automobile` entity, and add a singleton driver's licence with front/back scans and a full-screen show-mode.

**Architecture:** Registration is three more fields on an entity that already exists, plus scans on the vehicle note's existing attachments column. The licence is one note under a new catalog with a fixed subject, its image bytes referenced from the note's attachments column and its front/back mapping recorded in content.

**Tech Stack:** Flutter, Riverpod (`AsyncNotifier`), Drift via the existing note repositories, `local_auth` (already present), gen-l10n (ARB, en + zh).

**Spec:** `docs/superpowers/specs/2026-08-27-vehicle-documents-design.md`

## Global Constraints

- **`LocalAutomobileRepository` rebuilds the entity field by field in FOUR places** — `createAutomobile` (~line 47), `updateAutomobile` (~79), `deactivateAutomobile` (~97) and `_deserialize` (~201). A field missed in **any one** never reaches storage, or is silently wiped by an unrelated edit. This exact class of bug was shipped three times in the insurance work.
- **Licence image BYTES are referenced from the note's `attachments` column.** `VaultGc` builds its live-path set by reading every note's attachments column and deletes any vault file not in it. Storing refs only in content would make the images invisible to GC, and the next run would delete the user's licence photos. Content records only `frontImagePath` / `backImagePath`.
- **Both licence images and registration scans are `sensitive: true`**, so they route through `EncryptedVaultStore`. Unlock is once per session via the existing `local_auth` gate — no new security machinery.
- **`cloudApi` mode hides the three NEW registration fields and the whole licence feature.** Neither reaches the API; offering them would take input, report success, and discard it. The existing `registrationExpiryDate` picker STAYS visible in all modes — the API does carry it.
- **`licenceClass` and `jurisdiction` are stored literals, never translated.** Same rule as `ContactInfo.role` and the settings enums.
- **Zero hardcoded user-facing strings.** Every one gets an ARB key in BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`, which must stay at equal key count (506 each today).
- **Unknown JSON keys are preserved** via `extraFields` on the licence.
- Run `flutter analyze` (2 pre-existing issues, in `onboarding_screen.dart` and `main.dart` — anything else is yours) and the relevant tests before every commit.
- **Mutation-check every load-bearing guarantee**: revert the fix and confirm the test that names it fails. Assert the mutation actually applied — a mutation that silently fails to apply looks identical to a passing test.

---

### Task 1: Registration fields on `Automobile`

**Files:**
- Modify: `lib/features/gas_log/domain/entities/automobile.dart`
- Modify: `lib/core/data/local/local_automobile_repository.dart`
- Test: `test/core/data/local/local_automobile_registration_test.dart`

**Interfaces:**
- Produces: `Automobile.registrationNumber`, `.registrationJurisdiction`, `.registrationIssuedDate` (all nullable), alongside the existing `.registrationExpiryDate`.

- [ ] **Step 1: Write the failing test**

Write `test/core/data/local/local_automobile_registration_test.dart`. Model the database harness on `test/core/data/local/local_gas_log_repository_station_rename_test.dart` — real `HmmDatabase(NativeDatabase.memory())`, a seeded author, real `LocalHmmNoteRepository` + `LocalNoteCatalogRepository`:

```dart
  test('registration details survive a create', () async {
    final created = await repo.createAutomobile(_seedAuto().copyWithRegistration(
      number: 'REG-123',
      jurisdiction: 'Ontario',
      issued: DateTime.utc(2026, 1, 1),
    ));

    expect(created.registrationNumber, 'REG-123');
    expect(created.registrationJurisdiction, 'Ontario');
    expect(created.registrationIssuedDate, DateTime.utc(2026, 1, 1));
  });

  test('registration details survive an unrelated edit', () async {
    // updateAutomobile rebuilds the entity field by field; a field it forgets
    // is wiped by an edit that had nothing to do with it.
    final created = await repo.createAutomobile(_seedAuto().copyWithRegistration(
      number: 'REG-123', jurisdiction: 'Ontario'));

    await repo.updateAutomobile(created.id, created.copyWithPlate('NEW-PLATE'));

    final reloaded = (await repo.getAutomobiles()).single;
    expect(reloaded.plate, 'NEW-PLATE');
    expect(reloaded.registrationNumber, 'REG-123');
    expect(reloaded.registrationJurisdiction, 'Ontario');
  });

  test('registration details survive deactivation', () async {
    // deactivateAutomobile is a THIRD rebuild site and is easy to miss.
    final created = await repo.createAutomobile(_seedAuto().copyWithRegistration(
      number: 'REG-123'));

    await repo.deactivateAutomobile(created.id);

    final reloaded = (await repo.getAutomobiles(includeInactive: true)).single;
    expect(reloaded.registrationNumber, 'REG-123');
  });

  test('a vehicle with no registration details reads back null, not empty', () async {
    final created = await repo.createAutomobile(_seedAuto());
    expect(created.registrationNumber, isNull);
    expect(created.registrationIssuedDate, isNull);
  });
```

`_seedAuto()` copies the fixture from the gas-log test. Add whatever small `copyWithRegistration` / `copyWithPlate` test helpers you need at the bottom of the test file — `Automobile` has no general `copyWith`, and adding one is out of scope. **Check `getAutomobiles`'s real signature** before using `includeInactive`; if it differs, read deactivated vehicles however the repository actually exposes them.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/local/local_automobile_registration_test.dart`
Expected: FAIL — `registrationNumber` is not defined.

- [ ] **Step 3: Add the fields to the entity**

In `lib/features/gas_log/domain/entities/automobile.dart`, add three constructor parameters and three fields beside `registrationExpiryDate`:

```dart
  /// Ownership registration. The expiry date has existed since before this
  /// feature; these three join it.
  final String? registrationNumber;

  /// Province / state. Free text: it varies by country and a fixed list would
  /// reject a valid registration.
  final String? registrationJurisdiction;

  final DateTime? registrationIssuedDate;
```

Include them in `==` and `hashCode` if the class defines them.

- [ ] **Step 4: Thread them through ALL FOUR rebuild sites**

In `lib/core/data/local/local_automobile_repository.dart`:

1. `_serialize` — add three keys beside `registrationExpiryDate`:

```dart
      'registrationNumber': auto.registrationNumber,
      'registrationJurisdiction': auto.registrationJurisdiction,
      'registrationIssuedDate': auto.registrationIssuedDate?.toIso8601String(),
```

2. `_deserialize` (~line 201) — read them back, tolerating a malformed date:

```dart
        registrationNumber: d['registrationNumber'] as String?,
        registrationJurisdiction: d['registrationJurisdiction'] as String?,
        registrationIssuedDate: d['registrationIssuedDate'] != null
            ? DateTime.tryParse(d['registrationIssuedDate'] as String)
            : null,
```

3. `createAutomobile` (~47) and `updateAutomobile` (~79) — wherever they construct an `Automobile`, carry the three fields across.

4. `deactivateAutomobile` (~97) — the same. **This is the one that gets forgotten**: it rebuilds the entity to flip `isActive`, so a field it omits is destroyed by deactivating a vehicle.

Also check `lib/features/gas_log/data/repositories/automobile_repository.dart` (~line 73) and `lib/core/data/local/local_gas_log_repository.dart` (~155), which both rebuild an `Automobile` too.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/data/local/local_automobile_registration_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Mutation-check each rebuild site**

One at a time, delete `registrationNumber:` from `createAutomobile`, then from `updateAutomobile`, then from `deactivateAutomobile`. Each must fail its own test. **Confirm each edit actually applied before trusting the result** — then restore it.

Expected: three separate failures, one per site. If deactivation's mutation survives, the deactivation test is not reaching that path — fix the test, not the assertion.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/gas_log/domain/entities/automobile.dart lib/core/data/local/local_automobile_repository.dart lib/features/gas_log/data/repositories/automobile_repository.dart lib/core/data/local/local_gas_log_repository.dart test/core/data/local/local_automobile_registration_test.dart
git commit -m "feat(automobile): add registration number, jurisdiction and issued date"
```

---

### Task 2: Registration in the vehicle edit screen

**Files:**
- Modify: `lib/features/gas_log/presentation/screens/automobile_edit_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/gas_log/automobile_registration_form_test.dart`

**Interfaces:**
- Consumes: the three fields from Task 1.

- [ ] **Step 1: Add ARB keys**

Add to `app_en.arb`:

```json
"vehicleRegistrationSection": "Registration",
"vehicleRegistrationNumber": "Registration number",
"vehicleRegistrationJurisdiction": "Province / State",
"vehicleRegistrationIssued": "Issued"
```

And to `app_zh.arb`:

```json
"vehicleRegistrationSection": "行驶证",
"vehicleRegistrationNumber": "登记号",
"vehicleRegistrationJurisdiction": "省 / 州",
"vehicleRegistrationIssued": "发证日期"
```

> These Chinese strings have not been reviewed by a native speaker — a standing risk across the app. Flag for review rather than assuming correct.

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Write `test/features/gas_log/automobile_registration_form_test.dart` asserting:

- the three fields render under the `vehicleRegistrationSection` heading, alongside the existing expiry picker
- entering a registration number and saving passes it to the repository
- editing an existing vehicle pre-populates all three
- **in `cloudApi` mode the three new fields are absent, while the existing expiry picker remains** (override `dataModeProvider` with a stub, as `mutate_service_record_attachments_test.dart` does)

Mount inside a `ProviderScope` with `AppLocalizations.localizationsDelegates` and `supportedLocales` supplied on the `MaterialApp`, or the widget throws while building rather than failing an assertion.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/gas_log/automobile_registration_form_test.dart`
Expected: FAIL — the fields do not exist.

- [ ] **Step 4: Add the fields to the form**

Group the three new fields with the existing expiry picker under a `vehicleRegistrationSection` heading. Follow the file's existing conventions: `AppTextFormField` for text, `_optionalDatePicker` for the issued date.

**The screen composes its saved entity through a `_kSentinel` pattern** (`Object? field = _kSentinel`, then `identical(field, _kSentinel) ? orig.field : field as T?`). That exists precisely because `??` cannot express "set this to null" — reusing it is required for the issued date, which the user must be able to clear. Add the three fields to that compose method the same way.

Wrap ONLY the three new fields in the cloudApi guard:

```dart
if (ref.watch(dataModeProvider) != DataMode.cloudApi) ...[
  // registration number, jurisdiction, issued date
],
```

The expiry picker stays outside the guard — the API carries it.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/gas_log/automobile_registration_form_test.dart`
Expected: PASS

- [ ] **Step 6: Mutation-check the guard**

Remove the cloudApi guard. Expected: the cloudApi test fails. Restore it.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/gas_log lib/l10n test/features/gas_log
git commit -m "feat(automobile): edit registration details, hidden in cloudApi"
```

---

### Task 2b: Registration scans on the vehicle note

Added after a spec-coverage review: the spec puts registration scans on the vehicle's note, but `Automobile` exposes only `primaryImage` (a single `AttachmentRef?`), not the full set, and the edit screen has no attachments UI. This is the largest piece of Part A. **If you want Part A small, cut this task** — Tasks 1 and 2 deliver the registration *details* on their own, and scans can follow later.

**Files:**
- Modify: `lib/features/gas_log/domain/entities/automobile.dart`
- Modify: `lib/core/data/local/local_automobile_repository.dart`
- Modify: `lib/features/gas_log/presentation/screens/automobile_edit_screen.dart`
- Test: `test/core/data/local/local_automobile_attachments_test.dart`

**Interfaces:**
- Produces: `Automobile.attachments` (`NoteAttachments`), alongside the existing `primaryImage`.

- [ ] **Step 1: Write the failing test**

Against a real in-memory database, assert:

- a scan attached to a vehicle survives a create, and reads back
- it survives an unrelated edit (changing the plate) — the four rebuild sites from Task 1 apply here too
- it survives deactivation
- the car photo stays in `primaryImage` and is NOT adopted as a scan, and a scan is not promoted to the car photo
- removing a scan deletes its bytes only after the write lands

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/local/local_automobile_attachments_test.dart`
Expected: FAIL — `Automobile.attachments` does not exist.

- [ ] **Step 3: Expose the full attachment set**

Add `final NoteAttachments attachments;` to `Automobile`, defaulting via `NoteAttachments? attachments`) `: attachments = attachments ?? NoteAttachments.empty` — note this makes the constructor non-const, which is why `ServiceRecord` and `AutoInsurancePolicy` are non-const too. Check for `const Automobile(` call sites first; there were none for `AutoInsurancePolicy`.

`primaryImage` stays as it is: the car photo occupies the `primaryImage` slot, scans occupy `images`/`files`. In the repository, read it back with `note.effectiveAttachments` and write it with the existing `_attachmentsFor` pattern from `LocalServiceRecordRepository`.

Thread `attachments` through **all four rebuild sites** from Task 1.

- [ ] **Step 4: Add the section to the edit screen**

An `AttachmentsSection` under the Registration heading, following `service_record_form_screen.dart` — which is the reference for the pending/saved/removed item machinery, the `mounted` guards after each picker await, and passing picks to the save path. Persist picks with `sensitive: true`.

Put it inside the same `cloudApi` guard as the three new fields: attachments do not reach the API.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/data/local/local_automobile_attachments_test.dart`
Expected: PASS

- [ ] **Step 6: Mutation-check**

Drop `attachments:` from `deactivateAutomobile`. Expected: the deactivation test fails. Restore.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/gas_log lib/core/data/local test/core/data/local
git commit -m "feat(automobile): attach registration scans to a vehicle"
```

---

### Task 3: `DriverLicence` entity and codec

**Files:**
- Create: `lib/features/driver_licence/domain/driver_licence.dart`
- Create: `lib/features/driver_licence/data/driver_licence_codec.dart`
- Test: `test/features/driver_licence/driver_licence_codec_test.dart`

**Interfaces:**
- Produces: `DriverLicence` with `number`, `licenceClass`, `jurisdiction`, `issuedDate`, `expiryDate`, `frontImage`, `backImage` (both `VaultRef?`), `extraFields`, and `hasImages`; `DriverLicenceCodec.toMap` / `.fromMap(Map, NoteAttachments)`.

- [ ] **Step 1: Write the failing test**

Write `test/features/driver_licence/driver_licence_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/driver_licence/data/driver_licence_codec.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';

void main() {
  const front = VaultRef(
      path: 'attachments/note-1/front.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
      sensitive: true);
  const back = VaultRef(
      path: 'attachments/note-1/back.jpg',
      contentType: 'image/jpeg',
      byteSize: 100,
      sensitive: true);

  final attachments = NoteAttachments(images: const [front, back]);

  DriverLicence full() => DriverLicence(
        number: 'D1234-56789',
        licenceClass: 'G',
        jurisdiction: 'Ontario',
        issuedDate: DateTime.utc(2020, 5, 1),
        expiryDate: DateTime.utc(2030, 5, 1),
        frontImage: front,
        backImage: back,
      );

  test('round-trips a fully populated licence', () {
    expect(
      DriverLicenceCodec.fromMap(DriverLicenceCodec.toMap(full()), attachments),
      full(),
    );
  });

  test('round-trips a licence with only an expiry date', () {
    final sparse = DriverLicence(expiryDate: DateTime.utc(2030, 5, 1));
    expect(
      DriverLicenceCodec.fromMap(
          DriverLicenceCodec.toMap(sparse), NoteAttachments.empty),
      sparse,
    );
  });

  test('content records PATHS, not the refs themselves', () {
    // The bytes must be referenced from the attachments column so VaultGc sees
    // them; content only says which side each path is.
    final map = DriverLicenceCodec.toMap(full());
    expect(map['frontImagePath'], front.path);
    expect(map['backImagePath'], back.path);
    expect(map.containsKey('frontImage'), isFalse);
  });

  test('resolves each side from the attachments column by path', () {
    final decoded =
        DriverLicenceCodec.fromMap(DriverLicenceCodec.toMap(full()), attachments);
    expect(decoded.frontImage, front);
    expect(decoded.backImage, back);
  });

  test('a path with no matching attachment resolves to null, not a throw', () {
    // The mapping outlived the bytes; the rest of the licence must still read.
    final decoded = DriverLicenceCodec.fromMap(
        DriverLicenceCodec.toMap(full()), NoteAttachments.empty);
    expect(decoded.frontImage, isNull);
    expect(decoded.number, 'D1234-56789');
  });

  test('an attachment with no mapping is left alone, not adopted as a side', () {
    final decoded = DriverLicenceCodec.fromMap({'number': 'X'}, attachments);
    expect(decoded.frontImage, isNull);
    expect(decoded.backImage, isNull);
  });

  test('stores class and jurisdiction as literals', () {
    final map = DriverLicenceCodec.toMap(full());
    expect(map['licenceClass'], 'G');
    expect(map['jurisdiction'], 'Ontario');
  });

  test('unknown fields survive an edit', () {
    final decoded = DriverLicenceCodec.fromMap(
        {'number': 'X', 'futureThing': 'keep me'}, NoteAttachments.empty);
    final resaved = DriverLicenceCodec.toMap(decoded);
    expect(resaved['futureThing'], 'keep me');
  });

  test('a malformed date does not take the licence down', () {
    final decoded = DriverLicenceCodec.fromMap(
        {'number': 'X', 'expiryDate': 'not-a-date'}, NoteAttachments.empty);
    expect(decoded.number, 'X');
    expect(decoded.expiryDate, isNull);
  });

  test('hasImages is false only when both sides are absent', () {
    expect(const DriverLicence().hasImages, isFalse);
    expect(DriverLicence(frontImage: front).hasImages, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/driver_licence/driver_licence_codec_test.dart`
Expected: FAIL — the files do not exist.

- [ ] **Step 3: Write the entity**

Write `lib/features/driver_licence/domain/driver_licence.dart` with the fields listed in **Interfaces** above. Follow `lib/core/contact_block/contact_info.dart` for shape: const constructor, `final` fields, value `==`/`hashCode`, `extraFields` held privately and exposed as an `UnmodifiableMapView` (a plain field lets a caller edit the preservation map out from under the value object).

**Do not add a general `copyWith`.** `field ?? this.field` cannot express "clear this", which fails silently with wrong data. If a caller needs to change something, construct directly, or use the `_kSentinel` pattern from `automobile_edit_screen.dart`.

Document that `frontImage`/`backImage` bytes live in the note's attachments column.

- [ ] **Step 4: Write the codec**

Write `lib/features/driver_licence/data/driver_licence_codec.dart`:

- `toMap(DriverLicence)` — writes `extraFields` first so typed fields overwrite them, then the scalars, then `frontImagePath` / `backImagePath` taken from `frontImage?.path` / `backImage?.path`. Never writes the refs themselves.
- `fromMap(Map<String, dynamic>, NoteAttachments)` — reads scalars defensively (only consume a key when it holds the expected JSON type; anything else falls through to `extraFields`, exactly as `ContactInfoCodec` does), then resolves `frontImagePath` / `backImagePath` against `[...attachments.images, ...attachments.files]` by `path`, yielding null when there is no match.
- `_knownKeys` must include the two path keys so they do not leak into `extraFields`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/driver_licence/driver_licence_codec_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 6: Mutation-check the GC-safety guarantee**

Change `toMap` to write `'frontImage': ...` (a serialized ref) instead of `'frontImagePath'`.
Expected: `content records PATHS, not the refs themselves` fails. Restore.

This is the mutation that matters most in the whole plan: it is the difference between the licence photos surviving garbage collection and being deleted.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
git add lib/features/driver_licence test/features/driver_licence
git commit -m "feat(licence): add DriverLicence entity and GC-safe codec"
```

---

### Task 4: Licence repository

**Files:**
- Create: `lib/features/driver_licence/data/i_driver_licence_repository.dart`
- Create: `lib/core/data/local/local_driver_licence_repository.dart`
- Modify: `lib/core/data/repository_providers.dart`
- Test: `test/core/data/local/local_driver_licence_repository_test.dart`

**Interfaces:**
- Produces: `IDriverLicenceRepository` with `Future<DriverLicence?> getLicence()` and `Future<DriverLicence> saveLicence(DriverLicence, {List<PickedImageBytes> newFront, List<PickedImageBytes> newBack, List<VaultRef> removed})`; `driverLicenceCatalogName`; `kDriverLicenceSubject`; `localDriverLicenceRepositoryProvider`; `driverLicenceRepositoryModeProvider`.

- [ ] **Step 1: Write the failing test**

Write `test/core/data/local/local_driver_licence_repository_test.dart` against a real in-memory database, modelled on `test/core/data/local/local_insurance_repository_contacts_test.dart`. Assert:

- saving when none exists creates a note whose subject is exactly `DriverLicence:self`
- **saving twice UPDATES that one note rather than creating a second** — the singleton invariant
- `getLicence()` returns null when nothing has been saved
- details survive a save and read back whole
- a front image survives replacing the back image, and vice versa
- **both images appear in the note's `attachments` column**, so `VaultGc` will see them
- removed bytes are deleted only AFTER the write lands (drive it with a repository or note-layer stub that throws on the write, and assert the bytes survive — the same bug was found in both attachment notifiers)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/local/local_driver_licence_repository_test.dart`
Expected: FAIL — the repository does not exist.

- [ ] **Step 3: Write the interface and repository**

```dart
/// Three segments so `CatalogPalette.domainKeyFor` reads `AutomobileMan` as the
/// domain key and groups this with the rest of the vehicle domain.
const driverLicenceCatalogName = 'Hmm.AutomobileMan.DriverLicence';

/// There is exactly one licence, so the subject is fixed rather than derived.
/// A second save updates this note; it can never create a duplicate.
const kDriverLicenceSubject = 'DriverLicence:self';
```

Serialize like `LocalCheatsheetRepository` does — `{'note': {'content': {'DriverLicence': DriverLicenceCodec.toMap(l)}}}` — find the single note by subject within the catalog, and create or update it. Pass `attachments:` on both `HmmNoteCreate` and `HmmNoteUpdate` so the column always reflects the full set (an omitted set leaves a stale one behind).

**Persist new picks with `sensitive: true`** so they land in the encrypted vault.

**Delete removed bytes only after the write succeeds.** Deleting first means a failed save leaves the bytes gone while the note still lists their paths. Both existing attachment notifiers had this bug; do not reintroduce it.

- [ ] **Step 4: Wire the mode provider**

In `lib/core/data/repository_providers.dart`, beside the others:

```dart
final driverLicenceRepositoryModeProvider = Provider<IDriverLicenceRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (_useLocal(mode)) return ref.watch(localDriverLicenceRepositoryProvider);
  // No API exists for the licence; the UI hides the feature in this mode, so
  // reaching here is a wiring bug rather than a user-facing state.
  throw UnimplementedError('driver licence has no cloudApi repository');
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/data/local/local_driver_licence_repository_test.dart`
Expected: PASS

- [ ] **Step 6: Mutation-check the singleton and the delete ordering**

1. Change the subject to include a generated id. Expected: the "saving twice updates one note" test fails. Restore.
2. Move the delete back to before the write. Expected: the failed-write test fails. Restore.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/driver_licence lib/core/data test/core/data/local
git commit -m "feat(licence): add singleton local repository"
```

---

### Task 5: Licence ARB keys

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`

- [ ] **Step 1: Add the keys**

`app_en.arb`:

```json
"licenceTitle": "Driver's licence",
"licenceEmpty": "No licence saved yet",
"licenceAdd": "Add licence",
"licenceEdit": "Edit licence",
"licenceNumber": "Licence number",
"licenceClass": "Class",
"licenceJurisdiction": "Province / State",
"licenceIssued": "Issued",
"licenceExpires": "Expires",
"licenceFront": "Front",
"licenceBack": "Back",
"licenceCaptureFront": "Capture front",
"licenceCaptureBack": "Capture back",
"licenceShow": "Show licence",
"licenceNoImages": "No photo captured yet"
```

`app_zh.arb`:

```json
"licenceTitle": "驾驶证",
"licenceEmpty": "尚未保存驾驶证",
"licenceAdd": "添加驾驶证",
"licenceEdit": "编辑驾驶证",
"licenceNumber": "证件号码",
"licenceClass": "准驾车型",
"licenceJurisdiction": "省 / 州",
"licenceIssued": "发证日期",
"licenceExpires": "有效期至",
"licenceFront": "正面",
"licenceBack": "反面",
"licenceCaptureFront": "拍摄正面",
"licenceCaptureBack": "拍摄反面",
"licenceShow": "出示驾驶证",
"licenceNoImages": "尚未拍摄照片"
```

> Unreviewed by a native speaker. `准驾车型` for licence class is a mainland convention; confirm it reads right for your context.

- [ ] **Step 2: Regenerate and verify parity**

```bash
cd ~/Projects/hmm_console
flutter gen-l10n
python3 -c "
import json
en = json.load(open('lib/l10n/app_en.arb')); zh = json.load(open('lib/l10n/app_zh.arb'))
ek = {k for k in en if not k.startswith('@')}; zk = {k for k in zh if not k.startswith('@')}
print('en', len(ek), 'zh', len(zk)); print('missing from zh:', sorted(ek-zk)); print('missing from en:', sorted(zk-ek))
"
```

Expected: equal counts, both lists empty.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n && git commit -m "feat(licence): add en/zh strings"
```

---

### Task 6: Licence screen

**Files:**
- Create: `lib/features/driver_licence/states/driver_licence_state.dart`
- Create: `lib/features/driver_licence/presentation/screens/driver_licence_screen.dart`
- Test: `test/features/driver_licence/driver_licence_screen_test.dart`

**Interfaces:**
- Consumes: `driverLicenceRepositoryModeProvider` (Task 4).
- Produces: `DriverLicenceState extends AsyncNotifier<DriverLicence?>` with `save(DriverLicence, {List<PickedImageBytes> newFront, List<PickedImageBytes> newBack, List<VaultRef> removed})` - the same parameter names the repository takes, so nothing is renamed in transit; `driverLicenceStateProvider`; `DriverLicenceScreen`.

- [ ] **Step 1: Write the state**

Mirror `lib/features/cheatsheet/states/cheatsheets_state.dart`: read through the repository, write through it, then `ref.invalidateSelf()` rather than patching in memory.

- [ ] **Step 2: Write the failing widget test**

Assert:

- an empty repository shows `licenceEmpty` and a capture affordance
- a saved licence renders number, class, jurisdiction, issued and expiry
- front and back thumbnails appear in their own labelled slots (`licenceFront` / `licenceBack`)
- a licence with only a front image shows the front and an empty back slot — not an error
- editing a field and saving passes the change to the repository, preserving the images
- a double-tapped save calls the repository once (re-entrancy guard)

Supply the localization delegates on the `MaterialApp`, or the widget throws while building.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/driver_licence/driver_licence_screen_test.dart`
Expected: FAIL — the screen does not exist.

- [ ] **Step 4: Write the screen**

Details as editable fields (`AppTextFormField`, `_optionalDatePicker`-style pickers), two labelled image slots each with capture/replace, and a prominent action opening the show-mode (Task 7). Guard `save()` with an in-flight flag so a second tap is ignored — a double-tapped save has created duplicate records in this codebase before.

- [ ] **Step 5: Run test to verify it passes / Step 6: Mutation-check the re-entrancy guard**

Remove the in-flight flag. Expected: the double-tap test fails. Restore.

- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
git add lib/features/driver_licence test/features/driver_licence
git commit -m "feat(licence): add licence screen"
```

---

### Task 7: Show mode

**Files:**
- Create: `lib/features/driver_licence/presentation/screens/licence_show_screen.dart`
- Test: `test/features/driver_licence/licence_show_screen_test.dart`

**Interfaces:**
- Consumes: `DriverLicence` (Task 3); `lib/core/data/attachments/widgets/fullscreen_image.dart`.

- [ ] **Step 1: Write the failing test**

Assert:

- opens on the front image
- tapping (or swiping) flips to the back, and back again
- the correct image renders in each side — a mutation that swaps front and back must fail this
- the licence number and expiry are readable on screen, for a checker who wants the number rather than the photo
- a licence with only a front image does not offer a flip, and does not error
- a licence with no images at all shows `licenceNoImages` rather than a blank screen

- [ ] **Step 2: Run test to verify it fails / Step 3: Write the screen**

Full-screen, reusing `fullscreen_image.dart`. **No brightness or wakelock control** — those need `screen_brightness` and `wakelock_plus`, two new platform plugins, deliberately deferred. If you find yourself adding a dependency here, stop: that is a scope change, not an implementation detail.

- [ ] **Step 4: Run test to verify it passes / Step 5: Mutation-check the side mapping**

Swap `frontImage` and `backImage` at the render site. Expected: the correct-image-per-side test fails. Restore.

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/hmm_console
git add lib/features/driver_licence test/features/driver_licence
git commit -m "feat(licence): add full-screen show mode"
```

---

### Task 8: Navigation and entry points

**Files:**
- Modify: `lib/core/navigation/route_names.dart`
- Create: `lib/core/navigation/driver_licence_routes.dart`
- Modify: the router that assembles the route list (find it with `grep -rn "cheatsheetRoutes" lib/core/navigation/`)
- Modify: the dashboard, and `lib/features/launcher/domain/launcher_registry.dart`
- Test: `test/features/driver_licence/driver_licence_routes_test.dart`

- [ ] **Step 1: Write the failing test**

Assert both routes land on the right screens; the dashboard tile **navigates for real** and arrives at the licence screen (a tile that renders but routes nowhere passes a weaker test); and the launcher finds the destination by typing `lic`.

- [ ] **Step 2: Run test to verify it fails / Step 3: Add routes, tile and launcher destination**

Follow `cheatsheet_routes.dart`. In the launcher registry, the destination `id` and `routeName` stay **literal** — favorites persist by id, so a locale-dependent id would orphan every favorite on a language change. The `title` is localized, and the English term is **added to** `synonyms` rather than replacing them, so a bilingual user on a Chinese UI can still type `licence`.

**Hide both entry points in `cloudApi`**, since the repository throws there.

- [ ] **Step 4: Run test to verify it passes / Step 5: Mutation-check**

Point the dashboard tile at a nonexistent route. Expected: the navigation test fails. Restore.

- [ ] **Step 6: Commit**

```bash
cd ~/Projects/hmm_console
flutter analyze
flutter test
git add lib/core/navigation lib/features test/features
git commit -m "feat(licence): add routes, dashboard tile and launcher destination"
```

---

### Task 9: Full verification

- [ ] **Step 1: Analyzer** — `flutter analyze`. Expected: only the 2 pre-existing issues.
- [ ] **Step 2: Full suite** — `flutter test`. Expected: all pass. It stood at 1404 before this work. Run it in the background if it exceeds the foreground timeout.
- [ ] **Step 3: ARB parity** — rerun the parity script from Task 5, Step 2. Expected: equal counts, no differences.
- [ ] **Step 4: No hardcoded strings** — `grep -rnE "Text\('[A-Z]" lib/features/driver_licence/ || echo clean`. Expected: `clean`.
- [ ] **Step 5: GC safety, by hand.** Save a licence with both images, run whatever exercises `VaultGc`, then reopen the licence. **Both images must still be there.** This is the one failure a green suite could still miss, and its cost is the user's licence photos.
- [ ] **Step 6: Walk it in both languages** on a device — switch language in Settings and check the licence screen and show mode. The Chinese strings are unreviewed.
- [ ] **Step 7: Commit**

```bash
cd ~/Projects/hmm_console
git add -A lib test docs && git commit -m "chore(licence): verify analyzer, suite and en/zh parity"
```

---

## Out of scope

- **Expiry reminders** for registration, licence or insurance — all three carry expiry dates and none is surfaced as a warning today. The natural next feature; not needed to store the data.
- **Family members' licences.** Deliberate: adding one later means migrating a singleton to a collection, and probably reviving Contacts (#31).
- **Brightness and wakelock** in show mode — two new platform plugins.
- **Cheatsheet wallet rendering the licence images.** Wallet rows resolve to scalars (`NotePieceExtractor.field` returns `String?`); a row can already bind the licence number or expiry as text.
- **Backend work**: adding the three registration fields to the automobile API DTO (small, and the right long-term fix), and any API at all for the licence.
