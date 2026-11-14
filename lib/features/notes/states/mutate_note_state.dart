import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/link_preview.dart';
import '../../../core/data/attachments/video_attachment.dart';
import '../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/note_location.dart';
import '../../../core/data/repository_providers.dart';
import '../../../core/notes/note_state.dart';
import '../data/general_catalog.dart';
import '../data/models/hmm_note.dart';
import '../links/link_preview_fetcher.dart';
import 'note_delete_policy.dart';

class MutateNote {
  MutateNote(this.ref);
  final Ref ref;

  Future<HmmNote> createGeneral({
    required String subject,
    String? markdownBody,
    int? parentNoteId,
    DateTime? noteDate,
    NoteLocation? location,
  }) async {
    final catalog = await ensureGeneralCatalog(ref);
    final note = await ref
        .read(hmmNoteRepositoryProvider)
        .createNote(
          HmmNoteCreate(
            subject: subject.trim(),
            catalogId: catalog.id,
            content: markdownBody,
            parentNoteId: parentNoteId,
            noteDate: noteDate,
            location: location,
          ),
        );
    // The notes list watches the Notes table reactively, so no manual
    // invalidation is needed here (see notes_list_state.dart).
    return note;
  }

  /// Re-link an existing note onto [parentNoteId].
  Future<HmmNote> attachExisting(int noteId, int parentNoteId) =>
      ref.read(hmmNoteRepositoryProvider).setParentNote(noteId, parentNoteId);

  /// Detach a note (back to standalone).
  Future<HmmNote> detachNote(int noteId) =>
      ref.read(hmmNoteRepositoryProvider).setParentNote(noteId, null);

  /// Set a note's parent to [parentNoteId] (non-null attaches/re-links, null
  /// detaches). One call that covers attach, detach, and change.
  Future<HmmNote> setParent(int noteId, int? parentNoteId) =>
      ref.read(hmmNoteRepositoryProvider).setParentNote(noteId, parentNoteId);

  Future<HmmNote> updateGeneral(
    int id, {
    String? subject,
    String? markdownBody,
    DateTime? noteDate,
    NoteLocation? location,
  }) async {
    final note = await ref
        .read(hmmNoteRepositoryProvider)
        .updateNote(
          id,
          HmmNoteUpdate(
            subject: subject?.trim(),
            content: markdownBody,
            noteDate: noteDate,
            location: location,
          ),
        );
    return note;
  }

  /// Move an ordinary note to Recently Deleted (soft delete). Entity notes
  /// are refused with [EntityNoteDeleteRefused] — their own feature owns
  /// their delete (G7).
  Future<void> delete(int id) async {
    final repo = ref.read(hmmNoteRepositoryProvider);
    final note = await repo.getNoteById(id);
    if (note == null) return;
    final catalogName = await _catalogNameOf(note);
    if (!canDeleteFromNotes(note, catalogName)) {
      throw EntityNoteDeleteRefused(
        managePlaceFor(catalogName) ?? NoteManagePlace.ownScreen,
      );
    }
    await repo.deleteNote(id);
  }

  /// Undo a delete (clear deletedAt with a newer lastModifiedDate).
  Future<HmmNote> restore(int id) =>
      ref.read(hmmNoteRepositoryProvider).restoreNote(id);

  /// Pin or unpin (G14: writes the note's state row only — not a note
  /// edit, so it never bumps the note or re-pushes it).
  Future<NoteState> setPinned(int id, bool pinned) async => ref
      .read(noteStateRepositoryProvider)
      .setPinned(await _uuidOf(id), pinned);

  /// [flagColor] null clears the flag. Same state-only semantics as
  /// [setPinned].
  Future<NoteState> setFlagColor(int id, int? flagColor) async => ref
      .read(noteStateRepositoryProvider)
      .setFlagColor(await _uuidOf(id), flagColor);

  /// Set-replace a note's tags. Unlike pin / flag this IS a note edit: a
  /// changed set bumps the note so it re-syncs (an unchanged set is a no-op).
  Future<void> setTags(int noteId, Set<int> tagIds) =>
      ref.read(tagRepositoryProvider).setNoteTags(noteId, tagIds);

  Future<String> _uuidOf(int id) async {
    final note = await ref.read(hmmNoteRepositoryProvider).getNoteById(id);
    if (note == null) throw StateError('Note $id not found');
    // A state keyed by '' would match no note and sync as garbage.
    if (note.uuid.isEmpty) throw StateError('Note $id has no uuid');
    return note.uuid;
  }

  Future<String?> _catalogNameOf(HmmNote note) async {
    final cid = note.catalogId;
    if (cid == null) return null;
    return (await ref.read(noteCatalogRepositoryProvider).getCatalogById(cid))
        ?.name;
  }

  /// Persist already-picked [pick] bytes into the note's vault and append the
  /// resulting VaultRef to the note's attachments (first image becomes the
  /// primary). Used by the editor's attach-on-save flow.
  Future<HmmNote?> attachImageBytes(int noteId, PickedImageBytes pick) async {
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
    final updated = existing.copyWith(
      primaryImage: existing.primaryImage ?? added,
      images: existing.primaryImage == null
          ? existing.images
          : [...existing.images, added],
    );
    return repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
  }

  /// Persists [pick]'s bytes to the vault under [noteId] and returns the
  /// resulting VaultRef. Does not modify the note's attachments column — the
  /// caller reconciles attachments once, after rewriting the body (used by the
  /// editor's inline-image save path).
  Future<VaultRef> persistInlineImage(int noteId, PickedImageBytes pick) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    return picker.persistToVault(
      noteId: noteId,
      bytes: pick.bytes,
      originalName: pick.originalName,
      contentTypeHint: pick.contentType,
      sensitive: pick.sensitive,
    );
  }

  /// Writes the note's attachments column verbatim (the retention set that
  /// `vault_gc` reads).
  Future<HmmNote?> setAttachments(int noteId, NoteAttachments attachments) {
    return ref
        .read(hmmNoteRepositoryProvider)
        .updateNote(noteId, HmmNoteUpdate(attachments: attachments));
  }

  /// Removes [v] from the note: every `![alt](hmm-attachment://<inlinePath>)`
  /// in the body and the matching `videos` entry (other slots, preserved
  /// entries and unknown data are kept). Returns the previous body and
  /// attachments for undo, or null when the note is gone.
  Future<({String body, NoteAttachments attachments})?> removeVideo(
    int noteId,
    VideoAttachment v,
  ) async {
    final repo = ref.read(hmmNoteRepositoryProvider);
    final note = await repo.getNoteById(noteId);
    if (note == null) return null;
    final body = note.content ?? '';
    final before = note.effectiveAttachments;
    final line = RegExp(
      r'!\[[^\]]*\]\(hmm-attachment://' + RegExp.escape(v.inlinePath) + r'\)',
    );
    final nextBody = body.replaceAll(line, '');
    final nextAtts = before.copyWith(
      videos: [
        for (final e in before.videos)
          if (e.video.path != v.video.path) e,
      ],
    );
    await repo.updateNote(
      noteId,
      HmmNoteUpdate(content: nextBody, attachments: nextAtts),
    );
    return (body: body, attachments: before);
  }

  /// Sets the note's videos from a fresh read: the stored videos whose
  /// `inlinePath` is not in [removedInlinePaths], then each of [added] not
  /// already stored (by video path). Rebuilt with `copyWith`, so every other
  /// slot (including preserved and unknown data) is kept. Writes only when
  /// the list changes; returns the note either way, or null when it is gone.
  Future<HmmNote?> saveVideos(
    int noteId, {
    required List<VideoAttachment> added,
    required Set<String> removedInlinePaths,
  }) async {
    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final kept = [
      for (final v in existing.videos)
        if (!removedInlinePaths.contains(v.inlinePath)) v,
    ];
    final keptPaths = {for (final v in kept) v.video.path};
    final next = [
      ...kept,
      for (final v in added)
        if (keptPaths.add(v.video.path)) v,
    ];
    if (const ListEquality<VideoAttachment>().equals(next, existing.videos)) {
      return current;
    }
    return repo.updateNote(
      noteId,
      HmmNoteUpdate(attachments: existing.copyWith(videos: next)),
    );
  }

  /// Writes [body] and [attachments] back verbatim (undo of [removeVideo]).
  Future<void> restoreBodyAndAttachments(
    int noteId,
    String body,
    NoteAttachments attachments,
  ) async {
    await ref
        .read(hmmNoteRepositoryProvider)
        .updateNote(
          noteId,
          HmmNoteUpdate(content: body, attachments: attachments),
        );
  }

  /// Sets the note's link previews from a fresh read: the stored previews
  /// whose URL is in [presentUrls] (so one synced from another device in the
  /// meantime survives), then each of [added] not already stored. Each added
  /// thumbnail is persisted to the vault first; one that fails to persist
  /// leaves its preview without a thumbnail. The attachments are rebuilt
  /// with `copyWith`, so every other slot (including preserved and unknown
  /// data) is kept. Writes only when the list changes; returns the note
  /// either way, or null when it is gone.
  Future<HmmNote?> saveLinkPreviews(
    int noteId, {
    required Set<String> presentUrls,
    required List<FetchedLinkPreview> added,
  }) async {
    final repo = ref.read(hmmNoteRepositoryProvider);
    final stored = (await repo.getNoteById(noteId))?.effectiveAttachments;
    final storedUrls = {...?stored?.linkPreviews.map((p) => p.url)};
    final saved = <LinkPreview>[];
    for (final f in added) {
      if (storedUrls.contains(f.url) || !presentUrls.contains(f.url)) {
        continue;
      }
      VaultRef? thumb;
      final bytes = f.thumbnailBytes;
      if (bytes != null && bytes.isNotEmpty) {
        try {
          final picker = await ref.read(imageAttachmentPickerProvider.future);
          thumb = await picker.persistToVault(
            noteId: noteId,
            bytes: bytes,
            originalName: 'link-thumb',
            contentTypeHint: f.thumbnailContentType,
          );
        } catch (_) {
          thumb = null;
        }
      }
      saved.add(
        LinkPreview(
          url: f.url,
          provider: f.provider,
          title: f.title,
          durationSeconds: f.durationSeconds,
          thumbnail: thumb,
        ),
      );
    }
    // Read again: the thumbnail writes above took time.
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final kept = existing.linkPreviews.where(
      (p) => presentUrls.contains(p.url),
    );
    final keptUrls = {for (final p in kept) p.url};
    final next = [
      ...kept,
      for (final p in saved)
        if (!keptUrls.contains(p.url)) p,
    ];
    if (const ListEquality<LinkPreview>().equals(next, existing.linkPreviews)) {
      return current;
    }
    final updated = existing.copyWith(linkPreviews: next);
    return repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
  }

  /// Persist a picked PDF's bytes into the note's vault and append the
  /// resulting VaultRef to the note's `files` list.
  Future<HmmNote?> attachFileBytes(int noteId, PickedFileBytes pick) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    final added = await picker.persistFileToVault(
      noteId: noteId,
      bytes: pick.bytes,
      originalName: pick.originalName,
      contentType: pick.contentType ?? 'application/pdf',
    );
    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final updated = existing.copyWith(files: [...existing.files, added]);
    return repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
  }

  /// Picks an image for [noteId] (which must already exist), appends it, and
  /// persists. Returns null if the user cancels.
  Future<HmmNote?> addImage(
    int noteId, {
    AttachmentPickSource source = AttachmentPickSource.gallery,
  }) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    final VaultRef? picked = await picker.pickForNote(
      noteId: noteId,
      source: source,
    );
    if (picked == null) return null;

    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final updated = existing.copyWith(
      primaryImage: existing.primaryImage ?? picked,
      images: existing.primaryImage == null
          ? existing.images
          : [...existing.images, picked],
    );
    final note = await repo.updateNote(
      noteId,
      HmmNoteUpdate(attachments: updated),
    );
    return note;
  }
}

final mutateNoteProvider = Provider<MutateNote>((ref) => MutateNote(ref));
