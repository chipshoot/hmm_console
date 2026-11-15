# Video in Notes — Stage 4 (Finishing) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish video in notes: Keep offline, a 2 GB per-device video cache with oldest-used eviction, a Settings → Videos screen (usage, Upload on mobile data, Clear downloaded videos), a video length mark in the notes list, play-in-place on iPad, and "▶ Video, 0:48" in shared note text.

**Architecture:** A new `VideoCache` service owns the per-device cache: it reads a persisted `VideoCacheIndex` (last-used times and the Keep offline set, in SharedPreferences, never synced) and lists/deletes only files in the offload home (`Library/HmmVideos`), so a video still waiting to upload (home A, or in the upload queue) can never be evicted. Downloads, offloads and plays touch the index and trigger eviction. Play-in-place uses `video_player` (AVPlayer from a file path) on wide layouts; phones keep the native full-screen player.

**Tech Stack:** Flutter, Riverpod 3, SharedPreferences, `video_player` (new), Swift `hmm/video` plugin, gen-l10n (en/zh).

**Spec:** `docs/superpowers/specs/2026-11-12-note-video-design.md` (§3 Attached videos — Look, Video menu, Notes list, Space; §3 Sharing; §5.3 per-device state; §5.4; §8 Stage 4). Stage 3 plan: `docs/superpowers/plans/2026-11-14-note-video-stage3.md` (its Ruling 2 and "eviction is stage 4" defer here).

## Global Constraints

- Cache limit: **2 GB** = `2 * 1024 * 1024 * 1024` bytes (`kVideoCacheLimitBytes`). Oldest-used cleared first.
- **Keep offline** videos are never cleared and don't count toward the 2 GB.
- **Cache eviction never touches a video that hasn't finished uploading** (in home A, or in the upload queue) (§5.4, §6.2).
- Per-device state is **not** synced: cached or not, Keep offline, last-used, Upload on mobile data (§5.3). Never put these in `SyncableSettings`.
- Settings → Videos shows: downloaded size "of 2 GB", kept-offline count and size, the **Upload on mobile data** toggle, and **Clear downloaded videos** (keeps Keep offline ones).
- Video menu order: **Keep offline** (tick toggle), Save to Photos, Share…, Remove from note.
- iPad (wide) plays in place with an inline control bar and a full-screen button. **Nothing autoplays.** Phones keep the native full-screen player.
- Share text: a video line becomes `▶ Video, 0:48` (`▶ Video` when the length is unknown). The video file is shared only through its own Share… item.
- No step holds a whole video in memory.
- Project rules: `HmmIconButton` with a localized tooltip; `adaptiveIcon` Apple glyphs on Notes screens; every new string in `app_en.arb` and `app_zh.arb`, then `flutter gen-l10n`, commit the gen files; new screens get a `HelpId` + `helpFor` case + `HelpButton`; changed controls update their help entry; never `ref.watch` inside a `LayoutBuilder` builder; Cupertino dialogs on iOS/macOS, Material elsewhere; tests override `videoPlatformProvider`; never `dart format` a directory (format only touched files, and only files already formatted — don't reformat a whole legacy file); commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Rulings (plan-time, mine — for the user to check)

1. **Last-used tracking** is a SharedPreferences JSON map `video_cache_last_used` (path → epoch ms), touched on play, download and offload. A file with no entry falls back to its file-modified time. Cost: a cleared prefs store makes eviction order approximate.
2. **Settings → Videos is its own screen** (`/settings/videos`), reached from a row under Data storage that shows "1.2 GB of 2 GB". This gives it a help button per the project rule. Shown only in cloudStorage mode (in local mode every video is device-only and nothing is cached). Cost: local-mode users see no video space figure.
3. **Clear downloaded videos** asks for confirmation (states the size). It isn't undoable, but nothing is lost: the videos re-download on play.
4. **Keep offline downloads:** ticking it starts the download at once (the user asked). Kept videos that are missing (e.g. still uploading elsewhere) are fetched after each sync, but only on Wi-Fi/ethernet unless Upload on mobile data is on. Cost: on mobile data a kept video waits for Wi-Fi.
5. **List mark:** one video → `0:48`; several → `3 · 2:15` (count and total known length); no known length → the count, as today.
6. **Wide layout** = screen width ≥ `kNotesWideBreakpoint` (720), the breakpoint the notes screens already use. Full screen from the inline player pauses it and opens the native player at the same position (the `play` channel gains an optional `positionMs`).
7. **"PDF export"** in the spec: the app has no PDF export, only text share. This stage puts the placeholder in the text share. A PDF export is out of scope.
8. **Parked items folded in:** stale `.part` files in the offload home are deleted on the first cache sweep after launch; the audio session is deactivated when the native player closes.

## Review Focus

1. A video still uploading (home A, or in the queue) when the cache is over 2 GB or Clear downloaded runs → it must survive. Test in Task 1.
2. A Keep offline path whose file was purged (note emptied from Recently Deleted) → usage ignores it, nothing throws. Test in Task 1.
3. A download that pushes the cache over 2 GB → older videos go, the just-downloaded one stays. Tests in Task 1 (`protect`) and Task 2.
4. Turning on Upload on mobile data while videos wait for Wi-Fi → they start without waiting for a sync. Test in Task 4.
5. iPad tile for a video not on the device → downloads with the ring first, then plays inline; leaving the note stops playback. Test in Task 6.

---

### Task 1: Video cache index and cache service

**Files:**
- Create: `lib/core/data/attachments/video/video_cache_index.dart`
- Create: `lib/core/data/attachments/video/video_cache.dart`
- Modify: `lib/core/data/vault/vault_file_store.dart` (interface), `lib/core/data/vault/local_vault_store.dart`, any other `IVaultFileStore` implementers and test fakes (no-op bodies so they compile)
- Test: `test/core/data/attachments/video/video_cache_index_test.dart`, `test/core/data/attachments/video/video_cache_test.dart`, `test/core/data/vault/local_vault_store_offload_list_test.dart`

**Interfaces:**
- Consumes: `IVaultFileStore`, `VaultEntry(relativePath, byteSize)`, `VideoUploadQueueStore.read(providerId)`, `isVideoVaultPath`, `vaultFileStoreProvider`.
- Produces:
  - `IVaultFileStore.listOffloaded() → Future<List<VaultEntry>>` (offload home only, video paths only, skips `*.part`/`*.tmp`; empty when there is no offload root).
  - `IVaultFileStore.deleteOffloaded(String relPath) → Future<void>` (offload copy only; never touches home A).
  - `IVaultFileStore.offloadedModified(String relPath) → Future<DateTime?>`.
  - `IVaultFileStore.deleteStaleParts() → Future<int>` (deletes `*.part` under the offload root; returns the count).
  - `class VideoCacheIndex` — `VideoCacheIndex(SharedPreferences prefs)`; `void touch(String path, [DateTime? at])`; `DateTime? lastUsed(String path)`; `Set<String> get keptOffline`; `bool isKept(String path)`; `Future<void> setKept(String path, bool kept)`; `Future<void> forget(String path)` (drops the last-used entry only; a kept mark is the user's and stays). Keys `video_cache_last_used` (JSON map path → ms) and `video_keep_offline` (JSON list).
  - `const kVideoCacheLimitBytes = 2 * 1024 * 1024 * 1024;`
  - `class VideoCacheUsage { final int downloadedBytes; final int keptCount; final int keptBytes; }`
  - `class VideoCache` — `VideoCache({required IVaultFileStore files, required VideoCacheIndex index, required Future<Set<String>> Function() pendingUploads, int limitBytes = kVideoCacheLimitBytes})`; `Future<VideoCacheUsage> usage()`; `Future<List<String>> evictToFit({Set<String> protect = const {}})` (returns evicted paths); `Future<int> clearDownloaded()` (bytes freed); `Future<int> sweepStaleParts()`.
  - `final videoCacheIndexProvider = FutureProvider<VideoCacheIndex>`; `final videoCacheProvider = FutureProvider<VideoCache?>` (null when `vaultFileStoreProvider` is null). `pendingUploads` reads the active provider's queue paths via `VideoUploadQueueStore`.

- [ ] **Step 1: Write the failing tests**

`local_vault_store_offload_list_test.dart` (temp dirs for root and offload):
- `listOffloaded lists only video files in the offload home, with sizes` — a `.mov` in offload, a `.jpg` in offload, a `.mov.part` in offload, a `.mov` in root → only the offload `.mov`, with its byte size.
- `deleteOffloaded removes the offload copy and never the root copy` — same rel path in both homes; afterwards the root file exists and the offload file doesn't.
- `deleteStaleParts deletes only .part files in the offload home` — returns 1, the `.mov` stays.

`video_cache_index_test.dart` (`SharedPreferences.setMockInitialValues({})`):
- `touch then lastUsed round-trips across a new index on the same prefs`.
- `setKept adds and removes, and survives a new index`.
- `forget drops the last-used entry and keeps the kept mark`.

`video_cache_test.dart` (a fake `IVaultFileStore` holding offloaded entries with sizes and modified times and logging deletions; `limitBytes: 100`):
- `usage counts offloaded non-kept bytes as downloaded and kept ones separately` — a:40, b:30, kept c:50 → `downloadedBytes 70, keptCount 1, keptBytes 50`.
- `usage ignores a kept path that has no file` — kept `gone.mov` with no entry → `keptCount 0`, no throw.
- `evictToFit removes oldest-used first until under the limit` — a:60 (used t1), b:60 (t2), c:60 (t3) → evicts `[a, b]`.
- `evictToFit falls back to file modified time when there is no last-used entry`.
- `evictToFit never evicts kept or pending-upload paths` — over the limit with only kept + pending entries → evicts nothing.
- `evictToFit never evicts a protected path` — a:60 old, b:60 new and protected → evicts `[a]`.
- `clearDownloaded deletes every non-kept, non-pending offloaded video and returns the bytes`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/data/attachments/video/video_cache_index_test.dart test/core/data/attachments/video/video_cache_test.dart test/core/data/vault/local_vault_store_offload_list_test.dart`
Expected: FAIL (files and methods not defined).

- [ ] **Step 3: Implement**

`VideoCache.evictToFit`: candidates = `listOffloaded()` minus kept, minus `pendingUploads()`, minus `protect`; total = sum of all non-kept offloaded bytes; sort candidates by `index.lastUsed(path) ?? await files.offloadedModified(path) ?? epoch` ascending; `deleteOffloaded` + `index.forget` until total ≤ limit.

- [ ] **Step 4: Run the tests to verify they pass** (same command). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add <the files above>
git commit -m "feat(video): per-device video cache with oldest-used eviction and keep-offline index"
```

---

### Task 2: Touch and evict on download, offload and play; sweep on launch

**Files:**
- Modify: `lib/core/data/attachments/video/video_downloads.dart`, `lib/core/data/attachments/video/video_uploader.dart` (after `offload` ~L264; provider ~L281), `lib/features/notes/presentation/widgets/video_tile.dart` (`_play` ~L92-142), `lib/core/data/sync/video_upload_scheduler.dart` (`attach()`, provider ~L118)
- Test: `test/core/data/attachments/video/video_downloads_cache_test.dart`, `test/core/data/attachments/video/video_uploader_cache_test.dart`, `test/core/data/sync/video_upload_scheduler_test.dart` (extend)

**Interfaces:**
- Consumes: `videoCacheProvider`, `videoCacheIndexProvider` (Task 1).
- Produces: `VideoUploader` ctor gains optional `Future<void> Function(String path)? onOffloaded`; `VideoUploadScheduler` ctor gains optional `Future<void> Function()? onAttach` (runs once, on the first `attach()`).

- [ ] **Step 1: Write the failing tests**
- `video_downloads_cache_test.dart`: `a finished download touches the path and evicts with it protected` — a fake provider downloads; a fake cache records `evictToFit(protect:)` → `[{path}]`, and the index has `lastUsed(path)`. `a cancelled or failed download does not evict`.
- `video_uploader_cache_test.dart`: `after the last chunk and offload, onOffloaded is called with the path`; `a failed offload does not call onOffloaded`.
- `video_upload_scheduler_test.dart`: `onAttach runs once on the first attach, not on later attaches`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/data/attachments/video/video_downloads_cache_test.dart test/core/data/attachments/video/video_uploader_cache_test.dart test/core/data/sync/video_upload_scheduler_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**
- `VideoDownloads._fetch`: on `ready` from a download, `index.touch(path)` then `cache.evictToFit(protect: {path})`, best-effort (catch, `debugPrint` the runtime type only). A `ready` from an already-local file only touches.
- `videoUploaderProvider` passes `onOffloaded: (p) async { index.touch(p); await cache?.evictToFit(protect: {p}); }`.
- `VideoTile._play`: touch the index for a saved video before `platform.play(file.path)`.
- `videoUploadSchedulerProvider` passes `onAttach: () async { final c = await ref.read(videoCacheProvider.future); await c?.sweepStaleParts(); await c?.evictToFit(); }` (try/catch).

- [ ] **Step 4: Run the tests to verify they pass**, then `flutter test test/core/data test/features/notes`. Expected: PASS.

- [ ] **Step 5: Commit** — `feat(video): touch and evict the video cache on download, upload and play`

---

### Task 3: Keep offline

**Files:**
- Create: `lib/core/data/attachments/video/keep_offline.dart`
- Modify: `lib/features/notes/presentation/widgets/video_menu.dart`, `lib/core/data/sync/video_upload_scheduler.dart` (`maybeRun`), `lib/core/help/help_registry.dart` (note-detail video entry), `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, gen files
- Test: `test/core/data/attachments/video/keep_offline_test.dart`, `test/features/notes/presentation/widgets/video_menu_keep_offline_test.dart`

**Interfaces:**
- Consumes: `VideoCacheIndex.setKept / isKept / keptOffline` (Task 1), `VideoDownloads.fetch(path)`, the vault file store's `localFile`.
- Produces:
  - `class KeepOffline` — `KeepOffline({required VideoCacheIndex index, required Future<VideoFetchResult> Function(String) fetch, required Future<bool> Function(String) isLocal, required Future<bool> Function() mayUseNetwork})`; `Future<void> set(String path, bool kept)` (on `true` and not local → start `fetch(path)` without awaiting it); `Future<int> fetchMissing()` (when `mayUseNetwork()`, starts a fetch for every kept path that isn't local; returns how many).
  - `final keepOfflineProvider = FutureProvider<KeepOffline>`. `mayUseNetwork` here = Wi-Fi/ethernet (the uploader's `_isUnmetered`); Task 4 adds the mobile-data setting to it.
  - String `notesVideoKeepOffline` "Keep offline" / "离线保存".

- [ ] **Step 1: Write the failing tests**
- `keep_offline_test.dart`: `set true on a video not on the device starts a fetch`; `set true on a local video does not fetch`; `set false unmarks and does not delete the file`; `fetchMissing does nothing when the network is not allowed`; `fetchMissing fetches only kept paths that are not local`.
- `video_menu_keep_offline_test.dart` (Material branch; override `keepOfflineProvider` and `videoPlatformProvider`): `the menu lists Keep offline first, then Save to Photos, Share, Remove`; `tapping Keep offline marks the video kept`; `a kept video shows the tick`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/data/attachments/video/keep_offline_test.dart test/features/notes/presentation/widgets/video_menu_keep_offline_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**
- `video_menu.dart`: `_VideoAction.keepOffline` first in both branches. Material: `ListTile` with a trailing check when kept. Cupertino: the action reads "✓ Keep offline" when kept. Read the kept state before opening the sheet.
- `VideoUploadScheduler.maybeRun`: after the upload run, `fetchMissing()` (best-effort, try/catch).
- Help: extend `helpNoteDetailVideoBody` (en + zh) with one sentence on Keep offline.

- [ ] **Step 4: Run the tests to verify they pass**, then `flutter test test/features/notes test/core`. Expected: PASS.

- [ ] **Step 5: Commit** — `feat(video): keep offline from the video menu, fetched after sync`

---

### Task 4: Upload on mobile data setting and Settings → Videos screen

**Files:**
- Modify: `lib/core/settings/app_settings.dart`, `lib/core/settings/settings_controller.dart`, `lib/core/data/attachments/video/video_uploader.dart` (provider's `unmeteredNetwork` closure ~L293), `lib/core/data/attachments/video/keep_offline.dart` (`mayUseNetwork`), `lib/features/settings/presentation/screens/settings_screen.dart` (row inside the `dataMode == DataMode.cloudStorage` block under Data storage), `lib/core/navigation/router_config.dart`, `lib/core/navigation/route_names.dart`, `lib/core/help/help_registry.dart`, `lib/features/notes/presentation/screens/note_editor_screen.dart` and `lib/features/notes/presentation/widgets/video_tile.dart` (import `formatVideoSize` from its new home), ARB + gen files
- Create: `lib/core/util/format_bytes.dart` (`formatVideoSize` moved here unchanged from `note_editor_screen.dart` L1478), `lib/features/settings/presentation/screens/video_storage_screen.dart`
- Test: `test/core/settings/app_settings_video_test.dart`, `test/core/data/attachments/video/video_uploader_mobile_setting_test.dart`, `test/features/settings/presentation/video_storage_screen_test.dart`

**Interfaces:**
- Consumes: `videoCacheProvider` (`usage()`, `clearDownloaded()`), `videoUploadSchedulerProvider.maybeRun()`, `settingsProvider`.
- Produces:
  - `AppSettings.videoUploadOnMobileData` (bool, default `false`, JSON key `videoUploadOnMobileData`); `SettingsController.setVideoUploadOnMobileData(bool)`.
  - Route `/settings/videos`, `RouterNames.videoStorage`, `VideoStorageScreen`, `HelpId.videoStorage`.
  - Strings (en / zh): `settingsVideos` "Videos" / "视频"; `settingsVideosUsage` "{used} of {limit}" / "{used} / {limit}"; `videoStorageTitle` "Videos" / "视频"; `videoStorageDownloaded` "Downloaded" / "已下载"; `videoStorageKeptOffline` "Kept offline" / "离线保存"; `videoStorageKeptSummary` "{count} videos · {size}" / "{count} 个视频 · {size}"; `videoStorageMobileData` "Upload on mobile data" / "使用移动数据上传"; `videoStorageMobileDataHint` "Otherwise videos wait for Wi-Fi." / "否则视频会等待 Wi-Fi。"; `videoStorageClear` "Clear downloaded videos" / "清除已下载的视频"; `videoStorageClearConfirm` "Remove {size} of downloaded videos from this device? Kept-offline videos stay. Others download again when you play them." / "从本设备移除 {size} 已下载的视频？离线保存的视频会保留，其他视频播放时会重新下载。"; `videoStorageCleared` "Cleared {size}" / "已清除 {size}"; `helpVideoStorageTitle` / `Summary` and one `helpVideoStorage<Control>Title` / `Body` pair per control (Downloaded, KeptOffline, MobileData, Clear).

- [ ] **Step 1: Write the failing tests**
- `app_settings_video_test.dart`: `videoUploadOnMobileData defaults to false and round-trips through toJson/fromJson`; `an older blob without the key reads false`.
- `video_uploader_mobile_setting_test.dart`: `with the setting on, a queued entry uploads on mobile data` (fake unmetered = false).
- `video_storage_screen_test.dart` (fake cache: downloaded 1.2 GB, kept 2 · 300 MB; fake scheduler): `shows "1.2 GB of 2 GB" and "2 videos · 300 MB"`; `the toggle reflects videoUploadOnMobileData, sets it, and kicks the scheduler`; `Clear asks, then clears and shows the freed size`; `Cancel clears nothing`; `has a help button`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/settings/app_settings_video_test.dart test/core/data/attachments/video/video_uploader_mobile_setting_test.dart test/features/settings/presentation/video_storage_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**
- Uploader closure: `() async => (ref.read(settingsProvider).value?.videoUploadOnMobileData ?? false) || await _isUnmetered()`; `KeepOffline.mayUseNetwork` uses the same rule.
- The screen's toggle calls the setter, then `ref.read(videoUploadSchedulerProvider).maybeRun()` in a try/catch.
- Settings row: `ListTile` "Videos" with the usage subtitle, opening `/settings/videos`; cloudStorage only.
- Clear: platform dialog (Cupertino on iOS/macOS), then `clearDownloaded()`, then a SnackBar with the freed size.

- [ ] **Step 4: Run the tests to verify they pass**, then `flutter test test/features/settings test/core test/features/notes`. Expected: PASS.

- [ ] **Step 5: Commit** — `feat(settings): Videos storage screen with Upload on mobile data and Clear downloaded`

---

### Task 5: Notes-list length mark and share-text placeholder

**Files:**
- Modify: `lib/features/notes/presentation/widgets/note_row.dart` (videos part of the meta line ~L316-326), `lib/features/notes/states/note_sharer.dart` (`shareTextFor`), `lib/features/notes/presentation/widgets/note_actions_menu.dart` (~L204, pass the label), ARB + gen files
- Test: `test/features/notes/presentation/widgets/note_row_video_mark_test.dart`, `test/features/notes/states/note_sharer_test.dart` (extend)

**Interfaces:**
- Consumes: `VideoAttachment.durationMs` / `inlinePath`, `VideoTile.formatLength(int ms)`, `parseImageUri` / `formatImageUri` (`lib/core/data/attachments/inline_ref_uri.dart`).
- Produces: `String videoListMark(List<VideoAttachment> videos)` (top-level in `note_row.dart`); `String shareTextFor(HmmNote note, {String videoLabel = 'Video'})`; string `notesShareVideoLabel` "Video" / "视频".

- [ ] **Step 1: Write the failing tests**
- `note_row_video_mark_test.dart`: one 48 000 ms video → `'0:48'`; three (60 000, 75 000, null) → `'3 · 2:15'`; two with no lengths → `'2'`. Widget: a row for a note with one 48 s video shows `0:48` beside the video icon.
- `note_sharer_test.dart`: content `"Wind\n\n![Video](${formatImageUri(posterPath)})\n\nafter"` with a video whose `inlinePath` is `posterPath` and `durationMs: 48000` → `"Subject\n\nWind\n\n▶ Video, 0:48\n\nafter"`; no duration → `▶ Video`; a photo line (not a video's `inlinePath`) is unchanged; `videoLabel: '视频'` → `▶ 视频, 0:48`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/notes/presentation/widgets/note_row_video_mark_test.dart test/features/notes/states/note_sharer_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** — `shareTextFor` replaces each markdown image whose `parseImageUri(url)` is a key of `{v.inlinePath: v}` with `▶ $videoLabel, m:ss` (or `▶ $videoLabel`). The share menu passes `l.notesShareVideoLabel`.

- [ ] **Step 4: Run the tests to verify they pass**, then `flutter test test/features/notes`. Expected: PASS.

- [ ] **Step 5: Commit** — `feat(notes): video length in the list and a video placeholder in shared text`

---

### Task 6: iPad play-in-place, full screen at position, audio session release

**Files:**
- Modify: `pubspec.yaml` + `pubspec.lock` (`video_player`), `lib/core/data/attachments/video/video_platform.dart` (`play` gains `positionMs`; update fakes), `ios/Runner/VideoPlugin.swift` (`play`), `lib/features/notes/presentation/widgets/video_tile.dart`, `lib/core/help/help_registry.dart` (note-detail video entry mentions in-place play on iPad), ARB + gen files
- Create: `lib/features/notes/presentation/widgets/inline_video_player.dart`
- Test: `test/features/notes/presentation/widgets/inline_video_player_test.dart`, `test/features/notes/presentation/widgets/video_tile_wide_test.dart`

**Interfaces:**
- Consumes: `videoDownloadsProvider.fetch`, the vault file store's `localFile`, `VideoCacheIndex.touch`, `kNotesWideBreakpoint` (`note_selection.dart`).
- Produces:
  - `VideoPlatform.play(String videoPath, {int? positionMs})`.
  - `class InlineVideoPlayer extends StatefulWidget` — `InlineVideoPlayer({required File file, required double aspectRatio, required void Function(Duration position) onFullScreen, VideoPlayerController Function(File)? controllerFactory})`. Starts playing when built (it is only built after a tap). Control bar: play/pause, scrub slider, elapsed / total time, a full-screen `HmmIconButton` (tooltip `notesVideoFullScreen` "Full screen" / "全屏"). Disposes its controller on dispose.
  - `VideoTile` on wide screens (`MediaQuery.sizeOf(context).width >= kNotesWideBreakpoint`): a tap on a saved video resolves the file exactly as today (download ring included), then shows `InlineVideoPlayer` in place of the poster instead of calling `platform.play`. Full screen pauses and calls `platform.play(path, positionMs: …)`. Phones are unchanged.

- [ ] **Step 1: Write the failing tests**
- `inline_video_player_test.dart` (fake controller via `controllerFactory`): `shows play/pause, a slider and the time`; `pause toggles the controller`; `the full-screen button reports the current position`; `disposing the widget disposes the controller`.
- `video_tile_wide_test.dart` (surface 1024×768; `videoPlatformProvider` overridden with a recording fake): `on a wide screen, tapping a local video shows the inline player and does not call platform.play`; `on a phone, tapping calls platform.play`; `on a wide screen, a video not on the device downloads with the ring first, then plays inline`; `nothing plays before a tap`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/notes/presentation/widgets/inline_video_player_test.dart test/features/notes/presentation/widgets/video_tile_wide_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**
- `flutter pub add video_player` (expect `^2.9.x`).
- `InlineVideoPlayer` defaults to `VideoPlayerController.file(file)`.
- Swift `play`: read optional `positionMs`, seek with `CMTime(value: Int64(positionMs), timescale: 1000)` before `play()`; present an `AVPlayerViewController` subclass whose `viewDidDisappear` pauses and calls `AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)` (errors ignored).
- Check the Swift compiles: `flutter build ios --debug --no-codesign`, then `rm -rf .dart_tool/flutter_build build/ios` so the next signed build isn't left with an ad-hoc-signed native framework.

- [ ] **Step 4: Run the tests to verify they pass**, then the full `flutter test` and `flutter analyze` (baseline: 2 infos). Expected: PASS.

- [ ] **Step 5: Commit** — `feat(notes): play videos in place on iPad and release the audio session`

---

## Manual checks on device (spec §8, Stage 4)

- Keep offline a video on the iPad; Settings → Videos → Clear downloaded videos; the kept one still plays offline.
- Play videos on the iPad until the downloaded total passes 2 GB; Settings → Videos stays at or under 2 GB, and the oldest re-download on play.
- A video still uploading on the iPhone survives Clear downloaded videos there.
- With Upload on mobile data on, a waiting video uploads on cellular without tapping it.
- iPad: a tap plays in place with the control bar; full screen continues from the same spot; closing it lets other audio (Music) resume.
- The notes list shows the video length.
- Sharing a note with a video shows `▶ Video, 0:48` in the text.
