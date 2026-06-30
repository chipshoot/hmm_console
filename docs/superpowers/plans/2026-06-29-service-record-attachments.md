# Service-Record Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a vehicle's service record carry image and PDF attachments (receipts, invoices, work photos), shown as one flat typed list, in `local` and `cloudStorage` data modes.

**Architecture:** Approach A — the `ServiceRecord` entity carries its attachments as a read-through projection of the owning note's `attachments` column (the exact pattern `LocalAutomobileRepository` already uses for vehicle photos). The save flow mirrors the note editor: hold pending byte-picks, create/update the record to get a note id, persist picks into the vault under `attachments/note-{id}/…`, then write the note's `attachments` column. A new reusable `AttachmentsSection` widget renders the flat list (image thumbnails + PDF cards) for both the editable form and a read-only indicator. No backend or `cloudApi` work.

**Tech Stack:** Flutter, Riverpod 3 (AsyncNotifier), Drift (notes-as-storage), the existing vault/attachments stack (`IVaultStore`, `IImageAttachmentPicker`, `NoteAttachments`/`VaultRef`, `attachmentResolverProvider`), `image_picker`, `file_picker`, `open_filex`, `flutter_platform_widgets`.

---

## Reference reading (skim before starting)

- `docs/superpowers/specs/2026-06-29-service-record-attachments-design.md` — the design.
- `lib/core/data/local/local_automobile_repository.dart` — **the precedent**: `_attachmentsFor`, `attachments:` on create/update, `note.effectiveAttachments` on read.
- `test/core/data/local/local_automobile_repository_attachments_test.dart` — the precedent test (mirror its DB setup).
- `lib/core/data/attachments/attachment_ref.dart` — `VaultRef`, `NoteAttachments`.
- `lib/core/data/attachments/picker/image_attachment_picker.dart` — `persistToVault` / `persistFileToVault`.
- `lib/core/data/attachments/picker/{image,file}_byte_source.dart` — `PickedImageBytes`, `PickedFileBytes`, `imageByteSourceProvider`, `fileByteSourceProvider`.
- `lib/features/notes/presentation/util/open_attachment.dart` — to be lifted to core (Task 3).

## File Structure

**Create:**
- `lib/core/data/attachments/widgets/attachments_section.dart` — reusable flat typed attachment list + add/remove (Task 4).
- `test/features/automobile_records/domain/service_record_test.dart` (Task 1).
- `test/core/data/local/local_service_record_attachments_test.dart` (Task 2).
- `test/core/data/attachments/open_attachment_test.dart` — moved/retargeted if one exists; otherwise a smoke test for the lifted helper (Task 3).
- `test/core/data/attachments/widgets/attachments_section_test.dart` (Task 4).
- `test/features/automobile_records/states/mutate_service_record_attachments_test.dart` (Task 5).

**Modify:**
- `lib/features/automobile_records/domain/entities/service_record.dart` — add `attachments` + `copyWith` (Task 1).
- `lib/core/data/local/local_service_record_repository.dart` — round-trip the column (Task 2).
- `lib/core/data/attachments/open_attachment.dart` — new home of `openAttachment` (Task 3, moved from notes).
- `lib/features/notes/presentation/util/open_attachment.dart` — becomes a re-export, or its importers repoint (Task 3).
- `lib/features/automobile_records/states/mutate_service_record_state.dart` — add `save(...)` (Task 5).
- `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart` — attachments section + use `save` (Task 6).
- `lib/features/automobile_records/presentation/screens/service_records_screen.dart` — attachment indicator on the list tile (Task 7).

---

### Task 1: `ServiceRecord` carries attachments + `copyWith`

**Files:**
- Modify: `lib/features/automobile_records/domain/entities/service_record.dart`
- Test: `test/features/automobile_records/domain/service_record_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/automobile_records/domain/service_record_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

ServiceRecord _record() => ServiceRecord(
      id: 1,
      automobileId: 7,
      date: DateTime(2026, 1, 2),
      mileage: 100,
      type: ServiceType.oilChange,
    );

void main() {
  test('attachments defaults to empty', () {
    expect(_record().attachments.isEmpty, isTrue);
  });

  test('copyWith sets attachments and preserves other fields', () {
    const ref = VaultRef(
      path: 'attachments/note-1/a.jpg',
      contentType: 'image/jpeg',
      byteSize: 10,
    );
    final updated = _record().copyWith(
      attachments: NoteAttachments(images: const [ref]),
    );
    expect(updated.attachments.images, [ref]);
    expect(updated.id, 1);
    expect(updated.mileage, 100);
    expect(updated.type, ServiceType.oilChange);
  });

  test('copyWith without args is an equal-valued copy', () {
    final r = _record();
    final c = r.copyWith();
    expect(c.id, r.id);
    expect(c.date, r.date);
    expect(c.attachments, r.attachments);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/automobile_records/domain/service_record_test.dart > /tmp/t1.txt 2>&1; echo EXIT $?`
Expected: FAIL — `attachments`/`copyWith` not defined (compile error).

- [ ] **Step 3: Add the field + copyWith**

In `service_record.dart`, add the import near the top:

```dart
import '../../../../core/data/attachments/attachment_ref.dart';
```

`NoteAttachments.empty` is a non-const `static final`, so the constructor can no longer be `const`. Replace the existing `const ServiceRecord({ ... });` constructor with this non-const version that defaults `attachments` to empty via an initializer:

```dart
  ServiceRecord({
    required this.id,
    required this.automobileId,
    required this.date,
    required this.mileage,
    required this.type,
    this.description,
    this.cost,
    this.currency = 'CAD',
    this.shopName,
    this.parts = const [],
    this.tax,
    this.notes,
    this.createdDate,
    NoteAttachments? attachments,
  }) : attachments = attachments ?? NoteAttachments.empty;
```

Add the field declaration alongside the others:

```dart
  /// Read-through projection of the owning note's attachments column
  /// (images + PDF files). Empty when the record has none.
  final NoteAttachments attachments;
```

Add `copyWith` at the end of the class (before the closing brace):

```dart
  ServiceRecord copyWith({
    int? id,
    int? automobileId,
    DateTime? date,
    int? mileage,
    ServiceType? type,
    String? description,
    double? cost,
    String? currency,
    String? shopName,
    List<PartItem>? parts,
    double? tax,
    String? notes,
    DateTime? createdDate,
    NoteAttachments? attachments,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      automobileId: automobileId ?? this.automobileId,
      date: date ?? this.date,
      mileage: mileage ?? this.mileage,
      type: type ?? this.type,
      description: description ?? this.description,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      shopName: shopName ?? this.shopName,
      parts: parts ?? this.parts,
      tax: tax ?? this.tax,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
      attachments: attachments ?? this.attachments,
    );
  }
```

> Note: removing `const` from the constructor. Search the codebase for `const ServiceRecord(` and drop the `const` at each call site — there are a handful in tests and possibly the form. The compiler will point them out in the next step.

- [ ] **Step 4: Fix any `const ServiceRecord(` call sites**

Run: `cd /Users/fchy/projects/hmm_console && grep -rn "const ServiceRecord(" lib test`
For each hit, remove the leading `const`. (Construction stays valid; only the `const` qualifier is dropped.)

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/automobile_records/domain/service_record_test.dart > /tmp/t1.txt 2>&1; echo EXIT $?`
Expected: EXIT 0, all pass.

- [ ] **Step 6: Analyze + commit**

```bash
flutter analyze lib/features/automobile_records/domain/entities/service_record.dart
git add lib/features/automobile_records/domain/entities/service_record.dart test/features/automobile_records/domain/service_record_test.dart
git commit -m "$(cat <<'EOF'
feat(service-records): add attachments field + copyWith to ServiceRecord

Read-through projection of the owning note's attachments column, mirroring
the Automobile entity. Constructor drops const (NoteAttachments.empty is a
static final default).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Local repo round-trips the `attachments` column

**Files:**
- Modify: `lib/core/data/local/local_service_record_repository.dart`
- Test: `test/core/data/local/local_service_record_attachments_test.dart`

- [ ] **Step 1: Write the failing test** (mirrors `local_automobile_repository_attachments_test.dart` setup)

Create `test/core/data/local/local_service_record_attachments_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_service_record_repository.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

Automobile _seedAuto() => Automobile(
      id: 0, vin: '1HGBH41JXMN109186', maker: 'Honda', brand: 'Honda',
      model: 'Civic', year: 2020, plate: 'SVC-1', engineType: 'Gasoline',
      fuelType: 'Regular', meterReading: 1, isActive: true);

const _img = VaultRef(
  path: 'attachments/note-2/photo.jpg', contentType: 'image/jpeg',
  byteSize: 1000, originalName: 'photo.jpg');
const _pdf = VaultRef(
  path: 'attachments/note-2/receipt.pdf', contentType: 'application/pdf',
  byteSize: 2000, originalName: 'receipt.pdf');

void main() {
  late HmmDatabase db;
  late LocalServiceRecordRepository repo;
  late int autoId;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    final autoRepo = LocalAutomobileRepository(noteRepo, catalogRepo);
    repo = LocalServiceRecordRepository(noteRepo, catalogRepo);
    autoId = (await autoRepo.createAutomobile(_seedAuto())).id;
  });

  tearDown(() async => db.close());

  ServiceRecord _record({NoteAttachments? attachments}) => ServiceRecord(
        id: 0, automobileId: autoId, date: DateTime(2026), mileage: 100,
        type: ServiceType.oilChange, attachments: attachments);

  test('create without attachments leaves the column null', () async {
    final created = await repo.createRecord(autoId, _record());
    expect(created.attachments.isEmpty, isTrue);
    final row = await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
        .getSingle();
    expect(row.attachments, isNull);
  });

  test('image + pdf round-trip via getRecordById, not in content', () async {
    final created = await repo.createRecord(autoId, _record());
    await repo.updateRecord(autoId, created.id,
        created.copyWith(attachments: NoteAttachments(images: const [_img], files: const [_pdf])));

    final back = await repo.getRecordById(autoId, created.id);
    expect(back.attachments.images, [_img]);
    expect(back.attachments.files, [_pdf]);

    final row = await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
        .getSingle();
    expect(row.content!.contains('photo.jpg'), isFalse);
    expect(row.attachments!.contains('receipt.pdf'), isTrue);
  });

  test('update with empty attachments clears the column', () async {
    final created = await repo.createRecord(autoId, _record(
        attachments: NoteAttachments(images: const [_img])));
    await repo.updateRecord(autoId, created.id,
        created.copyWith(attachments: NoteAttachments.empty));
    final row = await (db.select(db.notes)..where((n) => n.id.equals(created.id)))
        .getSingle();
    expect(row.attachments, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/local/local_service_record_attachments_test.dart > /tmp/t2.txt 2>&1; echo EXIT $?`
Expected: FAIL — attachments not persisted (column null / images empty on read).

- [ ] **Step 3: Implement the round-trip** (copy the Automobile precedent)

In `local_service_record_repository.dart`:

Add the import:
```dart
import '../attachments/attachment_ref.dart';
```

Add a helper (place near `_subjectFor`):
```dart
  NoteAttachments _attachmentsFor(ServiceRecord r) =>
      r.attachments.isEmpty ? NoteAttachments.empty : r.attachments;
```

In `createRecord`, add `attachments:` to the `HmmNoteCreate(...)` (the `stamped` record carries the caller's attachments):
```dart
    final note = await _noteRepo.createNote(HmmNoteCreate(
      subject: _subjectFor(stamped),
      content: _serialize(stamped),
      catalogId: catalog.id,
      parentNoteId: autoId,
      attachments: _attachmentsFor(r),
    ));
```
Also thread `r.attachments` into the `stamped` ServiceRecord so the returned value reflects it — add `attachments: r.attachments,` to the `stamped` constructor.

In `updateRecord`, add `attachments:` to the `HmmNoteUpdate(...)`:
```dart
    await _noteRepo.updateNote(
      id,
      HmmNoteUpdate(
        subject: _subjectFor(updated),
        content: _serialize(updated),
        attachments: _attachmentsFor(r),
      ),
    );
```
Also add `attachments: r.attachments,` to the `updated` ServiceRecord constructor in `updateRecord`.

In `_deserialize`, add to the returned `ServiceRecord(...)`:
```dart
        attachments: note.effectiveAttachments,
```

> Invariant (document inline near `updateRecord`): callers must pass the *full* intended attachment set on every update — an update with empty attachments **clears** the column. The form (Task 6) always round-trips the loaded record's attachments, so this holds.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/local/local_service_record_attachments_test.dart > /tmp/t2.txt 2>&1; echo EXIT $?`
Expected: EXIT 0.

- [ ] **Step 5: Run the existing line-items test (no regression)**

Run: `flutter test test/core/data/local/local_service_record_line_items_test.dart > /tmp/t2b.txt 2>&1; echo EXIT $?`
Expected: EXIT 0.

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/local/local_service_record_repository.dart test/core/data/local/local_service_record_attachments_test.dart
git commit -m "$(cat <<'EOF'
feat(service-records): round-trip attachments column in local repo

Approach A read-through projection, copying the LocalAutomobileRepository
pattern: attachments live on the owning note's column, never in content.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Lift `openAttachment` to core (shared by both features)

**Files:**
- Create: `lib/core/data/attachments/open_attachment.dart`
- Modify: `lib/features/notes/presentation/util/open_attachment.dart` (re-export)
- Test: `test/core/data/attachments/open_attachment_test.dart`

- [ ] **Step 1: Move the file**

Copy the full contents of `lib/features/notes/presentation/util/open_attachment.dart` into a new `lib/core/data/attachments/open_attachment.dart`, fixing the now-shorter relative imports:
```dart
import 'attachment_providers.dart';
import 'attachment_ref.dart';
```
(the `dart:io`, `flutter_riverpod`, `open_filex`, `path`, `path_provider` imports are unchanged).

- [ ] **Step 2: Turn the old path into a re-export**

Replace the body of `lib/features/notes/presentation/util/open_attachment.dart` with:
```dart
// Moved to core so non-note features (e.g. service records) can share it.
export '../../../../core/data/attachments/open_attachment.dart';
```

- [ ] **Step 3: Verify no broken imports**

Run: `flutter analyze lib > /tmp/t3.txt 2>&1; echo EXIT $?`
Expected: EXIT 0 — the re-export keeps existing note imports (`fileOpenerProvider`, `openAttachment`) valid.

- [ ] **Step 4: Smoke test the lifted helper** (only if no test already covers it)

Run: `grep -rln "openAttachment\|fileOpenerProvider" test` — if an existing test references it, just run that test and skip writing a new one. Otherwise create `test/core/data/attachments/open_attachment_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/open_attachment.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';

class _FakeResolver implements IAttachmentResolver {
  @override
  Future<List<int>?> resolve(AttachmentRef ref) async => null; // not available
}

void main() {
  testWidgets('openAttachment returns a message when bytes are unavailable',
      (tester) async {
    late WidgetRef capturedRef;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        attachmentResolverProvider.overrideWith((ref) async => _FakeResolver()),
      ],
      child: Consumer(builder: (c, ref, _) {
        capturedRef = ref;
        return const SizedBox();
      }),
    ));
    final msg = await openAttachment(
      capturedRef,
      const VaultRef(path: 'attachments/note-1/x.pdf',
          contentType: 'application/pdf', byteSize: 1),
    );
    expect(msg, isNotNull); // 'File is not available on this device.'
  });
}
```

> If `IAttachmentResolver.resolve` returns `Future<Uint8List?>` (check the import in `resolver/attachment_resolver.dart`), change `_FakeResolver`'s return type to match and `import 'dart:typed_data'`.

Run: `flutter test test/core/data/attachments/open_attachment_test.dart > /tmp/t3b.txt 2>&1; echo EXIT $?`
Expected: EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/attachments/open_attachment.dart lib/features/notes/presentation/util/open_attachment.dart test/core/data/attachments/open_attachment_test.dart
git commit -m "$(cat <<'EOF'
refactor(attachments): lift openAttachment to core for cross-feature reuse

Notes path becomes a re-export; behaviour unchanged.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `AttachmentsSection` reusable widget

**Files:**
- Create: `lib/core/data/attachments/widgets/attachments_section.dart`
- Test: `test/core/data/attachments/widgets/attachments_section_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/core/data/attachments/widgets/attachments_section_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/file_byte_source.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachments_section.dart';

class _FakeResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final resolver = _FakeResolver();

  testWidgets('editable shows add buttons; read-only hides them',
      (tester) async {
    await tester.pumpWidget(_host(AttachmentsSection(
      items: const [], resolver: _FakeResolver(), editable: true,
      onAddImage: () {}, onAddPdf: () {},
    )));
    expect(find.byKey(const Key('att-add-image')), findsOneWidget);
    expect(find.byKey(const Key('att-add-pdf')), findsOneWidget);

    await tester.pumpWidget(_host(AttachmentsSection(
      items: const [], resolver: _FakeResolver(), editable: false,
    )));
    expect(find.byKey(const Key('att-add-image')), findsNothing);
    expect(find.byKey(const Key('att-add-pdf')), findsNothing);
  });

  testWidgets('renders a pdf file card with its name', (tester) async {
    final item = PendingFileItem(PickedFileBytes(
      bytes: Uint8List.fromList([1, 2, 3]),
      originalName: 'invoice.pdf', contentType: 'application/pdf'));
    await tester.pumpWidget(_host(AttachmentsSection(
      items: [item], resolver: resolver, editable: true,
      onAddImage: () {}, onAddPdf: () {})));
    expect(find.text('invoice.pdf'), findsOneWidget);
  });

  testWidgets('remove button invokes onRemove with the item', (tester) async {
    AttachmentItem? removed;
    final item = PendingFileItem(PickedFileBytes(
      bytes: Uint8List.fromList([1]), originalName: 'a.pdf',
      contentType: 'application/pdf'));
    await tester.pumpWidget(_host(AttachmentsSection(
      items: [item], resolver: resolver, editable: true,
      onAddImage: () {}, onAddPdf: () {}, onRemove: (i) => removed = i)));
    await tester.tap(find.byKey(const Key('att-remove-0')));
    expect(removed, same(item));
  });

  testWidgets('add-image button invokes onAddImage', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(AttachmentsSection(
      items: const [], resolver: resolver, editable: true,
      onAddImage: () => tapped = true, onAddPdf: () {})));
    await tester.tap(find.byKey(const Key('att-add-image')));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/attachments/widgets/attachments_section_test.dart > /tmp/t4.txt 2>&1; echo EXIT $?`
Expected: FAIL — `attachments_section.dart` / `AttachmentItem` undefined.

- [ ] **Step 3: Implement the widget**

Create `lib/core/data/attachments/widgets/attachments_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import '../attachment_ref.dart';
import '../picker/file_byte_source.dart';
import '../picker/image_byte_source.dart';
import '../resolver/attachment_resolver.dart';
import 'attachment_image.dart';

/// One row in an [AttachmentsSection]: a pending (in-memory) pick or a
/// saved [VaultRef]. Pending items aren't tappable-to-open (they have no
/// vault path yet); saved items are.
sealed class AttachmentItem {
  const AttachmentItem();
  bool get isImage;
  String get displayName;
}

class PendingImageItem extends AttachmentItem {
  const PendingImageItem(this.pick);
  final PickedImageBytes pick;
  @override
  bool get isImage => true;
  @override
  String get displayName => pick.originalName;
}

class PendingFileItem extends AttachmentItem {
  const PendingFileItem(this.pick);
  final PickedFileBytes pick;
  @override
  bool get isImage => false;
  @override
  String get displayName => pick.originalName;
}

class SavedAttachmentItem extends AttachmentItem {
  const SavedAttachmentItem(this.ref);
  final VaultRef ref;
  @override
  bool get isImage => ref.contentType.startsWith('image/');
  @override
  String get displayName => ref.originalName ?? 'attachment';
}

/// Flat, typed attachment list. Images render as 80×80 thumbnails; PDFs as
/// document cards. [editable] toggles the add controls and per-item remove.
class AttachmentsSection extends StatelessWidget {
  const AttachmentsSection({
    super.key,
    required this.items,
    required this.resolver,
    required this.editable,
    this.onAddImage,
    this.onAddPdf,
    this.onTap,
    this.onRemove,
  });

  final List<AttachmentItem> items;
  final IAttachmentResolver resolver;
  final bool editable;
  final VoidCallback? onAddImage;
  final VoidCallback? onAddPdf;
  final void Function(AttachmentItem item)? onTap;
  final void Function(AttachmentItem item)? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = <MapEntry<int, AttachmentItem>>[];
    final files = <MapEntry<int, AttachmentItem>>[];
    for (var i = 0; i < items.length; i++) {
      (items[i].isImage ? images : files).add(MapEntry(i, items[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Attachments', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (editable) ...[
              PlatformIconButton(
                key: const Key('att-add-image'),
                icon: const Icon(Icons.add_a_photo_outlined),
                onPressed: onAddImage,
              ),
              PlatformIconButton(
                key: const Key('att-add-pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: onAddPdf,
              ),
            ],
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No attachments yet',
                style: theme.textTheme.bodySmall),
          ),
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in images)
                _Thumb(
                  key: Key('att-${e.key}'),
                  item: e.value,
                  resolver: resolver,
                  editable: editable,
                  onTap: onTap == null ? null : () => onTap!(e.value),
                  onRemove: onRemove == null
                      ? null
                      : () => onRemove!(e.value),
                  removeKey: Key('att-remove-${e.key}'),
                ),
            ],
          ),
        for (final e in files)
          _FileCard(
            key: Key('att-${e.key}'),
            item: e.value,
            editable: editable,
            onTap: onTap == null ? null : () => onTap!(e.value),
            onRemove: onRemove == null ? null : () => onRemove!(e.value),
            removeKey: Key('att-remove-${e.key}'),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.item,
    required this.resolver,
    required this.editable,
    required this.removeKey,
    this.onTap,
    this.onRemove,
  });

  final AttachmentItem item;
  final IAttachmentResolver resolver;
  final bool editable;
  final Key removeKey;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final Widget image = switch (item) {
      PendingImageItem(:final pick) =>
        Image.memory(pick.bytes, width: 80, height: 80, fit: BoxFit.cover),
      SavedAttachmentItem(:final ref) => SizedBox(
          width: 80,
          height: 80,
          child: AttachmentImage(ref: ref, resolver: resolver),
        ),
      _ => const SizedBox(width: 80, height: 80),
    };
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
        ),
        if (editable && onRemove != null)
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              key: removeKey,
              icon: const Icon(Icons.cancel, size: 20),
              onPressed: onRemove,
            ),
          ),
      ],
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    super.key,
    required this.item,
    required this.editable,
    required this.removeKey,
    this.onTap,
    this.onRemove,
  });

  final AttachmentItem item;
  final bool editable;
  final Key removeKey;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
            ),
            if (editable && onRemove != null)
              GestureDetector(
                key: removeKey,
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
```

> If `PlatformIconButton` needs a different parameter name in this project's `flutter_platform_widgets` version, check an existing use (`grep -rn PlatformIconButton lib`) and match it.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/attachments/widgets/attachments_section_test.dart > /tmp/t4.txt 2>&1; echo EXIT $?`
Expected: EXIT 0. (If a pending-image render warning appears, the structural finders still pass — decoding isn't required for `find.byKey`.)

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/core/data/attachments/widgets/attachments_section.dart
git add lib/core/data/attachments/widgets/attachments_section.dart test/core/data/attachments/widgets/attachments_section_test.dart
git commit -m "$(cat <<'EOF'
feat(attachments): reusable AttachmentsSection (flat typed list)

Image thumbnails + PDF cards, editable flag, add/remove/tap callbacks.
Composes core AttachmentImage; not coupled to any feature.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Save flow in `MutateServiceRecordState`

**Files:**
- Modify: `lib/features/automobile_records/states/mutate_service_record_state.dart`
- Test: `test/features/automobile_records/states/mutate_service_record_attachments_test.dart`

The new `save(...)` orchestrates: create-or-update → persist pending picks under the note id → write the merged attachments column → delete removed bytes. Skips all vault work in `cloudApi`.

- [ ] **Step 1: Write the failing test** (in-memory DB + fake pickers, overriding providers)

Create `test/features/automobile_records/states/mutate_service_record_attachments_test.dart`:

```dart
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/file_byte_source.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_automobile_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_service_record_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';
import 'package:hmm_console/features/automobile_records/states/mutate_service_record_state.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

/// In-memory vault that records writes/deletes.
class _MemVault implements IVaultStore {
  final Map<String, Uint8List> store = {};
  final List<String> deleted = [];
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async =>
      store[p] = b;
  @override
  Future<Uint8List> getBytes(String p) async => store[p]!;
  @override
  Future<bool> exists(String p) async => store.containsKey(p);
  @override
  Future<void> delete(String p) async {
    deleted.add(p);
    store.remove(p);
  }
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

class _FakePicker implements IImageAttachmentPicker {
  _FakePicker(this.vault);
  final _MemVault vault;
  int _n = 0;
  @override
  Future<VaultRef?> pickForNote({required int noteId, AttachmentPickSource source = AttachmentPickSource.gallery}) async => null;
  @override
  Future<VaultRef> persistToVault({required int noteId, required Uint8List bytes, required String originalName, String? contentTypeHint}) async {
    final path = 'attachments/note-$noteId/img${_n++}.jpg';
    await vault.putBytes(path, bytes, contentType: 'image/jpeg');
    return VaultRef(path: path, contentType: 'image/jpeg', byteSize: bytes.length, originalName: originalName);
  }
  @override
  Future<VaultRef> persistFileToVault({required int noteId, required Uint8List bytes, required String originalName, required String contentType}) async {
    final path = 'attachments/note-$noteId/file${_n++}.pdf';
    await vault.putBytes(path, bytes, contentType: contentType);
    return VaultRef(path: path, contentType: contentType, byteSize: bytes.length, originalName: originalName);
  }
}

Automobile _seedAuto() => Automobile(
      id: 0, vin: '1HGBH41JXMN109186', maker: 'Honda', brand: 'Honda',
      model: 'Civic', year: 2020, plate: 'SVC-1', engineType: 'Gasoline',
      fuelType: 'Regular', meterReading: 1, isActive: true);

void main() {
  late HmmDatabase db;
  late _MemVault vault;
  late LocalServiceRecordRepository serviceRepo;
  late int autoId;

  Future<ProviderContainer> _container() async {
    final c = ProviderContainer(overrides: [
      serviceRecordRepositoryModeProvider.overrideWithValue(serviceRepo),
      vaultStoreProvider.overrideWith((ref) async => vault),
      imageAttachmentPickerProvider.overrideWith((ref) async => _FakePicker(vault)),
      dataModeProvider.overrideWith(() => _StubMode(DataMode.local)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    vault = _MemVault();
    final aid = await db.into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    final noteRepo = LocalHmmNoteRepository(db, () async => author);
    final catalogRepo = LocalNoteCatalogRepository(db);
    serviceRepo = LocalServiceRecordRepository(noteRepo, catalogRepo);
    autoId = (await LocalAutomobileRepository(noteRepo, catalogRepo)
            .createAutomobile(_seedAuto()))
        .id;
  });

  tearDown(() async => db.close());

  ServiceRecord _new() => ServiceRecord(
      id: 0, automobileId: autoId, date: DateTime(2026), mileage: 50,
      type: ServiceType.oilChange);

  test('new record persists pending image + pdf as VaultRefs', () async {
    final c = await _container();
    await c.read(mutateServiceRecordStateProvider.notifier).save(
      autoId: autoId, record: _new(), isEdit: false,
      pendingImages: [PickedImageBytes(bytes: Uint8List.fromList([9]), originalName: 'p.jpg')],
      pendingFiles: [PickedFileBytes(bytes: Uint8List.fromList([8]), originalName: 'r.pdf', contentType: 'application/pdf')],
    );
    final records = await serviceRepo.getRecords(autoId);
    expect(records, hasLength(1));
    expect(records.single.attachments.images, hasLength(1));
    expect(records.single.attachments.files, hasLength(1));
    expect(vault.store.keys.where((k) => k.endsWith('.jpg')), isNotEmpty);
  });

  test('removing an attachment deletes its bytes', () async {
    final c = await _container();
    final created = await serviceRepo.createRecord(autoId, _new());
    const ref = VaultRef(path: 'attachments/note-x/old.pdf', contentType: 'application/pdf', byteSize: 3);
    vault.store[ref.path] = Uint8List.fromList([1, 2, 3]);
    await c.read(mutateServiceRecordStateProvider.notifier).save(
      autoId: autoId, record: created, isEdit: true,
      removed: const [ref],
    );
    expect(vault.deleted, contains(ref.path));
  });
}

/// Minimal stub for the DataModeNotifier under test.
class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}
```

> Check the real type of `dataModeProvider` (`lib/core/data/data_mode.dart`): if it's a `NotifierProvider<DataModeNotifier, DataMode>`, the `_StubMode` override above is correct. If `build()` does async prefs work, have `_StubMode.build()` just return `_m` synchronously (it's a `Notifier`, not `AsyncNotifier`). Adjust the override form to match (`overrideWith(() => _StubMode(...))`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/automobile_records/states/mutate_service_record_attachments_test.dart > /tmp/t5.txt 2>&1; echo EXIT $?`
Expected: FAIL — `save` not defined.

- [ ] **Step 3: Implement `save`**

In `mutate_service_record_state.dart`, add imports:
```dart
import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/data_mode.dart';
```

Add the method inside the class:
```dart
  /// Create-or-update a record together with its attachments.
  ///
  /// New records: the record is created first (to get the note id), then
  /// pending picks are persisted under that id, then the attachments column
  /// is written. Existing records: picks persist under the existing id and
  /// the column is rewritten with the merged set. Vault work is skipped in
  /// cloudApi (service records aren't note-vault addressable there).
  Future<void> save({
    required int autoId,
    required ServiceRecord record,
    required bool isEdit,
    List<PickedImageBytes> pendingImages = const [],
    List<PickedFileBytes> pendingFiles = const [],
    List<VaultRef> retained = const [],
    List<VaultRef> removed = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(serviceRecordRepositoryModeProvider);

      // 1. Ensure a note id exists.
      final ServiceRecord saved =
          isEdit ? record : (await repo.createRecord(autoId, record))!;
      final noteId = saved.id;

      // 2. Persist pending picks + delete removed bytes (skip in cloudApi).
      final newRefs = <VaultRef>[];
      if (ref.read(dataModeProvider) != DataMode.cloudApi) {
        final picker = await ref.read(imageAttachmentPickerProvider.future);
        for (final img in pendingImages) {
          newRefs.add(await picker.persistToVault(
            noteId: noteId,
            bytes: img.bytes,
            originalName: img.originalName,
            contentTypeHint: img.contentType,
          ));
        }
        for (final f in pendingFiles) {
          newRefs.add(await picker.persistFileToVault(
            noteId: noteId,
            bytes: f.bytes,
            originalName: f.originalName,
            contentType: f.contentType ?? 'application/pdf',
          ));
        }
        if (removed.isNotEmpty) {
          final store = await ref.read(vaultStoreProvider.future);
          for (final r in removed) {
            await store.delete(r.path);
          }
        }
      }

      // 3. Assemble the merged attachment set (retained + new), split by type.
      bool isImage(VaultRef r) => r.contentType.startsWith('image/');
      final all = [...retained, ...newRefs];
      final attachments = NoteAttachments(
        images: all.where(isImage).toList(),
        files: all.where((r) => !isImage(r)).toList(),
      );

      // 4. Write the column. For a brand-new record with no attachments and
      //    nothing removed, the create in step 1 already persisted it.
      final needsWrite =
          isEdit || attachments.isNotEmpty || removed.isNotEmpty;
      if (needsWrite) {
        await repo.updateRecord(
            autoId, noteId, saved.copyWith(attachments: attachments));
      }
    });
    if (state.hasValue) _invalidate();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/automobile_records/states/mutate_service_record_attachments_test.dart > /tmp/t5.txt 2>&1; echo EXIT $?`
Expected: EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/automobile_records/states/mutate_service_record_state.dart test/features/automobile_records/states/mutate_service_record_attachments_test.dart
git commit -m "$(cat <<'EOF'
feat(service-records): save flow persists attachments under the note id

create/update -> persist pending picks -> write merged attachments column;
deletes removed bytes; no-ops the vault work in cloudApi.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Wire the attachments section into the form

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart`

No new test file (covered by Tasks 4–5 + manual smoke). Keep the change mechanical.

- [ ] **Step 1: Add state fields + imports**

Imports:
```dart
import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/open_attachment.dart';
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/attachments_section.dart';
import '../../../../core/data/data_mode.dart';
```

State fields in `_ServiceRecordFormScreenState`:
```dart
  final List<PickedImageBytes> _pendingImages = [];
  final List<PickedFileBytes> _pendingFiles = [];
  List<VaultRef> _savedRefs = []; // retained from the loaded record
```

In `_loadExisting()`, after assigning `_existing`, seed the saved refs:
```dart
      _savedRefs = [
        ...record.attachments.images.whereType<VaultRef>(),
        ...record.attachments.files.whereType<VaultRef>(),
      ];
```

- [ ] **Step 2: Build the items list + add/remove handlers**

Add helpers to the State class:
```dart
  List<AttachmentItem> get _items => [
        for (final p in _pendingImages) PendingImageItem(p),
        for (final r in _savedRefs)
          if (r.contentType.startsWith('image/')) SavedAttachmentItem(r),
        for (final p in _pendingFiles) PendingFileItem(p),
        for (final r in _savedRefs)
          if (!r.contentType.startsWith('image/')) SavedAttachmentItem(r),
      ];

  final List<VaultRef> _removedRefs = [];

  Future<void> _addImage() async {
    final pick = await ref
        .read(imageByteSourceProvider)
        .pick(AttachmentPickSource.gallery);
    if (pick != null) setState(() => _pendingImages.add(pick));
  }

  Future<void> _addPdf() async {
    final pick = await ref.read(fileByteSourceProvider).pickPdf();
    if (pick != null) setState(() => _pendingFiles.add(pick));
  }

  void _removeItem(AttachmentItem item) {
    setState(() {
      switch (item) {
        case PendingImageItem(:final pick):
          _pendingImages.remove(pick);
        case PendingFileItem(:final pick):
          _pendingFiles.remove(pick);
        case SavedAttachmentItem(:final ref):
          _savedRefs.remove(ref);
          _removedRefs.add(ref);
      }
    });
  }

  Future<void> _openItem(AttachmentItem item) async {
    if (item is SavedAttachmentItem) {
      final err = await openAttachment(ref, item.ref);
      if (err != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
    // Pending items have no vault path yet — openable after save.
  }
```

- [ ] **Step 3: Render the section in the form (non-cloudApi only)**

In `build`, before the `HighlightButton`, insert:
```dart
                    if (ref.watch(dataModeProvider) != DataMode.cloudApi) ...[
                      const SizedBox(height: 16),
                      AttachmentsSection(
                        items: _items,
                        resolver: ref
                                .watch(attachmentResolverProvider)
                                .valueOrNull ??
                            const _NullResolver(),
                        editable: true,
                        onAddImage: _addImage,
                        onAddPdf: _addPdf,
                        onRemove: _removeItem,
                        onTap: _openItem,
                      ),
                    ],
```

Add a tiny null-resolver fallback (resolver provider still loading) at file scope:
```dart
class _NullResolver implements IAttachmentResolver {
  const _NullResolver();
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
}
```
(Add `import 'dart:typed_data';` at the top.)

- [ ] **Step 4: Route `_submit` through `save`**

Delete the old tail of `_submit` (`final notifier = ...; if (widget.isEdit) { await notifier.edit(...); } else { await notifier.create(...); }`) and replace it with a single `save` call:
```dart
    final notifier = ref.read(mutateServiceRecordStateProvider.notifier);
    await notifier.save(
      autoId: widget.automobileId,
      record: record,
      isEdit: widget.isEdit,
      pendingImages: _pendingImages,
      pendingFiles: _pendingFiles,
      retained: _savedRefs,
      removed: _removedRefs,
    );
```
The existing `ref.listen` on `mutateServiceRecordStateProvider` still handles the success snackbar + pop.

For an edit, `record` must carry the existing id — it already uses `id: _existing?.id ?? 0`. Good.

- [ ] **Step 5: Analyze + run the automobile-records test suite**

Run: `flutter analyze lib/features/automobile_records > /tmp/t6.txt 2>&1; echo EXIT $?`
Expected: EXIT 0.
Run: `flutter test test/features/automobile_records test/core/data/local > /tmp/t6b.txt 2>&1; echo EXIT $?`
Expected: EXIT 0.

- [ ] **Step 6: Commit**

```bash
git add lib/features/automobile_records/presentation/screens/service_record_form_screen.dart
git commit -m "$(cat <<'EOF'
feat(service-records): attachments section in the service-record form

Pick images/PDFs, view/remove, save through MutateServiceRecordState.save.
Hidden in cloudApi mode.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Attachment indicator on the history list

The `service_records_screen` is a list whose tiles open the (editable) form — there is no separate read-only detail screen, so the "read-only view" from the spec is realized as an at-a-glance **indicator** (paperclip + count) on each tile; the form is where attachments are viewed/managed.

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_records_screen.dart`

- [ ] **Step 1: Add the indicator to `_ServiceTile`**

In `_ServiceTile.build`, compute the count and add it to the subtitle `Column` children (after the totals line):
```dart
            if (record.attachments.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${record.attachments.images.length + record.attachments.files.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
```
(`NoteAttachments` is already reachable via `record.attachments`; no new import needed.)

- [ ] **Step 2: Analyze + smoke test**

Run: `flutter analyze lib/features/automobile_records/presentation/screens/service_records_screen.dart > /tmp/t7.txt 2>&1; echo EXIT $?`
Expected: EXIT 0.

- [ ] **Step 3: Commit**

```bash
git add lib/features/automobile_records/presentation/screens/service_records_screen.dart
git commit -m "$(cat <<'EOF'
feat(service-records): show an attachment count on history tiles

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Final verification

- [ ] **Full analyze:** `flutter analyze > /tmp/final-analyze.txt 2>&1; echo EXIT $?` → EXIT 0.
- [ ] **Full test run:** `flutter test > /tmp/final-test.txt 2>&1; echo EXIT $?` → EXIT 0.
- [ ] **Manual smoke (iOS sim, local mode):** open a vehicle → Service history → add/edit a record → attach a photo and a PDF → save → reopen the record and confirm both render (photo thumbnail opens fullscreen; PDF opens in the OS viewer) → confirm the history tile shows the attachment count → remove one and confirm it's gone after save.

---

## Self-review notes (already reconciled)

- **Spec coverage:** entity (T1), repo round-trip (T2), `openAttachment` lift (T3), `AttachmentsSection` (T4), save flow (T5), form (T6), read-only visibility (T7). All spec sections map to a task.
- **Reconciliation:** the spec's "read-only section in the detail view" is implemented as a list-tile indicator (T7) because `service_records_screen` is a list, not a detail screen; the editable form doubles as the detail surface.
- **Type consistency:** `save(...)` named params match the form's call (T6); `AttachmentItem` variants match between widget (T4), save flow (none — it takes raw picks), and form (T6).
- **cloudApi safety:** form section hidden + `save` skips vault work in cloudApi; entity attachments stay empty and the API repo ignores them.
