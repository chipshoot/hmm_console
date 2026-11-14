import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/data/attachments/link_preview.dart';
import '../../../../core/data/attachments/picker/image_attachment_picker.dart'
    show AttachmentPickSource;
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/video/video_attachment_store.dart';
import '../../../../core/data/attachments/video/video_picker.dart';
import '../../../../core/data/attachments/video_attachment.dart';
import '../../../../core/data/data_mode.dart';
import '../../../../core/data/vault/encrypted_vault_store.dart'
    show VaultLockedException;
import '../../../../core/data/vault/vault_session.dart';
import '../widgets/inline_image_controller.dart';
import '../widgets/inline_insert.dart';
import '../widgets/note_link_picker.dart';
import '../widgets/note_markdown_body.dart';
import '../widgets/video_link_card.dart';
import '../../links/link_preview_fetcher.dart';
import '../../links/video_link.dart';
import '../../../../core/data/note_location.dart';
import '../../../../core/data/local/local_tag_repository.dart'
    show ITagRepository, normalizeTagName;
import '../../../../core/data/repository_providers.dart';
import '../../../gas_log/providers/location_provider.dart'
    show currentPositionProvider;
import '../../../settings/providers/geo_capture_provider.dart';
import '../../providers/note_location_capture.dart';
import '../widgets/note_file_card_list.dart';
import '../widgets/note_location_card.dart';
import '../widgets/note_tag_field.dart';
import '../widgets/record_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/util/uuid.dart';
import '../../data/subsystem_anchor.dart';
import '../../rendering/note_display.dart';
import '../../states/mutate_note_state.dart';
import '../../query/note_query.dart' show TagSource;
import '../../states/notes_list_state.dart';
import '../screens/note_detail_screen.dart' show noteDetailProvider;
import '../widgets/media_toolbar.dart';
import '../widgets/note_media_card_list.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId, this.presetParentId});
  final int? noteId; // null = create
  final int? presetParentId; // preset attach target for a new note
  bool get isNew => noteId == null;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _bodyFocus = FocusNode();
  int? _noteId; // becomes non-null once persisted
  int? _parentId;
  bool _parentTouched = false; // user changed the subsystem dropdown
  bool _busy = false;
  bool _loaded = false;

  /// Reusable inline-image capability: stages picked bytes + inserts placeholders
  /// for the live preview, and on save persists the picks and rewrites the body's
  /// `pending/<uuid>` placeholders to real vault paths.
  final InlineImageController _inline = InlineImageController();

  /// Images already attached to the note (when editing an existing note).
  List<AttachmentRef> _savedImages = [];

  /// The loaded note's full attachments payload, and the image paths that were
  /// referenced inline at load — used on save to detect images the user removed
  /// from the text so we can confirm before dropping them.
  NoteAttachments? _savedAttachments;
  List<String> _loadedInlinePaths = const [];

  /// PDF/files picked this session, not yet attached (attached on save).
  final List<PickedFileBytes> _pendingFiles = [];

  /// Files already attached to the note (when editing an existing note).
  List<AttachmentRef> _savedFiles = [];

  /// Editable note date shown under the title. New note: defaults to now.
  /// Existing note: the note's effectiveNoteDate. OneNote-style — tap to edit.
  late DateTime _noteDate;

  /// Captured/loaded note location (Phase 2b). Null = none. Shown as a card.
  NoteLocation? _pendingLocation;

  /// True once a persisted location was removed, so an update writes the clear.
  bool _locationCleared = false;

  /// Tag names shown in the tag field, and the names the note had when the
  /// editor opened (empty for a new note). Tags are written on save only if
  /// the two differ; [_tagsLoaded] is false for an existing note whose tags
  /// could not be read, so a save never overwrites them blind.
  List<String> _tagNames = [];
  List<String> _initialTagNames = [];
  bool _tagsLoaded = true;
  final _tagFieldKey = GlobalKey<NoteTagFieldState>();

  /// Videos picked this session, by the uuid of their `pending/` line.
  /// Persisted on save; their temp files are deleted when dropped.
  final Map<String, PickedVideo> _pendingVideos = {};

  /// Videos persisted to the vault but not yet written to the note's
  /// `videos` (a save that stopped part-way records them on the next save).
  final List<VideoAttachment> _unrecordedVideos = [];

  /// Link previews stored on the note, by URL.
  Map<String, LinkPreview> _savedLinks = {};

  /// Previews fetched this session, not yet saved (saved on save).
  final Map<String, FetchedLinkPreview> _pendingLinks = {};

  /// URLs already fetched this session, so a failed one is not retried.
  final Set<String> _linkAttempted = {};

  /// Fetches running now, by URL; Save waits for them (capped).
  final Map<String, Future<FetchedLinkPreview?>> _inFlight = {};

  /// Debounces link detection while typing.
  Timer? _detectTimer;

  /// Read once in initState, so no fetch reads `ref` after an await.
  late final LinkPreviewFetcher _fetcher;

  /// How long Save waits for link previews still being fetched.
  static const _fetchCap = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
    _parentId = widget.presetParentId;
    _noteDate = DateTime.now();
    _fetcher = ref.read(linkPreviewFetcherProvider);
    if (widget.noteId == null && widget.presetParentId == null) {
      // Opened from a tag's list: start with that tag. No lookup when the
      // list's live tag names are not loaded yet.
      final list = ref.read(notesListStateProvider).value;
      final source = list?.query.source;
      if (source is TagSource) {
        final name = list?.liveTagNames?[source.tagId];
        if (name != null) _tagNames = [name];
      }
    }
    if (widget.noteId != null) _tagsLoaded = false;
    if (widget.noteId == null) {
      _maybeCaptureLocation();
    }
  }

  /// For a new note, when the opt-in toggle is on, capture the current
  /// location in the background (non-blocking). Failures leave it null.
  Future<void> _maybeCaptureLocation() async {
    try {
      final enabled = await ref.read(geoCaptureEnabledProvider.future);
      if (!enabled || !mounted) return;
      // Force a fresh fix — both providers cache for the ProviderScope's
      // lifetime, so without this a second note would reuse the first note's
      // coordinates.
      ref.invalidate(currentPositionProvider);
      ref.invalidate(noteLocationCaptureProvider);
      final loc = await ref.read(noteLocationCaptureProvider.future);
      if (loc == null || !mounted) return;
      setState(() => _pendingLocation = loc);
    } catch (_) {
      // Best-effort: any failure ⇒ no card, no crash.
    }
  }

  @override
  void dispose() {
    _detectTimer?.cancel();
    for (final pick in _pendingVideos.values) {
      _deleteTemp(pick.tempPath);
    }
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_loaded || widget.noteId == null) return;
    _loaded = true;
    final note = await ref
        .read(hmmNoteRepositoryProvider)
        .getNoteById(widget.noteId!);
    if (note != null && mounted) {
      _subjectCtrl.text = note.subject;
      _bodyCtrl.text = note.content ?? '';
      _noteDate = note.effectiveNoteDate.toLocal();
      _savedAttachments = note.effectiveAttachments;
      _loadedInlinePaths = imageRefPathsIn(note.content ?? '');
      _savedImages = [
        if (note.effectiveAttachments.primaryImage != null)
          note.effectiveAttachments.primaryImage!,
        ...note.effectiveAttachments.images,
      ];
      // Reflect the note's real attachment so the dropdown isn't stuck on
      // "None". Don't mark it touched — an untouched dropdown must not
      // rewrite the parent on save.
      if (!_parentTouched) _parentId = note.parentNoteId;
      _pendingLocation = note.location;
      _savedFiles = [...note.effectiveAttachments.files];
      _savedLinks = {
        for (final p in note.effectiveAttachments.linkPreviews) p.url: p,
      };
      setState(() {});
      // A link line saved without a preview gets one now.
      _detectNow();
    }
    await _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final byNote = await ref
          .read(tagRepositoryProvider)
          .watchNoteTags()
          .first;
      if (!mounted) return;
      final names = [
        for (final t
            in byNote[widget.noteId] ?? const <({int id, String name})>[])
          t.name,
      ];
      setState(() {
        _initialTagNames = names;
        _tagNames = [...names];
        _tagsLoaded = true;
      });
    } catch (e) {
      debugPrint('note editor tags load: ${e.runtimeType}');
    }
  }

  bool get _tagsChanged {
    if (!_tagsLoaded) return false;
    Set<String> keys(List<String> v) => {
      for (final n in v) (normalizeTagName(n) ?? n).toLowerCase(),
    };
    final a = keys(_tagNames);
    final b = keys(_initialTagNames);
    return a.length != b.length || !a.containsAll(b);
  }

  /// Resolves the chosen names to tags (creating the missing ones) and sets
  /// the note's membership. Runs after the note itself is saved, only when
  /// the tags changed.
  Future<void> _saveTags(
    int noteId,
    MutateNote mutate,
    ITagRepository repo,
  ) async {
    final ids = <int>{};
    for (final n in _tagNames) {
      ids.add((await repo.ensureTag(n)).id);
    }
    await mutate.setTags(noteId, ids);
    _initialTagNames = [..._tagNames];
  }

  /// Persists the note (create or update) and returns its id.
  Future<int?> _save() async {
    final l = AppLocalizations.of(context);
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.notesSubjectRequired)));
      return null;
    }
    // Save-time-lock guard (Task B5, binding constraint): a sensitive pick
    // must be persisted only while the vault is unlocked. Checked BEFORE any
    // note mutation runs, so a cancelled/failed unlock aborts the whole save
    // — the staged pick (and its `pending/` placeholder) is left exactly as
    // it was. This runs ahead of `_persistInlineImages` → `resolveAndRewrite`,
    // whose `persist` swallows exceptions into "failed" and strips the
    // placeholder; a VaultLockedException must never reach that path.
    if (_inline.hasSensitivePendingIn(_bodyCtrl.text)) {
      final unlocked = await _ensureVaultUnlocked();
      if (!unlocked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unlock Secure Vault to save the sensitive image. Nothing was saved.',
              ),
            ),
          );
        }
        return null;
      }
    }
    // Typed-but-uncommitted tag text counts as a tag.
    _tagFieldKey.currentState?.commitPending();
    final mutate = ref.read(mutateNoteProvider);
    // Read before the awaits below (no ref use after an await), and only
    // when the tags changed: an untouched tag set never needs the repo.
    final tagRepo = _tagsChanged ? ref.read(tagRepositoryProvider) : null;
    final videoStore = _pendingVideos.isEmpty
        ? null
        : ref
              .read(videoAttachmentStoreProvider.future)
              .then<VideoAttachmentStore?>((s) => s, onError: (_) => null);
    setState(() => _busy = true);
    try {
      if (_noteId == null) {
        final note = await mutate.createGeneral(
          subject: subject,
          markdownBody: _bodyCtrl.text,
          parentNoteId: _parentId,
          noteDate: _noteDate.toUtc(),
          location: _pendingLocation,
        );
        _noteId = note.id;
      } else {
        // 2b has no edit-to-a-new-place path: we only ever clear a removed
        // location (NoteLocation.empty); otherwise pass null = don't touch.
        await mutate.updateGeneral(
          _noteId!,
          subject: subject,
          markdownBody: _bodyCtrl.text,
          noteDate: _noteDate.toUtc(),
          location: _locationCleared ? NoteLocation.empty : null,
        );
        // Persist the chosen subsystem only if the user changed it — covers
        // attach (id), detach (null), and re-link. An untouched dropdown
        // leaves the existing parent intact (avoids the async-load race).
        if (_parentTouched) {
          await mutate.setParent(_noteId!, _parentId);
        }
        ref.invalidate(noteDetailProvider(_noteId!));
      }
      // Order matters. Videos first: resolveAndRewrite strips every
      // `pending/` line it does not own, so video lines must be real by
      // then. Then images, which write the attachments loaded with the
      // note. Then the video record, read fresh so the image write is kept.
      if (_noteId != null) {
        if (videoStore != null) {
          await _persistPendingVideos(_noteId!, mutate, videoStore);
        }
        await _persistInlineImages(_noteId!, mutate);
        await _reconcileVideos(_noteId!, mutate);
        ref.invalidate(noteDetailProvider(_noteId!));
      }
      // Attach any PDFs added this session, then clear them.
      if (_pendingFiles.isNotEmpty && _noteId != null) {
        for (final pick in _pendingFiles) {
          await mutate.attachFileBytes(_noteId!, pick);
        }
        if (mounted) setState(() => _pendingFiles.clear());
        ref.invalidate(noteDetailProvider(_noteId!));
      }
      if (_noteId != null && tagRepo != null) {
        await _saveTags(_noteId!, mutate, tagRepo);
      }
      // Link previews last: saveLinkPreviews reads the note fresh, so the
      // writes above (body, images, files) are kept.
      if (_noteId != null) {
        await _saveLinkPreviews(_noteId!, mutate);
      }
      return _noteId;
    } on VaultLockedException {
      // Defense-in-depth for the B5 save-time TOCTOU: the vault relocked
      // (auto-lock) during one of the awaits above, after the top-of-method
      // guard already checked it unlocked. `resolveAndRewrite` rethrows this
      // instead of folding it into "failed" (which would silently strip the
      // sensitive placeholder), so the save aborts here with the same
      // data-safe UX as a cancelled unlock: nothing stripped, the staged
      // pick and its `pending/` placeholder are left exactly as they were.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unlock Secure Vault to save the sensitive image. Nothing was saved.',
            ),
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pick an image (gallery/camera) and insert it inline at the cursor as a
  /// pending placeholder. The bytes are staged for the live preview and
  /// persisted on the next save. No subject required to add.
  Future<void> _addMedia(AttachmentPickSource source) async {
    final pick = await ref.read(imageByteSourceProvider).pick(source);
    if (pick == null || !mounted) return;
    setState(() => _inline.stageAndInsert(_bodyCtrl, pick));
  }

  /// Pick an image and stage it marked sensitive (Task B5). Requires the
  /// vault to be unlocked before staging — driving the unlock/setup flow
  /// first — so a sensitive placeholder is never inserted without the vault
  /// having been unlocked at least once this session. The save path
  /// (`_save()`) re-checks at save time, since the session can relock
  /// (inactivity timeout / app backgrounded) between staging and saving.
  Future<void> _addSensitiveMedia(AttachmentPickSource source) async {
    final unlocked = await _ensureVaultUnlocked();
    if (!unlocked || !mounted) return;
    final pick = await ref.read(imageByteSourceProvider).pick(source);
    if (pick == null || !mounted) return;
    setState(
      () => _inline.stageAndInsert(_bodyCtrl, pick.copyWith(sensitive: true)),
    );
  }

  /// Ensures the Secure Vault is unlocked, prompting the user if needed.
  /// Returns true iff the vault is unlocked when this returns. Never throws.
  ///
  /// Blocker fix: VaultSessionController.build() cannot await, so it starts
  /// out `locked` and only refresh() computes the real state (see
  /// vault_session.dart). This is the editor's gate for BOTH the
  /// add-sensitive pick and the save-time guard, so it refreshes first —
  /// without this, a fresh install with no vault yet would read the stale
  /// `locked` default here, drive the unlock flow, and hit
  /// VaultKeyService.unlock's `StateError('vault not configured')` instead
  /// of routing to the "Set up Secure Vault in Settings" message below.
  Future<bool> _ensureVaultUnlocked() async {
    final l = AppLocalizations.of(context);
    await ref.read(vaultSessionProvider.notifier).refresh();
    final status = ref.read(vaultSessionProvider);
    if (status == VaultStatus.unlocked) return true;
    if (status == VaultStatus.absent || status == VaultStatus.corrupt) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Set up Secure Vault in Settings to add a sensitive image.',
            ),
          ),
        );
      }
      return false;
    }
    final ctrl = ref.read(vaultSessionProvider.notifier);
    if (await ctrl.unlockWithBiometric()) return true;
    if (!mounted) return false;
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _EditorVaultUnlockDialog(),
    );
    if (passphrase == null || passphrase.isEmpty) return false;
    final ok = await ctrl.unlockWithPassphrase(passphrase);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.vaultIncorrectPassphrase)));
    }
    return ok;
  }

  /// Persist each inline pending pick still referenced in the body, rewrite the
  /// `pending/<uuid>` placeholders to their real vault paths, save the rewritten
  /// body, and add the new refs to the note's attachments (so vault_gc retains
  /// them). Picks the user inserted then deleted before saving are dropped.
  Future<void> _persistInlineImages(int noteId, MutateNote mutate) async {
    // 1) Persist newly-picked inline images + rewrite their placeholders via the
    //    shared controller. A pick can fail (e.g. oversize photo) — a failed or
    //    missing pick's placeholder is stripped so no `pending/` URI survives.
    final before = _bodyCtrl.text;
    final result = await _inline.resolveAndRewrite(
      noteId: noteId,
      body: _bodyCtrl,
      persist: mutate.persistInlineImage,
    );
    // Persist the clean (rewritten/stripped) body so the store never keeps a
    // `pending/` placeholder — behaviour preserved from the pre-refactor editor.
    if (_bodyCtrl.text != before) {
      await mutate.updateGeneral(noteId, markdownBody: _bodyCtrl.text);
    }
    if (mounted) setState(() {}); // body text + staged bytes changed
    if (result.hadFailures && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Some images couldn't be added and were skipped."),
        ),
      );
    }

    // 2) Detect images that were inline at load but the user removed from the
    //    text. Never drop a stored image silently — confirm first.
    //    A saved video's line is not an image: _reconcileVideos asks about it.
    final removed = InlineImageController.removedImagePaths(
      _loadedInlinePaths,
      _bodyCtrl.text,
    ).where((p) => _savedAttachments?.videoForInlinePath(p) == null).toSet();
    var deleteRemoved = false;
    if (removed.isNotEmpty && mounted) {
      deleteRemoved = await _confirmRemoveImages(removed.length);
    }

    // 3) Reconcile the attachments retention set if anything changed.
    if (result.newRefs.isEmpty && removed.isEmpty) return;
    bool keep(AttachmentRef r) =>
        r is! VaultRef || !(deleteRemoved && removed.contains(r.path));
    final base = _savedAttachments ?? NoteAttachments.empty;
    final images = <AttachmentRef>[
      ...base.images.where(keep),
      for (final r in result.newRefs)
        if (!base.images.contains(r)) r,
    ];
    final primary = (base.primaryImage != null && keep(base.primaryImage!))
        ? base.primaryImage
        : null;
    await mutate.setAttachments(
      noteId,
      base.copyWith(
        primaryImage: primary,
        clearPrimaryImage: primary == null,
        images: images,
      ),
    );
  }

  /// Persists each picked video still in the body, rewrites its `pending/`
  /// line to the video's inline path, saves the body and records the
  /// persisted videos in the note's `videos`. A video that fails is stripped
  /// from the body; picks no longer in the body are dropped. Every dropped
  /// pick's temp file is deleted.
  Future<void> _persistPendingVideos(
    int noteId,
    MutateNote mutate,
    Future<VideoAttachmentStore?> storeFuture,
  ) async {
    // Take the picks out first: dispose deletes the temp files of whatever
    // is left in _pendingVideos, and these are being imported now.
    final pending = Map.of(_pendingVideos);
    _pendingVideos.clear();
    final referenced = {
      for (final uuid in pendingUuidsIn(_bodyCtrl.text))
        if (pending.containsKey(uuid)) uuid,
    };
    final store = referenced.isEmpty ? null : await storeFuture;
    final uuidToPath = <String, String>{};
    final added = <VideoAttachment>[];
    final failed = <String>[];
    for (final uuid in referenced) {
      final pick = pending[uuid]!;
      if (store == null) {
        failed.add(uuid);
        continue;
      }
      try {
        final v = await store.persist(noteId: noteId, pick: pick);
        uuidToPath[uuid] = v.inlinePath;
        added.add(v);
        // Until saveVideos below succeeds, a later save records it.
        _unrecordedVideos.add(v);
      } catch (e) {
        debugPrint('note editor: video persist failed (${e.runtimeType})');
        failed.add(uuid);
      }
    }
    var text = rewritePendingToVault(_bodyCtrl.text, uuidToPath);
    for (final uuid in failed) {
      text = removePendingImage(text, uuid);
    }
    for (final e in pending.entries) {
      if (!uuidToPath.containsKey(e.key)) _deleteTemp(e.value.tempPath);
    }
    if (text != _bodyCtrl.text) {
      _bodyCtrl.text = text;
      await mutate.updateGeneral(noteId, markdownBody: text);
    }
    // Record the videos now, so a later step that throws (a relocked vault
    // in the image step) cannot leave them out of the note. The image
    // step's attachments write starts from _savedAttachments, which then
    // already holds them.
    if (added.isNotEmpty) {
      final note = await mutate.saveVideos(
        noteId,
        added: added,
        removedInlinePaths: const {},
      );
      _unrecordedVideos.removeWhere(added.contains);
      if (note != null) _savedAttachments = note.effectiveAttachments;
    }
    if (mounted) {
      setState(() {});
      if (failed.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).notesVideoAddFailed),
          ),
        );
      }
    }
  }

  /// Writes the note's `videos`: adds the videos persisted this save whose
  /// lines are still in the body, and drops saved videos whose lines the
  /// user deleted, after confirming. Keep leaves them attached.
  Future<void> _reconcileVideos(int noteId, MutateNote mutate) async {
    final present = imageRefPathsIn(_bodyCtrl.text).toSet();
    final saved = _savedAttachments;
    final removed = <String>{
      for (final p in _loadedInlinePaths)
        if (saved?.videoForInlinePath(p) != null && !present.contains(p)) p,
    };
    if (removed.isNotEmpty) {
      final confirmed = mounted && await _confirmRemoveVideos(removed.length);
      if (!confirmed) removed.clear();
    }
    final added = [
      for (final v in _unrecordedVideos)
        if (present.contains(v.inlinePath)) v,
    ];
    if (added.isEmpty && removed.isEmpty) {
      _unrecordedVideos.clear();
      return;
    }
    final note = await mutate.saveVideos(
      noteId,
      added: added,
      removedInlinePaths: removed,
    );
    _unrecordedVideos.clear();
    if (note != null && mounted) {
      setState(() => _savedAttachments = note.effectiveAttachments);
    }
  }

  /// Asks whether to remove [count] saved videos whose lines were deleted.
  /// True = remove; Keep or dismiss = keep them attached.
  Future<bool> _confirmRemoveVideos(int count) async {
    final l = AppLocalizations.of(context);
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final title = Text(l.notesVideoRemoveConfirm(count));
    final dialog = isApple
        ? showCupertinoDialog<bool>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: title,
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l.notesVideoRemoveConfirmKeep),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l.notesVideoRemoveConfirmRemove),
                ),
              ],
            ),
          )
        : showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: title,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l.notesVideoRemoveConfirmKeep),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l.notesVideoRemoveConfirmRemove),
                ),
              ],
            ),
          );
    return await dialog ?? false;
  }

  /// Videos can't go into a note with sensitive items (saved or staged).
  bool get _videoBlockedBySensitive =>
      (_savedAttachments?.hasSensitive ?? false) ||
      _inline.hasSensitivePendingIn(_bodyCtrl.text);

  /// Picks a library video and inserts it at the cursor as a `pending/`
  /// line; it is persisted on save. Refused in cloudApi and in notes with
  /// sensitive items; a large video asks first.
  Future<void> _addVideo() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    void say(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));
    final mode = ref.read(dataModeProvider);
    if (mode == DataMode.cloudApi) {
      say(l.notesVideoNeedsOneDrive);
      return;
    }
    if (_videoBlockedBySensitive) {
      say(l.notesVideoSensitiveBlocked);
      return;
    }
    final PickedVideo? pick;
    try {
      pick = await ref.read(videoPickerProvider).pick();
    } on VideoPickException catch (e) {
      say(
        e.error == VideoPickError.tooLarge
            ? l.notesVideoTooLarge
            : l.notesVideoUnsupported,
      );
      return;
    } catch (e) {
      debugPrint('note editor: video pick failed (${e.runtimeType})');
      say(l.notesVideoAddFailed);
      return;
    }
    if (pick == null) return;
    if (!mounted) {
      _deleteTemp(pick.tempPath);
      return;
    }
    if (pick.verdict == VideoSizeVerdict.warn) {
      final ok = await _confirmLargeVideo(pick.byteSize, mode);
      if (!ok || !mounted) {
        _deleteTemp(pick.tempPath);
        return;
      }
    }
    final uuid = generateUuid();
    setState(() {
      _pendingVideos[uuid] = pick!;
      insertImageAtCursor(_bodyCtrl, uuid, 'Video');
    });
  }

  /// Warns about a large video's size. True = add it.
  Future<bool> _confirmLargeVideo(int bytes, DataMode mode) async {
    final l = AppLocalizations.of(context);
    final size = formatVideoSize(bytes);
    final body = Text(
      mode == DataMode.cloudStorage
          ? l.notesVideoLargeBodyCloud(size)
          : l.notesVideoLargeBodyLocal(size),
    );
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final dialog = isApple
        ? showCupertinoDialog<bool>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text(l.notesVideoLargeTitle),
              content: body,
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l.commonCancel),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l.notesVideoAdd),
                ),
              ],
            ),
          )
        : showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.notesVideoLargeTitle),
              content: body,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l.notesVideoAdd),
                ),
              ],
            ),
          );
    return await dialog ?? false;
  }

  /// Best-effort delete of a picked video's temp file.
  static void _deleteTemp(String path) {
    try {
      unawaited(File(path).delete().then<void>((_) {}, onError: (_) {}));
    } catch (_) {}
  }

  /// Saves the previews of the link lines still in the body. Detects any
  /// link not yet looked at, then waits up to [_fetchCap] for running
  /// fetches; one still running then is left out and its line stays plain.
  /// `saveLinkPreviews` keeps the stored previews whose lines remain (read
  /// fresh) and writes only on a change.
  Future<void> _saveLinkPreviews(int noteId, MutateNote mutate) async {
    _detectTimer?.cancel();
    _detectNow();
    final arrived = <String, FetchedLinkPreview>{};
    if (_inFlight.isNotEmpty) {
      await Future.wait([
        for (final e in _inFlight.entries)
          e.value.timeout(_fetchCap, onTimeout: () => null).then((r) {
            if (r != null) arrived[e.key] = r;
          }),
      ]);
    }
    final present = standaloneUrlsIn(_bodyCtrl.text);
    // No link lines now and none stored at load: nothing to keep or add.
    if (present.isEmpty && _savedLinks.isEmpty) return;
    final added = {
      ..._pendingLinks,
      ...arrived,
    }.values.where((p) => present.contains(p.url)).toList();
    final note = await mutate.saveLinkPreviews(
      noteId,
      presentUrls: present,
      added: added,
    );
    if (note == null || !mounted) return;
    setState(() {
      _savedAttachments = note.effectiveAttachments;
      _savedLinks = {
        for (final p in note.effectiveAttachments.linkPreviews) p.url: p,
      };
      _pendingLinks.clear();
    });
    ref.invalidate(noteDetailProvider(noteId));
  }

  /// Body changed: look for new link lines once typing pauses.
  void _scheduleDetect() {
    _detectTimer?.cancel();
    _detectTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _detectNow();
    });
  }

  /// Starts a fetch for every video link line not yet looked at.
  void _detectNow() {
    final urls = standaloneUrlsIn(_bodyCtrl.text);
    // A link line that was removed may be pasted again: forget it.
    _linkAttempted.removeWhere((u) => !urls.contains(u));
    for (final url in urls) {
      _fetchLink(url);
    }
  }

  /// Fetches a video link's preview once per session. Other links, and a
  /// failed fetch, leave the line a plain link.
  Future<void> _fetchLink(String url) async {
    if (parseVideoLink(url) == null) return;
    if (_savedLinks.containsKey(url) || _pendingLinks.containsKey(url)) {
      return;
    }
    if (!_linkAttempted.add(url)) return;
    final future = _fetcher.fetch(url);
    _inFlight[url] = future;
    final result = await future;
    _inFlight.remove(url);
    if (result == null || !mounted) return;
    setState(() => _pendingLinks[url] = result);
  }

  /// Asks for a video link and inserts it on its own line at the cursor,
  /// then fetches its preview straight away. Off Apple platforms the field
  /// is prefilled from a clipboard link; on iOS / macOS it starts empty
  /// (reading the clipboard there prompts; the user pastes instead).
  Future<void> _addVideoLink() async {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    var initial = '';
    if (!isApple) {
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text;
        if (text != null) initial = standaloneUrl(text) ?? '';
      } catch (_) {
        // No clipboard: start empty.
      }
      if (!mounted) return;
    }
    final dialog = isApple
        ? showCupertinoDialog<String>(
            context: context,
            builder: (_) => _AddVideoLinkDialog(initial: initial),
          )
        : showDialog<String>(
            context: context,
            builder: (_) => _AddVideoLinkDialog(initial: initial),
          );
    final url = await dialog;
    if (url == null || !mounted) return;
    setState(() => insertUrlLine(_bodyCtrl, url));
    _fetchLink(url);
  }

  /// Asks whether to delete stored images the user removed from the text.
  /// Returns true = delete them, false = keep them attached (default on
  /// dismiss). A stored image is never dropped without this confirmation.
  Future<bool> _confirmRemoveImages(int count) async {
    final l = AppLocalizations.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.notesRemoveStoredImagesTitle),
        content: Text(
          'You removed $count image${count == 1 ? '' : 's'} from this note. '
          'Delete the stored image${count == 1 ? '' : 's'}, or keep '
          '${count == 1 ? 'it' : 'them'} attached?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.notesKeepAttached),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  /// Pick a PDF and hold it pending — attaches on the next save.
  Future<void> _addFile() async {
    final pick = await ref.read(fileByteSourceProvider).pickPdf();
    if (pick != null && mounted) {
      setState(() => _pendingFiles.add(pick));
    }
  }

  /// Record a voice note (modal sheet) and hold it pending — attaches on save.
  Future<void> _addRecording() async {
    final pick = await showRecordSheet(context, ref);
    if (pick != null && mounted) {
      setState(() => _pendingFiles.add(pick));
    }
  }

  /// Pick a note from the searchable picker and insert an inline
  /// `[subject](hmm-note://uuid)` link at the cursor.
  Future<void> _addNoteLink() async {
    final note = await showNoteLinkPicker(context, ref, excludeNoteId: _noteId);
    if (note == null || !mounted) return;
    // The link text is the title the picker showed, never an id subject
    // such as `Contact:<id>`.
    final catalogName = ref
        .read(notesListStateProvider)
        .value
        ?.catalogsById[note.catalogId]
        ?.name;
    final title = ref
        .read(noteDisplayRegistryProvider)
        .title(note, catalogName, AppLocalizations.of(context));
    setState(() => insertNoteLinkAtCursor(_bodyCtrl, note.uuid, title));
  }

  String get _stampText =>
      '${DateFormat.yMMMMd().format(_noteDate)} · ${DateFormat.jm().format(_noteDate)}';

  /// OneNote-style: tap the date line to edit the note date (date + time).
  /// Cupertino modal on Apple; Material date-then-time on Android.
  Future<void> _pickNoteDate() async {
    final l = AppLocalizations.of(context);
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (isApple) {
      DateTime temp = _noteDate;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: Text(l.notesDone),
                      onPressed: () {
                        setState(() => _noteDate = temp);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _noteDate,
                  use24hFormat: false,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: _noteDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_noteDate),
      );
      if (!mounted) return;
      setState(() {
        _noteDate = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? _noteDate.hour,
          time?.minute ?? _noteDate.minute,
        );
      });
    }
  }

  /// Compact nav bar (no large title — the subject *is* the page title).
  PreferredSizeWidget _buildNav(BuildContext context, AppColors c) {
    final l = AppLocalizations.of(context);
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    Future<void> onSave() async {
      final id = await _save();
      if (id != null && context.mounted) context.pop();
    }

    if (isApple) {
      return CupertinoNavigationBar(
        backgroundColor: c.groupedBackground,
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
          onPressed: _busy ? null : onSave,
          child: Text(
            'Save',
            style: TextStyle(
              color: c.accent,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return AppBar(
      backgroundColor: c.groupedBackground,
      actions: [
        TextButton(onPressed: _busy ? null : onSave, child: Text(l.commonSave)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    _loadExisting();
    final c = context.appColors;
    // The keyboard's bottom inset lifts the in-body MediaToolbar above it;
    // surface the hide-keyboard affordance only while the keyboard is up.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Minor fix: Settings hides SecureVaultSection under cloudApi (there's
    // no filesystem-backed vault to set up there), so offering the
    // "add sensitive image" affordance in that mode is a dead end — tapping
    // it tells the user to "Set up Secure Vault in Settings", and no such
    // setting exists. Mirror the Settings gate here.
    final dataMode = ref.watch(dataModeProvider);
    // Cards for the link lines in the body: saved previews, then fetched.
    final present = standaloneUrlsIn(_bodyCtrl.text);
    final linkCards = <String, LinkCardData>{
      for (final p in _savedLinks.values)
        if (present.contains(p.url)) p.url: LinkCardData.fromPreview(p),
      for (final p in _pendingLinks.values)
        if (present.contains(p.url))
          p.url: LinkCardData(
            url: p.url,
            provider: p.provider,
            title: p.title,
            durationSeconds: p.durationSeconds,
            thumbnailBytes: p.thumbnailBytes,
          ),
    };
    return Scaffold(
      backgroundColor: c.groupedBackground,
      appBar: _buildNav(context, c),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subsystem attach — a control above / outside the note page.
          // Collapsed while the keyboard is up: it frees writing space and,
          // by leaving MediaToolbar as the Column's only fixed child, avoids
          // a RenderFlex overflow when a short (landscape) viewport shrinks
          // the Expanded body to nothing.
          if (!keyboardUp)
            _SubsystemStrip(
              parentId: _parentId,
              onChanged: (v) => setState(() {
                _parentId = v;
                _parentTouched = true;
              }),
            ),
          // The note page: borderless title · timestamp · one rule · canvas.
          Expanded(
            child: ColoredBox(
              color: c.secondaryGroupedBackground,
              // Scrollable so the body stays reachable above the keyboard once
              // images/cards fill the page — otherwise the fixed content above
              // it squeezes the body field to nothing and the input panel
              // covers it. The translucent GestureDetector keeps the
              // "tap anywhere on the canvas to write" affordance now that the
              // body no longer fills the whole page.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _bodyFocus.requestFocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _subjectCtrl,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: DesignTokens.titleLarge.copyWith(
                          color: c.label,
                          fontSize: 26,
                        ),
                        decoration: InputDecoration(
                          hintText: l.notesTitleHint,
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _busy ? null : _pickNoteDate,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _stampText,
                              style: DesignTokens.caption.copyWith(
                                color: c.tertiaryLabel,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_calendar_outlined,
                              size: 14,
                              color: c.tertiaryLabel,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      NoteTagField(
                        key: _tagFieldKey,
                        enabled: _tagsLoaded,
                        names: _tagNames,
                        onChanged: (v) => setState(() => _tagNames = v),
                      ),
                      if (_pendingLocation != null &&
                          !_pendingLocation!.isEmpty)
                        NoteLocationCard(
                          location: _pendingLocation!,
                          onRemove: () => setState(() {
                            _pendingLocation = null;
                            _locationCleared = true;
                          }),
                        ),
                      const SizedBox(height: 12),
                      Divider(height: 1, thickness: 1, color: c.separator),
                      const SizedBox(height: 12),
                      // Existing (already-saved) images that aren't shown
                      // inline in the body render as trailing cards. Newly
                      // picked images are inline (see the preview below).
                      NoteMediaCardList(
                        saved: _savedImages
                            .where(
                              (r) =>
                                  r is! VaultRef ||
                                  !imageRefPathsIn(
                                    _bodyCtrl.text,
                                  ).contains(r.path),
                            )
                            .toList(),
                      ),
                      NoteFileCardList(
                        saved: _savedFiles,
                        pending: _pendingFiles,
                        onRemovePending: (i) =>
                            setState(() => _pendingFiles.removeAt(i)),
                      ),
                      TextField(
                        controller: _bodyCtrl,
                        focusNode: _bodyFocus,
                        maxLines: null,
                        minLines: 8,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        // Rebuild so the inline-image preview and trailing-card
                        // dedup track edits (e.g. deleting an image line).
                        onChanged: (_) {
                          setState(() {});
                          _scheduleDetect();
                        },
                        style: TextStyle(
                          fontSize: 16,
                          color: c.label,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: l.notesBodyHint,
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                      if (_bodyCtrl.text.contains('hmm-attachment://') ||
                          linkCards.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Divider(height: 1, thickness: 1, color: c.separator),
                        const SizedBox(height: 8),
                        Text(
                          'Preview',
                          style: DesignTokens.caption.copyWith(
                            color: c.tertiaryLabel,
                          ),
                        ),
                        const SizedBox(height: 8),
                        NoteMarkdownBody(
                          data: _bodyCtrl.text,
                          pendingBytes: _inline.pendingBytes,
                          resolver: ref.watch(attachmentResolverProvider).value,
                          selectable: false,
                          linkCards: linkCards,
                          videos: {
                            for (final v
                                in _savedAttachments?.videos ??
                                    const <VideoAttachment>[])
                              v.inlinePath: v,
                          },
                          pendingVideos: _pendingVideos,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Lives in the body (not as bottomNavigationBar) so that the
          // Scaffold's resizeToAvoidBottomInset lifts it to sit just above
          // the software keyboard — the add-media controls stay reachable
          // while typing instead of being hidden behind the keyboard. The
          // trailing hide-keyboard button appears only while it's up.
          MediaToolbar(
            onPick: _addMedia,
            onPickSensitive: dataMode == DataMode.cloudApi
                ? null
                : _addSensitiveMedia,
            onPickFile: _addFile,
            onRecord: _addRecording,
            onLinkToNote: _addNoteLink,
            onAddVideoLink: _addVideoLink,
            onAddVideo: _addVideo,
            addVideoAvailable:
                dataMode != DataMode.cloudApi && !_videoBlockedBySensitive,
            enabled: !_busy,
            onDismissKeyboard: keyboardUp
                ? () => FocusScope.of(context).unfocus()
                : null,
          ),
        ],
      ),
    );
  }
}

/// The "Attach to subsystem" control, on a grey strip above the note page.
class _SubsystemStrip extends ConsumerWidget {
  const _SubsystemStrip({required this.parentId, required this.onChanged});

  final int? parentId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final anchorsAsync = ref.watch(subsystemAnchorsProvider);
    return Container(
      decoration: BoxDecoration(
        color: c.groupedBackground,
        border: Border(bottom: BorderSide(color: c.separator)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Attach to subsystem',
            style: DesignTokens.rowSecondary.copyWith(color: c.secondaryLabel),
          ),
          const Spacer(),
          anchorsAsync.maybeWhen(
            data: (anchors) {
              final value = anchors.any((a) => a.id == parentId)
                  ? parentId
                  : null;
              return Container(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                decoration: BoxDecoration(
                  color: c.secondaryGroupedBackground,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                  border: Border.all(color: c.separator),
                ),
                child: DropdownButton<int?>(
                  value: value,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusMedium,
                  ),
                  icon: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: c.secondaryLabel,
                  ),
                  style: DesignTokens.rowTitle.copyWith(
                    color: c.label,
                    fontSize: 15,
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(l.notesNone),
                    ),
                    for (final a in anchors)
                      DropdownMenuItem<int?>(
                        value: a.id,
                        child: Text(a.subject),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              );
            },
            orElse: () => const SizedBox(height: 20),
          ),
        ],
      ),
    );
  }
}

/// A video's size for the large-video warning, base 1024: whole MB below
/// 1 GiB ("742 MB"), else one-decimal GB ("1.3 GB").
@visibleForTesting
String formatVideoSize(int bytes) {
  const mib = 1024 * 1024;
  const gib = 1024 * mib;
  if (bytes < gib) return '${(bytes / mib).round()} MB';
  return '${(bytes / gib).toStringAsFixed(1)} GB';
}

/// Inserts [url] at [c]'s cursor (replacing any selection) as a line of its
/// own starting in column 0, and puts the cursor after that line. Adds a line
/// break only where one is missing; spaces before the cursor on its line are
/// dropped so the URL never starts indented.
@visibleForTesting
void insertUrlLine(TextEditingController c, String url) {
  final text = c.text;
  final sel = c.selection;
  final start = sel.isValid ? sel.start : text.length;
  final end = sel.isValid ? sel.end : text.length;
  final before = text.substring(0, start).replaceFirst(RegExp(r'[ \t]+$'), '');
  final after = text.substring(end);
  final lead = before.isEmpty || before.endsWith('\n') ? '' : '\n';
  final trail = after.isEmpty || after.startsWith('\n') ? '' : '\n';
  final head = '$before$lead$url$trail';
  final cursor = after.startsWith('\n') ? head.length + 1 : head.length;
  c.value = TextEditingValue(
    text: '$head$after',
    selection: TextSelection.collapsed(offset: cursor),
  );
}

/// One-field dialog for a video link. Pops the trimmed URL, or shows an
/// inline error when the text is not a single http(s) link.
class _AddVideoLinkDialog extends StatefulWidget {
  const _AddVideoLinkDialog({required this.initial});

  final String initial;

  @override
  State<_AddVideoLinkDialog> createState() => _AddVideoLinkDialogState();
}

class _AddVideoLinkDialogState extends State<_AddVideoLinkDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);
  bool _invalid = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final url = standaloneUrl(_ctrl.text);
    if (url == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    void onChanged(String _) {
      if (_invalid) setState(() => _invalid = false);
    }

    if (isApple) {
      return CupertinoAlertDialog(
        title: Text(l.notesAddVideoLinkTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoTextField(
                controller: _ctrl,
                autofocus: true,
                placeholder: l.notesAddVideoLinkHint,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: onChanged,
                onSubmitted: (_) => _submit(),
              ),
              if (_invalid)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.notesAddVideoLinkInvalid,
                    style: const TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _submit,
            child: Text(l.notesAddVideoLinkAdd),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(l.notesAddVideoLinkTitle),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: l.notesAddVideoLinkHint,
          errorText: _invalid ? l.notesAddVideoLinkInvalid : null,
        ),
        onChanged: onChanged,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.notesAddVideoLinkAdd)),
      ],
    );
  }
}

/// Minimal passphrase-entry dialog used by the editor's save-time unlock
/// guard (Task B5). Deliberately local/private rather than reusing the B4
/// `SecureVaultSection` dialogs, which are private to that widget — this is
/// a focused equivalent, not a shared export.
class _EditorVaultUnlockDialog extends StatefulWidget {
  const _EditorVaultUnlockDialog();

  @override
  State<_EditorVaultUnlockDialog> createState() =>
      _EditorVaultUnlockDialogState();
}

class _EditorVaultUnlockDialogState extends State<_EditorVaultUnlockDialog> {
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.vaultUnlockDialogTitle),
      content: TextField(
        controller: _passCtrl,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(labelText: l.vaultPassphrase),
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _passCtrl.text.isEmpty
              ? null
              : () => Navigator.of(context).pop(_passCtrl.text),
          child: Text(l.vaultUnlock),
        ),
      ],
    );
  }
}
