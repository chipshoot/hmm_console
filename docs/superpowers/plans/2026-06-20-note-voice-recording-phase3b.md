# Note Voice Recording (Phase 3b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a note carry voice recordings — tap 🎤 in the editor, record in a modal sheet, get an audio card with play/pause + seek — stored/synced/GC'd through the existing Phase 3a `files` attachment list.

**Architecture:** A recording is a `VaultRef` with content-type `audio/mp4` in `NoteAttachments.files`. No model/codec/sync/GC changes — those already handle any file ref. Phase 3b adds `audio/mp4` to the three allowlists, a `record`-backed recorder seam, a modal record sheet, and a `just_audio`-backed audio card; the existing file-card list dispatches by content-type (`audio/*` → audio card, else → PDF card).

**Tech Stack:** Backend — .NET 10, `Hmm.Core.Vault` (JSON Schema). Client — Flutter, `record` (recorder + mic permission), `just_audio` (player), `path_provider` (existing).

**Two repos:**
- Backend: `/Users/fchy/projects/hmm`, branch off `main` (e.g. `feat/note-voice`)
- Client: `/Users/fchy/projects/hmm_console`, branch off `main` (e.g. `feat/note-voice-phase3b`)

---

## File Structure

### Backend (`/Users/fchy/projects/hmm`)
- Modify: `src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json` — add `audio/mp4` to the contentType enum
- Test: `src/Hmm.Core.Vault.Tests/NoteAttachmentsCodecTests.cs`

### Client (`/Users/fchy/projects/hmm_console`)
- Modify: `lib/core/data/attachments/attachment_ref_codec.dart` — allowlist `audio/mp4`
- Modify: `lib/core/data/attachments/picker/image_attachment_picker.dart` — allowlist + `_extFor`
- Modify: `pubspec.yaml` — add `record`, `just_audio`
- Modify: `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml` — mic permission
- Create: `lib/core/data/attachments/recorder/audio_recorder.dart` — recorder seam
- Create: `lib/features/notes/presentation/widgets/record_sheet.dart` — modal record sheet
- Create: `lib/features/notes/presentation/widgets/note_audio_card.dart` — audio playback card
- Modify: `lib/features/notes/presentation/widgets/note_file_card_list.dart` — content-type dispatch
- Modify: `lib/features/notes/presentation/widgets/media_toolbar.dart` — 🎤 button
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart` — `_addRecording`

---

# PART A — Backend (`/Users/fchy/projects/hmm`)

## Task A1: Allow `audio/mp4` through the Vault schema

**Files:**
- Modify: `src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json`
- Test: `src/Hmm.Core.Vault.Tests/NoteAttachmentsCodecTests.cs`

- [ ] **Step 1: Write the failing test** — in `src/Hmm.Core.Vault.Tests/NoteAttachmentsCodecTests.cs`, in the `RoundTrip` class, add (mirrors the 3a `Files_round_trip`):

```csharp
        [Fact]
        public void Audio_file_round_trips()
        {
            var audio = new VaultRef
            {
                Path = "attachments/note-1/rec.m4a",
                ContentType = "audio/mp4",
                ByteSize = 1024,
                OriginalName = "recording-1.m4a",
            };
            var value = new NoteAttachments(files: new List<VaultRef> { audio });

            var json = NoteAttachmentsCodec.Encode(value);
            Assert.NotNull(json);
            var back = NoteAttachmentsCodec.Decode(json!);

            Assert.Single(back.Files);
            Assert.Equal("audio/mp4", back.Files[0].ContentType);
        }
```

- [ ] **Step 2: Run it to verify it fails** — Run: `dotnet test src/Hmm.Core.Vault.Tests/Hmm.Core.Vault.Tests.csproj --filter "FullyQualifiedName~Audio_file_round_trips"`
Expected: FAIL — `Decode` throws a `FormatException` (schema validation: `audio/mp4` not in the contentType enum).

- [ ] **Step 3: Add the enum value** — in `src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json`, in the shared `contentType` enum (which already lists the image types + `application/pdf`), add `"audio/mp4"`:

```json
      "enum": [
        "image/jpeg",
        "image/png",
        "image/heic",
        "image/webp",
        "application/pdf",
        "audio/mp4"
      ],
```

- [ ] **Step 4: Run it to verify it passes** — Run: `dotnet test src/Hmm.Core.Vault.Tests/Hmm.Core.Vault.Tests.csproj`
Expected: PASS (new test + all existing).

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json src/Hmm.Core.Vault.Tests/NoteAttachmentsCodecTests.cs
git commit -m "feat(vault): allow audio/mp4 content type for voice attachments"
```

---

# PART B — Client (`/Users/fchy/projects/hmm_console`)

## Task B1: Allowlists + `_extFor` accept `audio/mp4`

**Files:**
- Modify: `lib/core/data/attachments/attachment_ref_codec.dart`
- Modify: `lib/core/data/attachments/picker/image_attachment_picker.dart`
- Test: `test/core/data/attachments/audio_content_type_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/core/data/attachments/audio_content_type_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';

const _audio = VaultRef(
    path: 'attachments/n/rec.m4a', contentType: 'audio/mp4', byteSize: 1024);

void main() {
  test('an audio/mp4 ref round-trips through the codec', () {
    final value = NoteAttachments(files: const [_audio]);
    final back = NoteAttachmentsCodec.decode(NoteAttachmentsCodec.encode(value));
    expect(back.files.single, _audio);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/core/data/attachments/audio_content_type_test.dart`
Expected: FAIL — decode throws `FormatException` ("contentType \"audio/mp4\" is not allowed").

- [ ] **Step 3: Codec allowlist** — in `lib/core/data/attachments/attachment_ref_codec.dart`, in `_allowedContentTypes`, after `'application/pdf'`, add:

```dart
  // Phase 3b: voice recordings.
  'audio/mp4',
```

- [ ] **Step 4: Picker allowlist + ext** — in `lib/core/data/attachments/picker/image_attachment_picker.dart`:

In `_allowedFileContentTypes`, add `'audio/mp4',` after `'application/pdf',`.

In `_extFor`, before the `_ => 'bin'` default, add:

```dart
        'audio/mp4' => 'm4a',
```

- [ ] **Step 5: Run it to verify it passes** — Run: `flutter test test/core/data/attachments/audio_content_type_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/attachments/attachment_ref_codec.dart lib/core/data/attachments/picker/image_attachment_picker.dart test/core/data/attachments/audio_content_type_test.dart
git commit -m "feat(notes): allow audio/mp4 in codec + picker allowlists"
```

## Task B2: Dependencies + platform mic permission

**Files:**
- Modify: `pubspec.yaml`
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add deps** — in `pubspec.yaml` under `dependencies:`, after `open_filex: ^4.5.0`, add:

```yaml
  record: ^5.1.2
  just_audio: ^0.9.40
```

Run: `flutter pub get`
Expected: resolves (note the actual versions chosen in `pubspec.lock`).

- [ ] **Step 2: iOS mic permission** — in `ios/Runner/Info.plist`, add inside the top-level `<dict>` (near other permission keys if present):

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>Record voice notes to attach to your notes.</string>
```

- [ ] **Step 3: Android mic permission** — in `android/app/src/main/AndroidManifest.xml`, add as a child of `<manifest>` (above `<application>`):

```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

- [ ] **Step 4: Verify build resolves** — Run: `flutter analyze`
Expected: No issues found (no code references the deps yet; this just confirms pub get + manifests didn't break analysis).

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "build(notes): add record + just_audio deps and mic permission"
```

## Task B3: `AudioRecorderService` seam

A thin, overridable wrapper so the sheet/editor tests run without a real mic.

**Files:**
- Create: `lib/core/data/attachments/recorder/audio_recorder.dart`

- [ ] **Step 1: Implement** — create `lib/core/data/attachments/recorder/audio_recorder.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A finished recording, held until the note is saved (then persisted to the
/// vault via the existing file path).
class AudioRecording {
  AudioRecording({
    required this.bytes,
    required this.fileName,
    this.contentType = 'audio/mp4',
  });
  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

/// Microphone recorder seam. Overridable in tests.
abstract interface class AudioRecorderService {
  Future<bool> hasPermission();
  Future<void> start();

  /// Stop and return the recording (null if nothing was captured).
  Future<AudioRecording?> stop();

  /// Stop and discard (delete the temp file).
  Future<void> cancel();
}

class RecordAudioRecorderService implements AudioRecorderService {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;

  @override
  Future<bool> hasPermission() => _rec.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'rec-${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _path = path;
  }

  @override
  Future<AudioRecording?> stop() async {
    final path = await _rec.stop();
    _path = null;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return AudioRecording(bytes: bytes, fileName: p.basename(path));
  }

  @override
  Future<void> cancel() async {
    await _rec.stop();
    final path = _path;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}

final audioRecorderProvider =
    Provider<AudioRecorderService>((ref) => RecordAudioRecorderService());
```

NOTE: the `record` package's API (`AudioRecorder`, `RecordConfig`, `AudioEncoder.aacLc`, `start(config, path:)`, `stop() → String?`) is for v5.x. If `flutter pub get` resolved a different major, adjust these calls to that version's API — keep the `AudioRecorderService` interface identical.

- [ ] **Step 2: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/core/data/attachments/recorder/audio_recorder.dart
git add lib/core/data/attachments/recorder/audio_recorder.dart
git commit -m "feat(notes): AudioRecorderService recorder seam"
```

Expected analyze: No issues.

## Task B4: Record sheet

**Files:**
- Create: `lib/features/notes/presentation/widgets/record_sheet.dart`
- Test: `test/features/notes/presentation/widgets/record_sheet_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/notes/presentation/widgets/record_sheet_test.dart`. Use a fake recorder; assert (a) Stop returns a `PickedFileBytes` with `audio/mp4`, (b) permission-denied returns null without recording.

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/file_byte_source.dart';
import 'package:hmm_console/core/data/attachments/recorder/audio_recorder.dart';
import 'package:hmm_console/features/notes/presentation/widgets/record_sheet.dart';

class _FakeRecorder implements AudioRecorderService {
  _FakeRecorder({this.permission = true});
  final bool permission;
  bool started = false;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start() async => started = true;
  @override
  Future<AudioRecording?> stop() async => AudioRecording(
      bytes: Uint8List.fromList([1, 2, 3]), fileName: 'rec.m4a');
  @override
  Future<void> cancel() async {}
}

Future<PickedFileBytes?> _run(WidgetTester tester, _FakeRecorder rec) async {
  PickedFileBytes? result;
  await tester.pumpWidget(ProviderScope(
    overrides: [audioRecorderProvider.overrideWithValue(rec)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () async => result = await showRecordSheet(context, ref),
              child: const Text('go'),
            );
          });
        }),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('Stop returns an audio PickedFileBytes', (tester) async {
    final rec = _FakeRecorder();
    PickedFileBytes? result;
    await tester.pumpWidget(ProviderScope(
      overrides: [audioRecorderProvider.overrideWithValue(rec)],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () async => result = await showRecordSheet(context, ref),
              child: const Text('go'),
            );
          }),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(rec.started, isTrue);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.contentType, 'audio/mp4');
  });

  testWidgets('permission denied returns null without recording',
      (tester) async {
    final rec = _FakeRecorder(permission: false);
    final result = await _run(tester, rec);
    expect(rec.started, isFalse);
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/notes/presentation/widgets/record_sheet_test.dart`
Expected: FAIL — `showRecordSheet` doesn't exist.

- [ ] **Step 3: Implement** — create `lib/features/notes/presentation/widgets/record_sheet.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../../core/data/attachments/recorder/audio_recorder.dart';

/// Opens the modal record sheet. Returns a pending audio pick on Stop, or
/// null on Cancel / dismiss / no permission.
Future<PickedFileBytes?> showRecordSheet(
    BuildContext context, WidgetRef ref) async {
  final recorder = ref.read(audioRecorderProvider);
  if (!await recorder.hasPermission()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Microphone permission needed to record')));
    }
    return null;
  }
  await recorder.start();
  if (!context.mounted) {
    await recorder.cancel();
    return null;
  }
  final pick = await showModalBottomSheet<PickedFileBytes?>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _RecordSheetBody(recorder: recorder),
  );
  // Dismissed without an explicit Stop/Cancel button → treat as cancel.
  if (pick == null) await recorder.cancel();
  return pick;
}

class _RecordSheetBody extends StatefulWidget {
  const _RecordSheetBody({required this.recorder});
  final AudioRecorderService recorder;

  @override
  State<_RecordSheetBody> createState() => _RecordSheetBodyState();
}

class _RecordSheetBodyState extends State<_RecordSheetBody> {
  Timer? _ticker;
  int _seconds = 0;
  int _recCount = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    _ticker?.cancel();
    final rec = await widget.recorder.stop();
    if (!mounted) return;
    if (rec == null) {
      Navigator.of(context).pop(null);
      return;
    }
    Navigator.of(context).pop(PickedFileBytes(
      bytes: rec.bytes,
      originalName: 'recording-${++_recCount}.m4a',
      contentType: rec.contentType,
    ));
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    _ticker?.cancel();
    await widget.recorder.cancel();
    if (mounted) Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red),
                const SizedBox(width: 8),
                Text('Recording…  $_time',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel')),
                FilledButton(onPressed: _busy ? null : _stop,
                    child: const Text('Stop')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/notes/presentation/widgets/record_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/widgets/record_sheet.dart test/features/notes/presentation/widgets/record_sheet_test.dart
git commit -m "feat(notes): modal record sheet returning a pending audio pick"
```

## Task B5: `NoteAudioCard`

A play/pause + time + seek card. The `just_audio` player is wrapped behind a tiny interface so the widget is testable without a platform player.

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_audio_card.dart`
- Test: `test/features/notes/presentation/widgets/note_audio_card_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/notes/presentation/widgets/note_audio_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_audio_card.dart';

void main() {
  testWidgets('renders name + a play button and a remove button', (t) async {
    var removed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteAudioCard(
          name: 'recording-1.m4a',
          resolvePath: () async => '/tmp/x.m4a',
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.text('recording-1.m4a'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });

  testWidgets('read-only hides the remove button', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteAudioCard(
          name: 'a.m4a', resolvePath: () async => '/tmp/x.m4a', readOnly: true),
      ),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/notes/presentation/widgets/note_audio_card_test.dart`
Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement** — create `lib/features/notes/presentation/widgets/note_audio_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Journal-style audio card: play/pause + elapsed/total + a seekable slider.
/// [resolvePath] returns a local playable file path (resolved lazily on first
/// play so the card renders instantly).
class NoteAudioCard extends StatefulWidget {
  const NoteAudioCard({
    super.key,
    required this.name,
    required this.resolvePath,
    this.onRemove,
    this.readOnly = false,
  });

  final String name;
  final Future<String> Function() resolvePath;
  final VoidCallback? onRemove;
  final bool readOnly;

  @override
  State<NoteAudioCard> createState() => _NoteAudioCardState();
}

class _NoteAudioCardState extends State<NoteAudioCard> {
  AudioPlayer? _player;
  bool _loading = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<AudioPlayer> _ensure() async {
    if (_player != null) return _player!;
    final p = AudioPlayer();
    final path = await widget.resolvePath();
    await p.setFilePath(path);
    _player = p;
    return p;
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final p = await _ensure();
      if (p.playing) {
        await p.pause();
      } else {
        if (p.position >= (p.duration ?? Duration.zero)) await p.seek(Duration.zero);
        await p.play();
      }
    } catch (_) {
      // Playback failure → leave the card in a non-playing state.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) =>
      '${(d.inMinutes).toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = _player;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
                (player?.playing ?? false) ? Icons.pause : Icons.play_arrow),
            onPressed: _toggle,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium),
                if (player != null)
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      final total = player.duration ?? Duration.zero;
                      final max = total.inMilliseconds.toDouble();
                      return Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: pos.inMilliseconds
                                  .clamp(0, max == 0 ? 1 : max.toInt())
                                  .toDouble(),
                              max: max == 0 ? 1 : max,
                              onChanged: (v) => player
                                  .seek(Duration(milliseconds: v.toInt())),
                            ),
                          ),
                          Text('${_fmt(pos)} / ${_fmt(total)}',
                              style: theme.textTheme.bodySmall),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          if (!widget.readOnly && widget.onRemove != null)
            GestureDetector(
              onTap: widget.onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                  padding: EdgeInsets.all(8), child: Icon(Icons.close, size: 18)),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/notes/presentation/widgets/note_audio_card_test.dart`
Expected: PASS. (The player is never created in the test — `resolvePath` isn't called until play is tapped, and the test only checks the initial render + remove. The icon is `play_arrow` because `_player` is null.)

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/widgets/note_audio_card.dart test/features/notes/presentation/widgets/note_audio_card_test.dart
git commit -m "feat(notes): NoteAudioCard play/pause + seek widget"
```

## Task B6: File-card list dispatches audio vs PDF by content-type

**Files:**
- Modify: `lib/features/notes/presentation/widgets/note_file_card_list.dart`
- Test: `test/features/notes/presentation/widgets/note_file_card_list_dispatch_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/notes/presentation/widgets/note_file_card_list_dispatch_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_audio_card.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_file_card.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_file_card_list.dart';

const _pdf = VaultRef(
    path: 'attachments/n/r.pdf', contentType: 'application/pdf', byteSize: 3);
const _audio = VaultRef(
    path: 'attachments/n/rec.m4a', contentType: 'audio/mp4', byteSize: 9);

void main() {
  testWidgets('audio ref → NoteAudioCard, pdf ref → NoteFileCard', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: NoteFileCardList(saved: const [_pdf, _audio], readOnly: true),
        ),
      ),
    ));
    expect(find.byType(NoteFileCard), findsOneWidget);
    expect(find.byType(NoteAudioCard), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/notes/presentation/widgets/note_file_card_list_dispatch_test.dart`
Expected: FAIL — both render as `NoteFileCard` (no audio dispatch).

- [ ] **Step 3: Implement dispatch** — rewrite `lib/features/notes/presentation/widgets/note_file_card_list.dart` to branch by content-type. Replace the whole file with:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../util/open_attachment.dart';
import 'note_audio_card.dart';
import 'note_file_card.dart';

/// Renders saved file refs + pending picks. Audio (`audio/*`) renders as a
/// [NoteAudioCard]; everything else (PDF) as a [NoteFileCard].
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

  static bool _isAudio(String contentType) => contentType.startsWith('audio/');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (saved.isEmpty && pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in saved) _savedCard(context, ref, s),
        for (var i = 0; i < pending.length; i++) _pendingCard(i),
      ],
    );
  }

  Widget _savedCard(BuildContext context, WidgetRef ref, AttachmentRef s) {
    final name =
        s is VaultRef ? (s.originalName ?? p.basename(s.path)) : 'file';
    final contentType = s is VaultRef ? s.contentType : '';
    if (_isAudio(contentType)) {
      return NoteAudioCard(
        name: name,
        readOnly: true,
        resolvePath: () => _refToTempPath(ref, s, name),
      );
    }
    return NoteFileCard(
      name: name,
      byteSize: s is VaultRef ? s.byteSize : 0,
      readOnly: true,
      onOpen: () async {
        final err = await openAttachment(ref, s);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
        }
      },
    );
  }

  Widget _pendingCard(int i) {
    final pick = pending[i];
    final remove = (readOnly || onRemovePending == null)
        ? null
        : () => onRemovePending!(i);
    if (_isAudio(pick.contentType ?? '')) {
      return NoteAudioCard(
        name: pick.originalName,
        readOnly: readOnly,
        onRemove: remove,
        resolvePath: () => _bytesToTempPath(pick),
      );
    }
    return NoteFileCard(
      name: pick.originalName,
      byteSize: pick.bytes.length,
      readOnly: readOnly,
      onRemove: remove,
    );
  }

  /// Resolve a saved ref's bytes to a per-ref temp file path (mirrors the
  /// open_attachment temp-dir keying so same-named files don't collide).
  Future<String> _refToTempPath(
      WidgetRef ref, AttachmentRef attachment, String name) async {
    final resolver = await ref.read(attachmentResolverProvider.future);
    final bytes = await resolver.resolve(attachment);
    if (bytes == null) throw StateError('audio not available');
    final key = attachment is VaultRef
        ? attachment.path.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')
        : 'misc';
    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'note-audio', key));
    await outDir.create(recursive: true);
    final file = File(p.join(outDir.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String> _bytesToTempPath(PickedFileBytes pick) async {
    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'note-audio-pending'));
    await outDir.create(recursive: true);
    final file = File(p.join(outDir.path, pick.originalName));
    await file.writeAsBytes(pick.bytes);
    return file.path;
  }
}
```

- [ ] **Step 4: Run it to verify it passes** — Run: `flutter test test/features/notes/presentation/widgets/note_file_card_list_dispatch_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the existing file-card-list consumers' tests** — Run: `flutter test test/features/notes/presentation/`
Expected: PASS (the editor file test + detail rendering still work — PDF still renders as `NoteFileCard`).

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/widgets/note_file_card_list.dart test/features/notes/presentation/widgets/note_file_card_list_dispatch_test.dart
git commit -m "feat(notes): file-card list dispatches audio vs pdf by content type"
```

## Task B7: 🎤 button + editor wiring

**Files:**
- Modify: `lib/features/notes/presentation/widgets/media_toolbar.dart`
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Test: `test/features/notes/presentation/note_editor_record_test.dart` (new)

- [ ] **Step 1: Extend the toolbar test** — in `test/features/notes/presentation/widgets/media_toolbar_test.dart`, add the `onRecord` param to both existing `MediaToolbar(...)` constructions (`onRecord: () {}`), and add a case:

```dart
  testWidgets('mic button fires onRecord', (t) async {
    var tapped = false;
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(
        bottomNavigationBar: MediaToolbar(
            onPick: (_) {}, onPickFile: () {}, onRecord: () => tapped = true),
      ),
    ));
    await t.tap(find.byIcon(Icons.mic_none_outlined));
    expect(tapped, isTrue);
  });
```

- [ ] **Step 2: Run it to verify it fails** — Run: `flutter test test/features/notes/presentation/widgets/media_toolbar_test.dart`
Expected: FAIL — `onRecord` param / mic icon doesn't exist.

- [ ] **Step 3: Add the mic button** — in `lib/features/notes/presentation/widgets/media_toolbar.dart`, add a required `final VoidCallback onRecord;` (after `onPickFile`), and in the `Row` after the PDF `IconButton` add:

```dart
            IconButton(
              icon: const Icon(Icons.mic_none_outlined),
              color: c.accent,
              onPressed: enabled ? onRecord : null,
            ),
```

- [ ] **Step 4: Run the toolbar test** — Run: `flutter test test/features/notes/presentation/widgets/media_toolbar_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing editor test** — create `test/features/notes/presentation/note_editor_record_test.dart`. Override `audioRecorderProvider` with a fake that returns an audio recording on stop; tap the mic button; tap Stop in the sheet; assert a `NoteAudioCard` appears as a pending card. (Mirror `note_editor_file_test.dart`'s `_FakeMutate` + GoRouter + `AppColors.light` setup; override `audioRecorderProvider`, `mutateNoteProvider`, `subsystemAnchorsProvider`.)

```dart
    await tester.tap(find.byIcon(Icons.mic_none_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteAudioCard), findsOneWidget);
```

Use a fake recorder identical in shape to `record_sheet_test.dart`'s `_FakeRecorder` (returns `AudioRecording(bytes: [1,2,3], fileName: 'rec.m4a')` from `stop()`, permission true).

- [ ] **Step 6: Run it to verify it fails** — Run: `flutter test test/features/notes/presentation/note_editor_record_test.dart`
Expected: FAIL — no mic wiring in the editor.

- [ ] **Step 7: Wire the editor** — in `lib/features/notes/presentation/screens/note_editor_screen.dart`:

Add imports:

```dart
import '../widgets/record_sheet.dart';
```

Add the handler near `_addFile`:

```dart
  Future<void> _addRecording() async {
    final pick = await showRecordSheet(context, ref);
    if (pick != null && mounted) {
      setState(() => _pendingFiles.add(pick));
    }
  }
```

Pass `onRecord: _addRecording` to the `MediaToolbar(...)` (alongside `onPick`/`onPickFile`).

- [ ] **Step 8: Run it to verify it passes** — Run: `flutter test test/features/notes/presentation/note_editor_record_test.dart`
Expected: PASS.

- [ ] **Step 9: Analyze + presentation regression** — Run: `flutter analyze lib/features/notes/presentation/screens/note_editor_screen.dart lib/features/notes/presentation/widgets/media_toolbar.dart` and `flutter test test/features/notes/presentation/`
Expected: No issues; all pass.

- [ ] **Step 10: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/widgets/media_toolbar.dart lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/widgets/media_toolbar_test.dart test/features/notes/presentation/note_editor_record_test.dart
git commit -m "feat(notes): mic button + record-to-pending-audio editor flow"
```

## Task B8: Full client verification

- [ ] **Step 1: Analyze** — Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Full test suite** — Run: `flutter test`
Expected: All pass.

- [ ] **Step 3: Manual smoke (optional, iOS device — recording needs real hardware)** — Create a note → tap 🎤 → grant mic permission → record a few seconds → Stop → an audio card appears → tap play (hears playback) → Save. Reopen the note → the audio card shows read-only and plays. Record again → Cancel → nothing attached.

---

## Notes on scope / sequencing

- **No model/sync/GC changes** — a recording is a `VaultRef` in the existing `files` list; persistence reuses `attachFileBytes` → `persistFileToVault` and the save loop already added in 3a. The 3a attachment-ref sync carries audio refs for free.
- **Backend** is one schema-enum line (so `cloudApi` accepts audio refs when that repo lands); independently deployable.
- **Out of scope:** waveform rendering, pause/resume/trim, lock-screen controls, transcription, non-`audio/mp4` formats.
```
