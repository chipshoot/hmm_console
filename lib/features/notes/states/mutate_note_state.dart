import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../core/data/attachments/picker/file_byte_source.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/note_location.dart';
import '../../../core/data/repository_providers.dart';
import '../../../core/notes/note_state.dart';
import '../data/general_catalog.dart';
import '../data/models/hmm_note.dart';
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
    final note = await ref.read(hmmNoteRepositoryProvider).createNote(
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
    final note = await ref.read(hmmNoteRepositoryProvider).updateNote(
          id,
          HmmNoteUpdate(
              subject: subject?.trim(),
              content: markdownBody,
              noteDate: noteDate,
              location: location),
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
    final updated = NoteAttachments(
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
    final updated = NoteAttachments(
      primaryImage: existing.primaryImage,
      images: existing.images,
      files: [...existing.files, added],
    );
    return repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
  }

  /// Picks an image for [noteId] (which must already exist), appends it, and
  /// persists. Returns null if the user cancels.
  Future<HmmNote?> addImage(
    int noteId, {
    AttachmentPickSource source = AttachmentPickSource.gallery,
  }) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    final VaultRef? picked =
        await picker.pickForNote(noteId: noteId, source: source);
    if (picked == null) return null;

    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final updated = NoteAttachments(
      primaryImage: existing.primaryImage ?? picked,
      images: existing.primaryImage == null
          ? existing.images
          : [...existing.images, picked],
    );
    final note =
        await repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
    return note;
  }
}

final mutateNoteProvider = Provider<MutateNote>((ref) => MutateNote(ref));
