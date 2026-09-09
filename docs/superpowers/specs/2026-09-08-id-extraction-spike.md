# ID Extraction — Spike

**Status:** planned 2026-09-08. **Output is an ANSWER, not code we keep.**

## The question

Do the user's ACTUAL cards carry machine-readable data that yields exact
fields, or must extraction be OCR heuristics written per card?

This is a fact about physical cards, not about a standard. North American
licences are supposed to carry a PDF417 barcode under AAMVA; passports are
supposed to carry an ICAO 9303 MRZ. Whether *these* cards do, and what they
actually contain, decides between two very different pieces of work:

| Answer | What gets built |
|---|---|
| Structured data present | A parser against a fixed format. Exact fields, no guessing. |
| Nothing machine-readable | OCR plus heuristics per card type and jurisdiction. Brittle, needs review every time. |

Building parsers against a specification and discovering the cards differ is
the waste this exists to prevent.

## Why not just OCR the front

A licence number misread by one character is worse than no help at all — it
looks filled in and is wrong. Structured sources avoid the guess entirely:

| Source | Reliability |
|---|---|
| PDF417 barcode (licence back) | Exact — named fields, no character recognition |
| MRZ (passport) | Exact and SELF-CHECKING — carries check digits, so a misread detects itself |
| OCR + heuristics (health card) | Best-effort; always needs human review |

The existing scan session already captures the back of the card, which is
where a licence barcode lives.

## The probe

A **throwaway** dev-only screen. Not shipped, not merged, deleted when the
question is answered.

Provisional dependency: `google_mlkit_barcode_scanning` — same Google
on-device family as the `google_mlkit_text_recognition` already shipped, so no
new vendor and nothing leaves the device. If the answer is "no useful
barcode", the package comes back out in one revert.

### It must report STRUCTURE, not CONTENT

The raw payload of a licence barcode IS the user's identity data — name, date
of birth, address, licence number. A probe that dumps it to the screen invites
pasting it into a chat log, a bug report, or a file.

So the probe outputs a **redacted summary** and never the values:

- barcode **format** (PDF417 / QR / none) and payload **byte length**
- whether the payload begins with `@`+`ANSI ` (the AAMVA header)
- the **set of 3-letter element codes present** (`DAQ`, `DBB`, `DCS`, …) with
  every value replaced by its length — enough to know which fields exist
- for OCR: the **number** of text blocks, and whether any line matches the MRZ
  shape `^[A-Z0-9<]{30,44}$`

That answers the question completely while being safe to share verbatim.

Nothing is written to disk, logged, or persisted. On-screen only.

### What to do

Scan each card, once per side where relevant, and record the summary:

- [ ] Driver's licence — front and back
- [ ] Health card — front and back
- [ ] Passport — photo page

### How to read the result

| Observation | Conclusion |
|---|---|
| Licence back yields PDF417 starting `ANSI ` with `DAQ`/`DBB`/`DCS` codes | Standard AAMVA. Build a parser; exact licence fields are available. |
| Licence back yields a barcode that is NOT AAMVA | Jurisdiction-specific. Decide whether one format is worth a parser. |
| Licence back yields no barcode | OCR heuristics only, or manual entry stays. |
| Passport photo page shows MRZ-shaped lines | Build an ICAO 9303 parser; check digits make it self-verifying. |
| Health card yields nothing machine-readable | Expected. OCR heuristics, low confidence, review mandatory — or leave it manual. |

## If the answer is "structured data exists"

The architecture is already in this repo. `receipt_scan` has the exact shape:
a `ReceiptExtractor` interface (`domain/receipt_extractor.dart`), an on-device
implementation, a separate text parser, and a **pure `applyDraft` merge**
(`domain/apply_draft.dart`) that fills only empty fields and never overwrites.

A `DocumentExtractor` per card type plugged into that same flow generalises to
health card and passport nearly free — and is the reusable photo-ID component
already agreed to come after the licence works.

Two constraints, both already decided and not up for re-litigation here:

- **On-device only for identity documents.** These images are deliberately
  encrypted at rest; sending one to a cloud model would undo that.
- **Never silently auto-fill.** Show what was read, let the user accept or
  correct it. A quietly saved misread licence number is worse than no help.

## Out of scope

- Any parser. This spike decides whether to write one.
- Shipping the probe screen. It is deleted either way.
- Cloud extraction of identity documents — ruled out, see above.
