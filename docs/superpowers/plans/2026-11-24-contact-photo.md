# Contact Photo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An optional iOS-style photo per contact — large on the contact screen, a circle in the list, initials when none — stored in the contact note's `attachments.primaryImage` and synced like note images.

**Architecture:** `Contact` gains a `photo` (`AttachmentRef?`) read from the note's attachments, never from content JSON. `LocalContactRepository` writes attachments on every save, preserving other keys. The edit state holds picked bytes (`PickedImageBytes`, via `imageByteSourceProvider`) until save, then persists them with `IImageAttachmentPicker.persistToVault` against the contact's note id — the same two-step the note editor uses, because a new contact has no note id yet. One `ContactPhoto` widget draws photo / pending bytes / initials everywhere.

**Tech Stack:** Flutter, Riverpod, Drift, gen-l10n (en, zh).

**Spec:** `docs/superpowers/specs/2026-11-24-contact-photo-design.md` (owner-approved 2026-11-24; Q1 = **B, auto-fit, no crop screen**).

## Global Constraints

- **No new package** (Q1 = B). The photo is shown `BoxFit.cover`, centred, clipped to a circle.
- Not sensitive: `persistToVault(..., sensitive: false)`.
- Photo lives only in `attachments.primaryImage`; never in the contact content JSON (`ContactCodec` unchanged).
- Rebuild attachments with `NoteAttachments.copyWith` — never re-list known fields (CLAUDE.md, Data layer).
- iOS: `CupertinoActionSheet` via `showCupertinoModalPopup`; Android: `showModalBottomSheet` — branch on `Theme.of(context).platform`.
- Icon buttons use `HmmIconButton`; changed screens update their `help_registry.dart` entries.
- Strings in both `app_en.arb` and `app_zh.arb`, then `flutter gen-l10n`; generated files are committed.
- Sizes: detail/edit photo **120** pt diameter; list photo **40** pt.
- Never `dart format` a directory; format only touched files.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A contact saved for another reason (rename, birthday, another contact taking "This is me") keeps its photo — tested in Task 2.
2. Adding a photo to a brand-new, unsaved contact — tested in Task 3.
3. Picker failures (`AttachmentPickerException`: too large / unsupported type) show a snackbar, never crash or lose the form — tested in Task 4.
4. Removing a photo drops the ref from `attachments` (so `VaultGc` frees the bytes) while other attachment keys survive — tested in Task 2.
5. A photo whose file arrives by sync after the note shows once it lands (`retryOn: attachmentsPulledSignalProvider`) — wired in Task 4 (same as `note_row.dart`).

---

### Task 1: `Contact.photo` and initials

**Files:**
- Modify: `lib/features/contacts/domain/entities/contact.dart` (constructor, field, `copyWith`, `==`, `hashCode`)
- Create: `lib/features/contacts/domain/contact_initials.dart`
- Test: `test/features/contacts/domain/contact_test.dart`, Create `test/features/contacts/domain/contact_initials_test.dart`

**Interfaces:**
- Produces: `final AttachmentRef? photo;` on `Contact` (constructor `this.photo`); `copyWith({Object? photo = _kSentinel, ...})` (sentinel so `photo: null` clears); `photo` in `==`/`hashCode`.
- Produces: `String? contactInitials(Contact c)`.

- [ ] **Step 1: Write failing tests**

```dart
// contact_test.dart — build `ref` with VaultRef's real constructor
test('copyWith keeps photo when omitted and clears it with null', () {
  final c = Contact(id: 'a', firstName: 'Jane', photo: ref);
  expect(c.copyWith(firstName: 'Janet').photo, ref);
  expect(c.copyWith(photo: null).photo, isNull);
});
test('photo takes part in equality', () {
  expect(Contact(id: 'a', photo: ref) == Contact(id: 'a'), isFalse);
});

// contact_initials_test.dart
expect(contactInitials(Contact(id: 'a', firstName: 'jane', lastName: 'smith')), 'JS');
expect(contactInitials(Contact(id: 'a', firstName: 'Jane')), 'J');
expect(contactInitials(Contact(id: 'a', lastName: '王', firstName: '小明')), '王');
expect(contactInitials(Contact(id: 'a', contactType: ContactType.organization, organizationName: 'acme')), 'A');
expect(contactInitials(Contact(id: 'a')), isNull);
```

- [ ] **Step 2: Run** `flutter test test/features/contacts/domain/` — Expected: FAIL (no `photo`, no `contactInitials`).
- [ ] **Step 3: Implement.** Initials rule: if `displayName` is empty → null; if its first rune is CJK (Han `㐀-鿿`, Hangul `가-힯`, kana `぀-ヿ`) → that character; organization → first letter of `organizationName` uppercased; person → uppercased first letter of `firstName` then of `lastName` (whichever exist).
- [ ] **Step 4: Run** `flutter test test/features/contacts` — Expected: PASS.
- [ ] **Step 5: Commit** `feat(contacts): Contact.photo and initials`.

---

### Task 2: Repository reads and writes the photo

**Files:**
- Modify: `lib/core/data/local/local_contact_repository.dart` (`_deserialize`, `_write`, new `noteIdFor`)
- Modify: `lib/features/contacts/data/i_contact_repository.dart`
- Modify: `test/features/contacts/data/contact_repository_fakes.dart`
- Test: `test/features/contacts/data/local_contact_repository_test.dart`

**Interfaces:**
- Consumes: `Contact.photo` (Task 1).
- Produces: `Future<int?> noteIdFor(String contactId)` on `IContactRepository` — the stored note's id, or null if none.

- [ ] **Step 1: Write failing tests** (in the existing file's setup style):
  - `'save with a photo, read it back'` — save `Contact(id:'', firstName:'Jane', photo: ref)`; `getContact(saved.id)!.photo == ref`.
  - `'saving without photo change keeps the photo'` — save with photo, read back, save `copyWith(firstName:'Janet')`; photo still `ref`.
  - `'photo: null removes it and keeps other attachment keys'` — create the contact, then set `NoteAttachments(primaryImage: ref, extra: {'future': 1})` on its note directly via the notes repo; save `copyWith(photo: null)`; the note's `effectiveAttachments.primaryImage` is null and `extra['future'] == 1`.
  - `'another contact taking isSelf keeps the first one's photo'` — A (isSelf, photo), then save B with `isSelf: true`; A's photo unchanged, A.isSelf false.
  - `'noteIdFor returns the note id, null for unknown'`.
- [ ] **Step 2: Run** `flutter test test/features/contacts/data/local_contact_repository_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `_deserialize`: after `ContactCodec.fromMap`, `.copyWith(photo: note.effectiveAttachments.primaryImage)`.
  - `_write`: create passes `attachments: c.photo == null ? NoteAttachments.empty : NoteAttachments(primaryImage: c.photo)`; update passes `attachments: existing.effectiveAttachments.copyWith(primaryImage: c.photo, clearPrimaryImage: c.photo == null)`. Attachments go on **both** paths (see `LocalDriverLicenceRepository.saveLicence`).
  - `noteIdFor`: match by `contactSubjectFor(id)` like `_write`.
  - Fake: implement `noteIdFor` (stable int per stored id, null when absent).
- [ ] **Step 4: Run** `flutter test test/features/contacts` — Expected: PASS.
- [ ] **Step 5: Commit** `feat(contacts): store the contact photo in the note's primaryImage`.

---

### Task 3: Edit state picks, stages and saves the photo

**Files:**
- Modify: `lib/features/contacts/states/contact_edit_state.dart`
- Modify: `lib/features/contacts/states/contacts_state.dart` (`save` returns `Future<Contact>`)
- Test: `test/features/contacts/states/contact_edit_state_test.dart`, `contacts_state_test.dart`

**Interfaces:**
- Consumes: `noteIdFor` (Task 2); `imageByteSourceProvider` / `PickedImageBytes` (`lib/core/data/attachments/picker/image_byte_source.dart`); `imageAttachmentPickerProvider` → `IImageAttachmentPicker.persistToVault({required int noteId, required Uint8List bytes, required String originalName, String? contentTypeHint, bool sensitive})`.
- Produces on `ContactEditData`: `final PickedImageBytes? pendingPhoto;` and `final bool photoRemoved;`.
- Produces on `ContactEditState`: `Future<void> pickPhoto(AttachmentPickSource source)` (null pick = no change; sets `pendingPhoto`, clears `photoRemoved`; lets `AttachmentPickerException` propagate), `void removePhoto()` (clears `pendingPhoto`, sets `photoRemoved`), `bool get hasPhoto` (pending, or `contact.photo != null && !photoRemoved`).
- Produces: `ContactsState.save(Contact) → Future<Contact>` returning the saved contact with its minted id.

- [ ] **Step 1: Write failing tests** (override `imageByteSourceProvider` with a fake returning canned bytes and `imageAttachmentPickerProvider` with a fake recording `persistToVault` calls and returning a `VaultRef`):
  - `'photo picked on a new contact is persisted after the first save'` — blank-id contact, `pickPhoto(gallery)`, `save()`; the fake got `noteId == repo.noteIdFor(savedId)`; the stored contact's `photo` is the returned ref.
  - `'cancelled pick changes nothing'` — fake returns null; `pendingPhoto` null; `save()` stores no photo.
  - `'removePhoto clears the stored photo on save'`.
  - `'save without touching the photo keeps it and never calls the picker'`.
  - contacts_state: `'save returns the saved contact with its id'`.
- [ ] **Step 2: Run** `flutter test test/features/contacts/states/` — Expected: FAIL.
- [ ] **Step 3: Implement** `save()`: build `contact` as now; if `photoRemoved` → `contact.copyWith(photo: null)`; `saved = await contacts.save(contact)`; if `pendingPhoto != null` → `noteId = await repo.noteIdFor(saved.id)`, `ref = await picker.persistToVault(noteId: noteId!, bytes: …, originalName: …, contentTypeHint: …)`, then `await contacts.save(saved.copyWith(photo: ref))`. Keep the existing `_inFlight` guard and rethrow behaviour.
- [ ] **Step 4: Run** `flutter test test/features/contacts` — Expected: PASS.
- [ ] **Step 5: Commit** `feat(contacts): pick, stage and save a contact photo`.

---

### Task 4: `ContactPhoto` widget, screens, strings, help

**Files:**
- Create: `lib/features/contacts/presentation/widgets/contact_photo.dart`
- Modify: `contact_tile.dart`, `contact_detail_screen.dart`, `contact_edit_screen.dart`, `lib/core/help/help_registry.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (+ regenerated `lib/l10n/gen/*`)
- Test: Create `test/features/contacts/presentation/contact_photo_test.dart`; extend `contact_edit_screen_test.dart`, `contacts_list_screen_test.dart`, `contact_detail_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3; `attachmentResolverProvider` (`FutureProvider<IAttachmentResolver>`), `AttachmentImage(ref:, resolver:, fit: BoxFit.cover, retryOn:)`, `attachmentsPulledSignalProvider`.
- Produces: `ContactPhoto({required Contact contact, required double size, PickedImageBytes? pending, bool removed = false})` — order: `pending` bytes (`Image.memory`) → `contact.photo` unless `removed` (`AttachmentImage`, initials as loading/error placeholder) → initials in a `CircleAvatar` tinted `colorScheme.primaryContainer` → `Icons.person_outline` / `Icons.business_outlined` when initials are null. Always a circle of `size`.

ARB keys:

| key | en | zh |
|---|---|---|
| `contactPhotoChoose` | Choose photo | 选择照片 |
| `contactPhotoTake` | Take photo | 拍照 |
| `contactPhotoRemove` | Remove photo | 移除照片 |
| `contactPhotoChange` | Change photo | 更换照片 |
| `contactPhotoPickFailed` | Couldn't add the photo | 无法添加照片 |
| `helpContactEditPhotoTitle` | Photo | 照片 |
| `helpContactEditPhotoBody` | Tap the circle at the top to choose a photo, take one, or remove it. It shows on the contact and in the list. | 点按顶部的圆圈，可选择照片、拍照或移除照片。照片会显示在联系人页面和列表中。 |

Cancel uses the existing `commonCancel`.

- [ ] **Step 1: Write failing widget tests:**
  - `contact_photo_test`: no photo, Jane Smith → text `JS`; `pending` given → an `Image` whose provider is a `MemoryImage`; `removed: true` with a photo → initials.
  - list: Jane Smith's tile shows `JS` in a `ContactPhoto` of size 40.
  - detail: a `ContactPhoto` of size 120 above the name.
  - edit (iOS platform override): tapping key `contact-photo-button` shows Choose photo, Take photo, Cancel and **no** Remove photo when there is no photo; with a photo, Remove photo appears; choosing it shows initials.
  - edit: a fake `imageByteSourceProvider` throwing `AttachmentPickerException('too big')` → snackbar `too big`; another error → `contactPhotoPickFailed`; the form stays open.
  - help: `HelpId.contactEdit` includes `helpContactEditPhotoTitle` with icon `Icons.add_a_photo_outlined`.
- [ ] **Step 2: Run** `flutter test test/features/contacts/presentation/ test/core/help/` — Expected: FAIL.
- [ ] **Step 3: Implement.**
  - Tile: `leading: ContactPhoto(contact: contact, size: 40)`.
  - Detail: replace the header `ListTile`'s leading icon with a centred `ContactPhoto(size: 120)` above the name and relationship.
  - Edit: centred tappable `ContactPhoto(size: 120, pending: data.pendingPhoto, removed: data.photoRemoved)` at the top of the form (key `contact-photo-button`, semantic label `contactPhotoChange`); sheet per Global Constraints; actions call `pickPhoto(gallery|camera)` / `removePhoto()`; capture the messenger before awaits.
  - Help entry added to `HelpId.contactEdit`; run `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter test` (full) and `flutter analyze` — Expected: all pass, no issues.
- [ ] **Step 5: Commit** `feat(contacts): show contact photos in the list, contact and editor`.
