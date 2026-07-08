# Receipt Line-Item Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deterministically correct scanned receipt line-item quantities (and fill missing unit prices) from the printed line amount, so extraction errors like the `Shp`-column case never reach the user.

**Architecture:** The backend cloud extractor starts returning each line's printed `amount` (data only). The Flutter client parses it and, in a new pure `reconcileLineItem` function applied inside `applyDraft`, recomputes `quantity = round(amount / unitCost)` (or fills `unitCost = amount / quantity`). Adjustments are surfaced in the existing post-scan snackbar. No persistence or entity changes.

**Tech Stack:** .NET 10 (`Hmm.ServiceApi`, System.Text.Json, xUnit) for the backend data capture; Flutter/Dart (Riverpod, flutter_test) for the client logic.

**Repos:** Task 1 is in `~/projects/hmm` (backend). Tasks 2–5 are in `~/projects/hmm_console` (client). Task 6 deploys both.

## Global Constraints

- Reconciliation is **client-side only**; the backend adds data capture, no reconciliation logic.
- Reconciliation is a **pure, total function**: never throws, never blocks a save; un-reconcilable lines pass through unchanged.
- Tolerance for "consistent": `|round(a/u)*u - a| <= max(0.01, 0.01 * a.abs())`.
- Only lines with `amount > 0` are reconciled (skip null/zero/negative — discounts).
- Backend JSON stays **camelCase** (`[JsonProperty("amount")]`), matching the existing contract.
- Flagging is a **snackbar summary only** — no editor/row/`PartItem`/persistence changes.
- Commit footer on every commit: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: Backend — capture the printed line `amount`

**Repo:** `~/projects/hmm`

**Files:**
- Modify: `src/Hmm.Utility.Services/ReceiptExtractionResult.cs` (add `Amount` to `ReceiptExtractionLineItem`)
- Modify: `src/Hmm.Utility.Services/AnthropicReceiptExtractionProvider.cs` (schema field, prompt clause, `MapInput`)
- Modify: `src/Hmm.ServiceApi.DtoEntity/Utility/ApiReceiptDraft.cs` (add `Amount` to `ApiReceiptLineItem`)
- Modify: `src/Hmm.ServiceApi/Areas/UtilityService/Controllers/ReceiptExtractionController.cs` (`ToDto` maps `Amount`)
- Test: `src/Hmm.ServiceApi.Core.Tests/AnthropicReceiptExtractionProviderTests.cs`
- Test: `src/Hmm.ServiceApi.Core.Tests/ReceiptDraftSerializationTests.cs`

**Interfaces:**
- Produces (wire contract): each `/v1/receipts/extract` line item gains a camelCase `amount` (nullable number).

- [ ] **Step 1: Write the failing test — provider maps `amount`**

Add to `AnthropicReceiptExtractionProviderTests.cs`:

```csharp
[Fact]
public async Task ExtractAsync_MapsLineItemAmount()
{
    var json = """
    {
      "stop_reason": "tool_use",
      "content": [
        {"type":"tool_use","name":"record_service_receipt","input":{
          "lineItems":[
            {"type":"Part","name":"Oil","quantity":7,"unitCost":17.95,"amount":125.65}
          ]}}
      ]
    }
    """;
    var provider = CreateProvider(new MockHttpMessageHandler(json));

    var result = await provider.ExtractAsync(Engine(), Bytes, "image/jpeg");

    Assert.True(result.Success);
    Assert.Equal(125.65, result.Value.LineItems[0].Amount.Value);
}
```

- [ ] **Step 2: Add the failing serialization assertion**

In `ReceiptDraftSerializationTests.cs`, inside `ApiReceiptDraft_serializes_with_camelCase_keys`, set an amount on the line item and assert the key. Change the line item construction to include `Amount = 10.0` and add:

```csharp
            Assert.Contains("\"amount\"", json);
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `cd ~/projects/hmm && dotnet test src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj --filter "FullyQualifiedName~ExtractAsync_MapsLineItemAmount|FullyQualifiedName~ApiReceiptDraft_serializes"`
Expected: FAIL — `ReceiptExtractionLineItem` / `ApiReceiptLineItem` have no `Amount` (compile error), or the `amount` key is absent.

- [ ] **Step 4: Add `Amount` to the result model**

In `ReceiptExtractionResult.cs`, add to `ReceiptExtractionLineItem` (after `UnitCost`):

```csharp
        public double? Amount { get; set; }
```

- [ ] **Step 5: Add `amount` to schema, prompt, and mapping**

In `AnthropicReceiptExtractionProvider.cs` `BuildSchema`, add `amount` after `unitCost`:

```csharp
                                unitCost = new { type = nullableNumber, description = "Per-unit price (not the line total)" },
                                amount = new { type = nullableNumber, description = "Line total for this item (unit price x quantity)" }
```

In the prompt text, append one sentence to the existing string (after the cross-check sentence):

```csharp
                                    + " Also set amount to the line's printed total for that item."
```

In `MapInput`, add `Amount` to the `new ReceiptExtractionLineItem { ... }` initializer (after `UnitCost = GetDouble(item, "unitCost")`):

```csharp
                        UnitCost = GetDouble(item, "unitCost"),
                        Amount = GetDouble(item, "amount")
```

- [ ] **Step 6: Add `Amount` to the DTO and controller mapping**

In `ApiReceiptDraft.cs`, add to `ApiReceiptLineItem` (after `UnitCost`):

```csharp
        [JsonProperty("amount")]
        public double? Amount { get; set; }
```

In `ReceiptExtractionController.cs` `ToDto`, add to the `new ApiReceiptLineItem { ... }` initializer (after `UnitCost = li.UnitCost`):

```csharp
                UnitCost = li.UnitCost,
                Amount = li.Amount
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd ~/projects/hmm && dotnet test src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj`
Expected: PASS (all, including the two new assertions).

- [ ] **Step 8: Commit**

```bash
cd ~/projects/hmm
git add src/Hmm.Utility.Services/ReceiptExtractionResult.cs src/Hmm.Utility.Services/AnthropicReceiptExtractionProvider.cs src/Hmm.ServiceApi.DtoEntity/Utility/ApiReceiptDraft.cs src/Hmm.ServiceApi/Areas/UtilityService/Controllers/ReceiptExtractionController.cs src/Hmm.ServiceApi.Core.Tests/AnthropicReceiptExtractionProviderTests.cs src/Hmm.ServiceApi.Core.Tests/ReceiptDraftSerializationTests.cs
git commit -m "feat(receipts): return printed line amount from extraction

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Client — `ReceiptLineItem.amount` + parse it

**Repo:** `~/projects/hmm_console`

**Files:**
- Modify: `lib/features/receipt_scan/domain/receipt_draft.dart` (`ReceiptLineItem` gains `amount`)
- Modify: `lib/features/receipt_scan/data/api_llm_extractor.dart` (`_fromJson` parses `amount`)
- Test: `test/features/receipt_scan/data/api_llm_extractor_test.dart`

**Interfaces:**
- Produces: `ReceiptLineItem` gains `final double? amount;` (constructor param `this.amount`).

- [ ] **Step 1: Write the failing test**

In `api_llm_extractor_test.dart`, add `"amount"` to the first line item of the `okBody` constant (`{"type": "Labour", "name": "Oil change", "quantity": 1, "unitCost": 40, "amount": 40}`), then add a test:

```dart
  test('parses line-item amount', () async {
    final (ex, _) = _make(200, okBody);
    final draft = await ex.extract(_image());
    expect(draft.lineItems.first.amount, 40);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/receipt_scan/data/api_llm_extractor_test.dart`
Expected: FAIL — `ReceiptLineItem` has no `amount` getter (compile error).

- [ ] **Step 3: Add `amount` to `ReceiptLineItem`**

In `receipt_draft.dart`, in the `ReceiptLineItem` class, add the constructor param and field:

```dart
  const ReceiptLineItem({
    required this.type,
    required this.name,
    this.quantity = 1,
    this.unitCost,
    this.amount,
  });

  final LineItemType type;
  final String name;
  final int quantity;
  final double? unitCost;
  final double? amount;
```

- [ ] **Step 4: Parse `amount` in the extractor**

In `api_llm_extractor.dart` `_fromJson`, add `amount` to the `ReceiptLineItem(...)` built in the `lineItems` comprehension (after `unitCost:`):

```dart
              unitCost: _asNum(_get(it, 'unitCost'))?.toDouble(),
              amount: _asNum(_get(it, 'amount'))?.toDouble(),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/receipt_scan/data/api_llm_extractor_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/receipt_scan/domain/receipt_draft.dart lib/features/receipt_scan/data/api_llm_extractor.dart test/features/receipt_scan/data/api_llm_extractor_test.dart
git commit -m "feat(receipt-scan): parse line-item amount from extraction

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Client — pure `reconcileLineItem`

**Repo:** `~/projects/hmm_console`

**Files:**
- Create: `lib/features/receipt_scan/domain/reconcile_line_items.dart`
- Test: `test/features/receipt_scan/domain/reconcile_line_items_test.dart`

**Interfaces:**
- Consumes: `ReceiptLineItem` (with `amount`) from Task 2.
- Produces: `class ReconciledItem { final ReceiptLineItem item; final bool adjusted; }` and `ReconciledItem reconcileLineItem(ReceiptLineItem li)`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/receipt_scan/domain/reconcile_line_items_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:hmm_console/features/receipt_scan/domain/reconcile_line_items.dart';

ReceiptLineItem _li({int quantity = 1, double? unitCost, double? amount}) =>
    ReceiptLineItem(
        type: LineItemType.part,
        name: 'x',
        quantity: quantity,
        unitCost: unitCost,
        amount: amount);

void main() {
  test('fixes quantity from amount / unitCost (the Shp case)', () {
    final r = reconcileLineItem(_li(quantity: 1, unitCost: 17.95, amount: 125.65));
    expect(r.item.quantity, 7);
    expect(r.adjusted, isTrue);
  });

  test('fills a missing unit price from amount / quantity', () {
    final r = reconcileLineItem(_li(quantity: 4, unitCost: null, amount: 32));
    expect(r.item.unitCost, 8);
    expect(r.adjusted, isTrue);
  });

  test('leaves an already-consistent line unchanged', () {
    final r = reconcileLineItem(_li(quantity: 1, unitCost: 40, amount: 40));
    expect(r.item.quantity, 1);
    expect(r.adjusted, isFalse);
  });

  test('does not fabricate a quantity when the ratio is not a clean integer', () {
    final r = reconcileLineItem(_li(quantity: 1, unitCost: 3, amount: 10));
    expect(r.item.quantity, 1);
    expect(r.adjusted, isFalse);
  });

  test('skips when amount is missing, zero, or negative', () {
    expect(reconcileLineItem(_li(quantity: 1, unitCost: 5, amount: null)).adjusted,
        isFalse);
    expect(reconcileLineItem(_li(quantity: 1, unitCost: 5, amount: 0)).adjusted,
        isFalse);
    expect(reconcileLineItem(_li(quantity: 1, unitCost: 5, amount: -5)).adjusted,
        isFalse);
  });

  test('skips quantity fix when unitCost is zero', () {
    final r = reconcileLineItem(_li(quantity: 2, unitCost: 0, amount: 10));
    expect(r.item.unitCost, 5); // falls through to unit-price fill
    expect(r.adjusted, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/projects/hmm_console && flutter test test/features/receipt_scan/domain/reconcile_line_items_test.dart`
Expected: FAIL — `reconcile_line_items.dart` does not exist.

- [ ] **Step 3: Implement the reconciler**

Create `lib/features/receipt_scan/domain/reconcile_line_items.dart`:

```dart
import 'receipt_draft.dart';

/// A line item after reconciliation, plus whether it was changed.
class ReconciledItem {
  const ReconciledItem(this.item, {required this.adjusted});
  final ReceiptLineItem item;
  final bool adjusted;
}

/// Deterministically corrects one scanned line item from its printed [amount],
/// the authoritative signal (quantity x unitCost == amount). Total and
/// side-effect free: a line it cannot reconcile is returned unchanged with
/// [ReconciledItem.adjusted] == false.
ReconciledItem reconcileLineItem(ReceiptLineItem li) {
  final a = li.amount;
  final u = li.unitCost;
  final q = li.quantity;

  // Only a positive printed total is a usable signal (skip discounts/credits).
  if (a == null || a <= 0) return ReconciledItem(li, adjusted: false);

  final tol = a * 0.01 > 0.01 ? a * 0.01 : 0.01;

  // Fix quantity when a unit price is known.
  if (u != null && u > 0) {
    final derived = (a / u).round();
    final clean = (derived * u - a).abs() <= tol;
    if (derived >= 1 && clean && derived != q) {
      return ReconciledItem(
        ReceiptLineItem(
            type: li.type,
            name: li.name,
            quantity: derived,
            unitCost: u,
            amount: a),
        adjusted: true,
      );
    }
    return ReconciledItem(li, adjusted: false);
  }

  // Fill a missing/zero unit price from amount / quantity.
  if (q > 0) {
    return ReconciledItem(
      ReceiptLineItem(
          type: li.type,
          name: li.name,
          quantity: q,
          unitCost: a / q,
          amount: a),
      adjusted: true,
    );
  }

  return ReconciledItem(li, adjusted: false);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/projects/hmm_console && flutter test test/features/receipt_scan/domain/reconcile_line_items_test.dart`
Expected: PASS (all 6).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/receipt_scan/domain/reconcile_line_items.dart test/features/receipt_scan/domain/reconcile_line_items_test.dart
git commit -m "feat(receipt-scan): deterministic line-item reconciler

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Client — apply the reconciler in `applyDraft`

**Repo:** `~/projects/hmm_console`

**Files:**
- Modify: `lib/features/receipt_scan/domain/apply_draft.dart` (`ApplyDraftResult.adjustedItemCount`; reconcile each appended item; dedup on the reconciled values)
- Test: `test/features/receipt_scan/domain/apply_draft_test.dart`

**Interfaces:**
- Consumes: `reconcileLineItem` (Task 3).
- Produces: `ApplyDraftResult` gains `final int adjustedItemCount;` (required constructor arg).

- [ ] **Step 1: Write the failing test**

Add to `apply_draft_test.dart`:

```dart
  test('reconciles a scanned line and reports the adjustment', () {
    final draft = ReceiptDraft(
      source: ReceiptExtractorMode.cloudAi,
      lineItems: const [
        ReceiptLineItem(
            type: LineItemType.part,
            name: 'Oil',
            quantity: 1,
            unitCost: 17.95,
            amount: 125.65),
      ],
    );
    final r = applyDraft(ScanFormValues.empty(), draft);
    expect(r.values.items.single.quantity, 7);
    expect(r.adjustedItemCount, 1);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/receipt_scan/domain/apply_draft_test.dart`
Expected: FAIL — `ApplyDraftResult` has no `adjustedItemCount`, and the quantity is still 1.

- [ ] **Step 3: Add `adjustedItemCount` to `ApplyDraftResult`**

In `apply_draft.dart`, update the class:

```dart
class ApplyDraftResult {
  const ApplyDraftResult({
    required this.values,
    required this.filledScalarCount,
    required this.appendedItemCount,
    required this.adjustedItemCount,
    required this.totalsMismatch,
  });

  final ScanFormValues values;
  final int filledScalarCount;
  final int appendedItemCount;
  final int adjustedItemCount;
  final bool totalsMismatch;
}
```

- [ ] **Step 4: Reconcile inside `applyDraft`**

Add the import at the top of `apply_draft.dart`:

```dart
import 'reconcile_line_items.dart';
```

Replace the `final appended = [ ... ];` comprehension with a loop that reconciles first, dedups on the reconciled values, and counts adjustments:

```dart
  var adjusted = 0;
  final appended = <PartItem>[];
  for (final li in draft.lineItems) {
    final rec = reconcileLineItem(li);
    if (alreadyOnForm(rec.item)) continue; // dedup on reconciled values
    if (rec.adjusted) adjusted++;
    appended.add(PartItem(
      type: rec.item.type,
      name: rec.item.name,
      quantity: rec.item.quantity,
      unitCost: rec.item.unitCost,
      currency: currency ?? form.currency ?? 'CAD',
    ));
  }
  final items = [...form.items, ...appended];
```

Then pass the count in the returned `ApplyDraftResult(...)`:

```dart
    appendedItemCount: appended.length,
    adjustedItemCount: adjusted,
    totalsMismatch: mismatch,
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd ~/projects/hmm_console && flutter test test/features/receipt_scan/domain/apply_draft_test.dart`
Expected: PASS (new test plus the existing dedup/mismatch tests).

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/receipt_scan/domain/apply_draft.dart test/features/receipt_scan/domain/apply_draft_test.dart
git commit -m "feat(receipt-scan): reconcile line items during applyDraft

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Client — surface adjustments in the scan snackbar

**Repo:** `~/projects/hmm_console`

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart` (`ScanSuccess` snackbar)

**Interfaces:**
- Consumes: `ApplyDraftResult.adjustedItemCount` (Task 4).

**Note on testing:** the change is a string interpolation inside the existing snackbar. The counting logic is already covered by Task 4's `applyDraft` test, and widget-testing this form requires the full provider/router harness for no added confidence. Verify with `flutter analyze` + the full suite rather than a new widget test.

- [ ] **Step 1: Add the adjusted clause to the snackbar**

In `service_record_form_screen.dart`, in the `ScanSuccess` case, just before the existing `final mismatch = ...` line, add:

```dart
        final adjusted = applied.adjustedItemCount > 0
            ? ' (adjusted ${applied.adjustedItemCount} '
                '${applied.adjustedItemCount == 1 ? "quantity" : "quantities"} '
                'to match line totals)'
            : '';
```

Then update the snackbar `Text(...)` to include it:

```dart
            content: Text(
              'Filled ${applied.filledScalarCount} fields and '
              '${applied.appendedItemCount} line items$adjusted — '
              'review before saving.$mismatch',
            ),
```

- [ ] **Step 2: Verify analyze + full suite pass**

Run: `cd ~/projects/hmm_console && flutter analyze lib/features/automobile_records/presentation/screens/service_record_form_screen.dart && flutter test`
Expected: `No issues found!` and `All tests passed!`.

- [ ] **Step 3: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/presentation/screens/service_record_form_screen.dart
git commit -m "feat(receipt-scan): report reconciled quantities in scan snackbar

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Rollout & end-to-end verification

**Repos:** both.

- [ ] **Step 1: Merge each repo's work to `main`**

Use `superpowers:finishing-a-development-branch` per repo (verify tests, `--no-ff` merge, push).

- [ ] **Step 2: Deploy the backend**

```bash
cd ~/projects/hmm && ./scripts/deploy-api.sh --deploy
```
Expected: ends with `Done`; `ssh ... 'systemctl is-active hmm-api'` returns `active`.

- [ ] **Step 3: Build the client to the device**

```bash
cd ~/projects/hmm_console && ./scripts/run-prod-ios-device.sh
```
Expected: `Installing and launching...` then `Flutter run key commands.`

- [ ] **Step 4: Verify with the sample receipt**

Scan `~/projects/hmm/docs/Automobile_service.pdf` on a service record. The GTX oil and engine-oil enviro-fee lines should show **quantity 7** (7 × $17.95 = $125.65, 7 × $0.22 = $1.54), and the snackbar should read `... (adjusted 2 quantities to match line totals) ...`. Confirm the values persist after save + reopen.

---

## Self-Review

**Spec coverage:**
- Backend `amount` capture (schema/result/MapInput/DTO/controller) → Task 1. ✓
- Client `ReceiptLineItem.amount` + parse → Task 2. ✓
- Pure reconciler (fix quantity; fill missing unit price; tolerance; skip rules) → Task 3. ✓
- `applyDraft` integration + `adjustedItemCount`, dedup composes → Task 4. ✓
- Snackbar-only flag → Task 5. ✓
- Testing (reconciler, applyDraft, extractor, backend provider + serialization) → Tasks 1–4. ✓
- Rollout (backend then client, additive) → Task 6. ✓
- Out-of-scope items (per-row markers, total validation, backend reconciliation) → not implemented, as intended. ✓

**Type consistency:** `reconcileLineItem` / `ReconciledItem.{item,adjusted}` used identically in Tasks 3–4; `ReceiptLineItem.amount` defined in Task 2 and consumed in Tasks 3–4; `ApplyDraftResult.adjustedItemCount` defined in Task 4 and consumed in Task 5; backend `Amount` names consistent across Task 1.

**Dedup ordering:** Task 4 reconciles **before** the `alreadyOnForm` dedup check so a re-scan of the same receipt (raw qty 1 → reconciled qty 7) matches the already-appended reconciled row and is skipped — no duplicate. ✓
