# Note Creation & Review Improvements (Apple Journal style) — Design

**Date:** 2026-06-18
**Status:** Approved (brainstorm) — Phase 1 pending implementation plan
**Reference UI:** Apple **Journal** app — media as large rounded cards, a bottom media toolbar, title + date + body flow.

This logs the issues reported during on-device testing plus three new improvements for note creation/review, and details the **Phase 1** (image) implementation. Phases 2–3 are recorded for later.

## Reported issues (from iPhone testing)

- **I1 — Add-image requires a subject.** `NoteEditorScreen._addImage` calls `_save()` first (an image must attach to a persisted note), and save requires a subject → "subject needed" interrupts the pick.
- **I2 — No image in the editor.** After attaching, the editor only shows an "Image added" SnackBar; the OneNote editor has no media area, so you don't see the image until you reopen the note from the list.
- **I3 — Detail thumbnails aren't tappable.** `AttachmentGallery` renders 120px thumbnails with no `onTap`; you can't open the full original. The **vehicle-info screen already does this right** (`automobile_edit_screen._showFullscreenPhoto`: `Dialog` + `InteractiveViewer` + `AttachmentImage`, tap-to-dismiss).

## Phasing

| Phase | Scope | Status |
|-------|-------|--------|
| **1** | Journal-style **images** in create/review: media cards, image-first attach-on-save, bottom media toolbar (photo/camera), shared fullscreen viewer. Fixes I1/I2/I3. | **Now** |
| **2** | Metadata: editable **note date** + immutable **created-at**; optional **geo location** card. | Logged |
| **3** | More media: **voice recording**, **PDF** cards (record/play, attach/preview). | Logged |

---

## Phase 1 — Journal-style images (implement now)

### Layout (editor)

Keeps the existing OneNote structure **and the subsystem-attach dropdown strip**, adds media cards + a bottom toolbar:

```
‹ Notes                         Save     ← compact nav (existing)
[ Attach to subsystem  Automobile ▾ ]    ← KEPT (existing strip)
Camry oil change                         ← title (existing)
June 18, 2026 · 10:24 PM                  ← date (display; editable date = Phase 2)
────────────────────────────             ← divider (existing)
Replaced oil & filter at 84,210 km…      ← body (existing, scrolls)
┌──────────────────────────┐
│   [ large rounded photo ]  ✕ │         ← media card (added)
└──────────────────────────┘
┌── ⟳ Adding photo… ───────┐             ← pending placeholder
└──────────────────────────┘
[ 📷 ] [ 📸 ]                             ← bottom media toolbar (Phase 1: photo, camera)
```

### Components

- **`NoteMediaCardList`** (new, shared) — renders a list of image attachments as **large rounded cards** (Journal style), replacing the 120px thumbnail strip. Two modes:
  - *editable* (editor): each card shows a ✕ to remove; a pending card shows a spinner + "Adding photo…".
  - *read-only* (review): tap a card → fullscreen.
  Used by both the editor and the detail/review screen so they look identical.

- **`MediaToolbar`** (new) — a bottom bar of round buttons. Phase 1: **Photos** (gallery) and **Camera**. Designed to hold more buttons (voice/location/PDF) added in later phases. Sits above the keyboard inset.

- **`showFullscreenImage(context, ref)`** (new, shared) — extracted from `automobile_edit_screen._showFullscreenPhoto`: a `Dialog` + `InteractiveViewer` + `AttachmentImage`, tap-to-dismiss, pinch-zoom. The vehicle screen is refactored to call it (no behavior change there). The editor cards and detail cards both call it.

### "Image-first, attach on save" data flow (fixes I1)

- The editor holds an in-state `pendingPicks` list (images picked this session, stored to a **temp** location — no note id needed). Picking adds to the list and the card appears **immediately** (rendered from local bytes, spinner while loading).
- On **Save**: the note is created/updated (subject still required *to save*), then each pending pick is attached to the note's vault via the existing attach path, and `pendingPicks` clears. If save is blocked (no subject), pending picks **stay** — nothing is lost, and the error message becomes "Add a subject before saving" (no longer tied to the image pick).
- Editing an existing note: its saved attachments load into the card list; new picks are pending until the next save. Uniform model.

### Review screen (fixes I2 read-side + I3)

`NoteDetailScreen` renders attachments via `NoteMediaCardList` (read-only) instead of the old `AttachmentGallery`; tapping a card opens `showFullscreenImage`.

### Testing (Phase 1)

- Widget: picking an image in a **new** note shows a pending card **before** save; on save the note is created and the image attached.
- Widget: tapping a media card (editor or review) opens the fullscreen viewer.
- Widget: removing a pending card (✕) drops it from the list and it is not attached on save.
- Refactor guard: the vehicle screen still opens its fullscreen photo (now via the shared helper).

### Phase 1 explicitly NOT included

- Editable note date / created-at (Phase 2).
- Geo location (Phase 2).
- Voice, PDF, or any non-image media (Phase 3) — the toolbar shows only photo/camera in Phase 1.

---

## Phase 2 — Metadata (logged)

- **N2 — Dates.** Add a user-editable **note date** (defaults to "now") shown under the title and editable via a date/time picker, **separate** from an immutable **created-at** timestamp that is never user-editable (audit). Data model: the Drift `Notes` table already has `createDate` (treat as the immutable created-at) — add a new nullable `noteDate` column for the user-facing/editable date; the list/review/sort use `noteDate` (falling back to `createDate`). Migration required.
- **N1 — Geo location.** Optional per note. On create, attempt a fix (the app already depends on `geolocator`); store lat/lng (+ optional reverse-geocoded label via the existing geocoding API) as note metadata, shown as a **location card** (Journal style). User can decline for **this** note (skip) or for **all** notes (a Settings toggle, persisted). If the device can't get a fix, store/show nothing (empty). No blocking prompts on the create flow.

## Phase 3 — More media (logged)

- **N3 — Voice + PDF.** Extend the attachment model beyond images to typed media (audio, document). Toolbar gains 🎤 (record → waveform card → playback) and 📄 (attach PDF → preview card → open). Requires: an attachment content-type, a recorder/player (new dependency), and a PDF viewer (new dependency). Largest phase; its own spec when scheduled.

## Cross-cutting notes

- **Attachment model.** Phase 1 uses the existing image vault (`NoteAttachments` = primaryImage + images, `AttachmentRef`). Phase 3 will need a media **type** on the ref; flag at that time — out of scope for Phase 1.
- **Shared widgets.** `NoteMediaCardList`, `MediaToolbar`, and `showFullscreenImage` are built so the editor, the review screen, and (for the viewer) the vehicle screen share one implementation — no divergent copies.

## Out of scope (all phases)

- Rich inline media *within* the markdown body (images stay as cards, not inline in text).
- Editing/markup of images (crop, annotate).
- Cloud-sync changes for new media types (handled when Phase 3 is scheduled).
