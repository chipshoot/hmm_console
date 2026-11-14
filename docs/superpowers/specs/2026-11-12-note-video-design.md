# Video in Notes — Design

Status: agreed in brainstorm + grilling, 2026-11-12. Not yet planned.
Mockups: https://claude.ai/artifact/SEMfpy2fqu2C3xWYhPNmKF (private to the owner).

## 1. Intent

Some moments can't be explained by a photo: a day of big wind, or a screen
recording that shows how something happened. Notes should hold video the way
they hold photos, so the note shows what happened.

Two kinds of video, delivered as one project: a compatibility build (stage 0)
and then four stages (§3):

1. **Video links.** A YouTube or Bilibili video shown in a note as a card
   (thumbnail, title, length, play button). Tapping it opens their app. Almost
   no data to sync.
2. **Attached videos.** The user's own clips, usually under a minute and
   sometimes a few minutes, **kept at original quality** (never compressed or
   re-encoded). They sync to the user's other devices (iPhone → iPad) the way
   photos do.

## 2. Goals, non-goals, anti-goals

**Goals**
- Add a video from the photo library (this includes iOS screen recordings) and
  play it in the note on the same device straight away.
- See the same video on the iPad through OneDrive sync without the app loading
  whole videos into memory and without downloading every video eagerly.
- Keep the device's storage use bounded and visible.
- Turn YouTube and Bilibili links into tappable preview cards.

**Non-goals (first version)**
- Compression, transcoding, trimming or editing.
- Encrypted (sensitive) videos, and videos in notes that hold sensitive
  items.
- Videos in Hmm server (`cloudApi`) mode, or the Hmm server storing or
  streaming video.
- Other cloud providers. The storage layer must allow them later, but only
  OneDrive is implemented.
- True background upload after the app is closed (an iOS background URL
  session). It can be added later.
- Videos on screens other than notes (vehicle service records and so on).
- Changing how photos sync. Photos keep downloading eagerly as today.
- Playing YouTube or Bilibili videos inside Hmm.
- Promising Android. The code should work there, but only iPhone and iPad are
  tested.

**Anti-goals (a failure even if it "works")**
- Any step that holds a whole video in memory. A 1 GB video must not crash or
  stall the app on an iPhone.
- A video that exists only on the phone getting lost: cleared from the cache,
  left out of a backup, or deleted before its upload finished.
- Quietly lowering quality.
- Storing a video unencrypted inside a note that holds sensitive items.
- Older installed app versions crashing on a note that contains a video or a
  video card (they may render it plainly, but must not crash or corrupt the
  note).

## 3. Decisions (made by the user)

### Video links (stage 1)
- **Sites:** built for YouTube and Bilibili, with title, thumbnail and length
  (see §6.1 on length). Other links whose page publishes a standard preview
  (Open Graph `og:image` and `og:title`) get a simpler card with image and
  title. Everything else stays a plain link.
- **How a card is made:** pasting a supported link **on its own line** turns
  it into a card. A link inside a sentence stays a normal link. An **"Add
  video link"** item in the attach menu does the same thing.
- **Tap:** opens the YouTube or Bilibili app, or the browser if the app isn't
  installed (`url_launcher`, external application mode). iOS's own "◀ Hmm"
  button returns to the note, and the note stays where it was.
- **Preview data:** fetched **once** when the link is added and **saved with
  the note** (title, length, thumbnail image). It works offline and survives if
  the video is taken down. The card shows "May no longer be available" only
  when opening fails.

### Attached videos
- **Quality:** original, never re-encoded.
- **Source:** the photo library picker (videos and screen recordings).
  Recording inside the app is optional and may come later.
- **Count:** no limit on videos per note.
- **Size:** warning dialog over **500 MB** ("Large video", with size and
  OneDrive cost, Cancel/Add). Over **2 GB** the video is refused.
- **Placement:** inline in the note text wherever the user puts it, the way
  inline photos are.
- **Look:**
  - **iPhone:** preview frame with a play button and length badge. A tap opens
    a full-screen Apple-style player (swipe down to close, scrub, skip ±10 s,
    rotate for landscape, sound on).
  - **iPad (wide layout):** plays in place with an inline control bar and a
    full-screen button.
  - Nothing plays on its own.
- **Video menu** (long press): Keep offline (a tick toggle), Save to Photos,
  Share…, Remove from note.
- **Notes list:** rows show a small video mark with the length, beside the
  existing row icons.
- **Sync (OneDrive):**
  - Note text and preview frame sync straight away. The video uploads
    **separately**.
  - Uploads go up in pieces, are resumable, and **wait for Wi-Fi** unless the
    per-device setting "Upload on mobile data" is on. A tap on "Waiting for
    Wi-Fi" offers "Upload now using mobile data" for that video.
  - Uploads run while the app is open plus the short time iOS allows after it
    goes to the background, and resume on next launch.
  - Other devices show "Still uploading from iPhone" until the video exists in
    the cloud.
  - Other devices download a video **only when play is tapped** (with a
    progress ring; a second tap cancels), unless it is marked Keep offline.
- **Space:**
  - Every device keeps a **2 GB cache** of downloaded or recently added videos.
    The oldest-used are cleared first.
  - **Keep offline** videos are never cleared and don't count toward the 2 GB.
  - Settings → Storage → Videos shows downloaded size of 2 GB, kept-offline
    count and size, the Upload on mobile data toggle, and "Clear downloaded
    videos" (which keeps Keep offline ones).
- **Deploy backups:** skip videos already in OneDrive, and **always include
  videos not yet uploaded**. In local mode every video is device-only, so all
  are backed up.
- **Deleting:** follows the photo rules. A deleted note stays in Recently
  Deleted for 30 days, then its videos and posters are removed from OneDrive
  and from every device's storage. A video removed while editing is cleaned up
  the same way removed photos are now.

### Modes and limits
- **local mode:** works fully; videos stay on the device.
- **cloudStorage (OneDrive):** full feature.
- **cloudApi:** the video option is shown **greyed out** with "Videos need
  OneDrive sync for now". Video links still work, since they need no server
  storage.
- **Sensitive items** (user decision, 2026-11-12):
  - Hmm has no note-level sensitive flag; sensitivity is per attachment
    (`VaultRef.sensitive`, "Add sensitive image").
  - There is **no "sensitive video" option**. A video is never encrypted.
  - A note that holds **any sensitive attachment** can't take a video:
    "Videos can't be added to notes with sensitive items yet".
  - Video link cards are allowed everywhere; their thumbnails are public
    images and are stored unencrypted.
  - If a note already has a video and the user then adds a sensitive item,
    that is allowed. The rule only gates adding videos.
- **Sharing or exporting a note** as text or PDF: the video appears as its
  preview frame with "▶ Video, 0:48". The video file itself is shared only
  through its own Share… item.

### Delivery: stage 0 plus four stages, each merged and installed when done
0. **Compatibility build** (user decision, 2026-11-12):
   - **What it does:** the attachments codec and every reader of it (note
     mapper, `collectReferencedVaultPaths` in vault GC, sync reconcile and
     purge, the editor's attachment reconcile) **tolerate** unknown content
     types and unknown top-level keys, and **preserve** both on re-encode.
     Unknown entries are skipped for display, never deleted, and never GC'd
     while referenced.
   - **Rollout:** installed on both iPhone and iPad (backup first) **before**
     any note gets a video or a link card.
   - **Why:**
     - Today `_validateContentType` (`attachment_ref_codec.dart`) throws on
       `video/*`. That breaks note loading (`hmm_note_mapper.dart`) and sync
       (`vault_gc.dart`).
     - An unknown top-level key is dropped the next time an older build
       re-encodes the note.
1. **Video links:** cards, paste detection, the attach-menu item, saved
   previews, external open.
2. **Video on one device:**
   - Picker, size warning and cap, path-based storage (§5.1), preview frame
     and metadata.
   - Inline display and full-screen player.
   - Video menu (Save to Photos, Share, Remove).
   - Blocks for sensitive notes and cloudApi.
   - Usable in local mode, and on the iPhone alone in cloudStorage (the video
     doesn't sync yet; the note text does).
3. **OneDrive sync:**
   - Chunked resumable upload, Wi-Fi gating and the mobile-data override.
   - Eager poster sync with lazy video download.
   - The "Still uploading" state, purge and GC for videos.
   - Backup placement (§5.4).
4. **Finishing:**
   - Keep offline, the 2 GB cache and eviction, Settings → Storage → Videos.
   - The notes-list video mark, iPad play-in-place.
   - Share/export placeholder text.

## 4. What exists today (facts from the codebase, 2026-11-12)

**Note content and attachments**
- Notes are markdown. Inline photos are `![alt](hmm-attachment://<vault path>)`
  (`lib/core/data/attachments/inline_ref_uri.dart`). A pending (unsaved) image
  uses `hmm-attachment://pending/<uuid>`, rewritten on save.
- Plain web and video links are already tappable markdown links, opened with
  `url_launcher` (`note_markdown_body.dart`). This comes from
  `docs/superpowers/specs/2026-07-11-note-inline-refs-and-secure-attachments-design.md`
  and the `2026-07-11-note-links-phase2` plan; this design extends it with
  cards.
- `NoteAttachments` (`lib/core/data/attachments/attachment_ref.dart`) has
  `primaryImage`, `images` and `files` slots. `files` carries PDF and audio,
  told apart by `contentType`. Audio renders as `NoteAudioCard`
  (`lib/features/notes/presentation/widgets/note_audio_card.dart`) via
  `note_file_card_list.dart`.

**Storage and sync**
- Storage interface: `IVaultStore` (`lib/core/data/vault/vault_store.dart`).
  It is byte-array only (`putBytes`, `getBytes`); there is no file-path or
  streaming API. Implementations: local, API, encrypted.
- The cap is 8 MB on every layer: `kMaxAttachmentBytes` in
  `attachments/picker/image_attachment_picker.dart`, plus the backend
  `MaxBytes`.
- `CloudSyncProvider` (`lib/core/data/sync/cloud_sync_provider.dart`) moves
  attachments as whole `Uint8List` (`pushAttachment`, `pullAttachment`,
  `listAttachmentPaths`).
  - OneDrive (`onedrive_graph_client.dart`) uploads with one simple PUT. Graph
    limits that to about 4 MB; larger files need `createUploadSession`.
  - The orchestrator pulls every missing attachment eagerly, one at a time.
- Purge and GC exist (`vault_gc.dart`, `pending_remote_purge_store.dart`).
- Sensitive attachments use single-pass AES-GCM (`encrypted_vault_store.dart`).

**Pickers, players and packages**
- `image_picker` is a dependency; `pickVideo` / `pickMedia` are never called.
- There is no video player package and nothing that makes video thumbnails.
- There are six separate MIME allow-lists across the client and backend.

**Deploy backup**
- `Hmm/scripts/hmm-release.sh` `ios_backup()` copies the app container's
  `Documents` and `Library/Application Support` with `devicectl`. Anything
  outside those two folders is not in the deploy backup.

## 5. Required behaviour of the parts (the how, where it was decided or is load-bearing)

### 5.1 Path-based storage for large files
- Add file-path operations alongside the existing byte methods. Examples:
  store from a source file path, give back a local file path, stream to or
  from a file. Small files (photos, PDF, audio) may keep using bytes.
- Every video operation (pick → copy in → poster → upload → download → play →
  share → save to Photos) works from files on disk. Memory use must not grow
  with video size.
- Copy-in from the picker should be a file move or copy, not a read into
  memory.
- The 8 MB cap stays for non-video attachments. Videos use the 500 MB warning
  and the 2 GB cap, checked from the file's size **before** copying.
- **Verify** that the picker path hands back the original file without
  re-encoding. On iOS some picker settings export or transcode video (for
  example to H.264 or a lower preset), and that would break the
  original-quality decision. Use passthrough or the original asset.

### 5.2 Provider-neutral large-file sync
- `CloudSyncProvider` gains large-file operations that any backend can
  implement: chunked resumable upload from a file path with progress,
  download to a file path with progress and cancel, and an existence check.
  OneDrive implements them with a Graph upload session. Its fragment size must
  be a multiple of 320 KiB, and the session URL is persisted so an upload
  resumes after an app restart or dropped connection.
- Video files are **excluded** from the eager attachment pull. Posters (small
  images) are pulled eagerly like photos.
- An upload queue is persisted, so a pending upload survives restarts. Each
  entry records note, path, bytes sent and session URL. The queue respects
  Wi-Fi gating (connectivity detection is needed) and the per-video
  mobile-data override.
- "Still uploading" on another device = the note references a video the cloud
  doesn't have yet. Re-check on each sync, and when play is tapped.
- Purge and GC treat video and poster paths like photo paths.

### 5.3 Note format and backward compatibility
- **Attached video:** referenced inline in the markdown at the position the
  user chose, and recorded in the note's attachments. The record holds
  content type, byte size, duration, width and height, poster path and
  original name.
- **Video link card:** the markdown keeps the **plain URL on its own line**,
  so any older build or plain renderer shows a working link. The saved preview
  (provider, title, length, thumbnail path) lives in the note's attachments
  data, keyed by URL.
- Per-device state is **not** synced: cached or not, Keep offline, upload
  progress.
- Builds from before stage 0 cannot meet the no-crash, no-corruption rule.
  So stage 0 is installed on every device first, and from then on the
  tolerate-and-preserve rule protects every later attachment type.

### 5.4 Where files live on the device
- **Not yet uploaded, or local mode:** inside the folders the deploy backup
  copies (`Documents` or `Library/Application Support`).
- **Already uploaded** (cache and Keep offline): in a Library location
  **outside** those two folders, excluded from iCloud device backup. It must
  not be purged by iOS for Keep offline videos, so it is not
  `Library/Caches`.
- An uploaded video moves from the first location to the second once its
  upload is confirmed.
- **Cache eviction never touches a video that hasn't finished uploading.**

### 5.5 Video links
- **YouTube:** IDs come from `youtube.com/watch?v=`, `youtu.be/`, `/shorts/`
  and `m.youtube.com`. Title and thumbnail come from YouTube oEmbed.
- **Bilibili:** `bilibili.com/video/BV…` (and `av…`) and `b23.tv` short links,
  resolving the redirect. Title, cover and duration come from Bilibili's
  public video info endpoint.
- **Fetching:** the device fetches directly (no Hmm server). The thumbnail is
  saved as a small image attachment that syncs like a photo.
- **Paste:** pasting a link alone on a line in the editor converts that line
  to a card after the preview fetch succeeds. If the fetch fails, the line
  stays a plain link, with no error dialog.

## 6. Left to the builder

### 6.1 Open technical choices
- The exact markdown syntax for an inline video and for marking a link line as
  a card.
- The exact JSON shape in `NoteAttachments` (new slot vs `files` with a
  `video/*` type), within §5.3.
- **YouTube length:** oEmbed doesn't return it. Get it some reasonable way
  without an API key, or hide the length badge for YouTube when it can't be
  had. Don't add a Google API key just for this.
- Which video player package. It must meet the player behaviour in §3.
  `video_player`/AVPlayer with custom controls, or a plugin that presents
  `AVPlayerViewController`, are both fine.
- How the poster and metadata are made: a thumbnail plugin or a small native
  call to `AVAssetImageGenerator`.
- The Save to Photos mechanism. Adding to the library needs
  `NSPhotoLibraryAddUsageDescription`.
- The connectivity package and how the cache tracks last-used time.
- How the six MIME allow-lists get `video/*`. Keep it to the client paths this
  project touches; the backend is out of scope.

### 6.2 Calls I made during the brainstorm (marked as mine, for the user to check)
- Videos not yet uploaded are never evicted from the cache.
- Nothing autoplays.
- The preview frame is generated on the adding device at add time.
- The picker shows progress while a video downloads from iCloud Photos.
- A failed link preview fetch leaves a plain link silently.
- Video links are allowed in sensitive notes and in cloudApi mode, because
  they need no file storage.
- Removing a video from a note in view mode (long press → Remove) commits
  immediately with Undo, per the app's `showUndoableAction` rule.
- The "Large video" warning only states the size and where it goes: "uses
  that much OneDrive space" in cloudStorage, "uses that much space on this
  device" in local mode. No quota call.
- The "if a note already has a video, adding a sensitive item later is
  allowed" rule in §3.

## 7. Project rules that apply
- Icon buttons use `HmmIconButton` with a localized tooltip, and Apple glyphs
  via `adaptiveIcon` on Notes screens.
- Every new string is in English and Chinese ARB files.
- New controls get help entries in `help_registry.dart`.
- Never `ref.watch` inside a `LayoutBuilder` builder (see the 2026-11 iPad
  full-screen bug).
- Deploys back up first and install over the existing app. Never uninstall.

## 8. Manual checks on device (per stage)
- **Stage 0:**
  - Both devices run the compat build.
  - A note whose JSON carries a `video/*` ref and an unknown key (made in a
    test build) opens and syncs.
  - Adding a photo to it keeps both entries.
- **Stage 1:**
  - Paste a YouTube, a youtu.be, a Shorts, a Bilibili BV and a b23.tv link.
    Each becomes a card.
  - Tap opens the app, and "◀ Hmm" returns to the note.
  - Offline, the card still shows.
  - The plain-renderer fallback shows the URL as a working link.
- **Stage 2:**
  - Add a 1 GB 4K video and a 2-minute screen recording on the iPhone. No
    crash, memory stays flat, the file is byte-identical to the original
    (compare sizes or hashes).
  - Over 2 GB is refused, and between 500 MB and 2 GB the warning shows.
  - A note with a sensitive image blocks videos, and no "sensitive video"
    option exists.
- **Stage 3:**
  - On mobile data the upload waits, and the override uploads.
  - Kill the app mid-upload; it resumes.
  - The iPad shows "Still uploading", then the poster. A tap downloads and
    plays.
  - Delete the note, empty Recently Deleted (or wait 30 days); the files leave
    OneDrive.
  - A deploy backup excludes uploaded videos and includes pending ones.
- **Stage 4:**
  - Keep offline survives "Clear downloaded videos".
  - The cache stays under 2 GB.
  - iPad inline play works.
  - The list mark shows.
  - A PDF export shows "▶ Video".
