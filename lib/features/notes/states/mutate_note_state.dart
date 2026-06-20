import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/attachment_ref.dart';
import '../../../core/data/attachments/attachment_providers.dart';
import '../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../core/data/hmm_note_input.dart';
import '../../../core/data/note_location.dart';
import '../../../core/data/repository_providers.dart';
import '../data/general_catalog.dart';
import '../data/models/hmm_note.dart';

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

  Future<void> delete(int id) async {
    await ref.read(hmmNoteRepositoryProvider).deleteNote(id);
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
