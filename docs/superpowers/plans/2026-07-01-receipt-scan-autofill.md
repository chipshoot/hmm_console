# Receipt Scan Auto-Fill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user scan a receipt (photo or PDF) on the service-record form and have the fields pre-fill for review, via two user-selectable extractors: on-device OCR and cloud AI.

**Architecture:** A `receipt_scan/` feature module (Flutter) with a `ReceiptExtractor` interface and two impls selected by a persisted preference, mirroring `DataMode`. A pure `applyDraft` merge fills the form (fill-empty scalars, append line items). Cloud AI is a new `POST /v1/receipts/extract` endpoint (.NET) that calls Claude Haiku 4.5 via the official Anthropic C# SDK with structured outputs. The scanned receipt is kept as an attachment (reusing the shipped attachment system).

**Tech Stack:** Flutter, Riverpod, `google_mlkit_text_recognition`, `image_picker`/`file_picker`, `shared_preferences`; .NET 10 `Hmm.ServiceApi`, official `Anthropic` C# SDK, `HttpClient`-style DI.

**Two phases — each independently shippable:**
- **Phase A (Tasks 1–8): on-device only, NO backend.** Ships a working "Scan receipt" feature using on-device OCR. Stop-and-ship point.
- **Phase B (Tasks 9–13): Cloud AI.** Backend endpoint + client `ApiLlmExtractor`, layered on top.

---

## Reference reading (skim before starting)

- `docs/superpowers/specs/2026-07-01-receipt-scan-autofill-design.md` — the design (contract, mapping table, UX, error handling).
- `docs/superpowers/specs/2026-06-29-service-record-attachments-design.md` + `lib/core/data/attachments/` — the attachment system reused for keeping the receipt.
- `lib/core/data/data_mode.dart` + `lib/core/data/repository_providers.dart` — the mode-preference + provider-selection pattern to mirror.
- `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart` — the form to wire into (already has pending-pick lists from the attachments feature).
- Backend precedent (`~/projects/hmm`): `src/Hmm.Utility.Services/{IGeocodingService.cs,GeocodingSettings.cs,NominatimGeocodingService.cs}`, `src/Hmm.ServiceApi/Areas/UtilityService/Controllers/GeocodingController.cs`, and how they're registered in `Startup.cs`.
- `claude-api` skill (C# doc) — Anthropic C# SDK: `dotnet add package Anthropic`, `Model.ClaudeHaiku4_5`, `DocumentBlockParam`/`Base64PdfSource`, `OutputConfig`/`JsonOutputFormat`. **Verify exact image-block + structured-output type names against the SDK repo before writing** — do not guess bindings.

## File Structure

**Phase A — Flutter (create):**
- `lib/features/receipt_scan/domain/receipt_draft.dart` — `ReceiptInput`, `ReceiptDraft`, `ReceiptLineItem`, `ReceiptExtractorMode`, `ReceiptExtractionException`.
- `lib/features/receipt_scan/domain/receipt_extractor.dart` — the `ReceiptExtractor` interface.
- `lib/features/receipt_scan/domain/apply_draft.dart` — pure merge into a form-value object.
- `lib/features/receipt_scan/data/receipt_text_parser.dart` — pure OCR-text heuristics.
- `lib/features/receipt_scan/data/on_device_ocr_extractor.dart` — ML Kit wrapper.
- `lib/features/receipt_scan/providers/receipt_extractor_providers.dart` — mode notifier + `receiptExtractorProvider`.
- `lib/features/receipt_scan/presentation/scan_receipt_flow.dart` — the pick→persist-as-attachment→extract→apply orchestration helper.
- Tests mirroring each.

**Phase A — Flutter (modify):**
- `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart` — "Scan receipt" button + apply draft.
- `lib/features/settings/presentation/screens/settings_screen.dart` — extractor-mode setting + first-use consent.
- `pubspec.yaml` — add `google_mlkit_text_recognition`.

**Phase B — .NET (create):** `AnthropicSettings.cs`, `IReceiptExtractionService.cs` + `ClaudeReceiptExtractionService.cs` (in `Hmm.Utility.Services`), `ReceiptExtractionController.cs` (UtilityService area), `ApiReceiptDraft` DTOs, tests.
**Phase B — Flutter (create/modify):** `lib/features/receipt_scan/data/api_llm_extractor.dart`; wire `cloudAi` into `receiptExtractorProvider`.

---

# PHASE A — On-device vertical slice (no backend)

### Task 1: Extraction contract

**Files:** Create `lib/features/receipt_scan/domain/receipt_draft.dart`, `.../receipt_extractor.dart`. Test: `test/features/receipt_scan/domain/receipt_draft_test.dart`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

void main() {
  test('empty draft has null scalars and no line items', () {
    const d = ReceiptDraft(source: ReceiptExtractorMode.onDevice);
    expect(d.shopName, isNull);
    expect(d.lineItems, isEmpty);
  });

  test('ReceiptExtractorMode round-trips through its wire value', () {
    expect(ReceiptExtractorMode.fromWire('cloudAi'), ReceiptExtractorMode.cloudAi);
    expect(ReceiptExtractorMode.onDevice.wire, 'onDevice');
    expect(ReceiptExtractorMode.fromWire('nonsense'), ReceiptExtractorMode.onDevice);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`flutter test test/features/receipt_scan/domain/receipt_draft_test.dart > /tmp/r1.txt 2>&1; echo EXIT $?`).

- [ ] **Step 3: Implement the contract**

`receipt_draft.dart`:
```dart
import 'dart:typed_data';

import '../../automobile_records/domain/entities/line_item_type.dart';
import '../../automobile_records/domain/entities/service_type.dart';

enum ReceiptExtractorMode {
  onDevice('onDevice'),
  cloudAi('cloudAi');

  const ReceiptExtractorMode(this.wire);
  final String wire;

  static ReceiptExtractorMode fromWire(String? s) =>
      ReceiptExtractorMode.values.firstWhere(
        (m) => m.wire == s,
        orElse: () => ReceiptExtractorMode.onDevice,
      );
}

class ReceiptInput {
  const ReceiptInput({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType; // image/* or application/pdf
  bool get isPdf => contentType == 'application/pdf';
}

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.type,
    required this.name,
    this.quantity = 1,
    this.unitCost,
  });
  final LineItemType type;
  final String name;
  final int quantity;
  final double? unitCost;
}

class ReceiptDraft {
  const ReceiptDraft({
    required this.source,
    this.shopName,
    this.date,
    this.odometer,
    this.serviceType,
    this.lineItems = const [],
    this.tax,
    this.total,
    this.currency,
    this.rawText,
  });

  final ReceiptExtractorMode source;
  final String? shopName;
  final DateTime? date;
  final int? odometer;
  final ServiceType? serviceType;
  final List<ReceiptLineItem> lineItems;
  final double? tax;
  final double? total;
  final String? currency;
  final String? rawText;
}

class ReceiptExtractionException implements Exception {
  const ReceiptExtractionException(this.message);
  final String message;
  @override
  String toString() => 'ReceiptExtractionException: $message';
}
```

`receipt_extractor.dart`:
```dart
import 'receipt_draft.dart';

/// Extracts a [ReceiptDraft] from a receipt image/PDF. Implementations fill
/// what they can; unfound fields stay null. Throws [ReceiptExtractionException]
/// on failure.
abstract interface class ReceiptExtractor {
  Future<ReceiptDraft> extract(ReceiptInput input);
}
```

- [ ] **Step 4: Run — expect PASS.** Analyze the two files. Commit:
```
feat(receipt-scan): extraction contract (ReceiptDraft, ReceiptExtractor, mode)
```

---

### Task 2: `applyDraft` merge (pure)

The merge fills a value object the form binds to. Fill-empty scalars, append line items, flag totals mismatch.

**Files:** Create `lib/features/receipt_scan/domain/apply_draft.dart`. Test: `test/features/receipt_scan/domain/apply_draft_test.dart`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/receipt_scan/domain/apply_draft.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

ReceiptDraft _draft() => ReceiptDraft(
      source: ReceiptExtractorMode.cloudAi,
      shopName: 'Bob Auto',
      date: DateTime(2026, 3, 2),
      odometer: 45000,
      tax: 3.5,
      total: 53.5,
      currency: 'CAD',
      lineItems: const [
        ReceiptLineItem(type: LineItemType.labour, name: 'Oil change', unitCost: 40),
        ReceiptLineItem(type: LineItemType.part, name: 'Filter', unitCost: 10),
      ],
    );

void main() {
  test('fills empty scalars and appends line items', () {
    final before = ScanFormValues.empty();
    final r = applyDraft(before, _draft());
    expect(r.values.shopName, 'Bob Auto');
    expect(r.values.mileage, 45000);
    expect(r.values.tax, 3.5);
    expect(r.values.currency, 'CAD');
    expect(r.values.items, hasLength(2));
    expect(r.filledScalarCount, greaterThan(0));
    expect(r.appendedItemCount, 2);
  });

  test('never overwrites a filled scalar', () {
    final before = ScanFormValues.empty().copyWith(shopName: 'My Shop');
    final r = applyDraft(before, _draft());
    expect(r.values.shopName, 'My Shop'); // preserved
  });

  test('appends items onto existing ones', () {
    final before = ScanFormValues.empty().copyWith(
      items: const [PartItem(type: LineItemType.fee, name: 'Shop fee', quantity: 1, unitCost: 5)],
    );
    final r = applyDraft(before, _draft());
    expect(r.values.items, hasLength(3));
  });

  test('flags a totals mismatch', () {
    final mismatch = ReceiptDraft(
      source: ReceiptExtractorMode.cloudAi,
      total: 999,
      tax: 3.5,
      lineItems: const [ReceiptLineItem(type: LineItemType.labour, name: 'x', unitCost: 40)],
    );
    final r = applyDraft(ScanFormValues.empty(), mismatch);
    expect(r.totalsMismatch, isTrue);
  });
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

`apply_draft.dart`:
```dart
import '../../automobile_records/domain/entities/part_item.dart';
import '../../automobile_records/domain/entities/service_type.dart';
import 'receipt_draft.dart';

/// Mutable-ish snapshot of the scalar + line-item fields the scan can fill.
/// The form maps its controllers to/from this.
class ScanFormValues {
  const ScanFormValues({
    this.shopName,
    this.date,
    this.mileage,
    this.type,
    this.tax,
    this.currency,
    this.items = const [],
  });

  factory ScanFormValues.empty() => const ScanFormValues();

  final String? shopName;
  final DateTime? date;
  final int? mileage;
  final ServiceType? type;
  final double? tax;
  final String? currency;
  final List<PartItem> items;

  ScanFormValues copyWith({
    String? shopName,
    DateTime? date,
    int? mileage,
    ServiceType? type,
    double? tax,
    String? currency,
    List<PartItem>? items,
  }) =>
      ScanFormValues(
        shopName: shopName ?? this.shopName,
        date: date ?? this.date,
        mileage: mileage ?? this.mileage,
        type: type ?? this.type,
        tax: tax ?? this.tax,
        currency: currency ?? this.currency,
        items: items ?? this.items,
      );
}

class ApplyDraftResult {
  const ApplyDraftResult({
    required this.values,
    required this.filledScalarCount,
    required this.appendedItemCount,
    required this.totalsMismatch,
  });
  final ScanFormValues values;
  final int filledScalarCount;
  final int appendedItemCount;
  final bool totalsMismatch;
}

/// Pure merge: fills only currently-empty scalars, appends the draft's line
/// items to any existing rows, and flags a soft totals mismatch.
ApplyDraftResult applyDraft(ScanFormValues form, ReceiptDraft draft) {
  var filled = 0;
  bool isBlank(Object? v) => v == null || (v is String && v.trim().isEmpty);

  String? shopName = form.shopName;
  if (isBlank(shopName) && !isBlank(draft.shopName)) { shopName = draft.shopName; filled++; }
  DateTime? date = form.date;
  if (date == null && draft.date != null) { date = draft.date; filled++; }
  int? mileage = form.mileage;
  if (mileage == null && draft.odometer != null) { mileage = draft.odometer; filled++; }
  ServiceType? type = form.type;
  if (type == null && draft.serviceType != null) { type = draft.serviceType; filled++; }
  double? tax = form.tax;
  if (tax == null && draft.tax != null) { tax = draft.tax; filled++; }
  String? currency = form.currency;
  if (isBlank(currency) && !isBlank(draft.currency)) { currency = draft.currency; filled++; }

  final appended = [
    for (final li in draft.lineItems)
      PartItem(
        type: li.type,
        name: li.name,
        quantity: li.quantity,
        unitCost: li.unitCost,
        currency: currency ?? form.currency ?? 'CAD',
      ),
  ];
  final items = [...form.items, ...appended];

  // Totals mismatch: compare the draft's stated total against the computed
  // subtotal (sum of appended items) + tax, when a total is present.
  var mismatch = false;
  if (draft.total != null) {
    final subtotal = appended.fold<double>(0, (s, p) => s + (p.unitCost ?? 0) * p.quantity);
    final computed = subtotal + (tax ?? 0);
    mismatch = (computed - draft.total!).abs() > 0.01;
  }

  return ApplyDraftResult(
    values: form.copyWith(
      shopName: shopName, date: date, mileage: mileage, type: type,
      tax: tax, currency: currency, items: items,
    ),
    filledScalarCount: filled,
    appendedItemCount: appended.length,
    totalsMismatch: mismatch,
  );
}
```

> Note: `copyWith` here fills-empty only because callers pass already-merged values; the merge logic itself enforces fill-empty. Verify `PartItem`'s constructor params (`type`,`name`,`quantity`,`unitCost`,`currency`) against `part_item.dart` and adjust if they differ.

- [ ] **Step 4: Run — expect PASS.** Analyze. Commit:
```
feat(receipt-scan): pure applyDraft merge (fill-empty scalars, append items)
```

---

### Task 3: `ReceiptTextParser` (pure heuristics)

**Files:** Create `lib/features/receipt_scan/data/receipt_text_parser.dart`. Test: `test/features/receipt_scan/data/receipt_text_parser_test.dart`.

- [ ] **Step 1: Write the failing test** (table of sample receipt texts)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/data/receipt_text_parser.dart';

const _sample = '''
BOB'S AUTO SERVICE
123 Main St
Date: 2026-03-02
Oil Change        40.00
Oil Filter        10.00
GST               3.50
TOTAL            53.50
''';

void main() {
  test('pulls shop, date, tax, total, currency from typical text', () {
    final d = const ReceiptTextParser().parse(_sample);
    expect(d.shopName, "BOB'S AUTO SERVICE");
    expect(d.date, DateTime(2026, 3, 2));
    expect(d.tax, 3.50);
    expect(d.total, 53.50);
    expect(d.lineItems, isEmpty); // on-device does not itemize
    expect(d.rawText, _sample);
  });

  test('returns nulls (never throws) on empty/garbage', () {
    final d = const ReceiptTextParser().parse('   \n  ');
    expect(d.total, isNull);
    expect(d.shopName, isNull);
  });
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement** the parser as a pure class: `parse(String text) → ReceiptDraft` (source `onDevice`, `lineItems: const []`, `rawText: text`). Heuristics:
  - `shopName`: first non-empty trimmed line.
  - `date`: first regex match of `\d{4}-\d{2}-\d{2}` or `\d{1,2}/\d{1,2}/\d{2,4}` → `DateTime`.
  - amount regex: `RegExp(r'(\d+[.,]\d{2})')`.
  - `tax`: amount on the last line matching `RegExp(r'\b(tax|gst|hst|vat|pst)\b', caseSensitive: false)`.
  - `total`: amount on the last line matching `RegExp(r'\b(total|amount due|balance)\b', caseSensitive: false)` (exclude "subtotal").
  - `currency`: `$`→ null-or-`CAD` heuristic (leave null unless a symbol maps cleanly; keep simple — return null when unsure).
  Wrap the whole body so it never throws; return partial `ReceiptDraft` on any parse error.

- [ ] **Step 4: Run — expect PASS.** Analyze. Commit:
```
feat(receipt-scan): ReceiptTextParser heuristics for on-device OCR
```

---

### Task 4: `OnDeviceOcrExtractor` (ML Kit wrapper)

**Files:** `pubspec.yaml` (add `google_mlkit_text_recognition`), create `lib/features/receipt_scan/data/on_device_ocr_extractor.dart`. Test: `test/features/receipt_scan/data/on_device_ocr_extractor_test.dart`.

- [ ] **Step 1: Add the dependency**

`flutter pub add google_mlkit_text_recognition` — then `flutter pub get > /tmp/r4.txt 2>&1; echo EXIT $?`.

- [ ] **Step 2: Write the failing test** — inject a fake text source so no plugin is needed:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/data/on_device_ocr_extractor.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

void main() {
  test('delegates recognized text to the parser and sets rawText', () async {
    final ex = OnDeviceOcrExtractor(recognize: (_) async => 'SHOP\nTOTAL 10.00');
    final d = await ex.extract(ReceiptInput(
        bytes: Uint8List.fromList([1]), contentType: 'image/jpeg'));
    expect(d.total, 10.0);
    expect(d.rawText, 'SHOP\nTOTAL 10.00');
    expect(d.source, ReceiptExtractorMode.onDevice);
  });

  test('rejects PDF input on-device', () async {
    final ex = OnDeviceOcrExtractor(recognize: (_) async => '');
    expect(
      () => ex.extract(ReceiptInput(bytes: Uint8List(0), contentType: 'application/pdf')),
      throwsA(isA<ReceiptExtractionException>()),
    );
  });
}
```

- [ ] **Step 3: Implement**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../domain/receipt_draft.dart';
import '../domain/receipt_extractor.dart';
import 'receipt_text_parser.dart';

/// Injectable so tests bypass ML Kit. Production writes bytes to a temp file
/// and runs TextRecognizer on it.
typedef RecognizeText = Future<String> Function(Uint8List imageBytes);

class OnDeviceOcrExtractor implements ReceiptExtractor {
  OnDeviceOcrExtractor({RecognizeText? recognize, ReceiptTextParser? parser})
      : _recognize = recognize ?? _mlkitRecognize,
        _parser = parser ?? const ReceiptTextParser();

  final RecognizeText _recognize;
  final ReceiptTextParser _parser;

  @override
  Future<ReceiptDraft> extract(ReceiptInput input) async {
    if (input.isPdf) {
      throw const ReceiptExtractionException(
          'PDF receipts need Cloud AI extraction. Use a photo, or switch to Cloud AI.');
    }
    try {
      final text = await _recognize(input.bytes);
      if (text.trim().isEmpty) {
        throw const ReceiptExtractionException('No text found in the image.');
      }
      return _parser.parse(text);
    } on ReceiptExtractionException {
      rethrow;
    } catch (e) {
      throw ReceiptExtractionException('Could not read the receipt: $e');
    }
  }

  static Future<String> _mlkitRecognize(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'receipt-ocr-${bytes.length}.jpg'));
    await file.writeAsBytes(bytes);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
```

> Verify `TextRecognizer` / `InputImage.fromFilePath` / `TextRecognitionScript` names against the installed `google_mlkit_text_recognition` version; adjust if the API differs.

- [ ] **Step 4: Run — expect PASS.** Analyze. Commit:
```
feat(receipt-scan): OnDeviceOcrExtractor (ML Kit + parser), PDF rejected
```

---

### Task 5: Extractor-mode preference + provider

**Files:** Create `lib/features/receipt_scan/providers/receipt_extractor_providers.dart`. Test: `test/features/receipt_scan/providers/receipt_extractor_providers_test.dart`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/data/on_device_ocr_extractor.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:hmm_console/features/receipt_scan/providers/receipt_extractor_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to onDevice and returns the on-device extractor', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(receiptExtractorModeProvider), ReceiptExtractorMode.onDevice);
    expect(c.read(receiptExtractorProvider), isA<OnDeviceOcrExtractor>());
  });

  test('setMode persists and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(receiptExtractorModeProvider.notifier).setMode(ReceiptExtractorMode.cloudAi);
    expect((await SharedPreferences.getInstance()).getString('receipt_extractor_mode'), 'cloudAi');
  });
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement** a `ReceiptExtractorModeNotifier extends Notifier<ReceiptExtractorMode>` (mirror `DataModeNotifier`: `build()` returns `onDevice` + fire-and-forget prefs load; `setMode` writes `shared_preferences` key `receipt_extractor_mode`). `receiptExtractorProvider` returns `OnDeviceOcrExtractor()` for `onDevice`. **Phase A: `cloudAi` also returns `OnDeviceOcrExtractor()` for now** with a `// TODO(phase B): ApiLlmExtractor` — so the setting is functional before the backend lands. (Task 13 swaps in the real cloud extractor.)

- [ ] **Step 4: Run — expect PASS.** Analyze. Commit:
```
feat(receipt-scan): extractor-mode preference + provider (cloudAi stubbed to on-device)
```

---

### Task 6: Scan orchestration helper

Pick → persist-as-attachment (reuse the shipped picker) → extract → return an `ApplyDraftResult` + the new `VaultRef`. Keeps the form thin and is state-testable.

**Files:** Create `lib/features/receipt_scan/presentation/scan_receipt_flow.dart`. Test: `test/features/receipt_scan/presentation/scan_receipt_flow_test.dart`.

- [ ] **Step 1: Write the failing test** — override `receiptExtractorProvider` with a fake returning a fixed draft, and a fake vault/picker (reuse the `_MemVault`/`_FakePicker` pattern from `mutate_service_record_attachments_test.dart`); assert the returned result applied the draft and produced a `VaultRef`, and that an extractor throw surfaces as a `ReceiptScanFailure` without losing the attachment.

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement** `scanReceipt({required WidgetRef ref, required int? noteId, required ReceiptInput input, required ScanFormValues current})`:
  1. Persist the bytes to the vault via the existing picker (`persistToVault` for images / `persistFileToVault` for PDFs) **only when a noteId exists and mode != cloudApi**; otherwise hold the raw pick to attach on save (return it so the form adds it to its pending list).
  2. `final draft = await ref.read(receiptExtractorProvider).extract(input);`
  3. `final applied = applyDraft(current, draft);`
  4. Return a small result record: `(applied, pendingImage?, pendingFile?, error?)`.

  Wrap extraction in try/catch → return a failure result with the message; the attachment/pending pick is preserved regardless.

- [ ] **Step 4: Run — expect PASS.** Analyze. Commit:
```
feat(receipt-scan): scanReceipt orchestration (persist + extract + applyDraft)
```

---

### Task 7: Wire "Scan receipt" into the form

**Files:** Modify `service_record_form_screen.dart`. (No new test — covered by Tasks 2/3/6 + manual smoke.)

- [ ] **Step 1** Add a prominent "Scan a receipt" button at the top of the form body, with a subtitle showing the active mode (`ref.watch(receiptExtractorModeProvider)`). Hide it in `cloudApi` **data** mode only if you also want to skip keeping the attachment — otherwise show it (extraction still works; the receipt just isn't kept, per the spec).

- [ ] **Step 2** On tap, show a source sheet (Camera / Photo / File-PDF), reusing `imageByteSourceProvider` / `fileByteSourceProvider`. **Disable the PDF option when `receiptExtractorModeProvider == onDevice`** with a hint ("PDF receipts need Cloud AI").

- [ ] **Step 3** Build a `ReceiptInput` from the pick, show a non-blocking progress indicator, call `scanReceipt(...)` with a `ScanFormValues` snapshot of the current controllers. On success: write the returned `ScanFormValues` back into the controllers/state (only-empty already enforced by the merge), add the returned pending pick to the form's `_pendingImages`/`_pendingFiles`, and show a summary SnackBar ("Filled N fields and M line items — review before saving"); show the totals-mismatch note if flagged. On failure: SnackBar with the message; controllers untouched; pending pick still added.

- [ ] **Step 4** Analyze + run the automobile-records + receipt_scan suites:
```
flutter analyze lib/features > /tmp/r7.txt 2>&1; echo EXIT $?
flutter test test/features/automobile_records test/features/receipt_scan > /tmp/r7b.txt 2>&1; echo EXIT $?
```
Commit:
```
feat(receipt-scan): Scan-receipt button + apply draft on the service-record form
```

---

### Task 8: Settings — extractor mode + first-use consent

**Files:** Modify `settings_screen.dart`. Test: a widget test asserting the toggle persists and the consent sheet appears once.

- [ ] **Step 1** Write a widget test: tapping "Cloud AI" the first time shows a consent dialog; confirming persists `receiptExtractorMode = cloudAi` and sets a `receipt_cloud_consent = true` flag; a second switch does not re-prompt.

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3** Add a "Receipt extraction" section: two options (On-device (private) / Cloud AI (more accurate)). Selecting Cloud AI checks a `receipt_cloud_consent` pref; if unset, show a one-time consent sheet explaining the receipt is uploaded to the backend, and set the flag on confirm. Persist the mode via `receiptExtractorModeProvider.notifier.setMode`.

- [ ] **Step 4: Run — expect PASS.** Analyze. Commit:
```
feat(receipt-scan): settings toggle + one-time Cloud-AI consent
```

**► Phase A ship point.** Full analyze + full test suite green → this is a mergeable, on-device-only feature. (Cloud AI selection currently behaves as on-device until Phase B.)

---

# PHASE B — Cloud AI (backend + client)

> Backend work is in `~/projects/hmm`. Follow the `IGeocodingService` precedent exactly (typed-`HttpClient` DI, `ProcessingResult<T>`, `[ApiVersion("1.0")]` controller). After any entity/DI change, run `dotnet build Hmm.sln -c Release`. Deploy is out of scope for this plan (use `scripts/deploy-api.sh --deploy` when ready).

### Task 9: `AnthropicSettings` + service interface + DTOs

**Files (create, `~/projects/hmm`):** `src/Hmm.Utility.Services/AnthropicSettings.cs`, `src/Hmm.Utility.Services/IReceiptExtractionService.cs`, DTO(s) in `src/Hmm.ServiceApi.DtoEntity/Utility/`. Test project: `src/Hmm.ServiceApi.Core.Tests`.

- [ ] **Step 1** `AnthropicSettings` (mirror `GeocodingSettings`): `SectionName = "AnthropicSettings"`, `ApiKey`, `Model = "claude-haiku-4-5"`, `BaseUrl` (optional), `MaxTokens = 2048`. Add the section to `appsettings.json` with the key sourced from the environment on the VPS (never commit the key).

- [ ] **Step 2** `IReceiptExtractionService`:
```csharp
Task<ProcessingResult<ReceiptDraftDto>> ExtractAsync(byte[] bytes, string contentType);
```
`ReceiptDraftDto` + `ReceiptLineItemDto` mirror the Flutter `ReceiptDraft` (shop, date, odometer, serviceType, lineItems[type,name,quantity,unitCost], tax, total, currency). `type` values match `LineItemType` wire values.

- [ ] **Step 3** Build (`dotnet build Hmm.sln -c Release`). Commit:
```
feat(receipts): AnthropicSettings + IReceiptExtractionService + ReceiptDraftDto
```

---

### Task 10: `ClaudeReceiptExtractionService`

Calls Claude Haiku 4.5 with the receipt as an image/PDF content block + **structured outputs** (`output_config.format` with the `ReceiptDraftDto` JSON schema), then deserializes.

**Files:** `src/Hmm.Utility.Services/ClaudeReceiptExtractionService.cs`. Test: `src/Hmm.ServiceApi.Core.Tests/ClaudeReceiptExtractionServiceTests.cs`.

- [ ] **Step 1** Add the SDK: from the repo root, `dotnet add src/Hmm.Utility.Services package Anthropic`.

- [ ] **Step 2: Write the failing test** — inject a fake so no network is hit. Prefer constructor-injecting an `AnthropicClient` built over a stub `HttpMessageHandler` that returns a canned structured-output response; assert `ExtractAsync` maps it to `ReceiptDraftDto` (shop/date/line items/tax), and that a non-2xx / malformed response returns `ProcessingResult.Fail`. (Mirror `NominatimGeocodingServiceTests` for the fake-handler pattern.)

- [ ] **Step 3: Implement.** Verify the exact C# SDK symbols against the `claude-api` C# doc + SDK repo before writing; the known shapes:
  - Client: `new AnthropicClient { ApiKey = settings.ApiKey }` (or inject one for testability).
  - Model: `Model.ClaudeHaiku4_5` (or `settings.Model` as the model string).
  - Content: a user message whose content is `[ <image-or-PDF block>, <text block: "Extract this vehicle service receipt."> ]`.
    - PDF: `new DocumentBlockParam { Source = new Base64PdfSource { Data = base64 } }`.
    - Image: the C# image block param (**confirm the exact type name** — `ImageBlockParam` + a `Base64ImageSource { MediaType, Data }` — from the SDK; the reference shows the Python/JSON shape `{type:image, source:{type:base64, media_type, data}}`).
  - Structured output: `OutputConfig = new OutputConfig { Format = new JsonOutputFormat { Schema = <ReceiptDraft JSON schema dict> } }`. Schema must set `additionalProperties:false` on every object and avoid unsupported constraints (no min/max/length). The first text block of the response is valid JSON → `JsonSerializer.Deserialize<ReceiptDraftDto>`.
  - `MaxTokens = settings.MaxTokens`. Wrap in try/catch → `ProcessingResult.Fail` on API/parse errors; return `ProcessingResult.Ok(dto)` on success.

- [ ] **Step 4: Run the test** (`dotnet test src/Hmm.ServiceApi.Core.Tests --filter FullyQualifiedName~ClaudeReceiptExtractionService`). Commit:
```
feat(receipts): ClaudeReceiptExtractionService (Haiku 4.5 + structured outputs)
```

---

### Task 11: `POST /v1/receipts/extract` controller + DI

**Files:** `src/Hmm.ServiceApi/Areas/UtilityService/Controllers/ReceiptExtractionController.cs`; register in `Startup.cs`. Test: `src/Hmm.ServiceApi.Core.Tests/ReceiptExtractionControllerTests.cs`.

- [ ] **Step 1: Write the failing test** — multipart upload with an image → `200` + draft; unsupported content type → `415`; oversize (>8 MB) → `413`; missing JWT → `401`. Mirror `GeocodingControllerTests`.

- [ ] **Step 2: Implement the controller** (`[Authorize] [ApiController] [ApiVersion("1.0")] [Route("/v{version:apiVersion}/receipts")]`):
  - `POST("extract")` accepting `IFormFile file` (multipart). Validate content type ∈ {jpeg,png,heic,webp,pdf} → else `415`; length ≤ 8 MB → else `413`. Read bytes, call `_service.ExtractAsync(bytes, file.ContentType)`, map `ProcessingResult` → `Ok(dto)` / `BadRequest(...)` (mirror `GeocodingController`).

- [ ] **Step 3: Register DI** in `Startup.cs`: `services.Configure<AnthropicSettings>(config.GetSection(AnthropicSettings.SectionName));` and register `IReceiptExtractionService → ClaudeReceiptExtractionService` (typed `AddHttpClient<...>()` if the service takes an `HttpClient`, else `AddScoped`). Build Release.

- [ ] **Step 4: Run tests** (`dotnet test src/Hmm.ServiceApi.Core.Tests --filter FullyQualifiedName~ReceiptExtractionController`). Commit:
```
feat(receipts): POST /v1/receipts/extract endpoint + DI wiring
```

---

### Task 12: Client `ApiLlmExtractor`

**Files (Flutter):** `lib/features/receipt_scan/data/api_llm_extractor.dart`. Test: `test/features/receipt_scan/data/api_llm_extractor_test.dart`.

- [ ] **Step 1: Write the failing test** — a mock Dio (or `api_client`) returns a canned `ReceiptDraft` JSON → assert correct deserialization into `ReceiptDraft` (source `cloudAi`, line items mapped to `LineItemType`); a `4xx/5xx` or network error → `ReceiptExtractionException`.

- [ ] **Step 2: Implement** `ApiLlmExtractor implements ReceiptExtractor` backed by the shared `api_client` (`lib/core/network/`): `POST /v1/receipts/extract` as `multipart/form-data` with the receipt bytes; parse the JSON response into `ReceiptDraft`. Map errors to `ReceiptExtractionException`.

- [ ] **Step 3: Run — expect PASS.** Analyze. Commit:
```
feat(receipt-scan): ApiLlmExtractor (Dio -> /v1/receipts/extract)
```

---

### Task 13: Route `cloudAi` to the real extractor

**Files:** Modify `receipt_extractor_providers.dart`. Test: extend `receipt_extractor_providers_test.dart`.

- [ ] **Step 1** Update the mode-`cloudAi` test to expect `isA<ApiLlmExtractor>()`.
- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3** In `receiptExtractorProvider`, return `ApiLlmExtractor(ref.watch(apiClientProvider))` for `cloudAi` (remove the Phase-A stub). Confirm the exact `api_client` provider name.
- [ ] **Step 4: Run — expect PASS.** Analyze. Commit:
```
feat(receipt-scan): cloudAi mode now uses the backend extractor
```

---

## Final verification

- [ ] **Flutter full analyze + test:** `flutter analyze > /tmp/rfa.txt 2>&1; echo EXIT $?` and `flutter test > /tmp/rft.txt 2>&1; echo EXIT $?` → both EXIT 0.
- [ ] **Backend build + tests:** `dotnet build Hmm.sln -c Release` and `dotnet test src/Hmm.ServiceApi.Core.Tests` → green.
- [ ] **Manual smoke (iOS sim):** on-device — photograph a receipt → fields pre-fill → review → save; PDF option disabled on-device. Cloud AI (after deploy) — switch mode (consent once) → scan a PDF invoice → line items itemize → save. Confirm the receipt is kept as an attachment and a failed extraction leaves the form untouched but keeps the attachment.

## Self-review notes (reconciled)

- **Spec coverage:** contract (T1), merge (T2), on-device parser+extractor (T3–T4), preference+provider (T5, T13), orchestration (T6), form (T7), settings+consent (T8), backend endpoint (T9–T11), cloud client (T12). All spec sections map to a task.
- **Refinement vs spec:** the spec said "tool use" for structured output; this plan uses **structured outputs (`output_config.format`)** — the cleaner, purpose-built mechanism, confirmed supported on Haiku 4.5 in the `claude-api` reference. Functionally equivalent (forced schema-valid JSON); noted here so the two documents don't read as contradictory.
- **Binding caveats flagged:** exact `google_mlkit` API, the C# image-block param type, and the C# structured-output/`Model` symbols must be verified against their sources before writing (do not guess) — called out in T4/T10.
- **Phase A is backend-free and shippable** (Tasks 1–8); `cloudAi` is stubbed to on-device until T13 so the setting never dead-ends.
