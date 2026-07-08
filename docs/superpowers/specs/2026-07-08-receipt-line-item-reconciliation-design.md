# Receipt Line-Item Reconciliation — Design

**Date:** 2026-07-08
**Status:** Approved (pending implementation plan)
**Repos:** `hmm_console` (client — reconciliation logic), `hmm` (backend — data capture only)

## Problem

The cloud-AI receipt extractor returns line items whose `quantity` and
`unitCost` are unreliable — the model cannot be prompted to 100% accuracy. A
concrete failure: on a Subaru service order whose quantity column is headed
`Shp` ("shipped"), the model returned `quantity = 1` for every line even
though the oil line was 7 units (7 × $17.95 = $125.65). Prompt tuning reduces
but cannot eliminate this class of error.

## Principle

A receipt line is over-specified: it prints **unit price, quantity, and line
amount**, bound by `quantity × unitCost = amount`. The printed **amount** is
the authoritative signal (it is what the customer paid). Instead of trusting
the model's `quantity`/`unitCost`, we **deterministically recompute** them in
code from `amount`, then flag that we did so. This removes the error class
regardless of the AI engine or prompt.

## Scope

**In scope**
- Capture the printed line **amount** in the cloud extraction (backend).
- Client-side, pure reconciliation of each scanned line item:
  - fix `quantity` from `amount ÷ unitCost`;
  - fill a missing `unitCost` from `amount ÷ quantity`.
- A single **snackbar summary** after a scan reporting how many lines were
  adjusted.

**Out of scope (future, not this plan)**
- Per-row "adjusted" markers in the line-items editor.
- Receipt-level total validation (sum of lines + tax ≈ `total`).
- Moving reconciliation to the backend, or adding a document-AI provider.
- On-device OCR (it produces no structured line items — unaffected).

## Decisions

- **Location:** client-side, in the receipt-scan domain, applied as the
  scanned draft populates the review form. Reconciliation is engine-agnostic
  arithmetic but lives next to the review UX; only the cloud-AI path produces
  line items, so nothing else is touched.
- **Behavior:** auto-correct (deterministic) **and** flag via a snackbar
  count. The existing pre-save review remains the final safety net.
- **Coverage:** quantity correction **and** missing-unit-price fill.

## Architecture & data flow

```
PDF/image
  -> POST /v1/receipts/extract  (backend: Claude vision, tool schema)
       -> ApiReceiptDraft.lineItems[] now includes `amount`   [BACKEND CHANGE]
  -> ApiLlmExtractor._fromJson  (client parses `amount` into ReceiptLineItem)
  -> applyDraft(form, draft)
       -> reconcileLineItem() per appended item  [NEW pure fn]
       -> ApplyDraftResult.adjustedItemCount
  -> scan handler shows snackbar incl. adjusted count
  -> user reviews + saves (unchanged)
```

## Component 1 — Backend data capture (`hmm`)

No reconciliation logic on the backend; it only needs to *return* the printed
line total so the client has the independent signal.

- **Schema** (`AnthropicReceiptExtractionProvider.BuildSchema`): add
  `amount` to the line-item object — `{ type: ["number","null"],
  description: "Line total for this item (unit price x quantity)" }`. The
  prompt already references the amount column; add one clause tying amount to
  quantity × unit price.
- **Result model** (`ReceiptExtractionResult.cs`):
  `ReceiptExtractionLineItem.Amount` (`double?`).
- **Mapping** (`MapInput`): `Amount = GetDouble(item, "amount")`.
- **DTO** (`ApiReceiptDraft.cs`): `ApiReceiptLineItem.Amount` with
  `[JsonProperty("amount")]` (camelCase, matching the rest of the contract).
- **Controller** (`ReceiptExtractionController.ToDto`): map `Amount`.

## Component 2 — Client model + parse (`hmm_console`)

- `ReceiptLineItem` (`receipt_draft.dart`): add `final double? amount`.
- `ApiLlmExtractor._fromJson`: parse `amount` via the existing casing-tolerant
  `_get(it, 'amount')` → `_asNum(...)?.toDouble()`.

## Component 3 — Reconciler (`hmm_console`, new pure module)

`lib/features/receipt_scan/domain/reconcile_line_items.dart`

```dart
/// Result of reconciling one line item.
class ReconciledItem {
  const ReconciledItem(this.item, {required this.adjusted});
  final ReceiptLineItem item;
  final bool adjusted;
}

/// Deterministically corrects a single line from its printed amount.
/// Total and side-effect free: any line it cannot reconcile is returned
/// unchanged with adjusted == false.
ReconciledItem reconcileLineItem(ReceiptLineItem li);
```

Rules (in order), with `a = amount`, `u = unitCost`, `q = quantity`, and
tolerance `tol(a) = max(0.01, 0.01 * a.abs())`:

1. **Skip** when un-reconcilable: `a == null`, or `a <= 0` (discounts/credits).
   Return unchanged, `adjusted = false`.
2. **Fix quantity** when `u != null && u > 0`:
   - `derived = (a / u).round()`.
   - If `derived >= 1` and `(derived * u - a).abs() <= tol(a)` and
     `derived != q` → return item with `quantity = derived`,
     `adjusted = true`.
   - Else (already consistent, or ratio not a clean integer) → unchanged,
     `adjusted = false`.
3. **Fill missing unit price** when `(u == null || u == 0) && q > 0`:
   - `unitCost = a / q` → return item with that `unitCost`,
     `adjusted = true`.
4. Otherwise → unchanged, `adjusted = false`.

Only one of steps 2/3 applies to a given line (2 requires a known unit price,
3 requires a missing one).

## Component 4 — `applyDraft` integration + snackbar

- `applyDraft` (`apply_draft.dart`): run each draft line item through
  `reconcileLineItem` when building the `appended` list (after the existing
  dedup check, so duplicates are still skipped). Count `adjusted == true`.
- `ApplyDraftResult`: add `final int adjustedItemCount`.
- Scan handler (`service_record_form_screen.dart`,
  `ScanSuccess` case): extend the existing snackbar, e.g.
  `"Filled 3 fields and 8 line items` `(adjusted 2 quantities to match line
  totals)` `— review before saving."` The adjusted clause appears only when
  `adjustedItemCount > 0`.

No changes to `ServiceLineItemsEditor` / `ServiceLineItemRow` / `PartItem` /
persistence.

## Error handling & edge cases

- Reconciler never throws; un-reconcilable lines pass through unchanged.
- `u == 0` or `u == null`: quantity cannot be derived → try unit-price fill
  (step 3) if quantity is known; else leave.
- `a` present but `a / u` not near an integer: the amount or unit price was
  misread — do **not** fabricate a wrong integer; leave the line and do not
  flag (the user reviews).
- Negative/zero amounts (discounts, credits): left untouched.
- Reconciliation is display-time only; nothing new is persisted, and
  `PartItem.lineTotal` remains a computed `unitCost * quantity`.

## Testing

**Client — reconciler unit tests** (`reconcile_line_items_test.dart`)
- Shp case: `amount 125.65, unitCost 17.95, quantity 1` → `quantity 7`,
  `adjusted`.
- Missing unit price: `amount 32, unitCost null, quantity 4` →
  `unitCost 8`, `adjusted`.
- Already consistent: `amount 40, unitCost 40, quantity 1` → unchanged, not
  adjusted.
- Non-integer ratio: `amount 10, unitCost 3, quantity 1` → unchanged (3.33
  not clean), not adjusted.
- `unitCost 0` / `amount null` / negative amount → unchanged, not adjusted.

**Client — applyDraft** (`apply_draft_test.dart`)
- A draft line needing correction yields the corrected quantity and
  `adjustedItemCount == 1`; dedup still works alongside reconciliation.

**Client — extractor** (`api_llm_extractor_test.dart`)
- `amount` parsed from both camelCase and PascalCase bodies.

**Backend** (`Hmm.ServiceApi.Core.Tests`)
- Provider test: a tool response with `"amount"` maps to
  `LineItem.Amount`.
- Serialization test: `ApiReceiptDraft` emits camelCase `amount`.

## Rollout

1. Backend: add `amount` capture, deploy to VPS (existing installed client
   ignores the new field harmlessly until updated).
2. Client: model + reconciler + applyDraft + snackbar, build to device.

Both are additive and backward compatible.
