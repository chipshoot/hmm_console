# Receipt Scan Auto-Fill — Design

Owner: Flutter `hmm_console` + .NET `Hmm.ServiceApi`
Status: **Draft / pre-implementation**
Date: 2026-07-01
Sibling docs: `docs/superpowers/specs/2026-06-29-service-record-attachments-design.md`
(the attachment system this reuses for keeping the scanned receipt).

## Why

Entering a service record by hand — especially the typed line items
(labour / part / fee) — is tedious, and that manual entry is where a
recent save bug surfaced. A vehicle service receipt already contains
almost everything the record needs. This feature lets a user **scan a
receipt (photo or PDF)** and have the form **pre-fill** — shop, date,
odometer, line items, tax — for review and save. Extraction is always
an optional accelerator layered on top of manual entry, never a gate.

## Scope

**In scope (v1):**
- A unified **"Scan receipt"** flow on the service-record form.
- **Two user-selectable extractors** behind one interface:
  - on-device OCR (`google_mlkit_text_recognition`) — offline, private,
    scalar fields only.
  - cloud AI — a new `Hmm.ServiceApi` endpoint that calls Claude vision
    and returns structured line items + scalars.
- Pre-fill the form for **review** (never auto-save); least-surprise
  merge (fill-empty scalars, append line items).
- The scanned receipt is **kept as an attachment** on the record
  (reusing the attachment system).
- A Settings preference to choose the extractor; one-time consent before
  the first Cloud-AI use.

**Out of scope (v1):**
- Auto-saving an extracted record without user review.
- Extracting anything other than a **service record** (no gas receipts,
  insurance docs, etc. — those can reuse the pattern later).
- On-device **PDF** OCR (ML Kit reads images; PDF receipts are
  Cloud-AI-only in v1).
- Per-field confidence scores / highlighting.
- Multi-receipt batch scan.
- Fine-tuning or a local ML model — the on-device path is heuristic
  parsing over ML Kit text.

## Architecture

A new feature module `lib/features/receipt_scan/`, following the
clean-architecture + provider-selection pattern already used for
`DataMode` (`repository_providers.dart`).

### Extractor interface + implementations

```
abstract interface class ReceiptExtractor {
  Future<ReceiptDraft> extract(ReceiptInput input);
}
```

- **`OnDeviceOcrExtractor`** — runs `google_mlkit_text_recognition` on
  the image, then a pure `ReceiptTextParser` applies heuristics. Fills
  scalar fields only; `lineItems: []`. Offline + private. Images only.
- **`ApiLlmExtractor`** — posts the receipt to
  `POST /v1/receipts/extract`; the backend calls Claude vision and
  returns structured JSON. Fills the whole draft including classified
  line items. Handles images and PDFs.

Selected by a persisted `ReceiptExtractorMode` (`onDevice` / `cloudAi`)
via a `receiptExtractorProvider` (mirrors `repository_providers.dart`).
Default `onDevice` — nothing leaves the device unless the user opts in.

### Extraction contract (extractor-agnostic, pure data)

Every field is optional; an extractor fills what it finds, anything
unfound stays `null` and the form field is left for the user.

```
ReceiptInput { Uint8List bytes; String contentType }  // image/* or application/pdf

ReceiptDraft {
  String?  shopName;
  DateTime? date;
  int?     odometer;            // maps to ServiceRecord.mileage
  ServiceType? serviceType;     // inferred category; often null
  List<ReceiptLineItem> lineItems;   // possibly empty (on-device)
  double?  tax;
  double?  total;               // grand total — cross-check only, not stored
  String?  currency;
  String?  rawText;             // OCR text / model notes — debug + fallback
  ReceiptExtractorMode source;
}

ReceiptLineItem {               // maps 1:1 to PartItem
  LineItemType type;            // labour | part | fee
  String name;
  int    quantity;
  double? unitCost;
}
```

**Mapping into the form (all pre-fill, user edits before save):**

| Draft field | ServiceRecord field | Notes |
|---|---|---|
| `shopName` | `shopName` | |
| `date` | `date` | |
| `odometer` | `mileage` | attempted; blank if absent |
| `serviceType` | `type` | inferred when possible; else user picks |
| `lineItems` | `parts` | the itemization — the high-value part |
| `tax` | `tax` | |
| `currency` | `currency` | |
| `total` | — | not stored; compared to computed subtotal+tax → soft warning |

**Capability difference (deliberate):** `ApiLlmExtractor` fills the
whole draft. `OnDeviceOcrExtractor` fills scalars (shop, date, total,
tax, currency) and returns `lineItems: []`; partial drafts are
first-class. `rawText` is always populated on-device.

**Failure:** `extract` throws a typed `ReceiptExtractionException`
(network down, no text detected, model error). The UI surfaces it; the
user enters the record manually. Extraction never blocks manual entry.

## Backend (`Hmm.ServiceApi`)

Follows the existing external-service precedent (`IGeocodingService` /
`NominatimGeocodingService` in `Hmm.Utility.Services`, config-bound
settings).

- **Endpoint:** `POST /v1/receipts/extract` (utility-style, like
  `/v1/geocoding` — no `autoId` needed). JWT bearer. Body
  `multipart/form-data` carrying the receipt file (mirrors the vault
  upload). Reuses the attachment storage policy: allowed
  `image/jpeg|png|heic|webp` + `application/pdf`, 8 MB cap, `415` on
  unsupported type, `413` on oversize, `401` on missing/invalid JWT.
- **Service:** `IReceiptExtractionService` with
  `ClaudeReceiptExtractionService`. Sends the receipt as an image or
  PDF content block to the Anthropic Messages API and forces structured
  output via **tool use** — a single `record_service_receipt` tool
  whose input schema is exactly `ReceiptDraftDto`. The model's tool call
  is the validated JSON; the service maps it to the DTO. No free-text
  parsing.
- **Config:** `AnthropicSettings { ApiKey, Model, BaseUrl, MaxTokens }`
  bound from `appsettings`/env. The API key lives in the VPS
  environment/secret, never in the client. **Model:** default
  **Haiku 4.5** (`claude-haiku-4-5-20251001`) — capable at receipt
  extraction, cheapest/fastest — configurable so it can be bumped to
  Sonnet if accuracy needs it.
- **PDF:** passed through as a document content block (the API accepts
  PDFs natively); no server-side rasterization.
- The exact vision/PDF/tool-use request shape, token limits, and
  pricing are to be confirmed against the `claude-api` reference during
  planning.

## On-device parser (client)

- `google_mlkit_text_recognition` runs on the **image** and returns text
  blocks/lines.
- A pure `ReceiptTextParser` (no plugin dependency, fully unit-testable)
  applies heuristics: shop = top non-empty block; `date` = first
  date-like match; `tax` = amount on a line matching `tax|gst|hst|vat`;
  `total` = amount on the last `total|amount due|balance` line;
  `currency` = from symbol, else the app default. Returns
  `lineItems: []` (itemization is unreliable on-device) and always sets
  `rawText`.
- **Limitation (surfaced in UI):** ML Kit reads images, not PDFs. In
  on-device mode the PDF source option is disabled with a hint
  ("PDF receipts need Cloud AI"). Photos work in both modes.

## UX flow & settings

**Settings** — a "Receipt extraction" entry (beside the data-mode
selector): **On-device (private)** (default) / **Cloud AI (more
accurate)**, persisted as `ReceiptExtractorMode`. The **first** time
Cloud AI is selected/used, a one-time consent sheet explains the receipt
is uploaded to the backend for extraction.

**"Scan receipt" flow** on the service-record form:
1. A prominent **"Scan a receipt"** button at the top of the form, with
   a subtitle showing the active mode.
2. Tap → source sheet **Camera / Photo / File (PDF)**, reusing the
   existing byte-source pickers. On-device mode disables the PDF option.
3. The picked bytes do two things at once:
   - **Kept as an attachment** — added to the form's pending-pick list,
     so the receipt is saved with the record on Save. This follows the
     attachment feature's scope (`local` / `cloudStorage` only); in
     `cloudApi` **data** mode, where service-record attachments aren't
     wired, the receipt is used for extraction only and not kept.
   - **Sent to the active extractor**, with a non-blocking, cancellable
     progress indicator ("Reading receipt…").
4. On success the `ReceiptDraft` pre-fills the form with least-surprise
   rules: scalar fields fill **only if empty** (never overwrite user
   input); line items are **appended** to existing rows. A summary
   snackbar reports what it did ("Filled 6 fields and 4 line items —
   review before saving"); a soft warning appears if `total` disagrees
   with the computed subtotal+tax.
5. Everything stays editable — review, correct, Save (the normal save
   flow persists both the record and the kept receipt).
6. On failure a snackbar shows the reason; the form is untouched, the
   receipt is still attached, and the user continues manually.

## Error handling

- **Extractor failure** (network, no text, model error) →
  `ReceiptExtractionException` → snackbar; form untouched; manual entry
  proceeds; the receipt stays attached.
- **Unsupported/oversize file** → rejected at pick-time (client) and by
  the endpoint (`415`/`413`); user-facing message.
- **PDF in on-device mode** → PDF source disabled with a hint.
- **Totals mismatch** → soft, non-blocking warning; never rejects.
- **Offline in Cloud-AI mode** → `ReceiptExtractionException`
  surfaced; suggest switching to on-device or entering manually.

## Testing

Automated coverage leans on **pure, injectable units**; model/plugin
accuracy is manual smoke (no flaky network/LLM in CI).

**Client:**
- `applyDraft(form, draft)` merge *(pure, highest value)*: fill-empty
  scalars, append line items, totals-mismatch flag — table-driven.
- `ReceiptTextParser` *(pure)*: canned OCR text → correct
  shop/date/tax/total/currency, empty line items, `null`s for missing.
- `OnDeviceOcrExtractor`: injected fake text-recognizer returns canned
  `RecognizedText` → delegates to parser, sets `rawText`.
- `ApiLlmExtractor`: mock `api_client` returns canned draft JSON →
  correct deserialization; error responses → `ReceiptExtractionException`.
- `receiptExtractorProvider`: override mode → right impl type.
- Settings: `ReceiptExtractorMode` persists/loads via `SharedPreferences`
  mock; first-use consent flag flips once.
- Scan orchestration (state/widget): fake extractor returns a draft →
  fills empty fields, appends items, keeps the receipt as a pending
  attachment; on throw, form unchanged + receipt still attached + error
  surfaced; on-device mode disables the PDF source option.

**Backend (.NET, xUnit):**
- `ClaudeReceiptExtractionService`: fake `HttpMessageHandler` returns a
  canned Anthropic tool-use response → maps to `ReceiptDraftDto`; asserts
  the request carries the image/PDF block + `record_service_receipt`
  tool schema; error responses → typed exception.
- `POST /v1/receipts/extract`: multipart → `200` + draft; unsupported →
  `415`; oversize → `413`; unauthorized → `401`.
- Schema/DTO sync: a sample tool-input JSON deserializes into
  `ReceiptDraftDto`.

**Not in CI (manual smoke):** real-receipt accuracy for both the
on-device parser and the Claude prompt, validated against a small local
corpus of real receipt images/PDFs.

## Implementation order

Each step ships independently.

1. **Contract:** `ReceiptInput`, `ReceiptDraft`, `ReceiptLineItem`,
   `ReceiptExtractorMode`, `ReceiptExtractionException`, `ReceiptExtractor`
   interface.
2. **Merge:** pure `applyDraft(form, draft)` + tests.
3. **On-device parser:** `ReceiptTextParser` (pure) + tests.
4. **On-device extractor:** `OnDeviceOcrExtractor` wrapping ML Kit
   (injectable text source) + test.
5. **Backend:** `AnthropicSettings`, `IReceiptExtractionService` +
   `ClaudeReceiptExtractionService`, `POST /v1/receipts/extract`
   controller + DTOs + tests. (Confirm API shape against `claude-api`.)
6. **Cloud extractor:** `ApiLlmExtractor` (Dio) + test.
7. **Provider + settings:** `receiptExtractorProvider`,
   `ReceiptExtractorMode` notifier, Settings UI + first-use consent.
8. **Form wiring:** "Scan receipt" button + source sheet + progress +
   apply-draft + keep-as-attachment; PDF disabled on-device.

Steps 1–4 + 7–8 ship an on-device-only vertical slice with no backend
work; steps 5–6 light up Cloud AI.
