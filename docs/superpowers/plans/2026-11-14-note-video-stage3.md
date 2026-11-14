# Video in Notes — Stage 3 (OneDrive video sync) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In cloudStorage (OneDrive) mode, a video added on one device uploads in resumable pieces (waiting for Wi-Fi unless the user says otherwise). Another device shows "Still uploading" until the video is in the cloud, then downloads it when play is tapped and plays it.

**Architecture:**
- **Two homes for a video file:**
  - Until it is uploaded (and always in local mode), the video stays in the vault under `Documents/vault/`, which the deploy backup copies.
  - Once its upload is confirmed, it moves to `Library/HmmVideos/`, mirroring the vault path. That folder is outside the backed-up folders and marked excluded from iCloud backup.
  - Downloads land there too.
  - `LocalVaultStore` looks in both places for video paths.
- **Provider-neutral large-file operations on `CloudSyncProvider`:** start an upload session, ask where it stands, send one chunk, cancel, check existence, and download to a file with progress and cancel. OneDrive implements them with a Graph upload session; the session URL is called *without* the Authorization header.
- **A persisted upload queue** (shared_preferences JSON, per provider) and a `VideoUploader`:
  - It runs one upload at a time, reads ≤ 10 MiB of the file per chunk, and saves progress after every chunk.
  - It waits for Wi-Fi unless that video was allowed mobile data.
  - It restarts a session that expired.
- **Sync:** `_reconcileVault` stops skipping videos silently.
  - It enqueues local videos the cloud lacks.
  - It publishes which referenced videos the cloud has, but never pulls a video.
  - A scheduler kicks the uploader after each sync, on launch/resume, and when Wi-Fi returns, holding an iOS background task while it runs.
- **The video tile gains states:**
  - On the adding device: uploading % or "Waiting for Wi-Fi" (tap → upload over mobile data).
  - On other devices: "Still uploading", or download on tap with a progress ring (second tap cancels), then play.

**Tech Stack:** Flutter, Riverpod 3, Dio (already used by `OneDriveGraphClient`), `connectivity_plus` (already a dependency), `path_provider` (`getLibraryDirectory`), `shared_preferences`, Swift (`hmm/video` plugin). No new pub packages.

**Spec:** `docs/superpowers/specs/2026-11-12-note-video-design.md`, §3 "Sync (OneDrive)", "Deploy backups", "Deleting"; §5.2, §5.3, §5.4; §8 Stage 3. Stages 0–2 are merged: 91a6f49 and 2546683, plus the fix 7725bd3.

**Branch:** `feat/note-video-stage3` from main.

## Global Constraints

- **No whole video in memory, ever.**
  - The upload reads one fragment at a time with `RandomAccessFile`; never `readAsBytes`/`getBytes` on a video.
  - The download streams to a file.
  - Memory must not grow with video size.
- **Fragment size:** `kUploadFragmentBytes = 10 * 1024 * 1024` (10,485,760 = 32 × 327,680). Graph requires every fragment except the last to be a multiple of 320 KiB (327,680 bytes).
- **Graph upload session:**
  - `POST <vault item>:/createUploadSession` with body `{"item": {"@microsoft.graph.conflictBehavior": "replace"}}` returns `uploadUrl`.
  - Fragments: `PUT uploadUrl` with `Content-Length` and `Content-Range: bytes <start>-<end>/<total>`. 202 = more expected; 200/201 = complete.
  - `GET uploadUrl` gives `nextExpectedRanges` (`["<n>-"]`); 404 means the session is gone. `DELETE uploadUrl` cancels.
  - **Never send the Authorization header to `uploadUrl`** (it is pre-authenticated). Use a second `Dio` with no auth interceptor.
- **Persisted upload queue:**
  - Key `video_upload_queue:<providerId>` in shared_preferences.
  - JSON list of `{"path", "total", "session", "sent", "mobileOk"}`.
  - It survives restarts; the session URL is kept so an upload resumes.
- **Gating:**
  - An upload starts or continues only on Wi-Fi or ethernet (`ConnectivityResult.wifi` / `.ethernet`), unless its entry has `mobileOk: true`. That flag is set by "Upload now using mobile data" on that video.
  - The per-device "Upload on mobile data" setting comes in stage 4 (see Rulings).
- **Never pull a video eagerly.** Posters still sync like photos. A video downloads only when play is tapped.
- **Locations (§5.4):**
  - A not-yet-uploaded video stays in `<Documents>/vault/<path>`.
  - Confirmed-uploaded and downloaded videos live in `<Library>/HmmVideos/<path>`. On Android, use `<ApplicationSupport>/HmmVideos/<path>`.
  - `HmmVideos` is excluded from iCloud backup and is not `Library/Caches`.
  - Nothing in this stage evicts videos (eviction is stage 4).
- **Per-device state is never synced:** queue, progress, download state, and which home a file is in.
- **"Still uploading":** a referenced video the cloud lacks. It is re-checked on every sync and again when play is tapped.
- **Purge and GC:** they treat video paths like photo paths in both homes. A queued upload whose path no note references any more is cancelled and dropped.
- **Modes:** all of this runs only in cloudStorage with a provider whose `supportsLargeFiles` is true. local and cloudApi behave exactly as in stage 2.
- **Project rules:**
  - `HmmIconButton` + localized tooltip.
  - Every new string in `app_en.arb` and `app_zh.arb`, with gen files regenerated by `flutter gen-l10n` and committed.
  - Help entries updated when a control changes.
  - Cupertino dialogs on iOS, Material on Android (branch on `Theme.of(context).platform`).
  - Never `ref.watch` inside a `LayoutBuilder` builder.
  - Never `dart format` a directory.
  - Tests must override `videoPlatformProvider` (it checks `Platform.isIOS`).
- **Rollout:** install on both devices (back up first, install over).

### Rulings made while planning (for the user to check)

1. **Generic "Still uploading from another device".** The spec says "from iPhone", but no device name is recorded per video. Recording one means a new field and a native model call. If wrong, a later small change adds `addedOn` to `VideoAttachment.extra`.
2. **Per-video override only; the device-wide "Upload on mobile data" toggle comes in stage 4.** The spec places it in Settings → Storage → Videos, which is a stage 4 screen. If wrong, stage 3 users on cellular tap the override per video until stage 4.
3. **An uploaded video removed in the editor stays in OneDrive until its note is purged.** This is the same as removed photos today; the spec says "the same way removed photos are now". If wrong, a later remote-GC pass is needed for photos and videos alike.
4. **An upload error stops the run (the next sync retries).** It doesn't skip to the next video, because most errors are network-wide. If wrong, one corrupt entry could hold back later videos; the run logs the error and the next run retries.

## Review Focus

1. **App killed or connection dropped mid-upload.** The next run resumes from the server's `nextExpectedRanges`, not from zero. A session that has gone (404) restarts from zero and never corrupts the file. Tests: Task 3 "resumes from the server offset" and "restarts when the session is gone".
2. **Note deleted, or video removed, while its upload is queued or running.** No more chunks are sent, the session is cancelled, and the entry is dropped. Test: Task 3 "drops entries no note references".
3. **The other device taps play before the upload finishes.** It shows "Still uploading" with no download, no endless spinner, and no partial file. Test: Task 5 "play before upload finishes says still uploading".
4. **A download cancelled or failing midway.** It leaves no file at the video's path (only a removed `.part`), the tile is back in its download state, and the next tap starts again. Test: Task 5 "cancelled download leaves no file".
5. **A video in its uploaded home must still be found** by play, share, save, local purge and Settings clean-up. Test: Task 1 "offloaded video is found, listed and deleted".
6. **Memory stays flat.** No chunk handed to the provider exceeds `kUploadFragmentBytes`, and the whole file is never read. Test: Task 3 "chunks never exceed the fragment size".

---

### Task 1: Two homes for a video file, plus native helpers

**Files:**
- Modify: `lib/core/data/vault/local_vault_store.dart`, `lib/core/data/vault/vault_file_store.dart`, `lib/core/data/attachments/attachment_providers.dart`, `lib/core/data/attachments/video/video_platform.dart`, `ios/Runner/VideoPlugin.swift`
- Test: `test/core/data/vault/local_vault_file_store_test.dart`, `test/core/data/attachments/video/video_platform_test.dart`, `test/core/data/attachments/video/fake_video_platform.dart`

**Interfaces:**
- Produces:
  - `LocalVaultStore({required Directory rootDir, Directory? offloadDir})`.
  - `IVaultFileStore` gains:
    - `Future<void> offload(String relativePath)`: move a video from the vault root to the offload root. No-op if already there. Throws `ArgumentError` for non-video paths, and `VaultStoreException` if the file is in neither root.
    - `File? downloadTarget(String relativePath)`: where a download of this video should end up; null when there's no offload root.
  - `localFile(path)` returns the file from whichever root has it; the vault root wins if both do.
  - For video paths, `exists`, `delete` and `list` (used by `VaultGarbageCollector`) cover both roots. `delete` removes the file from both.
  - `VideoPlatform` gains:
    - `Future<void> excludeFromBackup(String path)`.
    - `Future<int?> beginBackgroundTask()`: null when unsupported.
    - `Future<void> endBackgroundTask(int id)`.
  - `FallbackVideoPlatform` implements all three as no-ops, returning null.
  - `vaultFileStoreProvider` builds the offload dir: `getLibraryDirectory()/HmmVideos` on iOS, `getApplicationSupportDirectory()/HmmVideos` elsewhere. It creates the dir and calls `excludeFromBackup(dir)` once.

- [ ] **Step 1: Write the failing tests** in `local_vault_file_store_test.dart`, with temp dirs for `rootDir` and `offloadDir`:
  - `offload moves a video into the offload root`: import `attachments/note-1/u.mov`, call `offload`. The file now exists under `offloadDir/attachments/note-1/u.mov` and no longer under `rootDir`, with the same bytes.
  - `offloaded video is found, listed and deleted`:
    - after `offload`, `localFile` returns the offload file, `exists` is true, and `list()` contains the path once;
    - `delete` removes it, after which `exists` is false.
  - `offload refuses a non-video path` (`.jpg`), throwing `ArgumentError`.
  - `offload of a missing file throws VaultStoreException`.
  - `downloadTarget points into the offload root`, and returns null when `offloadDir` is null.
- [ ] **Step 2: Run** `flutter test test/core/data/vault/local_vault_file_store_test.dart`. Expected: FAIL (no `offloadDir`).
- [ ] **Step 3: Implement.**
  - Move with `File.rename`, falling back to copy then delete.
  - Create parent dirs.
  - Validate paths with the existing `vaultRelativePathValidate`.
  - `list()` merges the offload root's video entries into the sorted result.
- [ ] **Step 4: Native.** In `VideoPlugin.swift` add:
  - `excludeFromBackup(path)`: set `URLResourceValues.isExcludedFromBackup = true` on the URL; result `nil`, or a `FlutterError` on failure.
  - `beginBackgroundTask`: `UIApplication.shared.beginBackgroundTask(withName: "hmm.videoUpload")`, whose expiration handler ends the task. Returns the task id as Int.
  - `endBackgroundTask(id)`.

  Add the Dart side in `MethodChannelVideoPlatform`, and extend `FakeVideoPlatform` to record calls. Add a `video_platform_test.dart` case per method that checks the channel method name and arguments.
- [ ] **Step 5: Run** both test files, then `flutter analyze`. Expected: PASS, with no new analyzer issues.
- [ ] **Step 6: Commit** `feat(vault): uploaded videos get their own home outside the backup`.

### Task 2: Large-file transfer on the sync provider (OneDrive upload sessions)

**Files:**
- Modify: `lib/core/data/sync/cloud_sync_provider.dart`, `lib/core/data/sync/onedrive_graph_client.dart`, `lib/core/data/sync/onedrive_sync_provider.dart`
- Test: `test/core/data/sync/onedrive_graph_upload_session_test.dart` (new), `test/core/data/sync/onedrive_sync_provider_large_file_test.dart` (new)

**Interfaces:**
- Produces, in `cloud_sync_provider.dart`:
  ```dart
  class TransferCancel { void cancel(); bool get isCancelled; }
  class TransferCancelledException implements Exception {}
  class LargeUploadSessionGone implements Exception {}
  // CloudSyncProvider defaults: false / UnsupportedError
  bool get supportsLargeFiles;
  Future<String> startLargeUpload(String path, int totalBytes);        // session handle
  Future<int?> largeUploadNextOffset(String handle);                   // null = session gone
  Future<bool> uploadLargeChunk(String handle, Uint8List chunk, int offset, int totalBytes); // true = complete; throws LargeUploadSessionGone on 404
  Future<void> cancelLargeUpload(String handle);                       // gone = success
  Future<bool> largeFileExists(String path);
  Future<void> downloadLargeFile(String path, File target,
      {void Function(int received, int total)? onProgress, TransferCancel? cancel}); // throws TransferCancelledException
  ```
- `OneDriveGraphClient(auth, sub, {Dio? dio, Dio? uploadDio})`. The default `uploadDio` has no interceptors and uses `validateStatus: (_) => true`. New methods:
  - `createUploadSession(rel)` returns the `uploadUrl`.
  - `uploadSessionNextOffset(url)` returns `int?`.
  - `putUploadFragment(url, chunk, offset, total)` returns `bool`.
  - `deleteUploadSession(url)`.
  - `attachmentExists(rel)` returns `bool`: `GET _userPath('vault/<rel>')`; 200 → true, 404 → false.
  - `downloadAttachmentTo(rel, savePath, {onProgress, CancelToken?})` uses `_dio.download` on the `:/content` path.
- `OneDriveSyncProvider.supportsLargeFiles => true`, mapping each operation onto the client. The handle is the `uploadUrl`.

- [ ] **Step 1: Write the failing tests** with a test-local `_RecordingAdapter implements HttpClientAdapter`, set on both Dios. It records method, URI, headers and body length, and replies from a queue. http_mock_adapter can't read streamed bodies (see `onedrive_graph_put_wire_test.dart`).
  - `createUploadSession posts the replace conflict behaviour` checks the URL ends `/vault/attachments/note-1/u.mov:/createUploadSession` and the JSON body is exact.
  - `fragment PUT goes to uploadUrl without Authorization` checks the `Content-Range` is `bytes 0-9/20`, `Content-Length: 10`, and that no `authorization` header is present. A 202 reply returns false; a 201 reply returns true.
  - `next offset parses nextExpectedRanges`: `["10485760-"]` → 10485760; a 404 → null.
  - `fragment 404 throws LargeUploadSessionGone`.
  - `attachmentExists maps 200/404`.
  - `downloadAttachmentTo writes the bytes to the file and reports progress`, and `cancel stops it with TransferCancelledException` (provider-level test, mapping `TransferCancel` to a Dio `CancelToken`).
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - The fragment body is `Stream.fromIterable([chunk])` with an explicit content length, as `putAttachment` does.
  - Graph errors go through the existing `_throwIfBad`.
  - `downloadLargeFile` downloads to `<target>.part` and renames on success. It deletes `.part` on any failure or cancel, then rethrows.
- [ ] **Step 4: Run** the tests. Expected: PASS. Also run `flutter test test/core/data/sync/`. Expected: all pass.
- [ ] **Step 5: Commit** `feat(sync): resumable large-file upload and download for OneDrive`.

### Task 3: Persisted upload queue and the uploader

**Files:**
- Create: `lib/core/data/attachments/video/video_upload_queue.dart`, `lib/core/data/attachments/video/video_uploader.dart`
- Test: `test/core/data/attachments/video/video_upload_queue_test.dart`, `test/core/data/attachments/video/video_uploader_test.dart`, with a fake `CloudSyncProvider` that records chunks and can 404 or fail on demand

**Interfaces:**
- Consumes:
  - Task 1: `IVaultFileStore.localFile`, `IVaultFileStore.offload`.
  - Task 2: the large-file provider operations.
- Produces:
  ```dart
  const kUploadFragmentBytes = 10 * 1024 * 1024;
  class VideoUploadEntry { final String path; final int total; final String? session; final int sent; final bool mobileOk; /* toJson/fromJson with keys path,total,session,sent,mobileOk */ }
  class VideoUploadQueueStore { Future<List<VideoUploadEntry>> read(String providerId); Future<void> put(String providerId, VideoUploadEntry e); Future<void> remove(String providerId, String path); }
  enum VideoUploadPhase { queued, waitingForWifi, uploading, failed }
  class VideoUploadState { final VideoUploadPhase phase; final int sent; final int total; double get fraction; }
  class VideoUploader {
    VideoUploader({required CloudSyncProvider provider, required VideoUploadQueueStore store,
      required IVaultFileStore files, required Future<bool> Function() unmeteredNetwork,
      required Future<Set<String>> Function() referencedPaths, int fragmentBytes = kUploadFragmentBytes});
    ValueListenable<Map<String, VideoUploadState>> get states;  // path → state; absent = nothing pending
    Future<void> load();                         // read the queue into states (queued)
    Future<void> enqueue(String path);           // idempotent; total from the local file's length
    Future<void> allowMobileData(String path);   // sets mobileOk, then run()
    Future<void> run();                          // single-flight: a second call while running returns the same future
  }
  final videoUploaderProvider = Provider<VideoUploader?>(...); // null unless cloudStorage and provider.supportsLargeFiles
  ```
- What `run()` does with each entry, in order:
  1. If its path is not in `referencedPaths()`, cancel its session (if any), remove it, and clear its state.
  2. If no local file exists, remove it.
  3. If `!mobileOk && !await unmeteredNetwork()`, mark it `waitingForWifi` and move to the next entry.
  4. If there's no session, call `startLargeUpload`. Otherwise call `largeUploadNextOffset`; when that returns null, start a new session with `sent = 0`.
  5. Loop: read `min(fragmentBytes, total - offset)` bytes at `offset` with `RandomAccessFile`, call `uploadLargeChunk`, persist `sent`, and update the state to `uploading`.
  6. On complete: `offload(path)`, remove the entry, and clear its state.
  7. On `LargeUploadSessionGone` mid-loop: restart once with a new session.
  8. On any other error: mark it `failed`, keep the entry, and stop the run.

- [ ] **Step 1: Write the failing tests.**
  - Queue: `round-trips entries and survives a fresh store` (via `SharedPreferences.setMockInitialValues`), `put replaces by path`, and `bad JSON reads as empty`.
  - Uploader, using a 25-byte temp file and `fragmentBytes: 10`:
    - `uploads in fragment-sized chunks and offloads when done`: chunks at offsets 0/10/20 with lengths 10/10/5, `offload` called, queue empty.
    - `chunks never exceed the fragment size`.
    - `resumes from the server offset`: entry `sent: 10`, session `s1`, fake reports next offset 20, so the only chunk sent is at 20.
    - `restarts when the session is gone`: next offset is null, so a new session and offsets 0/10/20.
    - `drops entries no note references`: `referencedPaths` is empty, so no chunk is sent, `cancelLargeUpload('s1')` is called, and the queue is empty.
    - `waits for Wi-Fi unless mobile data was allowed`: on metered, no chunk is sent and the state is `waitingForWifi`; after `allowMobileData`, the upload completes.
    - `an error marks failed and keeps the entry`.
    - `a second run() while running does not upload twice`.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement.** Open the `RandomAccessFile` once per entry and close it in `finally`. The connectivity check for the provider is `Connectivity().checkConnectivity()`, which must contain `wifi` or `ethernet`. `referencedPaths` is `collectReferencedVaultPaths(db)`.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(video): persisted, resumable, Wi-Fi-gated video upload queue`.

### Task 4: Sync enqueues uploads and learns what the cloud has; scheduler

**Files:**
- Modify: `lib/core/data/sync/sync_orchestrator.dart` (`_reconcileVault`, provider wiring), `lib/main.dart` (keep the scheduler alive, as `notePurgeSchedulerProvider` is kept)
- Create: `lib/core/data/attachments/video/remote_video_index.dart`, `lib/core/data/sync/video_upload_scheduler.dart`
- Test: `test/core/data/sync/sync_orchestrator_vault_reconcile_test.dart` (extend), `test/core/data/sync/video_upload_scheduler_test.dart` (new)

**Interfaces:**
- Consumes: Task 3 `VideoUploader.enqueue/run/load`; Task 1 `VideoPlatform.beginBackgroundTask/endBackgroundTask`.
- Produces:
  - `class RemoteVideoIndex extends ChangeNotifier`:
    - `Set<String>? get cloudHas`: null until the first sync lists the cloud.
    - `void update(Set<String> remoteVideoPaths)`.
    - `bool? has(String path)`: null when unknown.
  - `final remoteVideoIndexProvider = Provider<RemoteVideoIndex>(...)`.
  - `SyncOrchestrator` gets two optional constructor parameters:
    - `void Function(String path)? onLocalVideoMissingRemotely`, wired to `uploader.enqueue`;
    - `void Function(Set<String> remoteVideoPaths)? onRemoteVideos`, wired to `index.update`.
  - In `_reconcileVault`, video paths still never push or pull bytes. Instead:
    - `localHas && !remoteHas` → `onLocalVideoMissingRemotely(path)`;
    - after the loop, `onRemoteVideos(remote.where(isVideoVaultPath).toSet())`.
  - `VideoUploadScheduler`, whose provider listens like `notePurgeSchedulerProvider`, calls `uploader.run()`:
    - after each sync that finishes (`!controller.status.isSyncing`);
    - on start, after `uploader.load()`;
    - on `AppLifecycleState.resumed`;
    - when connectivity changes to include `wifi` or `ethernet`.

    While a run is in progress it holds `beginBackgroundTask()`, and ends it in `finally`.

- [ ] **Step 1: Write the failing tests.**
  - Reconcile:
    - `a local video the cloud lacks is enqueued, never pushed`: the callback gets the path, and `pushAttachment` is never called with it.
    - `a cloud-only video is not pulled`.
    - `remote video paths are published`: the callback gets exactly the remote video paths, not photos.
  - Scheduler, with a fake controller, uploader and platform:
    - `runs after a finished sync`;
    - `runs on resume`;
    - `runs when Wi-Fi returns`;
    - `holds a background task while running and ends it`;
    - `does not run while a sync is in progress`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `videoUploaderProvider` takes its `CloudSyncProvider` from `ref.watch(syncOrchestratorProvider).provider`.
  - So the callbacks in `syncOrchestratorProvider` must `ref.read(videoUploaderProvider)` **inside the callback body**, never while the orchestrator is being built; otherwise Riverpod reports a cycle.
  - `remoteVideoIndexProvider` has no dependencies and can be read directly. Keep the scheduler alive with a `ref.listen` in `main.dart` next to the purge scheduler's.
- [ ] **Step 4: Run** the tests, then `flutter test test/core/data/sync/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sync): queue video uploads from sync and track what the cloud has`.

### Task 5: Video tile states, download on play, strings and help

**Files:**
- Create: `lib/core/data/attachments/video/video_downloads.dart`
- Modify:
  - `lib/features/notes/presentation/widgets/video_tile.dart`
  - `lib/features/notes/presentation/widgets/video_menu.dart` (Share and Save to Photos download first when the file isn't local)
  - `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` and the gen files
  - `lib/core/help/help_registry.dart` (body text only)
  - `CLAUDE.md` (Notes row sentence)
- Test: `test/features/notes/presentation/widgets/video_tile_test.dart`, `test/core/data/attachments/video/video_downloads_test.dart`

**Interfaces:**
- Consumes:
  - Task 1: `downloadTarget`.
  - Task 2: `largeFileExists`, `downloadLargeFile`, `TransferCancel`.
  - Task 3: `videoUploaderProvider` (`states`, `allowMobileData`).
  - Task 4: `remoteVideoIndexProvider`.
- Produces:
  - A `VideoDownloads` Notifier (`videoDownloadsProvider`) whose state is a `Map<String, double>`: path → fraction 0–1, absent = not downloading.
  - `enum VideoFetchOutcome { ready, stillUploading, cancelled, failed }` and `class VideoFetchResult { final VideoFetchOutcome outcome; final File? file; }`, where `file` is set only when the outcome is `ready`.
  - `Future<VideoFetchResult> fetch(String path)`:
    - the local file if present → `ready`;
    - otherwise `largeFileExists` is false → `stillUploading`;
    - otherwise download to `downloadTarget(path)` with progress → `ready`;
    - `TransferCancelledException` → `cancelled` (no message);
    - any other error → `failed` (`notesVideoDownloadFailed`).
  - `void cancel(String path)`.
- Tile behaviour:

  | Situation | Shows | Tap |
  |---|---|---|
  | local file | poster + play (as stage 2) | plays |
  | uploader state `uploading` | chip "Uploading 34%" | plays (file is local) |
  | uploader state `waitingForWifi` | chip "Waiting for Wi-Fi" | the chip opens the mobile-data dialog; the poster plays |
  | uploader state `failed` | chip "Upload will retry" | plays |
  | not local, cloudStorage, `index.has == false` | chip "Still uploading" | live check: still absent → snackbar `notesVideoStillUploading`; present → download |
  | not local, cloudStorage, otherwise | cloud-download glyph on the play button | download with a progress ring on the play button, then play; tapping during the download cancels |
  | not local, not cloudStorage | as stage 2 | `notesVideoNotOnDevice` |

- New strings, English, with Chinese in `app_zh.arb`:
  - `notesVideoUploading` "Uploading {percent}%"
  - `notesVideoWaitingForWifi` "Waiting for Wi-Fi"
  - `notesVideoUploadRetry` "Upload will retry"
  - `notesVideoStillUploading` "Still uploading from another device"
  - `notesVideoMobileDataTitle` "Upload over mobile data?"
  - `notesVideoMobileDataBody` "This video is {size}. Uploading it now uses that much mobile data."
  - `notesVideoMobileDataUpload` "Upload now using mobile data"
  - `notesVideoMobileDataCancel` "Wait for Wi-Fi"
  - `notesVideoDownload` "Download and play" (semantics)
  - `notesVideoDownloading` "Downloading {percent}%. Tap to cancel." (semantics)
  - `notesVideoDownloadFailed` "Couldn't download the video"
- `helpNoteDetailVideoBody` becomes: "Tap a video to play it full screen. With OneDrive sync, a video uploads when you're on Wi-Fi, and other devices download it when you tap play. Long press it for Save to Photos, Share or Remove."

- [ ] **Step 1: Write the failing tests.**
  - Downloads, with a fake provider:
    - `fetch downloads to the offload target and reports progress`;
    - `fetch returns still-uploading when the cloud lacks it`, with no download call;
    - `cancelled download leaves no file`: neither the target nor `.part` exists afterwards, and the state is cleared.
  - Tile, with overrides for `videoUploaderProvider`, `remoteVideoIndexProvider`, `videoDownloadsProvider`, `vaultFileStoreProvider`, `videoPlatformProvider` and `dataModeProvider`:
    - `uploading chip shows the percent`;
    - `waiting chip opens the mobile-data dialog and Upload calls allowMobileData`;
    - `play before upload finishes says still uploading`;
    - `tap downloads then plays`: `platform.play` receives the downloaded path;
    - `second tap during download cancels`;
    - `local mode keeps the stage-2 not-on-device message`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - Chips sit top-left on the poster: a dark rounded box with white 12 pt text, like the length badge.
  - The dialog is a `CupertinoAlertDialog` on iOS and an `AlertDialog` elsewhere.
  - Size uses the existing size formatter from stage 2's Large video dialog.
  - Menu Share and Save to Photos call `fetch` first, using the same messages.
  - Add the strings, run `flutter gen-l10n`, and update the help body.
  - In CLAUDE.md, change the Notes row so "videos don't sync yet" reads: "in cloudStorage, videos upload in resumable pieces on Wi-Fi (`VideoUploader`, queue in prefs), move to `Library/HmmVideos` once uploaded, and download on play (`VideoDownloads`)".
- [ ] **Step 4: Run** the tests, then the full `flutter test` and `flutter analyze`. Expected: all pass, with only the 2 old infos.
- [ ] **Step 5: Commit** `feat(notes): upload, still-uploading and download-on-play states for videos`.

## Manual checks on device (spec §8, Stage 3)

- On mobile data the upload waits ("Waiting for Wi-Fi"); "Upload now using mobile data" uploads it.
- Kill the app mid-upload of a large (≥ 200 MB) video. On relaunch it resumes; the OneDrive file's size matches the original.
- The iPad shows "Still uploading", then (after the iPhone finishes and the iPad syncs) the poster with a download glyph. A tap shows the ring, then plays. A second tap during the download cancels it.
- Delete the note and empty Recently Deleted. The video and poster leave OneDrive and both devices.
- A deploy backup (`hmm-release.sh --backup`) of the iPhone excludes uploaded videos (not under `Documents`/`Application Support`) and includes a not-yet-uploaded one.
- Memory stays flat during a 1 GB upload and download (Xcode memory gauge).
