# Note PDF Attachments (Phase 3a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a note carry PDF (and structurally any non-image) file attachments shown as tappable Journal-style cards that open in the OS viewer — by adding a generic `files` list to the shared `NoteAttachments` model (client + backend), reusing the existing vault/persist plumbing, and closing the attachment-ref sync gap.

**Architecture:** `NoteAttachments` gains a third slot `files` alongside `primaryImage`/`images`; entries are type-agnostic `VaultRef`s rendered by `contentType`. PDF picking reuses `persistToVault`; viewing hands the vault file to the OS via `open_filex`. The synced note body starts carrying the `attachments` JSON column so refs (images + files) propagate across devices.

**Tech Stack:** Backend — .NET 10, `Hmm.Core.Vault` (System.Text.Json codec + JSON Schema), AutoMapper, xUnit. Client — Flutter, Drift, Riverpod, `file_picker` (existing), `open_filex` (new), `path_provider` (existing).

**Two repos:**
- Backend: `/Users/fchy/projects/hmm`, branch off `main` (e.g. `feat/note-pdf-attachments`)
- Client: `/Users/fchy/projects/hmm_console`, branch off `main` (e.g. `feat/note-pdf-attachments-phase3a`)

---

## File Structure

### Backend (`/Users/fchy/projects/hmm`)
- Modify: `src/Hmm.Core.Vault/NoteAttachments.cs` — add `Files`
- Modify: `src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json` — add `files`
- Modify: `src/Hmm.Core.Vault/NoteAttachmentsCodec.cs` — decode/encode `files`
- Test: `src/Hmm.Core.Vault.Tests/NoteAttachmentsCodecTests.cs`
- Modify: `src/Hmm.Core.Map/DomainEntity/HmmNote.cs` — add `Files`
- Modify: `src/Hmm.Core.Map/HmmMappingProfile.cs` — project `Files` from/to the column
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`, `ApiNoteForCreate.cs`, `ApiNoteForUpdate.cs` — add `Files`

### Client (`/Users/fchy/projects/hmm_console`)
- Modify: `lib/core/data/attachments/attachment_ref.dart` — `NoteAttachments.files`
- Modify: `lib/core/data/attachments/attachment_ref_codec.dart` — codec `files`
- Modify: `lib/core/data/vault/vault_gc.dart` — files reachable
- Create: `lib/core/data/attachments/picker/file_byte_source.dart` — `PickedFileBytes` + `FileByteSource`
- Create: `lib/features/notes/presentation/widgets/note_file_card.dart`
- Create: `lib/features/notes/presentation/widgets/note_file_card_list.dart`
- Create: `lib/features/notes/presentation/util/open_attachment.dart` — open helper + `fileOpenerProvider`
- Modify: `lib/features/notes/states/mutate_note_state.dart` — `attachFileBytes`
- Modify: `lib/features/notes/presentation/widgets/media_toolbar.dart` — 📄 button
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart` — pending files
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart` — file cards
- Modify: `lib/core/data/sync/sync_orchestrator.dart` — sync `attachments` column
- Modify: `pubspec.yaml` — add `open_filex`

---

# PART A — Backend (`/Users/fchy/projects/hmm`)

## Task A1: `files` in the Vault payload (container + schema + codec)

**Files:**
- Modify: `src/Hmm.Core.Vault/NoteAttachments.cs`
- Modify: `src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json`
- Modify: `src/Hmm.Core.Vault/NoteAttachmentsCodec.cs`
- Test: `src/Hmm.Core.Vault.Tests/NoteAttachmentsCodecTests.cs`

- [ ] **Step 1: Write the failing codec test** — in `NoteAttachmentsCodecTests.cs`, add (mirror the existing round-trip test's `VaultRef` construction):

```csharp
    [Fact]
    public void Encode_then_Decode_round_trips_files()
    {
        var pdf = new VaultRef
        {
            Path = "attachments/note-1/report.pdf",
            ContentType = "application/pdf",
            ByteSize = 240,
            OriginalName = "report.pdf",
        };
        var value = new NoteAttachments(files: new List<VaultRef> { pdf });

        var json = NoteAttachmentsCodec.Encode(value);
        Assert.NotNull(json);
        var back = NoteAttachmentsCodec.Decode(json!);

        Assert.Single(back.Files);
        Assert.Equal("attachments/note-1/report.pdf", back.Files[0].Path);
        Assert.Equal("application/pdf", back.Files[0].ContentType);
    }
```

NOTE: if `VaultRef` uses a constructor rather than init-properties, copy the exact construction from the existing test in this file.

- [ ] **Step 2: Run it to verify it fails** — Run: `dotnet test src/Hmm.Core.Vault.Tests/Hmm.Core.Vault.Tests.csproj --filter "FullyQualifiedName~round_trips_files"`
Expected: FAIL — `NoteAttachments` has no `Files` / `files` ctor param.

- [ ] **Step 3: Add `Files` to the container** — in `src/Hmm.Core.Vault/NoteAttachments.cs`:

After the `Images` property, add:

```csharp
    /// <summary>
    /// Non-image attachments (PDF now; audio later). Rendered by
    /// content type. Independent of <see cref="Images"/>.
    /// </summary>
    public IReadOnlyList<VaultRef> Files { get; }
```

Change the constructor signature and body:

```csharp
    public NoteAttachments(
        VaultRef? primaryImage = null,
        IList<VaultRef>? images = null,
        IList<VaultRef>? files = null)
    {
        images ??= Array.Empty<VaultRef>();
        files ??= Array.Empty<VaultRef>();
        // ... existing disjointness check on primaryImage/images unchanged ...
        PrimaryImage = primaryImage;
        Images = images.ToList().AsReadOnly();
        Files = files.ToList().AsReadOnly();
    }
```

Update `IsEmpty` to include files:

```csharp
    public bool IsEmpty => PrimaryImage == null && Images.Count == 0 && Files.Count == 0;
```

In `Equals`, after the images comparison, also compare `Files` element-wise (mirror the existing `Images` comparison loop); include `Files` in `GetHashCode`.

- [ ] **Step 4: Add `files` to the schema** — in `src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json`, in `properties`, after the `images` property, add a `files` property identical in shape to `images` (array of the vault-ref item definition). Do not add it to any `required` list.

- [ ] **Step 5: Decode + encode `files` in the codec** — in `src/Hmm.Core.Vault/NoteAttachmentsCodec.cs`:

In `Decode`, after building `images`, add a parallel block reading the `files` array (absent ⇒ empty list), then pass it: `return new NoteAttachments(primary, images, files);`.

In `Encode`, build the `files` list and emit it **only when non-empty** (so existing images-only payloads stay byte-identical). Replace the anonymous-object serialize with an order-preserving dictionary:

```csharp
        var files = value.Files.Select(VaultRefToJson).ToList();
        var dict = new Dictionary<string, object?>
        {
            ["primaryImage"] = primary,
            ["images"] = images,
        };
        if (files.Count > 0) dict["files"] = files;
        return JsonSerializer.Serialize(dict, JsonOptions);
```

- [ ] **Step 6: Run the codec tests** — Run: `dotnet test src/Hmm.Core.Vault.Tests/Hmm.Core.Vault.Tests.csproj`
Expected: PASS (new test + all existing, since empty `files` is omitted).

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Core.Vault/NoteAttachments.cs src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json src/Hmm.Core.Vault/NoteAttachmentsCodec.cs src/Hmm.Core.Vault.Tests/NoteAttachmentsCodecTests.cs
git commit -m "feat(vault): add generic files list to NoteAttachments payload"
```

## Task A2: `Files` on domain + DTOs + mapping projection

**Files:**
- Modify: `src/Hmm.Core.Map/DomainEntity/HmmNote.cs`
- Modify: `src/Hmm.Core.Map/HmmMappingProfile.cs`
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`, `ApiNoteForCreate.cs`, `ApiNoteForUpdate.cs`
- Test: `src/Hmm.Core.Map.Tests/HmmNoteAttachmentsMappingTests.cs`

- [ ] **Step 1: Write the failing mapping test** — in `src/Hmm.Core.Map.Tests/HmmNoteAttachmentsMappingTests.cs`, add a test that a `HmmNoteDao` whose `Attachments` column JSON contains a `files` entry maps to a domain `HmmNote` with one `Files` ref, and back. Mirror the existing attachments mapping test's setup; assert:

```csharp
        Assert.Single(note.Files);
        Assert.Equal("application/pdf", note.Files[0].ContentType);
```

Use a column JSON value of:
`{"images":[],"files":[{"kind":"vault","path":"attachments/n/r.pdf","contentType":"application/pdf","byteSize":3}]}`

- [ ] **Step 2: Run it to verify it fails** — Run: `dotnet test src/Hmm.Core.Map.Tests/Hmm.Core.Map.Tests.csproj --filter "FullyQualifiedName~Files"`
Expected: FAIL — `HmmNote` has no `Files`.

- [ ] **Step 3: Domain entity** — in `src/Hmm.Core.Map/DomainEntity/HmmNote.cs`, after the `Images` property, add:

```csharp
        /// <summary>Non-image attachments (PDF now, audio later). Rides the
        /// same <c>attachments</c> JSON column as PrimaryImage / Images.</summary>
        public IList<VaultRef> Files { get; set; } = new List<VaultRef>();
```

- [ ] **Step 4: Mapping projection** — in `src/Hmm.Core.Map/HmmMappingProfile.cs`:

In the `HmmNoteDao → HmmNote` map, after the `Images` `.ForMember`, add:

```csharp
            .ForMember(dest => dest.Files,
                opt => opt.MapFrom(src =>
                    NoteAttachmentsCodec.Decode(src.Attachments).Files.ToList()))
```

In the `HmmNote → HmmNoteDao` map, update the `Attachments` `.ForMember` `Encode(...)` call to pass the files list as the third `NoteAttachments` argument (mirror how PrimaryImage + Images are already passed).

- [ ] **Step 5: DTOs** — in `ApiNote.cs`, `ApiNoteForCreate.cs`, `ApiNoteForUpdate.cs`, after the `Images` property, add:

```csharp
        public IList<VaultRef> Files { get; set; } = new List<VaultRef>();
```

- [ ] **Step 6: Run the mapping + build** — Run: `dotnet test src/Hmm.Core.Map.Tests/Hmm.Core.Map.Tests.csproj` and `dotnet build src/Hmm.ServiceApi.DtoEntity/Hmm.ServiceApi.DtoEntity.csproj`
Expected: PASS; Build succeeded. (`Files` maps by convention HmmNote↔ApiNote.)

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Core.Map/DomainEntity/HmmNote.cs src/Hmm.Core.Map/HmmMappingProfile.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForCreate.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForUpdate.cs src/Hmm.Core.Map.Tests/HmmNoteAttachmentsMappingTests.cs
git commit -m "feat(notes): project attachment Files through domain + dto mapping"
```

- [ ] **Step 8: Backend regression** — Run: `dotnet test src/Hmm.Core.Tests/Hmm.Core.Tests.csproj src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj` (run each project separately if the multi-arg form is rejected).
Expected: PASS.

---

# PART B — Client (`/Users/fchy/projects/hmm_console`)

## Task B1: `NoteAttachments.files` (model)

**Files:**
- Modify: `lib/core/data/attachments/attachment_ref.dart`
- Test: `test/core/data/attachments/note_attachments_files_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/core/data/attachments/note_attachments_files_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';

const _pdf = VaultRef(
    path: 'attachments/n/r.pdf', contentType: 'application/pdf', byteSize: 3);

void main() {
  test('files participate in isEmpty and equality', () {
    final a = NoteAttachments(files: const [_pdf]);
    expect(a.isEmpty, isFalse);
    expect(a, NoteAttachments(files: const [_pdf]));
    expect(a == NoteAttachments.empty, isFalse);
  });

  test('empty payload still empty', () {
    expect(NoteAttachments.empty.isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/attachments/note_attachments_files_test.dart`
Expected: FAIL — `files` named param doesn't exist.

- [ ] **Step 3: Add `files`** — in `lib/core/data/attachments/attachment_ref.dart`, `NoteAttachments`:

Add to the constructor (after `images`):

```dart
    List<AttachmentRef> files = const [],
```

and in the initializer list set `files = List.unmodifiable(files)`. Add the field:

```dart
  final List<AttachmentRef> files;
```

Update `isEmpty`:

```dart
  bool get isEmpty => primaryImage == null && images.isEmpty && files.isEmpty;
```

In `==`, after the images element-wise comparison, add an identical loop comparing `files` (length + each element); include `files` in `hashCode` via `Object.hashAll(files)`; add `files` to `toString`.

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/core/data/attachments/note_attachments_files_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/attachments/attachment_ref.dart test/core/data/attachments/note_attachments_files_test.dart
git commit -m "feat(notes): add files list to NoteAttachments model"
```

## Task B2: Codec encodes/decodes `files`

**Files:**
- Modify: `lib/core/data/attachments/attachment_ref_codec.dart`
- Test: `test/core/data/attachments/note_attachments_codec_files_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/core/data/attachments/note_attachments_codec_files_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';

const _pdf = VaultRef(
    path: 'attachments/n/r.pdf', contentType: 'application/pdf', byteSize: 3);
const _img = VaultRef(
    path: 'attachments/n/a.jpg', contentType: 'image/jpeg', byteSize: 9);

void main() {
  test('files round-trip through encode/decode', () {
    final value = NoteAttachments(files: const [_pdf]);
    final encoded = NoteAttachmentsCodec.encode(value);
    final back = NoteAttachmentsCodec.decode(encoded);
    expect(back.files, [_pdf]);
  });

  test('images-only payload encodes identically to before (no files key)', () {
    final value = NoteAttachments(images: const [_img]);
    final encoded = NoteAttachmentsCodec.encode(value)!;
    expect(encoded.contains('files'), isFalse);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/attachments/note_attachments_codec_files_test.dart`
Expected: FAIL — decoded `files` is empty.

- [ ] **Step 3: Decode `files`** — in `attachment_ref_codec.dart` `fromJson`, after building `images`, add a parallel block:

```dart
    var files = const <AttachmentRef>[];
    final filesRaw = json['files'];
    if (filesRaw != null) {
      if (filesRaw is! List) {
        throw const FormatException('"files" must be an array');
      }
      files = filesRaw.map((e) {
        if (e is! Map<String, dynamic>) {
          throw const FormatException('each file must be an object');
        }
        return AttachmentRefCodec.fromJson(e);
      }).toList(growable: false);
    }
```

and pass it: `return NoteAttachments(primaryImage: primary, images: images, files: files);`

- [ ] **Step 4: Encode `files`** — in `toJson`, add `files` only when non-empty (back-compat):

```dart
  static Map<String, dynamic> toJson(NoteAttachments value) => {
        if (value.primaryImage != null)
          'primaryImage': AttachmentRefCodec.toJson(value.primaryImage!),
        'images':
            value.images.map(AttachmentRefCodec.toJson).toList(growable: false),
        if (value.files.isNotEmpty)
          'files':
              value.files.map(AttachmentRefCodec.toJson).toList(growable: false),
      };
```

- [ ] **Step 5: Run it to verify it passes** — Run: `flutter test test/core/data/attachments/note_attachments_codec_files_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/attachments/attachment_ref_codec.dart test/core/data/attachments/note_attachments_codec_files_test.dart
git commit -m "feat(notes): codec encodes/decodes attachment files"
```

## Task B3: Vault GC keeps `files` reachable

**Files:**
- Modify: `lib/core/data/vault/vault_gc.dart`
- Test: `test/core/data/vault/vault_gc_files_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/core/data/vault/vault_gc_files_test.dart`. Seed an in-memory db with one author + one note whose `attachments` column encodes a `files` PDF ref, then assert `collectReferencedVaultPaths` includes that path:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/vault/vault_gc.dart';

void main() {
  test('a files ref is reported as referenced (not collectable)', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final aid = await db.into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 't'));
    const pdf = VaultRef(
        path: 'attachments/n/r.pdf', contentType: 'application/pdf', byteSize: 3);
    final json = NoteAttachmentsCodec.encode(NoteAttachments(files: const [pdf]));
    await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 's', authorId: aid, attachments: Value(json),
        ));

    final paths = await collectReferencedVaultPaths(db);
    expect(paths, contains('attachments/n/r.pdf'));
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/vault/vault_gc_files_test.dart`
Expected: FAIL — `files` not in the reachable set.

- [ ] **Step 3: Include files** — in `lib/core/data/vault/vault_gc.dart`, `collectReferencedVaultPaths`, change the refs list to:

```dart
    final refs = <AttachmentRef?>[
      attachments.primaryImage,
      ...attachments.images,
      ...attachments.files,
    ];
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/core/data/vault/vault_gc_files_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/vault/vault_gc.dart test/core/data/vault/vault_gc_files_test.dart
git commit -m "feat(notes): keep attachment files reachable in vault GC"
```

## Task B4: `FileByteSource` (PDF picking)

**Files:**
- Create: `lib/core/data/attachments/picker/file_byte_source.dart`

- [ ] **Step 1: Implement** — create `lib/core/data/attachments/picker/file_byte_source.dart`:

```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raw picked file (PDF), held in editor state until the note is saved (then
/// persisted to the vault). Mirrors PickedImageBytes.
class PickedFileBytes {
  PickedFileBytes({
    required this.bytes,
    required this.originalName,
    this.contentType,
  });
  final Uint8List bytes;
  final String originalName;
  final String? contentType;
}

/// Picks a PDF's bytes WITHOUT writing to the vault (no note id needed).
abstract interface class FileByteSource {
  Future<PickedFileBytes?> pickPdf();
}

class FilePickerByteSource implements FileByteSource {
  @override
  Future<PickedFileBytes?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return null;
    return PickedFileBytes(
      bytes: file.bytes!,
      originalName: file.name,
      contentType: 'application/pdf',
    );
  }
}

/// Overridable in tests to return canned bytes without the platform picker.
final fileByteSourceProvider =
    Provider<FileByteSource>((ref) => FilePickerByteSource());
```

- [ ] **Step 2: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/core/data/attachments/picker/file_byte_source.dart
git add lib/core/data/attachments/picker/file_byte_source.dart
git commit -m "feat(notes): FileByteSource for picking PDF bytes"
```

Expected analyze: No issues.

## Task B5: `open_filex` dep + open helper

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/notes/presentation/util/open_attachment.dart`

- [ ] **Step 1: Add the dependency** — in `pubspec.yaml` under `dependencies:`, add `open_filex: ^4.5.0` (place alphabetically near other deps). Run: `flutter pub get`. Expected: resolves.

- [ ] **Step 2: Implement the open helper** — create `lib/features/notes/presentation/util/open_attachment.dart`:

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/attachment_providers.dart';

/// Opens a file at [path] in the OS default app. Wrapped in a provider so
/// tests can stub the platform call.
typedef FileOpener = Future<void> Function(String path);

final fileOpenerProvider = Provider<FileOpener>(
  (ref) => (path) => OpenFilex.open(path).then((_) {}),
);

/// Resolve [ref]'s bytes, write them to a temp file (named after the ref),
/// and open it with the OS. Returns an error string on failure, null on
/// success. Best-effort — never throws.
Future<String?> openAttachment(WidgetRef ref, AttachmentRef attachment) async {
  try {
    final resolver = await ref.read(attachmentResolverProvider.future);
    final bytes = await resolver.resolve(attachment);
    if (bytes == null) return 'File is not available on this device.';
    final name = attachment is VaultRef
        ? (attachment.originalName ?? p.basename(attachment.path))
        : 'attachment';
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    await ref.read(fileOpenerProvider)(file.path);
    return null;
  } catch (e) {
    return 'Could not open file: $e';
  }
}
```

NOTE: confirm `attachmentResolverProvider` exposes `IAttachmentResolver` with `resolve(AttachmentRef) → Future<Uint8List?>` (it does — used by `AttachmentImage`). If the import path differs, fix it to match `attachment_providers.dart`.

- [ ] **Step 3: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/features/notes/presentation/util/open_attachment.dart
git add pubspec.yaml pubspec.lock lib/features/notes/presentation/util/open_attachment.dart
git commit -m "feat(notes): open_filex dep + openAttachment helper"
```

Expected analyze: No issues.

## Task B6: `NoteFileCard` + `NoteFileCardList`

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_file_card.dart`
- Create: `lib/features/notes/presentation/widgets/note_file_card_list.dart`
- Test: `test/features/notes/presentation/widgets/note_file_card_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/notes/presentation/widgets/note_file_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_file_card.dart';

void main() {
  testWidgets('shows filename + size, fires onOpen and onRemove', (t) async {
    var opened = false, removed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteFileCard(
          name: 'report.pdf',
          byteSize: 240 * 1024,
          onOpen: () => opened = true,
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.textContaining('KB'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
    await t.tap(find.text('report.pdf'));
    expect(opened, isTrue);
  });

  testWidgets('read-only hides the remove button', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteFileCard(name: 'a.pdf', byteSize: 10, readOnly: true),
      ),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/notes/presentation/widgets/note_file_card_test.dart`
Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement `NoteFileCard`** — create `lib/features/notes/presentation/widgets/note_file_card.dart`:

```dart
import 'package:flutter/material.dart';

/// Journal-style file (PDF) card: doc icon + name + human size. Tap opens;
/// optional ✕ removes (editor only).
class NoteFileCard extends StatelessWidget {
  const NoteFileCard({
    super.key,
    required this.name,
    required this.byteSize,
    this.onOpen,
    this.onRemove,
    this.readOnly = false,
  });

  final String name;
  final int byteSize;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final bool readOnly;

  static String humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onOpen,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                  Text(humanSize(byteSize),
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (!readOnly && onRemove != null)
              GestureDetector(
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

- [ ] **Step 4: Implement `NoteFileCardList`** — create `lib/features/notes/presentation/widgets/note_file_card_list.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../util/open_attachment.dart';
import 'note_file_card.dart';

/// Renders saved file refs + pending picks as [NoteFileCard]s.
class NoteFileCardList extends ConsumerWidget {
  const NoteFileCardList({
    super.key,
    required this.saved,
    this.pending = const [],
    this.onRemovePending,
    this.readOnly = false,
  });

  final List<AttachmentRef> saved;
  final List<PickedFileBytes> pending;
  final void Function(int index)? onRemovePending;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (saved.isEmpty && pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in saved)
          NoteFileCard(
            name: s is VaultRef ? (s.originalName ?? p.basename(s.path)) : 'file',
            byteSize: s is VaultRef ? s.byteSize : 0,
            readOnly: true,
            onOpen: () async {
              final err = await openAttachment(ref, s);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              }
            },
          ),
        for (var i = 0; i < pending.length; i++)
          NoteFileCard(
            name: pending[i].originalName,
            byteSize: pending[i].bytes.length,
            readOnly: readOnly,
            onRemove: onRemovePending == null ? null : () => onRemovePending!(i),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run it to verify it passes** — Run: `flutter test test/features/notes/presentation/widgets/note_file_card_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/widgets/note_file_card.dart lib/features/notes/presentation/widgets/note_file_card_list.dart test/features/notes/presentation/widgets/note_file_card_test.dart
git commit -m "feat(notes): NoteFileCard + NoteFileCardList widgets"
```

## Task B7: `MutateNote.attachFileBytes`

**Files:**
- Modify: `lib/features/notes/states/mutate_note_state.dart`
- Test: `test/features/notes/states/attach_file_bytes_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/notes/states/attach_file_bytes_test.dart` (mirror `attach_image_bytes_test.dart`: a `_FakePicker` implementing `IImageAttachmentPicker` whose `persistToVault` returns a known PDF `VaultRef`, and a `_FakeRepo` capturing the written attachments). Assert the written attachments' `files` contains the ref:

```dart
    await mutate.attachFileBytes(
      1,
      PickedFileBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          originalName: 'r.pdf',
          contentType: 'application/pdf'),
    );
    expect(repo.written!.files, [_ref]);
```

(Reuse the harness shape from `test/features/notes/states/attach_image_bytes_test.dart`; add `import` for `file_byte_source.dart` and `attachment_ref.dart`.)

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/notes/states/attach_file_bytes_test.dart`
Expected: FAIL — `attachFileBytes` undefined.

- [ ] **Step 3: Implement** — in `lib/features/notes/states/mutate_note_state.dart`, add the import for `file_byte_source.dart`, then add (parallel to `attachImageBytes`):

```dart
  /// Persist a picked PDF's bytes into the note's vault and append the
  /// resulting VaultRef to the note's `files` list.
  Future<HmmNote?> attachFileBytes(int noteId, PickedFileBytes pick) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    final added = await picker.persistToVault(
      noteId: noteId,
      bytes: pick.bytes,
      originalName: pick.originalName,
      contentTypeHint: pick.contentType,
    );
    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final updated = NoteAttachments(
      primaryImage: existing.primaryImage,
      images: existing.images,
      files: [...existing.files, added],
    );
    return repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
  }
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/notes/states/attach_file_bytes_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/states/mutate_note_state.dart test/features/notes/states/attach_file_bytes_test.dart
git commit -m "feat(notes): MutateNote.attachFileBytes appends to files"
```

## Task B8: 📄 button in `MediaToolbar`

**Files:**
- Modify: `lib/features/notes/presentation/widgets/media_toolbar.dart`
- Test: `test/features/notes/presentation/widgets/media_toolbar_test.dart` (existing — extend)

- [ ] **Step 1: Extend the test** — in `test/features/notes/presentation/widgets/media_toolbar_test.dart`, add a case: a PDF button fires `onPickFile`. (Follow the existing test's `MediaToolbar` construction; supply `onPickFile: () => tapped = true`, tap `find.byIcon(Icons.picture_as_pdf_outlined)`, expect `tapped`.)

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/notes/presentation/widgets/media_toolbar_test.dart`
Expected: FAIL — `onPickFile` param / icon doesn't exist.

- [ ] **Step 3: Add the button** — in `media_toolbar.dart`, add a required `final VoidCallback onPickFile;` constructor param, and in the `Row` after the camera button add:

```dart
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              color: c.accent,
              onPressed: enabled ? onPickFile : null,
            ),
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/notes/presentation/widgets/media_toolbar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/widgets/media_toolbar.dart test/features/notes/presentation/widgets/media_toolbar_test.dart
git commit -m "feat(notes): add PDF button to MediaToolbar"
```

## Task B9: Editor wiring (pending files)

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Test: `test/features/notes/presentation/note_editor_file_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/notes/presentation/note_editor_file_test.dart`. Override `fileByteSourceProvider` with a fake returning canned PDF bytes; pump the editor; tap the 📄 button; assert a `NoteFileCard` appears. (Mirror `note_editor_media_test.dart`'s setup — `MaterialApp.router` with `ThemeData(extensions: const [AppColors.light])`, a `_FakeMutate`, and a `GoRouter`.) Stub the fake `FileByteSource.pickPdf` to return `PickedFileBytes(bytes: <png-or-any>, originalName: 'r.pdf', contentType: 'application/pdf')`.

```dart
    expect(find.byType(NoteFileCard), findsOneWidget);
    expect(find.text('r.pdf'), findsOneWidget);
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/notes/presentation/note_editor_file_test.dart`
Expected: FAIL — no file card / no 📄 wiring.

- [ ] **Step 3: Wire the editor** — in `note_editor_screen.dart`:

Add imports for `file_byte_source.dart` and `note_file_card_list.dart`.

Add state near `_pendingPicks`:

```dart
  final List<PickedFileBytes> _pendingFiles = [];
  List<AttachmentRef> _savedFiles = [];
```

In `_loadExisting`, after seeding `_savedImages`, add:

```dart
      _savedFiles = [...note.effectiveAttachments.files];
```

Add a pick handler (near `_addMedia`):

```dart
  Future<void> _addFile() async {
    final pick = await ref.read(fileByteSourceProvider).pickPdf();
    if (pick != null && mounted) {
      setState(() => _pendingFiles.add(pick));
    }
  }
```

Pass `onPickFile: _addFile` to the `MediaToolbar(...)`.

Render the file cards — after the `NoteMediaCardList(...)` in the build, add:

```dart
                    NoteFileCardList(
                      saved: _savedFiles,
                      pending: _pendingFiles,
                      onRemovePending: (i) =>
                          setState(() => _pendingFiles.removeAt(i)),
                    ),
```

In `_save`, after the pending-pics attach loop, add a parallel loop:

```dart
      if (_pendingFiles.isNotEmpty && _noteId != null) {
        for (final pick in _pendingFiles) {
          await mutate.attachFileBytes(_noteId!, pick);
        }
        if (mounted) setState(() => _pendingFiles.clear());
        ref.invalidate(noteDetailProvider(_noteId!));
      }
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/notes/presentation/note_editor_file_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + editor regression** — Run: `flutter analyze lib/features/notes/presentation/screens/note_editor_screen.dart` and `flutter test test/features/notes/presentation/`
Expected: No issues; all pass. (The existing `_FakeMutate`s don't override `attachFileBytes`, so they fall to `noSuchMethod`; only update them if a test exercises the file-save path.)

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/note_editor_file_test.dart
git commit -m "feat(notes): editor picks + shows + persists PDF files"
```

## Task B10: Detail view file cards

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart`

- [ ] **Step 1: Render** — in `note_detail_screen.dart`, add `import '../widgets/note_file_card_list.dart';`, then after the `NoteMediaCardList` line in the body add:

```dart
                  if (d.note.effectiveAttachments.files.isNotEmpty)
                    NoteFileCardList(
                        saved: d.note.effectiveAttachments.files,
                        readOnly: true),
```

- [ ] **Step 2: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/features/notes/presentation/screens/note_detail_screen.dart
git add lib/features/notes/presentation/screens/note_detail_screen.dart
git commit -m "feat(notes): show PDF file cards in note detail view"
```

Expected analyze: No issues.

## Task B11: Sync the `attachments` column (close the ref gap)

**Files:**
- Modify: `lib/core/data/sync/sync_orchestrator.dart`
- Test: `test/core/data/sync/sync_orchestrator_attachments_test.dart` (new)

- [ ] **Step 1: Write the failing round-trip test** — create `test/core/data/sync/sync_orchestrator_attachments_test.dart` (model on `sync_orchestrator_location_test.dart`'s harness + `_FakeProvider` with `pushed` + `remoteBodies` maps). Three cases:

  1. **outbound**: a note whose `attachments` column has a `files` PDF ref → pushed body's `attachments` string contains `r.pdf`.
  2. **inbound insert**: a remote body with an `attachments` JSON string → local note's `effectiveAttachments.files` has the ref.
  3. **inbound update omitting `attachments`** → local note's existing attachments preserved.

```dart
    // case 1 assertion:
    expect(provider.pushed[note.uuid]!['attachments'] as String, contains('r.pdf'));
    // case 2 assertion (after sync, read row, decode):
    final atts = NoteAttachmentsCodec.decode(row.attachments);
    expect(atts.files.single, isA<VaultRef>());
```

Use an attachments JSON of:
`{"images":[],"files":[{"kind":"vault","path":"attachments/n/r.pdf","contentType":"application/pdf","byteSize":3}]}`

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/sync/sync_orchestrator_attachments_test.dart`
Expected: FAIL — orchestrator doesn't serialize/apply `attachments`.

- [ ] **Step 3: Outbound** — in `_noteRowToBlob`'s `body` map, after the `'locationLabel'` key (or anywhere in the body), add:

```dart
        // Attachment refs (images + files). Bytes ride OS-level vault sync;
        // this carries the refs so they propagate across devices.
        'attachments': n.attachments,
```

- [ ] **Step 4: Inbound parse** — after the location parse block, add:

```dart
    final hasAttachments = body.containsKey('attachments');
    final attachmentsJson = body['attachments'] as String?;
```

- [ ] **Step 5: Inbound update branch** — in the `existing != null` update `NotesCompanion(...)`, after the `locationLabel:` member, add:

```dart
        attachments: hasAttachments
            ? Value(attachmentsJson)
            : const Value.absent(),
```

- [ ] **Step 6: Inbound insert branch** — in the insert `NotesCompanion.insert(...)`, after the `locationLabel:` member, add:

```dart
              attachments: Value(attachmentsJson),
```

- [ ] **Step 7: Run it to verify it passes** — Run: `flutter test test/core/data/sync/sync_orchestrator_attachments_test.dart`
Expected: PASS (all three).

- [ ] **Step 8: Analyze + sync regression** — Run: `flutter analyze lib/core/data/sync/sync_orchestrator.dart` and `flutter test test/core/data/sync/`
Expected: No issues; all pass.

- [ ] **Step 9: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/sync/sync_orchestrator.dart test/core/data/sync/sync_orchestrator_attachments_test.dart
git commit -m "feat(notes): sync attachment refs (images + files) across devices"
```

## Task B12: Full client verification

- [ ] **Step 1: Analyze** — Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Full test suite** — Run: `flutter test`
Expected: All pass.

- [ ] **Step 3: Manual smoke (optional, iOS)** — Create a note → tap 📄 → pick a PDF → a file card appears → Save. Open the note → the card shows; tap it → the PDF opens in the system viewer. Remove a pending file with ✕ before save → it's not attached.

---

## Notes on scope / sequencing

- **Backend ↔ client:** the Flutter `cloudApi` note repo still doesn't exist, so there's no client API mapper to touch; the backend `Files` is ready for it. `local` + `cloudStorage` are fully wired (including the now-synced attachment refs).
- **Sync side effect (intended):** Task B11 makes **image** refs sync too (previously they didn't) — a deliberate fix, covered by the round-trip test.
- **Out of scope:** voice (Phase 3b — reuses `files` + cards), in-app PDF rendering, non-PDF document types, attachment-byte transport changes.
```
