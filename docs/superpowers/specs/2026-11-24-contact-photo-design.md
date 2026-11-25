# Contact photo (#96)

Status: **approved by owner 2026-11-24** (Q1 = B, auto-fit). Built before #49
(login-free tiers), whose profile is the Me contact's card and photo. The
original contacts design (`2026-07-25-contacts-design.md`) listed contact
photos as out of scope; this adds them.

## Intent

An optional photo per contact, like the iOS Contacts photo: large at the top
of the contact screen, a small circle in the contact list, initials when there
is none. The Me contact's photo becomes the profile picture (#49 D4).

## Decided (owner, 2026-11-24)

- A real photo, not an avatar/emoji/Memoji; optional.
- Large on the contact screen, circle in the list, initials otherwise.
- Pick from photo library or take with the camera; change or remove.
- Synced with the contact.
- Not included: iOS Contact Poster, Memoji.

## Design (my calls unless marked)

- **Storage:** the contact note's `attachments.primaryImage` — the same slot
  and code path as the car photo (`automobile_edit_screen.dart`): picked and
  downsized by `IImageAttachmentPicker`, stored as a `VaultRef` in the
  vault, shown with `AttachmentImage`. Not sensitive. Syncs through the
  existing note + vault sync (OneDrive), and `VaultGc` frees a replaced photo.
- **Save path:** `LocalContactRepository._write` passes `attachments` on
  both create and update (as `LocalDriverLicenceRepository` does), rebuilding
  with `NoteAttachments.copyWith` so other attachment keys are kept.
  Today it writes content only.
- **Entity:** `Contact` gains `photo` (`AttachmentRef?`), read from the
  note's effective attachments, never from the content JSON.
- **Contact screen:** a large circular photo (about 120 pt) above the name;
  initials in a tinted circle when none. In the edit screen, tapping it
  opens Choose photo / Take photo / Remove photo (Cupertino action sheet on
  iOS, bottom sheet on Android).
- **List:** `ContactTile` shows a 40 pt circle (photo or initials).
- **Initials:** first letters of given + family name; a CJK name uses its
  first character; nothing usable → a person icon.
- **Images arriving later by sync** retry like note images
  (`AttachmentImage.retryOn`).
- **cloudApi:** contacts are unavailable there already; unchanged.
- **Help:** update the contact screen help entries for the photo control.

## Cropping (owner chose B, 2026-11-24)

- **Q1 Cropping.**
  - **A. Crop screen** — add the `image_cropper` package (native iOS crop
    view; Android uCrop). You frame the face yourself. New dependency.
  - **B. Auto-fit** — no new package; the photo is centred and fills the
    circle. Faces off-centre may be cut; you'd pick a better photo instead.
  - I'd pick **B now, A later if it bothers you**: it needs no new
    dependency, and most contact photos are already centred portraits.

## Left to the builder

Exact sizes, the tint colour for initials, sheet copy, test layout.
