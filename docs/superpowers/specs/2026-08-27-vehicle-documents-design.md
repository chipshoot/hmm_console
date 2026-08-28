# Vehicle Documents — Design Spec

**Date:** 2026-08-27
**Status:** Approved (brainstorming) — ready for planning
**Scope:** `hmm_console` only. Two documents a driver may be asked to produce: the vehicle's **ownership registration** and the **driver's licence**.

## Goal

Store the registration details that already half-exist on a vehicle, and add a driver's licence that can be *produced on demand* — at a traffic stop, or to a photo-ID checker — with front and back scans and a show-mode built for that moment.

## Why these two are not the same shape

A registration belongs to a **vehicle**; a licence belongs to a **person**. Putting the licence on `Automobile` would give someone with two cars two copies of their licence, free to drift apart. Since this app has no person entity — Contacts is deferred as **#31**, deliberately — the licence becomes a singleton instead.

## Locked decisions

| Area | Decision |
|---|---|
| Registration storage | **Fields on the existing `Automobile` entity.** No new record type, no new catalog. `registrationExpiryDate` already exists, is persisted, IS rendered in the vehicle edit form (`automobile_edit_screen.dart`, label `vehicleRegistrationExpiry`), and IS carried in the automobile API DTO. The three new fields join it. |
| Registration scan | Rides the vehicle's own note `attachments` column - the same mechanism the car photo already uses. Marked `sensitive`. |
| Licence scope | **Exactly one, the user's own.** Not family members. |
| Licence storage | A **singleton note**: catalog `Hmm.AutomobileMan.DriverLicence`, fixed subject `DriverLicence:self`. No list, no picker, no id management. |
| Licence images | **Named slots** `frontImage` / `backImage`, not a generic attachment list. An ID has exactly two sides and the show-mode must never present them in the wrong order. Bytes are referenced from the note's `attachments` column; content records which path is which side. See *Storage* - this is a vault-GC constraint, not a preference. |
| Encryption | Both licence images and the registration scan are stored `sensitive: true`, so they route through `EncryptedVaultStore`. |
| Unlock | **Once per app session**, via the existing `local_auth` gate and session key holder. No new security machinery. |
| Show mode | Full-screen, reusing `lib/core/data/attachments/widgets/fullscreen_image.dart`. Flip front↔back. **No brightness or wakelock control** — those are two new platform plugins for a nicety, deferred until the feature has been used. |
| Entry points | A dashboard tile **and** a launcher destination, so `/lic` finds it. Two taps at most. |
| Data mode | **local + cloudStorage only.** See *Data mode* below — this is a hard constraint, not a detail. |

## Why the licence gets a catalog when the contact block did not

This question was asked and answered once already, and the answer differs here for a reason worth recording.

A **contact block** is a *fragment of another record* — it always has a host (a policy, a note), so it needs no storage of its own and got none. A **licence is a standalone document belonging to no vehicle**. There is nothing for it to be a fragment of, and it carries its own attachments, which live on notes. So it must be a note, and every note needs a catalog.

`Hmm.AutomobileMan.DriverLicence` is three segments so `CatalogPalette.domainKeyFor` reads `AutomobileMan` as the domain key and groups it with the rest of the vehicle domain. It is a new **catalog**, not a new **domain** — exactly how `GasLog`, `ServiceRecord` and `AutoInsurancePolicy` each already sit under `AutomobileMan`.

## Data mode

Neither document reaches the API.

- **Attachments are local/cloudStorage only** — the API has no attachment support for these records. This already applies to service records and insurance.
- **The licence has no API at all**; `Hmm.AutomobileMan.DriverLicence` exists only client-side. `driverLicenceRepositoryModeProvider` throws `UnimplementedError` for `cloudApi`, matching how cheatsheets shipped before their backend existed.
- **The automobile API DTO already carries `registrationExpiryDate`**, so the vehicle itself is API-backed. The **three new registration fields are not in it**, so a `cloudApi` save would drop those three specifically. Adding them is small backend work in the `Hmm` repo (three nullable fields on the DTO plus mapping) and is the better long-term answer; it is out of scope here.

**Therefore, until that backend work lands, the UI hides the three new registration fields and the whole licence feature in `cloudApi` mode**, rather than accepting input and discarding it. Note the existing expiry picker stays visible in every mode, because the API does carry it. This is not caution for its own sake: the insurance work shipped without that guard and a `cloudApi` user could type an agent's phone number, see a success message, and lose it. The service-record form already has the guard; follow it.

## Data model

```dart
// Added to the existing Automobile entity, beside registrationExpiryDate.
final String? registrationNumber;
final String? registrationJurisdiction;   // province / state, free text
final DateTime? registrationIssuedDate;
```

```dart
/// The user's own driver's licence. Exactly one exists.
///
/// Persisted as a single HmmNote under `Hmm.AutomobileMan.DriverLicence`
/// with the fixed subject `DriverLicence:self`, so there is no id to manage
/// and a second save updates rather than creating a duplicate.
class DriverLicence {
  const DriverLicence({
    this.number,
    this.licenceClass,
    this.jurisdiction,
    this.issuedDate,
    this.expiryDate,
    this.frontImage,
    this.backImage,
    this.extraFields = const {},
  });

  final String? number;

  /// "G", "Class 5", "A" - free text, since it varies by jurisdiction and a
  /// fixed enum would reject a valid licence.
  final String? licenceClass;

  final String? jurisdiction;
  final DateTime? issuedDate;
  final DateTime? expiryDate;

  /// Named slots, not a list: the show-mode must always know which side it is
  /// displaying. Null means that side has not been captured yet.
  ///
  /// The BYTES live in the note's `attachments` column like every other
  /// attachment - see Storage for why that is not negotiable. These refs are
  /// resolved from that column on read, using the paths recorded in content.
  final VaultRef? frontImage;
  final VaultRef? backImage;

  /// Keys this version does not model, kept verbatim so an older client
  /// cannot destroy a newer one's data.
  final Map<String, dynamic> extraFields;

  bool get hasImages => frontImage != null || backImage != null;
}
```

Both `licenceClass` and `jurisdiction` are **stored literals**, never translated. Display copy, if any is needed, goes in a labels file — the same rule that applies to `ContactInfo.role` and the settings enums.

## Storage

- **Registration**: three more keys in the JSON the automobile note already writes, plus the scan on that note's `attachments` column. No migration; existing vehicles simply have the fields absent.
- **Licence**: one note, with the images stored in **two places that serve different jobs**:
  - The **bytes are referenced from the note's `attachments` column**, exactly like every other attachment in the app.
  - The **content JSON records two paths**, `frontImagePath` and `backImagePath`, naming which of those attachments is which side.

  On read, the two paths are resolved against the attachments column to produce `frontImage` / `backImage`.

  **This split is not incidental and must not be "simplified" away.** `VaultGc` builds its set of live paths by reading **every note's `attachments` column** and deleting any vault file it does not find there; its own documentation warns that an incomplete set deletes live attachments. Storing the refs only in content — the obvious first instinct, and what the first draft of this spec said — would make the licence images invisible to GC, and the next collection would delete the user's licence photos.

  Recording the side in content rather than in the column is what preserves the named-slot distinction, since `NoteAttachments` is an unordered set. The failure mode is also benign in the right direction: if the content mapping is ever lost, the bytes survive as ordinary unordered attachments rather than being deleted.
- Unknown JSON keys are preserved verbatim on both, via `extraFields`.

## UI

**Vehicle form** — the three new fields join the existing expiry picker, grouped under a "Registration" heading, with the scan attached. The expiry picker already exists and is already rendered; it is being grouped, not introduced.

**Licence screen** — details plus front/back thumbnails, an edit affordance, and capture actions for each side. An empty state when nothing has been captured yet.

**Show mode** — full-screen image, tap or swipe to flip sides, the licence details readable alongside for a checker who wants the number rather than the picture. Dismiss returns to the licence screen.

**Entry** — a dashboard tile, and a launcher destination whose `id` and `routeName` stay literal (favorites persist by id) while the title is localized, with English terms kept in `synonyms` so a bilingual user can still type `licence`.

## Localization

New user-facing strings get ARB keys in **both** `app_en.arb` and `app_zh.arb`, which must stay at equal key count. Stored values — `licenceClass`, `jurisdiction`, the catalog name, the subject — are never translated.

## Testing

- **Codec**: round-trip a fully populated licence, one with only an expiry date, and one with only a front image; unknown keys survive an edit; a malformed date does not take the whole licence down.
- **Singleton**: saving twice updates one note rather than creating a second; the subject is `DriverLicence:self` regardless of content.
- **Named slots**: capturing a back image leaves the front untouched, and vice versa; replacing one side deletes only that side's bytes, and only after the write lands.
- **GC safety**: both licence images appear in the note's `attachments` column, so a `VaultGc` run with a correctly-built referenced set does NOT delete them. Worth an explicit test - getting this wrong deletes the user's licence photos silently, and the first draft of this spec got it wrong.
- **Registration**: the three new fields survive a create and an unrelated edit — `LocalAutomobileRepository` rebuilds the automobile field by field, so a field it forgets never reaches storage. Test against a real database, not the codec alone.
- **Show mode**: flips sides; renders the correct image in each slot; a licence with one side missing degrades rather than erroring.
- **Data mode**: in `cloudApi` the licence entry point and the three NEW registration fields are absent, so nothing can be typed and lost; the existing expiry picker remains, since the API carries it.
- Every guarantee above should be **mutation-checked** — reverting the fix must fail the test that names it.

## Non-goals

- **Expiry reminders or dashboard warnings** for either document. Both carry expiry dates and a reminder is the obvious next feature; it is not needed to store the data.
- **Family members' licences.** Chosen deliberately; adding one later means a migration from singleton to collection, and probably reviving Contacts (#31).
- **Brightness and wakelock** in show mode — two new platform plugins.
- **Cheatsheet wallet rendering these.** Wallet rows resolve to scalars (`NotePieceExtractor.field` returns `String?`), so displaying an image there is its own piece of work. A cheatsheet row *can* already bind the licence number or expiry as text.
- **Backend support**: adding the three registration fields to the automobile API DTO (small, and the right long-term fix), and any API at all for the licence.

## Future phases

- Expiry reminders across registration, licence and insurance together — all three have expiry dates and none is surfaced today.
- Family licences, if and when a person model exists.
- Cheatsheet image rows, which would let the licence live in the wallet alongside everything else.
